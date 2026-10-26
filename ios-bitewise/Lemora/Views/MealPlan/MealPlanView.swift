import SwiftUI

/// Week plan shown inside Saved. The saved list itself is unchanged.
struct WeekPlanView: View {
    @Environment(AppStore.self) private var store
    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    @State private var picking: MealSlot?

    private var calendar: Calendar { Calendar.current }

    private var weekDates: [Date] {
        let today = calendar.startOfDay(for: Date())
        let start = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) ?? today
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    private var weekEntries: [MealPlanEntry] {
        (store.data.mealPlan ?? []).filter { entry in
            weekDates.contains { calendar.isDate($0, inSameDayAs: entry.date) }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                dayStrip
                ForEach(MealSlot.allCases) { slot in
                    slotRow(slot)
                }
                Button {
                    store.generateGrocery(from: weekEntries)
                } label: {
                    Label("Generate grocery list", systemImage: "cart.fill")
                        .font(.bw(.headline))
                        .foregroundStyle(BW.ink)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 52)
                        .background(BW.lemon, in: .rect(cornerRadius: 16))
                }
                .buttonStyle(BWPressableStyle())
                .disabled(weekEntries.isEmpty)
                .opacity(weekEntries.isEmpty ? 0.45 : 1)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(BW.canvas)
        .sheet(item: $picking) { slot in
            SavedMealPicker(slot: slot, date: selectedDate)
        }
    }

    private var dayStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(weekDates, id: \.self) { day in
                    let selected = calendar.isDate(day, inSameDayAs: selectedDate)
                    Button {
                        selectedDate = calendar.startOfDay(for: day)
                    } label: {
                        VStack(spacing: 4) {
                            Text(day.formatted(.dateTime.weekday(.narrow)))
                                .font(.bw(.caption, weight: .semibold))
                            Text(day.formatted(.dateTime.day()))
                                .font(.bw(.headline))
                        }
                        .foregroundStyle(selected ? Color.white : BW.ink)
                        .frame(width: 48, height: 58)
                        .background(selected ? BW.ink : BW.card, in: .rect(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(selected ? Color.clear : BW.hairline))
                    }
                    .buttonStyle(BWPressableStyle())
                }
            }
        }
        .scrollClipDisabled()
    }

    private func slotRow(_ slot: MealSlot) -> some View {
        let entry = (store.data.mealPlan ?? []).first {
            calendar.isDate($0.date, inSameDayAs: selectedDate) && $0.mealType == slot
        }
        let recipe = entry.flatMap { item in store.recipes.first { $0.id == item.recipeId } }
        return VStack(alignment: .leading, spacing: 8) {
            Label(slot.label, systemImage: slot.icon)
                .font(.bw(.subheadline, weight: .bold))
                .foregroundStyle(BW.inkSecondary)
            if let entry, let recipe {
                HStack(spacing: 12) {
                    FoodImage(name: recipe.imageName, height: 58, radius: 12)
                        .frame(width: 78)
                        .clipShape(.rect(cornerRadius: 12))
                    NavigationLink(value: Route.recipe(recipe.id)) {
                        Text(recipe.title)
                            .font(.bw(.headline))
                            .foregroundStyle(BW.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(BWPressableStyle())
                    Button {
                        store.removeMealPlanEntry(entry.id)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(BW.inkSecondary)
                            .frame(width: 36, height: 36)
                    }
                }
                .padding(14)
                .bwCard()
            } else {
                Button { picking = slot } label: {
                    Label("Add a saved meal", systemImage: "plus")
                        .font(.bw(.headline))
                        .foregroundStyle(BW.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .bwCard()
                }
                .buttonStyle(BWPressableStyle())
            }
        }
    }
}

private struct SavedMealPicker: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let slot: MealSlot
    let date: Date

    var body: some View {
        NavigationStack {
            Group {
                if store.activeSaved.isEmpty {
                    EmptyStateView(mascot: BWImage.mascotPeek, title: String(localized: "No saved meals yet"),
                                   message: String(localized: "Swipe right on meals you love in Discover and they'll land here."))
                } else {
                    List(store.activeSaved) { entry in
                        if let recipe = store.recipes.first(where: { $0.id == entry.recipeId }) {
                            Button {
                                store.addToMealPlan(recipeId: recipe.id, date: date, slot: slot)
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    FoodImage(name: recipe.imageName, height: 58, radius: 12)
                                        .frame(width: 78)
                                        .clipShape(.rect(cornerRadius: 12))
                                    Text(recipe.title)
                                        .font(.bw(.headline))
                                        .foregroundStyle(BW.ink)
                                        .multilineTextAlignment(.leading)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .background(BW.canvas)
            .navigationTitle("Choose a saved meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
