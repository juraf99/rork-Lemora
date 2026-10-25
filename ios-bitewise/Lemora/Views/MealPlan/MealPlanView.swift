import SwiftUI

// MARK: - MealPlanView

struct MealPlanView: View {
    @EnvironmentObject private var store: AppStore
    @State private var selectedDate = Date()
    @State private var showingRecipePicker = false
    @State private var activeSlot: MealSlot = .lunch
    @State private var weekOffset = 0

    private var weekDates: [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let weekStart = cal.date(byAdding: .day, value: weekOffset * 7, to: cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!) else { return [] }
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: weekStart) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                weekSelector
                dayCards
                groceryButton
            }
            .padding()
        }
        .navigationTitle("Meal Plan")
        .sheet(isPresented: $showingRecipePicker) {
            RecipePickerSheet(slot: activeSlot, date: selectedDate)
                .environmentObject(store)
        }
    }

    // MARK: - Week Selector

    private var weekSelector: some View {
        HStack {
            Button { weekOffset -= 1 } label: {
                Image(systemName: "chevron.left")
                    .font(.bw(.body, weight: .bold))
                    .foregroundStyle(BW.ink)
            }
            Spacer()
            if let first = weekDates.first, let last = weekDates.last {
                Text(weekLabel(first: first, last: last))
                    .font(.bw(.headline, weight: .bold))
                    .foregroundStyle(BW.ink)
            }
            Spacer()
            Button { weekOffset += 1 } label: {
                Image(systemName: "chevron.right")
                    .font(.bw(.body, weight: .bold))
                    .foregroundStyle(BW.ink)
            }
        }
        .padding(.horizontal, 4)
    }

    private func weekLabel(first: Date, last: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return "\(f.string(from: first)) \u{2013} \(f.string(from: last))"
    }
    // MARK: - Day Cards

    private var dayCards: some View {
        ForEach(weekDates, id: \.self) { date in
            dayCard(for: date)
        }
    }

    private func dayCard(for date: Date) -> some View {
        let cal = Calendar.current
        let isToday = cal.isDateInToday(date)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(dayLabel(date))
                    .font(.bw(.subheadline, weight: .bold))
                    .foregroundStyle(isToday ? BW.leafDeep : BW.ink)
                if isToday {
                    Text("Today")
                        .font(.bw(.caption2, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(BW.leafDeep, in: Capsule())
                }
                Spacer()
            }

            ForEach(MealSlot.allCases, id: \.self) { slot in
                slotRow(slot: slot, date: date)
            }
        }
        .padding(14)
        .background(BW.card, in: .rect(cornerRadius: 14))
    }

    private func dayLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: date)
    }

    // MARK: - Slot Row

    private func slotRow(slot: MealSlot, date: Date) -> some View {
        let entry = store.data.mealPlan.first {
            Calendar.current.isDate($0.date, inSameDayAs: date) && $0.mealType == slot
        }

        return HStack(spacing: 10) {
            Image(systemName: slot.icon)
                .font(.caption)
                .foregroundStyle(BW.inkSecondary)
                .frame(width: 20)

            if let entry = entry, let recipe = store.recipe(id: entry.recipeId) {
                HStack {
                    Text(recipe.title)
                        .font(.bw(.caption, weight: .medium))
                        .foregroundStyle(BW.ink)
                        .lineLimit(1)
                    Spacer()
                    if entry.isEaten {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(BW.leafDeep)
                    } else {
                        Button {
                            store.markMealEaten(entry.id)
                        } label: {
                            Text("Eaten")
                                .font(.bw(.caption2, weight: .bold))
                                .foregroundStyle(BW.leafDeep)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(BW.leafDeep.opacity(0.12), in: Capsule())
                        }
                    }
                    Button {
                        store.removeMealPlanEntry(entry.id)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(BW.inkSecondary.opacity(0.5))
                    }
                }
            } else {
                Button {
                    selectedDate = date
                    activeSlot = slot
                    showingRecipePicker = true
                } label: {
                    HStack {
                        Text(slot.label)
                            .font(.bw(.caption, weight: .medium))
                            .foregroundStyle(BW.inkSecondary)
                        Spacer()
                        Image(systemName: "plus.circle")
                            .font(.caption)
                            .foregroundStyle(BW.amber)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    // MARK: - Grocery Button

    private var groceryButton: some View {
        let hasEntries = !store.data.mealPlan.filter { entry in
            weekDates.contains(where: { d in Calendar.current.isDate(d, inSameDayAs: entry.date) })
        }.isEmpty

        return Button {
            store.generateGroceryFromMealPlan(weekDates: weekDates)
        } label: {
            Label("Generate Grocery List", systemImage: "cart.fill")
                .font(.bw(.body, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(hasEntries ? BW.leafDeep : BW.inkSecondary.opacity(0.3), in: .rect(cornerRadius: 14))
        }
        .disabled(!hasEntries)
        .padding(.top, 8)
    }
}

// MARK: - Recipe Picker Sheet

struct RecipePickerSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let slot: MealSlot
    let date: Date
    @State private var search = ""

    private var recipes: [Recipe] {
        let saved = store.data.saved.compactMap { store.recipe(id: $0.recipeId) }
        if search.isEmpty { return saved }
        return saved.filter { $0.title.localizedCaseInsensitiveContains(search) }
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
                            if let p = store.price(for: recipe).perServing {
                                Text(Money.format(p) + "/serving")
                                    .font(.bw(.caption2, weight: .medium))
                                    .foregroundStyle(BW.inkSecondary)
                            }
                        }
                        Spacer()
                    }
                }
            }
            .searchable(text: $search, prompt: "Search liked recipes")
            .navigationTitle("Add \(slot.label)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        MealPlanView()
            .environmentObject(AppStore())
    }
}
