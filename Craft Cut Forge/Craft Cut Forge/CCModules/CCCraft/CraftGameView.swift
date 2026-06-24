
// MARK: - Craft Game View

struct CraftGameView: View {
    @EnvironmentObject private var store: WorkshopStore
    @Environment(\.dismiss) private var dismiss

    let route: CraftRoute

    @State private var scene: CraftDropScene
    @State private var result: Bool?
    @State private var didApplyResult = false
    @State private var showCompletion = false

    init(route: CraftRoute) {
        self.route = route

        let scene = CraftDropScene(size: UIScreen.main.bounds.size)
        scene.scaleMode = .resizeFill
        scene.difficulty = route.difficulty

        _scene = State(initialValue: scene)
    }

    var body: some View {
        ZStack {
            SpriteView(scene: scene)
                .ignoresSafeArea()

            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("CRAFT STAGE")
                            .font(.caption.bold())
                            .foregroundColor(AppTheme.grayText)

                        Text("\(route.projectName) — \(route.stageTitle)")
                            .font(.headline.bold())
                            .foregroundColor(.white)
                    }

                    Spacer()

                    Text("⚡ 50 XP")
                        .font(.subheadline.bold())
                        .foregroundColor(AppTheme.yellow)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(AppTheme.card)
                        .clipShape(Capsule())
                }
                .padding()

                Spacer()

                Text("Swipe to cut the rope")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.bottom, 40)
            }

            if let result {
                resultOverlay(isPerfect: result)
            }
        }
        .onAppear {
            scene.onFinish = { perfect in
                DispatchQueue.main.async {
                    guard !didApplyResult else { return }

                    didApplyResult = true
                    result = perfect

                    store.completeStage(
                        projectID: route.projectID,
                        stageID: route.stageID,
                        perfect: perfect
                    )
                }
            }
        }
        .sheet(isPresented: $showCompletion, onDismiss: {
            dismiss()
        }) {
            ProjectCompletionView(projectID: route.projectID)
                .environmentObject(store)
        }
    }

    private func resultOverlay(isPerfect: Bool) -> some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()

            VStack(spacing: 18) {
                Text(isPerfect ? "⭐️" : "⚠️")
                    .font(.system(size: 60))

                Text(isPerfect ? "PERFECT CRAFT" : "CRAFT COMPLETED")
                    .font(.caption.bold())
                    .foregroundColor(AppTheme.grayText)

                Text(isPerfect ? "+50 XP" : "No Bonus XP")
                    .font(.system(size: 44, weight: .black))
                    .foregroundColor(isPerfect ? AppTheme.yellow : AppTheme.grayText)

                Text("\(route.stageTitle) completed")
                    .foregroundColor(AppTheme.grayText)

                Button {
                    if store.project(by: route.projectID)?.isCompleted == true {
                        showCompletion = true
                    } else {
                        dismiss()
                    }
                } label: {
                    Text("Continue")
                        .primaryButtonStyle()
                }
                .padding(.top, 12)
            }
            .padding(28)
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .padding(32)
        }
    }
}

// MARK: - Project Completion

struct ProjectCompletionView: View {
    @EnvironmentObject private var store: WorkshopStore
    @Environment(\.dismiss) private var dismiss

    let projectID: UUID

    private var project: CraftProject? {
        store.project(by: projectID)
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            if let project {
                VStack(spacing: 22) {
                    Text("🏆")
                        .font(.system(size: 72))

                    Text("PROJECT COMPLETED")
                        .font(.caption.bold())
                        .foregroundColor(AppTheme.grayText)

                    Text(project.name)
                        .font(.title.bold())
                        .foregroundColor(.white)

                    VStack(spacing: 8) {
                        Text("XP EARNED")
                            .font(.caption.bold())
                            .foregroundColor(AppTheme.grayText)

                        Text("+\(project.totalXP) XP")
                            .font(.system(size: 42, weight: .black))
                            .foregroundColor(AppTheme.yellow)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppTheme.yellow.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 18))

                    VStack(alignment: .leading, spacing: 14) {
                        Text("Materials Used")
                            .font(.caption.bold())
                            .foregroundColor(AppTheme.grayText)

                        ForEach(project.materials) { material in
                            HStack {
                                Text(material.category.icon)
                                Text(material.title)
                                    .foregroundColor(.white)

                                Spacer()

                                Text("- \(material.quantity.clean) \(material.unit.rawValue)")
                                    .foregroundColor(AppTheme.red)
                            }
                        }
                    }
                    .padding()
                    .background(AppTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 18))

                    Spacer()

                    Button {
                        store.confirmMaterialWriteOff(for: project.id)
                        dismiss()
                    } label: {
                        Text(project.materialsWrittenOff ? "Materials Written Off" : "Confirm Material Write-Off")
                            .primaryButtonStyle()
                    }
                    .disabled(project.materialsWrittenOff)

                    Button("Back to Workbench") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.grayText)
                }
                .padding()
            }
        }
    }
}