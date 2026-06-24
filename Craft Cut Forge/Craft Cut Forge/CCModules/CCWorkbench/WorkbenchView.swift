// MARK: - Workbench

struct WorkbenchView: View {
    @EnvironmentObject private var store: WorkshopStore
    @State private var showCreateProject = false

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    if store.projects.isEmpty {
                        EmptyWorkbenchView()
                    } else {
                        LazyVStack(spacing: 16) {
                            ForEach(store.projects) { project in
                                NavigationLink {
                                    ProjectDetailView(projectID: project.id)
                                } label: {
                                    ProjectCard(project: project)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showCreateProject) {
            CreateProjectView()
                .environmentObject(store)
        }
        .overlay(alignment: .bottomTrailing) {
            Button {
                showCreateProject = true
            } label: {
                Image(systemName: "plus")
                    .font(.title2.bold())
                    .foregroundColor(.black)
                    .frame(width: 58, height: 58)
                    .background(AppTheme.yellow)
                    .clipShape(Circle())
                    .shadow(color: AppTheme.yellow.opacity(0.35), radius: 16)
            }
            .padding(24)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Workbench")
                        .font(.largeTitle.bold())
                        .foregroundColor(.white)

                    Text("\(store.projects.filter { !$0.isCompleted }.count) active projects")
                        .foregroundColor(AppTheme.grayText)
                }

                Spacer()

                Text("⚡ \(store.xp) XP")
                    .font(.subheadline.bold())
                    .foregroundColor(AppTheme.yellow)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(AppTheme.card2)
                    .clipShape(Capsule())
            }

            HStack(spacing: 12) {
                StatMiniCard(title: "Active", value: "\(store.projects.filter { !$0.isCompleted }.count)")
                StatMiniCard(title: "Complete", value: "\(store.completedProjectsCount())")
                StatMiniCard(title: "Accuracy", value: "\(Int(store.perfectAccuracy() * 100))%")
            }
        }
    }
}

struct EmptyWorkbenchView: View {
    @EnvironmentObject private var store: WorkshopStore

    var body: some View {
        VStack(spacing: 18) {
            RoundedRectangle(cornerRadius: 18)
                .fill(AppTheme.card)
                .frame(height: 210)
                .overlay {
                    VStack(spacing: 12) {
                        Text("🛠️")
                            .font(.system(size: 50))

                        Text("No Projects Yet")
                            .font(.title2.bold())
                            .foregroundColor(.white)

                        Text("Create your first DIY project and start building.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(AppTheme.grayText)
                    }
                    .padding()
                }

            Text("Start with a simple pallet project and earn your first 50 XP.")
                .font(.callout)
                .foregroundColor(.white.opacity(0.8))
                .padding()
                .frame(maxWidth: .infinity)
                .background(AppTheme.card2)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

struct ProjectCard: View {
    @EnvironmentObject private var store: WorkshopStore
    let project: CraftProject

    @State private var route: CraftRoute?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(project.isCompleted ? "COMPLETED" : "IN PROGRESS")
                        .font(.caption.bold())
                        .foregroundColor(project.isCompleted ? AppTheme.green : AppTheme.yellow)

                    Text(project.name)
                        .font(.title3.bold())
                        .foregroundColor(.white)

                    Text("\(project.category) • \(project.stages.count) stages")
                        .font(.caption)
                        .foregroundColor(AppTheme.grayText)
                }

                Spacer()

                ProgressRing(
                    progress: project.progress,
                    color: project.isCompleted ? AppTheme.green : AppTheme.yellow,
                    size: 58
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(project.stages.prefix(3)) { stage in
                    HStack {
                        Image(systemName: stage.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(stage.isCompleted ? AppTheme.green : AppTheme.grayText)

                        Text(stage.title)
                            .foregroundColor(.white.opacity(stage.isCompleted ? 0.45 : 0.95))
                            .strikethrough(stage.isCompleted)

                        Spacer()

                        if stage.isCompleted {
                            Text(stage.wasPerfectDrop == true ? "+\(stage.xpEarned) XP" : "Done")
                                .font(.caption.bold())
                                .foregroundColor(stage.wasPerfectDrop == true ? AppTheme.yellow : AppTheme.green)
                        }
                    }
                    .font(.subheadline)
                }
            }

            HStack {
                ForEach(project.materials.prefix(3)) { material in
                    Text(material.title)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.75))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                }

                Spacer()
            }

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
                    Text("Craft Stage")
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppTheme.yellow)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            } else {
                Text("All stages complete")
                    .font(.headline)
                    .foregroundColor(AppTheme.green)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppTheme.green.opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
        .padding()
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .stroke(project.isCompleted ? AppTheme.green.opacity(0.35) : AppTheme.yellow.opacity(0.15), lineWidth: 1)
        }
        .fullScreenCover(item: $route) { route in
            CraftGameView(route: route)
                .environmentObject(store)
        }
    }
}

struct ProjectDetailView: View {
    @EnvironmentObject private var store: WorkshopStore
    let projectID: UUID

    @State private var route: CraftRoute?
    @State private var showCompletion = false

    private var project: CraftProject? {
        store.project(by: projectID)
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            if let project {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        HStack {
                            ProgressRing(
                                progress: project.progress,
                                color: project.isCompleted ? AppTheme.green : AppTheme.yellow,
                                size: 80
                            )

                            VStack(alignment: .leading, spacing: 8) {
                                Text(project.isCompleted ? "COMPLETED" : "IN PROGRESS")
                                    .font(.caption.bold())
                                    .foregroundColor(project.isCompleted ? AppTheme.green : AppTheme.yellow)

                                Text(project.name)
                                    .font(.title.bold())
                                    .foregroundColor(.white)

                                Text("\(project.completedStagesCount) / \(project.stages.count) stages complete")
                                    .foregroundColor(AppTheme.grayText)
                            }

                            Spacer()
                        }

                        section(title: "Tasks") {
                            VStack(spacing: 12) {
                                ForEach(project.stages) { stage in
                                    HStack {
                                        Image(systemName: stage.isCompleted ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(stage.isCompleted ? AppTheme.green : AppTheme.grayText)

                                        Text(stage.title)
                                            .foregroundColor(.white)
                                            .strikethrough(stage.isCompleted)

                                        Spacer()

                                        if stage.wasPerfectDrop == true {
                                            Text("+\(stage.xpEarned) XP")
                                                .foregroundColor(AppTheme.yellow)
                                                .font(.caption.bold())
                                        }
                                    }
                                }
                            }
                        }

                        section(title: "Materials") {
                            FlowLayout(items: project.materials.map { "\($0.title) \($0.quantity.clean) \($0.unit.rawValue)" })
                        }

                        if !project.shoppingList.isEmpty {
                            section(title: "Shopping List") {
                                VStack(spacing: 10) {
                                    ForEach(project.shoppingList) { item in
                                        HStack {
                                            Text(item.title)
                                                .foregroundColor(.white)

                                            Spacer()

                                            Text("\(item.quantity.clean) \(item.unit.rawValue)")
                                                .foregroundColor(AppTheme.grayText)

                                            Image(systemName: item.isPurchased ? "checkmark.circle.fill" : "circle")
                                                .foregroundColor(item.isPurchased ? AppTheme.green : AppTheme.grayText)
                                        }
                                    }
                                }
                            }
                        }

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
                                Text("Craft Stage")
                                    .primaryButtonStyle()
                            }
                        } else {
                            Button {
                                showCompletion = true
                            } label: {
                                Text("View Completion")
                                    .primaryButtonStyle(color: AppTheme.green)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Project")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $route) { route in
            CraftGameView(route: route)
                .environmentObject(store)
        }
        .sheet(isPresented: $showCompletion) {
            ProjectCompletionView(projectID: projectID)
                .environmentObject(store)
        }
    }

    private func section<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.caption.bold())
                .foregroundColor(AppTheme.grayText)

            content()
                .padding()
                .background(AppTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 18))
        }
    }
}