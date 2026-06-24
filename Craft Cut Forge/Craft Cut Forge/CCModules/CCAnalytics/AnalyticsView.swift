// MARK: - Analytics

struct AnalyticsView: View {
    @EnvironmentObject private var store: WorkshopStore
    @State private var showShop = false

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Analytics")
                                .font(.largeTitle.bold())
                                .foregroundColor(.white)

                            Text("Your workshop stats")
                                .foregroundColor(AppTheme.grayText)
                        }

                        Spacer()

                        Button {
                            showShop = true
                        } label: {
                            Text("Spend XP")
                                .font(.caption.bold())
                                .foregroundColor(AppTheme.yellow)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(AppTheme.card)
                                .clipShape(Capsule())
                        }
                    }

                    if store.completedStagesCount() == 0 {
                        EmptyAnalyticsView()
                    } else {
                        HStack(spacing: 12) {
                            StatMiniCard(title: "Projects", value: "\(store.completedProjectsCount())")
                            StatMiniCard(title: "Stages", value: "\(store.completedStagesCount())")
                            StatMiniCard(title: "XP", value: "\(store.xp)")
                        }

                        VStack(alignment: .leading, spacing: 16) {
                            Text("Perfect Drop Accuracy")
                                .font(.headline)
                                .foregroundColor(.white)

                            HStack {
                                ProgressRing(
                                    progress: store.perfectAccuracy(),
                                    color: AppTheme.yellow,
                                    size: 110
                                )

                                VStack(alignment: .leading, spacing: 10) {
                                    Label("Perfect: \(store.perfectDrops)", systemImage: "circle.fill")
                                        .foregroundColor(AppTheme.yellow)

                                    Label("Missed: \(store.missedDrops)", systemImage: "circle.fill")
                                        .foregroundColor(AppTheme.grayText)
                                }
                                .font(.subheadline)
                            }
                        }
                        .padding()
                        .background(AppTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 18))

                        VStack(alignment: .leading, spacing: 14) {
                            AnalyticsRow(
                                title: "Favorite Material",
                                value: store.favoriteMaterialCategory()?.rawValue ?? "None",
                                progress: 0.72,
                                color: AppTheme.yellow
                            )

                            AnalyticsRow(
                                title: "Avg Stages / Project",
                                value: averageStagesText,
                                progress: 0.55,
                                color: AppTheme.yellow
                            )

                            AnalyticsRow(
                                title: "Sessions This Week",
                                value: "\(store.xpByLastSevenDays().filter { $0.1 > 0 }.count)",
                                progress: 0.85,
                                color: AppTheme.green
                            )
                        }
                        .padding()
                        .background(AppTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 18))

                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("XP Earned")
                                    .font(.headline)
                                    .foregroundColor(.white)

                                Spacer()

                                Text("\(store.xp) XP total")
                                    .font(.caption.bold())
                                    .foregroundColor(AppTheme.yellow)
                            }

                            HStack(alignment: .bottom, spacing: 12) {
                                ForEach(Array(store.xpByLastSevenDays().enumerated()), id: \.offset) { _, item in
                                    VStack(spacing: 6) {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(AppTheme.yellow)
                                            .frame(
                                                width: 22,
                                                height: max(8, CGFloat(item.1) / 2)
                                            )

                                        Text(item.0)
                                            .font(.caption2)
                                            .foregroundColor(AppTheme.grayText)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            }
                            .frame(height: 120, alignment: .bottom)
                        }
                        .padding()
                        .background(AppTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 18))

                        Button {
                            showShop = true
                        } label: {
                            Text("Open XP Shop")
                                .primaryButtonStyle(color: AppTheme.card2, textColor: AppTheme.yellow)
                        }
                    }
                }
                .padding()
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showShop) {
            XPShopView()
                .environmentObject(store)
        }
    }

    private var averageStagesText: String {
        guard !store.projects.isEmpty else { return "0" }

        let average = Double(store.projects.map(\.stages.count).reduce(0, +)) / Double(store.projects.count)
        return String(format: "%.1f", average)
    }
}

struct EmptyAnalyticsView: View {
    @EnvironmentObject private var store: WorkshopStore

    var body: some View {
        VStack(spacing: 18) {
            Text("📊")
                .font(.system(size: 70))

            Text("NO STATISTICS YET")
                .font(.title2.bold())
                .foregroundColor(.white)

            Text("Complete your first project to unlock workshop analytics and track your progress.")
                .foregroundColor(AppTheme.grayText)
                .multilineTextAlignment(.center)

            Button {
                store.selectedTab = .workbench
            } label: {
                Text("Start Crafting")
                    .primaryButtonStyle()
            }
            .padding(.top, 12)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .frame(minHeight: 480)
    }
}

struct AnalyticsRow: View {
    let title: String
    let value: String
    let progress: Double
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundColor(AppTheme.grayText)

                Spacer()

                Text(value)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.1))

                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 6)
        }
    }
}

// MARK: - XP Shop

struct XPShopView: View {
    @EnvironmentObject private var store: WorkshopStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("XP Shop")
                                    .font(.largeTitle.bold())
                                    .foregroundColor(.white)

                                Text("⚙️ \(store.xp) XP available")
                                    .foregroundColor(AppTheme.grayText)
                            }

                            Spacer()

                            Button {
                                dismiss()
                            } label: {
                                Image(systemName: "xmark")
                                    .foregroundColor(.white)
                                    .padding(12)
                                    .background(AppTheme.card)
                                    .clipShape(Circle())
                            }
                        }

                        ForEach(ShopCategory.allCases) { category in
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text(category.rawValue.uppercased())
                                        .font(.caption.bold())
                                        .foregroundColor(AppTheme.grayText)

                                    Spacer()

                                    Text("200 XP each")
                                        .font(.caption)
                                        .foregroundColor(AppTheme.grayText)
                                }

                                LazyVGrid(
                                    columns: [
                                        GridItem(.flexible()),
                                        GridItem(.flexible()),
                                        GridItem(.flexible())
                                    ],
                                    spacing: 12
                                ) {
                                    ForEach(store.shopItems.filter { $0.category == category }) { item in
                                        ShopItemCard(item: item)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
    }
}

struct ShopItemCard: View {
    @EnvironmentObject private var store: WorkshopStore
    let item: ShopItem

    private var isOwned: Bool {
        store.isOwned(item)
    }

    var body: some View {
        Button {
            store.buyShopItem(item)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Text(item.icon)
                    .font(.system(size: 34))

                Text(item.title)
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .lineLimit(2)

                Spacer()

                Text(isOwned ? "✓ Owned" : "🔒 \(item.price) XP")
                    .font(.caption2.bold())
                    .foregroundColor(isOwned ? AppTheme.green : AppTheme.yellow)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background((isOwned ? AppTheme.green : AppTheme.yellow).opacity(0.12))
                    .clipShape(Capsule())
            }
            .padding()
            .frame(height: 135)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isOwned ? AppTheme.green.opacity(0.5) : Color.white.opacity(0.08), lineWidth: 1)
            }
        }
        .disabled(isOwned || store.xp < item.price)
    }
}
