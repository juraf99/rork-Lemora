import SwiftUI

struct MealPlanView: View {
    @Environment(AppStore.self) private var store
    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    @State private var showingRecipePicker = false
    @State private var activeSlot: MealSlot = .lunch
    @State private var weekOffset = 0

    private var calendar: Calendar {
        var cal = Calendar.current
        cal.locale = AppLanguage.current.locale
        return cal
    }

    private var weekDates: [Date] {
        let today = calendar.startOfDay(for: Date())
        let start = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) ?? today
        let shifted = calendar.date(byAdding: .day, value: weekOffset * 7, to: start) ?? start
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: shifted) }
    }

    private var weekEntries: [MealPlanEntry] {
        store.data.mealPlan.filter { entry in
            weekDates.contains { calendar.isDate($0, inSameDayAs: entry.date) }
        }
    }

    private var savedThisWeek: Double {
        store.data.cookLogs.filter { log in
            weekDates.contains { calendar.isDate($0, inSameDayAs: log.date) }
        }.reduce(0) { $0 + $1.savings }
    }

    private var mealsLeft: Int { weekEntries.filter { !$0.isEaten }.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                dayStrip
                dayMeals
                variety
                Text("Past meals count as eaten automatically. Their savings are already in your total.")
                    .font(.bw(.footnote, weight: .medium))
                    .foregroundStyle(BW.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                groceryButton
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .onAppear {
            store.settlePastMeals()
            if !weekDates.contains(where: { calendar.isDate($0, inSameDayAs: selectedDate) }) {
                selectedDate = weekDates.first ?? selectedDate
            }
        }
        .sheet(isPresented: $showingRecipePicker) {
            RecipePickerSheet(slot: activeSlot, date: selectedDate)
                .environment(store)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Button { weekOffset -= 1 } label: {
                        Image(systemName: "chevron.left").font(.caption.weight(.bold))
                    }
                    if let first = weekDates.first, let last = weekDates.last {
                        Text(weekLabel(first: first, last: last))
                            .font(.bw(.title2))
                            .foregroundStyle(BW.ink)
                    }
                    Button { weekOffset += 1 } label: {
                        Image(systemName: "chevron.right").font(.caption.weight(.bold))
                    }
                }
                .foregroundStyle(BW.ink)
                Text(budgetLine)
                    .font(.bw(.subheadline, weight: .medium))
                    .foregroundStyle(BW.inkSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(Money.format(savedThisWeek))
                    .font(.bw(.title2))
                    .foregroundStyle(BW.leafDeep)
                    .monospacedDigit()
                Text("saved so far")
                    .font(.bw(.caption, weight: .medium))
                    .foregroundStyle(BW.leafDeep)
            }
        }
    }

    private var budgetLine: String {
        if let budget = store.data.profile.weeklyBudget {
            return String(localized: "\(weekEntries.count) meals · \(Money.format(budget)) / week budget")
        }
        return String(localized: "\(weekEntries.count) meals")
    }

    private func weekLabel(first: Date, last: Date) -> String {
        let f = DateFormatter()
        f.locale = AppLanguage.current.locale
        f.setLocalizedDateFormatFromTemplate("MMMd")
        return "\(f.string(from: first)) – \(f.string(from: last))"
    }

    private var dayStrip: some View {
        HStack(spacing: 6) {
            ForEach(weekDates, id: \.self) { date in
                let on = calendar.isDate(date, inSameDayAs: selectedDate)
                let hasMeal = weekEntries.contains { calendar.isDate($0.date, inSameDayAs: date) }
                Button { selectedDate = date } label: {
                    VStack(spacing: 2) {
                        Text(weekday(date))
                            .font(.system(size: 10, weight: .bold))
                        Text(dayNumber(date))
                            .font(.bw(.subheadline, weight: .heavy))
                        Circle()
                            .fill(hasMeal ? (on ? Color.white : BW.leaf) : Color.clear)
                            .frame(width: 5, height: 5)
                    }
                    .foregroundStyle(on ? Color.white : BW.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(on ? BW.ink : BW.card, in: .rect(cornerRadius: 16))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func weekday(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = AppLanguage.current.locale
        f.setLocalizedDateFormatFromTemplate("EEE")
        return f.string(from: date).uppercased()
    }

    private func dayNumber(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = AppLanguage.current.locale
        f.setLocalizedDateFormatFromTemplate("d")
        return f.string(from: date)
    }

    private var dayMeals: some View {
        VStack(spacing: 10) {
            ForEach([MealSlot.breakfast, .lunch, .dinner], id: \.self) { slot in
                slotCard(slot)
            }
        }
    }

    @ViewBuilder
    private func slotCard(_ slot: MealSlot) -> some View {
        let entry = store.data.mealPlan.first {
            calendar.isDate($0.date, inSameDayAs: selectedDate) && $0.mealType == slot
        }
        if let entry, let recipe = store.recipe(id: entry.recipeId) {
            let price = store.price(for: recipe)
            HStack(spacing: 12) {
                FoodImage(name: recipe.imageName, height: 64, radius: 14)
                    .frame(width: 64)
                VStack(alignment: .leading, spacing: 3) {
                    Text(slot.label.uppercased())
                        .font(.bw(.caption2, weight: .heavy))
                        .foregroundStyle(BW.inkSecondary)
                    Text(recipe.title)
                        .font(.bw(.headline))
                        .foregroundStyle(BW.ink)
                        .lineLimit(1)
                    Text(priceLine(price))
                        .font(.bw(.caption, weight: .semibold))
                        .foregroundStyle(BW.leafDeep)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                if entry.isEaten {
                    Text("Eaten")
                        .font(.bw(.caption, weight: .heavy))
                        .foregroundStyle(BW.leafDeep)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(BW.leafSoft, in: Capsule())
                } else {
                    Button { store.eatMeal(entry.id) } label: {
                        Text("Mark eaten")
                            .font(.bw(.caption, weight: .heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(BW.ink, in: Capsule())
                    }
                    .buttonStyle(BWPressableStyle())
                }
            }
            .padding(12)
            .background(BW.card, in: .rect(cornerRadius: 20))
        } else {
            Button {
                activeSlot = slot
                showingRecipePicker = true
            } label: {
                HStack {
                    Text(slot.label)
                        .font(.bw(.subheadline, weight: .heavy))
                    Spacer()
                    Image(systemName: "plus")
                        .font(.subheadline.weight(.bold))
                }
                .foregroundStyle(BW.inkSecondary)
                .padding(16)
                .background(BW.card, in: .rect(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(BW.hairline, style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
            }
            .buttonStyle(.plain)
        }
    }

    private func priceLine(_ price: RecipePrice) -> String {
        let each = Money.format(price.perServing)
        if price.savings > 0.01 {
            return String(localized: "\(each) / serving · saves \(Money.format(price.savings))")
        }
        return String(localized: "\(each) / serving")
    }

    private var variety: some View {
        let recipes = weekEntries.compactMap { store.recipe(id: $0.recipeId) }
        let proteins = Set(recipes.map(\.mainProtein).filter { !$0.isEmpty })
        let cuisines = Set(recipes.map(\.cuisine))
        let repeats = hasRepeat(recipes.map(\.id))
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                chip(String(localized: "\(proteins.count) proteins this week"), fill: BW.leafSoft)
                chip(String(localized: "\(cuisines.count) cuisines"), fill: BW.lemonSoft)
            }
            Text(repeats ? String(localized: "A meal repeats within 2 days") : String(localized: "No repeat 2 days in a row"))
                .font(.bw(.subheadline, weight: .semibold))
                .foregroundStyle(BW.ink)
        }
    }

    private func hasRepeat(_ ids: [String]) -> Bool {
        let ordered = weekDates.flatMap { day in
            weekEntries.filter { calendar.isDate($0.date, inSameDayAs: day) }.map(\.recipeId)
        }
        guard ordered.count > 1 else { return false }
        for index in 1..<ordered.count where ordered[index] == ordered[index - 1] { return true }
        return ids.count != Set(ids).count && ordered.count > 2
    }

    private func chip(_ text: String, fill: Color) -> some View {
        Text(text)
            .font(.bw(.caption, weight: .heavy))
            .foregroundStyle(BW.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(fill, in: Capsule())
    }

    private var groceryButton: some View {
        Button {
            store.generateGroceryFromMealPlan(weekDates: weekDates)
        } label: {
            Text(weekEntries.isEmpty
                 ? String(localized: "Generate grocery list")
                 : String(localized: "Generate grocery list · \(mealsLeft) meals left"))
                .font(.bw(.headline, weight: .heavy))
                .foregroundStyle(BW.ink)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color(hex: 0xEFD35A), in: Capsule())
        }
        .buttonStyle(BWPressableStyle())
        .disabled(weekEntries.isEmpty)
        .opacity(weekEntries.isEmpty ? 0.45 : 1)
    }
}

struct RecipePickerSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let slot: MealSlot
    let date: Date
    @State private var search = ""

    private var recipes: [Recipe] {
        let liked = store.likedIds.compactMap { store.recipe(id: $0) }
        let pool = liked.isEmpty ? store.data.saved.compactMap { store.recipe(id: $0.recipeId) } : liked
        let matched = pool.filter { $0.mealType.rawValue == slot.rawValue || slot == .snack }
        let base = matched.isEmpty ? pool : matched
        if search.isEmpty { return base }
        return base.filter { $0.title.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationStack {
            List(recipes) { recipe in
                Button {
                    store.addToMealPlan(recipeId: recipe.id, date: date, slot: slot)
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        FoodImage(name: recipe.imageName, height: 50, radius: 8)
                            .frame(width: 50)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(recipe.title)
                                .font(.bw(.subheadline, weight: .bold))
                                .foregroundStyle(BW.ink)
                            if let price = store.price(for: recipe).perServing {
                                Text(String(localized: "\(Money.format(price)) / serving"))
                                    .font(.bw(.caption2, weight: .medium))
                                    .foregroundStyle(BW.inkSecondary)
                            }
                        }
                        Spacer()
                    }
                }
            }
            .searchable(text: $search, prompt: Text("Search liked recipes"))
            .navigationTitle(Text("Add \(slot.label)"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
