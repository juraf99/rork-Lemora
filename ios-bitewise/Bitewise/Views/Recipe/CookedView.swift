import SwiftUI

/// Celebration after cooking: shows the money saved on this meal using deals and the running total.
struct CookedView: View {
    let recipe: Recipe
    let logId: UUID
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var appear: Bool = false
    @State private var shownSavings: Double = 0

    private var log: CookLog? { store.cookLog(logId) }
    private var price: RecipePrice { store.price(for: recipe) }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                ZStack(alignment: .topLeading) {
                    FoodImage(name: recipe.imageName, height: 230, radius: 26)
                    LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .center, endPoint: .bottom)
                        .clipShape(.rect(cornerRadius: 26))
                    Label("Cooked", systemImage: "checkmark.circle.fill")
                        .font(.bw(.subheadline, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(BW.leaf, in: .capsule)
                        .padding(16)
                    Text(recipe.title)
                        .font(.bw(.title2, weight: .heavy)).foregroundStyle(.white)
                        .padding(18)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                }
                .frame(height: 230)
                .overlay(alignment: .topTrailing) {
                    MascotView(name: BWImage.mascotCheer, size: 96, bob: true)
                        .offset(x: 8, y: -26)
                        .scaleEffect(appear ? 1 : 0.4)
                }

                if price.savings > 0.01 {
                    VStack(spacing: 4) {
                        Text("You saved").font(.bw(.subheadline, weight: .medium)).foregroundStyle(BW.inkSecondary)
                        Text(Money.format(shownSavings))
                            .font(.system(size: 60, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(BW.ink)
                            .contentTransition(.numericText(value: shownSavings))
                        Text("on this meal with \(storeNames) deals")
                            .font(.bw(.subheadline, weight: .regular)).foregroundStyle(BW.inkSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 4)

                    VStack(spacing: 0) {
                        ForEach(Array(price.dealLines.enumerated()), id: \.element.id) { idx, line in
                            HStack(spacing: 12) {
                                Text(IngredientCatalog.emoji(line.ingredientId)).font(.title3)
                                Text(IngredientCatalog.name(line.ingredientId)).font(.bw(.body, weight: .medium)).foregroundStyle(BW.ink)
                                Spacer()
                                Text("saved \(Money.format(line.savings))").font(.bw(.subheadline, weight: .bold)).monospacedDigit().foregroundStyle(BW.leafDeep)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 13)
                            if idx < price.dealLines.count - 1 { Divider().overlay(BW.hairline).padding(.leading, 52) }
                        }
                    }
                    .bwCard()
                } else {
                    VStack(spacing: 6) {
                        Text("Nice cooking!").font(.bw(.title, weight: .heavy)).foregroundStyle(BW.ink)
                        Text("No current deals matched this recipe, but home cooking still beats takeout.")
                            .font(.bw(.subheadline, weight: .regular)).foregroundStyle(BW.inkSecondary).multilineTextAlignment(.center)
                    }
                }

                Toggle(isOn: Binding(
                    get: { log?.madeWithDeal ?? false },
                    set: { store.setMadeWithDeal(logId, $0) })) {
                    Label("Made with a deal", systemImage: "tag")
                        .font(.bw(.body, weight: .medium)).foregroundStyle(BW.ink)
                }
                .tint(BW.leaf)
                .padding(.horizontal, 16).frame(minHeight: 58)
                .bwCard()

                HStack(spacing: 16) {
                    MascotView(name: BWImage.stageLemon, size: 70)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Total saved with Bitewise").font(.bw(.subheadline, weight: .medium)).foregroundStyle(BW.inkSecondary)
                        Text(Money.format(store.totalSaved))
                            .font(.system(size: 36, weight: .heavy, design: .rounded)).monospacedDigit().foregroundStyle(BW.ink)
                            .contentTransition(.numericText(value: store.totalSaved))
                        Text("This month: \(Money.format(store.savedThisMonth))").font(.bw(.footnote, weight: .medium)).foregroundStyle(BW.inkSecondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(18)
                .background(BW.lemonSoft, in: .rect(cornerRadius: BW.cardRadius))

                if price.usesSampleData { SamplePricesNote() }

                Button("Done") { dismiss() }
                    .buttonStyle(BWPrimaryButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.top, 36)
            .padding(.bottom, 20)
        }
        .presentationDragIndicator(.visible)
        .presentationBackground(BW.canvas)
        .sensoryFeedback(.success, trigger: appear)
        .animation(.spring(response: 0.4), value: store.totalSaved)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { appear = true }
            withAnimation(.easeOut(duration: 0.9).delay(0.2)) { shownSavings = price.savings }
        }
    }

    private var storeNames: String {
        let names = Set(price.dealLines.compactMap { $0.deal?.retailerId }).map { RetailerCatalog.name($0) }.sorted()
        return names.formatted(.list(type: .and))
    }
}
