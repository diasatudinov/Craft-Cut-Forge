// MARK: - Craft Hub

struct CraftHubView: View {
    @EnvironmentObject private var store: WorkshopStore
    @State private var route: CraftRoute?

    private var activeProjects: [CraftProject] {
        store.projects.filter { !$0.isCompleted }
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Craft Zone")
                        .font(.largeTitle.bold())
                        .foregroundColor(.white)

                    Text("Close real DIY stages through the Cut & Drop mini-game.")
                        .foregroundColor(AppTheme.grayText)

                    if activeProjects.isEmpty {
                        Text("No active stages.")
                            .foregroundColor(AppTheme.grayText)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(AppTheme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                    } else {
                        ForEach(activeProjects) { project in
                            if let stage = project.activeStage {
                                Button {
                                    route = CraftRoute(
                                        projectID: project.id,
                                        stageID: stage.id,
                                        projectName: project.name,
                                        stageTitle: stage.title,
                                        difficulty: project.difficulty
                                    )
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(project.name)
                                                .font(.headline)
                                                .foregroundColor(.white)

                                            Text(stage.title)
                                                .foregroundColor(AppTheme.grayText)

                                            Text(project.difficulty.title)
                                                .font(.caption.bold())
                                                .foregroundColor(AppTheme.yellow)
                                        }

                                        Spacer()

                                        Image(systemName: "scissors")
                                            .foregroundColor(.black)
                                            .padding()
                                            .background(AppTheme.yellow)
                                            .clipShape(Circle())
                                    }
                                    .padding()
                                    .background(AppTheme.card)
                                    .clipShape(RoundedRectangle(cornerRadius: 18))
                                }
                            }
                        }
                    }

                    ShoppingListBlock()
                }
                .padding()
            }
        }
        .navigationBarHidden(true)
        .fullScreenCover(item: $route) { route in
            CraftGameView(route: route)
                .environmentObject(store)
        }
    }
}

struct ShoppingListBlock: View {
    @EnvironmentObject private var store: WorkshopStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Shopping List")
                .font(.title2.bold())
                .foregroundColor(.white)

            let entries = store.shoppingEntries()

            if entries.isEmpty {
                Text("No missing materials.")
                    .foregroundColor(AppTheme.grayText)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            } else {
                ForEach(entries) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.item.title)
                                .font(.headline)
                                .foregroundColor(.white)

                            Text("\(entry.projectName) • \(entry.item.quantity.clean) \(entry.item.unit.rawValue)")
                                .font(.caption)
                                .foregroundColor(AppTheme.grayText)
                        }

                        Spacer()

                        Button {
                            store.markShoppingItemPurchased(
                                projectID: entry.projectID,
                                itemID: entry.item.id
                            )
                        } label: {
                            Image(systemName: "checkmark")
                                .foregroundColor(.black)
                                .padding(10)
                                .background(AppTheme.yellow)
                                .clipShape(Circle())
                        }
                    }
                    .padding()
                    .background(AppTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }
}
