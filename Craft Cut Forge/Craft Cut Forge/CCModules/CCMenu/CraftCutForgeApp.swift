import SwiftUI
import SpriteKit
import UIKit

// MARK: - App

@main
struct CraftCutForgeApp: App {
    @StateObject private var store = WorkshopStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
        }
    }
}

// MARK: - Theme

enum AppTheme {
    static let background = Color(hex: 0x0E0B07)
    static let card = Color(hex: 0x1D1A10)
    static let card2 = Color(hex: 0x292414)
    static let yellow = Color(hex: 0xFFD21A)
    static let green = Color(hex: 0x4CC35A)
    static let red = Color(hex: 0xFF3B5C)
    static let grayText = Color.white.opacity(0.6)
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255,
            opacity: alpha
        )
    }
}

extension UIColor {
    convenience init(hex: UInt, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xff) / 255,
            green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255,
            alpha: alpha
        )
    }
}

// MARK: - Models

enum AppTab: Hashable {
    case workbench
    case craft
    case inventory
    case analytics
}

enum MaterialCategory: String, CaseIterable, Identifiable, Codable {
    case wood = "Wood"
    case plastic = "Plastic"
    case textile = "Textile"
    case metal = "Metal"
    case fasteners = "Fasteners"
    case other = "Other"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .wood: return "🪵"
        case .plastic: return "🧴"
        case .textile: return "🧵"
        case .metal: return "🔩"
        case .fasteners: return "🔧"
        case .other: return "📦"
        }
    }
}

enum MaterialUnit: String, CaseIterable, Identifiable, Codable {
    case pcs = "pcs"
    case kg = "kg"
    case m = "m"
    case l = "l"

    var id: String { rawValue }
}

enum CraftDifficulty: String, Codable {
    case easy
    case medium
    case hard

    static func from(materialCount: Int) -> CraftDifficulty {
        if materialCount <= 1 { return .easy }
        if materialCount <= 3 { return .medium }
        return .hard
    }

    var title: String {
        switch self {
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .hard: return "Hard"
        }
    }
}

struct InventoryMaterial: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var category: MaterialCategory
    var quantity: Double
    var unit: MaterialUnit
    var createdAt: Date = Date()
    var lastUsedAt: Date?

    var daysStored: Int {
        let date = lastUsedAt ?? createdAt
        return Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
    }

    var isStale: Bool {
        quantity > 0 && daysStored >= 365
    }
}

struct ProjectMaterialRequirement: Identifiable, Codable, Equatable {
    var id = UUID()
    var materialID: UUID?
    var title: String
    var category: MaterialCategory
    var quantity: Double
    var unit: MaterialUnit
    var isPurchased: Bool = false

    var isFromInventory: Bool {
        materialID != nil
    }
}

struct CraftStage: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var isCompleted: Bool = false
    var wasPerfectDrop: Bool?
    var xpEarned: Int = 0
}

struct CraftProject: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var category: String
    var stages: [CraftStage]
    var materials: [ProjectMaterialRequirement]
    var shoppingList: [ProjectMaterialRequirement]
    var createdAt: Date = Date()
    var completedAt: Date?
    var materialsWrittenOff: Bool = false

    var completedStagesCount: Int {
        stages.filter(\.isCompleted).count
    }

    var progress: Double {
        guard !stages.isEmpty else { return 0 }
        return Double(completedStagesCount) / Double(stages.count)
    }

    var isCompleted: Bool {
        !stages.isEmpty && stages.allSatisfy(\.isCompleted)
    }

    var activeStage: CraftStage? {
        stages.first { !$0.isCompleted }
    }

    var totalXP: Int {
        stages.map(\.xpEarned).reduce(0, +)
    }

    var difficulty: CraftDifficulty {
        CraftDifficulty.from(materialCount: materials.count + shoppingList.count)
    }
}

struct XPLog: Codable, Identifiable {
    var id = UUID()
    var date: Date
    var amount: Int
}

enum ShopCategory: String, CaseIterable, Identifiable {
    case workbenchThemes = "Workbench Themes"
    case ropeStyles = "Rope Styles"
    case successEffects = "Success Effects"
    case soundPacks = "Sound Packs"

    var id: String { rawValue }
}

struct ShopItem: Identifiable {
    let id: String
    let title: String
    let icon: String
    let category: ShopCategory
    let price: Int
}

struct ShoppingEntry: Identifiable {
    let id: UUID
    let projectID: UUID
    let projectName: String
    let item: ProjectMaterialRequirement
}

struct CraftRoute: Identifiable {
    let projectID: UUID
    let stageID: UUID
    let projectName: String
    let stageTitle: String
    let difficulty: CraftDifficulty

    var id: String {
        projectID.uuidString + stageID.uuidString
    }
}

// MARK: - Store

@MainActor
final class WorkshopStore: ObservableObject {
    @Published var selectedTab: AppTab = .workbench
    @Published private(set) var projects: [CraftProject] = []
    @Published private(set) var materials: [InventoryMaterial] = []
    @Published private(set) var xp: Int = 0
    @Published private(set) var perfectDrops: Int = 0
    @Published private(set) var missedDrops: Int = 0
    @Published private(set) var purchasedShopItemIDs: Set<String> = []
    @Published private(set) var xpLogs: [XPLog] = []

    private let storageKey = "craft_cut_forge_storage_v1"

    var shopItems: [ShopItem] {
        [
            .init(id: "classic_wood", title: "Classic Wood", icon: "🪵", category: .workbenchThemes, price: 200),
            .init(id: "steel_workshop", title: "Steel Workshop", icon: "⚙️", category: .workbenchThemes, price: 200),
            .init(id: "neon_cyber", title: "Neon Cyber", icon: "🧪", category: .workbenchThemes, price: 200),

            .init(id: "hemp_rope", title: "Hemp Rope", icon: "🪢", category: .ropeStyles, price: 200),
            .init(id: "chain", title: "Chain", icon: "⛓️", category: .ropeStyles, price: 200),
            .init(id: "laser_rope", title: "Laser Rope", icon: "🔴", category: .ropeStyles, price: 200),

            .init(id: "dust", title: "Dust", icon: "💨", category: .successEffects, price: 200),
            .init(id: "sparks", title: "Sparks", icon: "✨", category: .successEffects, price: 200),
            .init(id: "pixel_confetti", title: "Pixel Confetti", icon: "🎊", category: .successEffects, price: 200),

            .init(id: "carpenter", title: "Carpenter", icon: "🔨", category: .soundPacks, price: 200),
            .init(id: "metalworker", title: "Metalworker", icon: "⚒️", category: .soundPacks, price: 200),
            .init(id: "retro_game", title: "Retro Game", icon: "🎮", category: .soundPacks, price: 200)
        ]
    }

    init() {
        load()
    }

    func project(by id: UUID) -> CraftProject? {
        projects.first { $0.id == id }
    }

    func materialStatus(for material: InventoryMaterial) -> String {
        if material.quantity <= 0 { return "Used Up" }

        let isUsedInActiveProject = projects.contains { project in
            !project.isCompleted && project.materials.contains { $0.materialID == material.id }
        }

        if isUsedInActiveProject { return "In Use" }
        if material.isStale { return "Unused" }
        return "Stored"
    }

    func addMaterial(
        name: String,
        category: MaterialCategory,
        quantity: Double,
        unit: MaterialUnit
    ) {
        let material = InventoryMaterial(
            name: name,
            category: category,
            quantity: quantity,
            unit: unit
        )

        materials.append(material)
        save()
    }

    func recycleMaterial(_ materialID: UUID) {
        guard let index = materials.firstIndex(where: { $0.id == materialID }) else { return }
        materials[index].quantity = 0
        materials[index].lastUsedAt = Date()
        save()
    }

    func createProject(
        name: String,
        stageTitles: [String],
        materialSelections: [UUID: Double],
        shoppingItems: [ProjectMaterialRequirement]
    ) {
        let stages = stageTitles
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { CraftStage(title: $0) }

        let requirements: [ProjectMaterialRequirement] = materialSelections.compactMap { materialID, quantity in
            guard
                quantity > 0,
                let material = materials.first(where: { $0.id == materialID })
            else {
                return nil
            }

            return ProjectMaterialRequirement(
                materialID: material.id,
                title: material.name,
                category: material.category,
                quantity: quantity,
                unit: material.unit
            )
        }

        let project = CraftProject(
            name: name,
            category: requirements.first?.category.rawValue ?? "DIY",
            stages: stages,
            materials: requirements,
            shoppingList: shoppingItems
        )

        projects.insert(project, at: 0)
        save()
    }

    func completeStage(projectID: UUID, stageID: UUID, perfect: Bool) {
        guard
            let projectIndex = projects.firstIndex(where: { $0.id == projectID }),
            let stageIndex = projects[projectIndex].stages.firstIndex(where: { $0.id == stageID }),
            projects[projectIndex].stages[stageIndex].isCompleted == false
        else {
            return
        }

        projects[projectIndex].stages[stageIndex].isCompleted = true
        projects[projectIndex].stages[stageIndex].wasPerfectDrop = perfect
        projects[projectIndex].stages[stageIndex].xpEarned = perfect ? 50 : 0

        if perfect {
            xp += 50
            perfectDrops += 1
            xpLogs.append(XPLog(date: Date(), amount: 50))
        } else {
            missedDrops += 1
        }

        if projects[projectIndex].isCompleted {
            projects[projectIndex].completedAt = Date()
        }

        save()
    }

    func confirmMaterialWriteOff(for projectID: UUID) {
        guard let projectIndex = projects.firstIndex(where: { $0.id == projectID }) else { return }

        let project = projects[projectIndex]

        guard !project.materialsWrittenOff else { return }

        for requirement in project.materials {
            guard
                let materialID = requirement.materialID,
                let materialIndex = materials.firstIndex(where: { $0.id == materialID })
            else {
                continue
            }

            materials[materialIndex].quantity = max(0, materials[materialIndex].quantity - requirement.quantity)
            materials[materialIndex].lastUsedAt = Date()
        }

        projects[projectIndex].materialsWrittenOff = true
        save()
    }

    func markShoppingItemPurchased(projectID: UUID, itemID: UUID) {
        guard
            let projectIndex = projects.firstIndex(where: { $0.id == projectID }),
            let itemIndex = projects[projectIndex].shoppingList.firstIndex(where: { $0.id == itemID })
        else {
            return
        }

        projects[projectIndex].shoppingList[itemIndex].isPurchased = true
        save()
    }

    func shoppingEntries() -> [ShoppingEntry] {
        projects.flatMap { project in
            project.shoppingList
                .filter { !$0.isPurchased }
                .map {
                    ShoppingEntry(
                        id: $0.id,
                        projectID: project.id,
                        projectName: project.name,
                        item: $0
                    )
                }
        }
    }

    func buyShopItem(_ item: ShopItem) {
        guard !purchasedShopItemIDs.contains(item.id), xp >= item.price else { return }

        xp -= item.price
        purchasedShopItemIDs.insert(item.id)
        save()
    }

    func isOwned(_ item: ShopItem) -> Bool {
        purchasedShopItemIDs.contains(item.id)
    }

    func completedProjectsCount() -> Int {
        projects.filter(\.isCompleted).count
    }

    func completedStagesCount() -> Int {
        projects.flatMap(\.stages).filter(\.isCompleted).count
    }

    func perfectAccuracy() -> Double {
        let total = perfectDrops + missedDrops
        guard total > 0 else { return 0 }
        return Double(perfectDrops) / Double(total)
    }

    func favoriteMaterialCategory() -> MaterialCategory? {
        let usedCategories = projects.flatMap(\.materials).map(\.category)

        let grouped = Dictionary(grouping: usedCategories, by: { $0 })
        return grouped.max(by: { $0.value.count < $1.value.count })?.key
    }

    func xpByLastSevenDays() -> [(String, Int)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return (0..<7).reversed().map { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            let title = DateFormatter.shortWeekday.string(from: date)

            let amount = xpLogs
                .filter { calendar.isDate($0.date, inSameDayAs: date) }
                .map(\.amount)
                .reduce(0, +)

            return (title, amount)
        }
    }

    private func seedDemoData() {
        let oldDate = Calendar.current.date(byAdding: .day, value: -378, to: Date()) ?? Date()

        let pallets = InventoryMaterial(
            name: "Pallets",
            category: .wood,
            quantity: 2,
            unit: .pcs,
            createdAt: oldDate
        )

        let bottles = InventoryMaterial(
            name: "Glass Bottles",
            category: .other,
            quantity: 12,
            unit: .pcs
        )

        let screws = InventoryMaterial(
            name: "Screws 35mm",
            category: .fasteners,
            quantity: 40,
            unit: .pcs
        )

        let steel = InventoryMaterial(
            name: "Steel Sheet",
            category: .metal,
            quantity: 5,
            unit: .pcs
        )

        materials = [pallets, bottles, screws, steel]

        let palletProject = CraftProject(
            name: "Pallet Shelf",
            category: "Woodworking",
            stages: [
                CraftStage(title: "Disassemble pallet", isCompleted: true, wasPerfectDrop: true, xpEarned: 50),
                CraftStage(title: "Sand wood", isCompleted: true, wasPerfectDrop: false, xpEarned: 0),
                CraftStage(title: "Paint surface")
            ],
            materials: [
                ProjectMaterialRequirement(
                    materialID: pallets.id,
                    title: "Pallets",
                    category: .wood,
                    quantity: 2,
                    unit: .pcs
                ),
                ProjectMaterialRequirement(
                    materialID: screws.id,
                    title: "Screws 35mm",
                    category: .fasteners,
                    quantity: 10,
                    unit: .pcs
                )
            ],
            shoppingList: [
                ProjectMaterialRequirement(
                    materialID: nil,
                    title: "Paint",
                    category: .other,
                    quantity: 1,
                    unit: .pcs
                )
            ]
        )

        let bottleLamp = CraftProject(
            name: "Bottle Lamp",
            category: "Electrical",
            stages: [
                CraftStage(title: "Clean bottle", isCompleted: true, wasPerfectDrop: true, xpEarned: 50),
                CraftStage(title: "Cut glass"),
                CraftStage(title: "Wire bulb"),
                CraftStage(title: "Mount base")
            ],
            materials: [
                ProjectMaterialRequirement(
                    materialID: bottles.id,
                    title: "Glass Bottles",
                    category: .other,
                    quantity: 3,
                    unit: .pcs
                )
            ],
            shoppingList: [
                ProjectMaterialRequirement(
                    materialID: nil,
                    title: "Wire",
                    category: .other,
                    quantity: 1,
                    unit: .pcs
                )
            ]
        )

        var organizer = CraftProject(
            name: "Metal Organizer",
            category: "Metalwork",
            stages: [
                CraftStage(title: "Cut sheet", isCompleted: true, wasPerfectDrop: true, xpEarned: 50),
                CraftStage(title: "Bend edges", isCompleted: true, wasPerfectDrop: true, xpEarned: 50),
                CraftStage(title: "Powder coat", isCompleted: true, wasPerfectDrop: true, xpEarned: 50),
                CraftStage(title: "Assemble", isCompleted: true, wasPerfectDrop: false, xpEarned: 0)
            ],
            materials: [
                ProjectMaterialRequirement(
                    materialID: steel.id,
                    title: "Steel Sheet",
                    category: .metal,
                    quantity: 1,
                    unit: .pcs
                )
            ],
            shoppingList: []
        )

        organizer.completedAt = Date()

        projects = [palletProject, bottleLamp, organizer]
        xp = 420
        perfectDrops = 5
        missedDrops = 1
        purchasedShopItemIDs = ["classic_wood", "hemp_rope", "dust", "carpenter"]

        xpLogs = [
            XPLog(date: Date(), amount: 50),
            XPLog(date: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(), amount: 50),
            XPLog(date: Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date(), amount: 100),
            XPLog(date: Calendar.current.date(byAdding: .day, value: -4, to: Date()) ?? Date(), amount: 50),
            XPLog(date: Calendar.current.date(byAdding: .day, value: -5, to: Date()) ?? Date(), amount: 100)
        ]
    }

    private func save() {
        let payload = PersistencePayload(
            projects: projects,
            materials: materials,
            xp: xp,
            perfectDrops: perfectDrops,
            missedDrops: missedDrops,
            purchasedShopItemIDs: purchasedShopItemIDs,
            xpLogs: xpLogs
        )

        guard let data = try? JSONEncoder().encode(payload) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func load() {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let payload = try? JSONDecoder().decode(PersistencePayload.self, from: data)
        else {
            seedDemoData()
            save()
            return
        }

        projects = payload.projects
        materials = payload.materials
        xp = payload.xp
        perfectDrops = payload.perfectDrops
        missedDrops = payload.missedDrops
        purchasedShopItemIDs = payload.purchasedShopItemIDs
        xpLogs = payload.xpLogs
    }
}

struct PersistencePayload: Codable {
    var projects: [CraftProject]
    var materials: [InventoryMaterial]
    var xp: Int
    var perfectDrops: Int
    var missedDrops: Int
    var purchasedShopItemIDs: Set<String>
    var xpLogs: [XPLog]
}

// MARK: - Root

struct RootView: View {
    @EnvironmentObject private var store: WorkshopStore

    var body: some View {
        TabView(selection: $store.selectedTab) {
            NavigationStack {
                WorkbenchView()
            }
            .tabItem {
                Label("Workbench", systemImage: "hammer")
            }
            .tag(AppTab.workbench)

            NavigationStack {
                CraftHubView()
            }
            .tabItem {
                Label("Craft", systemImage: "scissors")
            }
            .tag(AppTab.craft)

            NavigationStack {
                InventoryView()
            }
            .tabItem {
                Label("Inventory", systemImage: "shippingbox")
            }
            .tag(AppTab.inventory)

            NavigationStack {
                AnalyticsView()
            }
            .tabItem {
                Label("Analytics", systemImage: "chart.bar")
            }
            .tag(AppTab.analytics)
        }
        .tint(AppTheme.yellow)
    }
}

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

// MARK: - Inventory

struct InventoryView: View {
    @EnvironmentObject private var store: WorkshopStore
    @State private var selectedCategory: MaterialCategory = .wood
    @State private var showAddMaterial = false
    @State private var reminderMaterial: InventoryMaterial?

    private var filteredMaterials: [InventoryMaterial] {
        store.materials.filter { $0.category == selectedCategory }
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Inventory")
                            .font(.largeTitle.bold())
                            .foregroundColor(.white)

                        Text("\(store.materials.count) items across categories")
                            .foregroundColor(AppTheme.grayText)
                    }

                    Spacer()

                    Button {
                        showAddMaterial = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(.black)
                            .padding(12)
                            .background(AppTheme.yellow)
                            .clipShape(Circle())
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(MaterialCategory.allCases) { category in
                            Button {
                                selectedCategory = category
                            } label: {
                                Text(category.rawValue)
                                    .font(.subheadline.bold())
                                    .foregroundColor(selectedCategory == category ? .black : .white)
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 10)
                                    .background(selectedCategory == category ? AppTheme.yellow : AppTheme.card)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

                if let stale = store.materials.first(where: \.isStale) {
                    Button {
                        reminderMaterial = stale
                    } label: {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(AppTheme.yellow)

                            Text("Material Reminder: \(stale.name)")
                                .foregroundColor(.white)

                            Spacer()

                            Text("\(stale.daysStored) days")
                                .font(.caption.bold())
                                .foregroundColor(AppTheme.yellow)
                        }
                        .padding()
                        .background(AppTheme.yellow.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(AppTheme.yellow.opacity(0.5), lineWidth: 1)
                        }
                    }
                }

                ScrollView {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ],
                        spacing: 14
                    ) {
                        ForEach(filteredMaterials) { material in
                            MaterialCard(material: material)
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
            .padding()
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showAddMaterial) {
            AddMaterialView()
                .environmentObject(store)
        }
        .sheet(item: $reminderMaterial) { material in
            MaterialReminderView(material: material)
                .environmentObject(store)
        }
    }
}

struct MaterialCard: View {
    @EnvironmentObject private var store: WorkshopStore
    let material: InventoryMaterial

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(material.category.icon)
                .font(.system(size: 38))

            Spacer()

            Text(material.name)
                .font(.headline)
                .foregroundColor(.white)

            Text("\(material.quantity.clean) \(material.unit.rawValue)")
                .foregroundColor(AppTheme.grayText)

            Text(store.materialStatus(for: material).uppercased())
                .font(.caption.bold())
                .foregroundColor(statusColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(statusColor.opacity(0.15))
                .clipShape(Capsule())
        }
        .padding()
        .frame(height: 190)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var statusColor: Color {
        switch store.materialStatus(for: material) {
        case "In Use": return AppTheme.yellow
        case "Unused": return AppTheme.red
        case "Used Up": return AppTheme.grayText
        default: return AppTheme.green
        }
    }
}

struct AddMaterialView: View {
    @EnvironmentObject private var store: WorkshopStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var category: MaterialCategory = .wood
    @State private var quantity = 1.0
    @State private var unit: MaterialUnit = .pcs

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Add Material")
                            .font(.largeTitle.bold())
                            .foregroundColor(.white)

                        inputTitle("Material Name")
                        TextField("e.g. Oak Plank", text: $name)
                            .inputStyle()

                        inputTitle("Category")
                        Picker("Category", selection: $category) {
                            ForEach(MaterialCategory.allCases) { category in
                                Text(category.rawValue).tag(category)
                            }
                        }
                        .pickerStyle(.menu)
                        .inputStyle()

                        inputTitle("Quantity")
                        Stepper("\(quantity.clean)", value: $quantity, in: 1...999, step: 1)
                            .foregroundColor(.white)
                            .inputStyle()

                        inputTitle("Unit")
                        Picker("Unit", selection: $unit) {
                            ForEach(MaterialUnit.allCases) { unit in
                                Text(unit.rawValue).tag(unit)
                            }
                        }
                        .pickerStyle(.segmented)

                        VStack(spacing: 8) {
                            Image(systemName: "camera")
                                .font(.title)
                                .foregroundColor(AppTheme.grayText)

                            Text("Tap to add photo")
                                .foregroundColor(AppTheme.grayText)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 130)
                        .background(AppTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 18))

                        Button {
                            store.addMaterial(
                                name: name,
                                category: category,
                                quantity: quantity,
                                unit: unit
                            )
                            dismiss()
                        } label: {
                            Text("Add Material")
                                .primaryButtonStyle()
                        }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.yellow)
                }
            }
        }
    }

    private func inputTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption.bold())
            .foregroundColor(AppTheme.grayText)
    }
}

struct MaterialReminderView: View {
    @EnvironmentObject private var store: WorkshopStore
    @Environment(\.dismiss) private var dismiss

    let material: InventoryMaterial

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 24) {
                Text("Material Reminder")
                    .font(.largeTitle.bold())
                    .foregroundColor(.white)

                VStack(alignment: .leading, spacing: 14) {
                    Label("INACTIVITY ALERT", systemImage: "clock")
                        .font(.headline.bold())
                        .foregroundColor(AppTheme.yellow)

                    Text("This material has not been used for over a year. Consider putting it to work or recycling it.")
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding()
                .background(AppTheme.yellow.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay {
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(AppTheme.yellow.opacity(0.5), lineWidth: 1)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text(material.name)
                        .font(.title2.bold())
                        .foregroundColor(.white)

                    Text("\(material.quantity.clean) \(material.unit.rawValue) • \(material.category.rawValue)")
                        .foregroundColor(AppTheme.grayText)

                    Text("Stored for \(material.daysStored) days")
                        .font(.headline)
                        .foregroundColor(AppTheme.yellow)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 18))

                Spacer()

                Button {
                    store.selectedTab = .workbench
                    dismiss()
                } label: {
                    Text("Use in Project")
                        .primaryButtonStyle()
                }

                Button {
                    store.recycleMaterial(material.id)
                    dismiss()
                } label: {
                    Text("Recycle Material")
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                Button("Remind me later") {
                    dismiss()
                }
                .foregroundColor(AppTheme.grayText)
                .frame(maxWidth: .infinity)
            }
            .padding()
        }
    }
}

// MARK: - Create Project

struct CreateProjectView: View {
    @EnvironmentObject private var store: WorkshopStore
    @Environment(\.dismiss) private var dismiss

    @State private var projectName = ""
    @State private var stageTitles = ["Disassemble pallet", "Sand wood", "Paint surface"]

    @State private var selectedMaterials: Set<UUID> = []
    @State private var materialQuantities: [UUID: Double] = [:]

    @State private var missingName = ""
    @State private var missingQuantity = 1.0
    @State private var missingCategory: MaterialCategory = .other
    @State private var missingUnit: MaterialUnit = .pcs
    @State private var shoppingItems: [ProjectMaterialRequirement] = []

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        Text("Create Project")
                            .font(.largeTitle.bold())
                            .foregroundColor(.white)

                        group("Project Name") {
                            TextField("Pallet Shelf", text: $projectName)
                                .inputStyle()
                        }

                        group("Stages") {
                            VStack(spacing: 10) {
                                ForEach(stageTitles.indices, id: \.self) { index in
                                    HStack {
                                        TextField(
                                            "Stage \(index + 1)",
                                            text: Binding(
                                                get: { stageTitles[index] },
                                                set: { stageTitles[index] = $0 }
                                            )
                                        )
                                        .inputStyle()

                                        if stageTitles.count > 1 {
                                            Button {
                                                stageTitles.remove(at: index)
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(AppTheme.grayText)
                                            }
                                        }
                                    }
                                }

                                Button {
                                    stageTitles.append("")
                                } label: {
                                    Label("Add stage", systemImage: "plus")
                                        .foregroundColor(AppTheme.yellow)
                                }
                            }
                        }

                        group("Materials from Inventory") {
                            if store.materials.isEmpty {
                                Text("Inventory is empty.")
                                    .foregroundColor(AppTheme.grayText)
                            } else {
                                VStack(spacing: 12) {
                                    ForEach(store.materials) { material in
                                        VStack(spacing: 10) {
                                            Toggle(isOn: materialBinding(material.id)) {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(material.name)
                                                        .foregroundColor(.white)

                                                    Text("\(material.quantity.clean) \(material.unit.rawValue) available")
                                                        .font(.caption)
                                                        .foregroundColor(AppTheme.grayText)
                                                }
                                            }
                                            .tint(AppTheme.yellow)

                                            if selectedMaterials.contains(material.id) {
                                                Stepper(
                                                    "Use \((materialQuantities[material.id] ?? 1).clean) \(material.unit.rawValue)",
                                                    value: Binding(
                                                        get: { materialQuantities[material.id] ?? 1 },
                                                        set: { materialQuantities[material.id] = min($0, material.quantity) }
                                                    ),
                                                    in: 1...max(1, material.quantity),
                                                    step: 1
                                                )
                                                .foregroundColor(.white)
                                            }
                                        }
                                        .padding()
                                        .background(AppTheme.card)
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                    }
                                }
                            }
                        }

                        group("Shopping List") {
                            VStack(spacing: 12) {
                                ForEach(shoppingItems) { item in
                                    HStack {
                                        Text(item.title)
                                            .foregroundColor(.white)

                                        Spacer()

                                        Text("\(item.quantity.clean) \(item.unit.rawValue)")
                                            .foregroundColor(AppTheme.grayText)
                                    }
                                    .padding()
                                    .background(AppTheme.card)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                }

                                TextField("Missing material name", text: $missingName)
                                    .inputStyle()

                                HStack {
                                    Stepper(
                                        "\(missingQuantity.clean)",
                                        value: $missingQuantity,
                                        in: 1...999,
                                        step: 1
                                    )
                                    .foregroundColor(.white)

                                    Picker("Unit", selection: $missingUnit) {
                                        ForEach(MaterialUnit.allCases) { unit in
                                            Text(unit.rawValue).tag(unit)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .foregroundColor(.white)
                                }

                                Picker("Category", selection: $missingCategory) {
                                    ForEach(MaterialCategory.allCases) { category in
                                        Text(category.rawValue).tag(category)
                                    }
                                }
                                .pickerStyle(.menu)
                                .inputStyle()

                                Button {
                                    let item = ProjectMaterialRequirement(
                                        materialID: nil,
                                        title: missingName,
                                        category: missingCategory,
                                        quantity: missingQuantity,
                                        unit: missingUnit
                                    )

                                    shoppingItems.append(item)
                                    missingName = ""
                                    missingQuantity = 1
                                } label: {
                                    Label("Add to Shopping List", systemImage: "cart.badge.plus")
                                        .foregroundColor(AppTheme.yellow)
                                }
                                .disabled(missingName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                        }

                        Button {
                            let selections = Dictionary(
                                uniqueKeysWithValues: selectedMaterials.map {
                                    ($0, materialQuantities[$0] ?? 1)
                                }
                            )

                            store.createProject(
                                name: projectName,
                                stageTitles: stageTitles,
                                materialSelections: selections,
                                shoppingItems: shoppingItems
                            )

                            dismiss()
                        } label: {
                            Text("Create Project")
                                .primaryButtonStyle()
                        }
                        .disabled(!canCreate)
                    }
                    .padding()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.yellow)
                }
            }
        }
    }

    private var canCreate: Bool {
        !projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        stageTitles.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private func materialBinding(_ id: UUID) -> Binding<Bool> {
        Binding {
            selectedMaterials.contains(id)
        } set: { isSelected in
            if isSelected {
                selectedMaterials.insert(id)
                materialQuantities[id] = materialQuantities[id] ?? 1
            } else {
                selectedMaterials.remove(id)
                materialQuantities[id] = nil
            }
        }
    }

    private func group<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.caption.bold())
                .foregroundColor(AppTheme.grayText)

            content()
        }
    }
}

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

// MARK: - SpriteKit Mini Game

final class CraftDropScene: SKScene {
    var difficulty: CraftDifficulty = .easy
    var onFinish: ((Bool) -> Void)?

    private var ropeNode: SKShapeNode?
    private var partNode: SKShapeNode?
    private var targetNode: SKShapeNode?
    private var laserNodes: [SKShapeNode] = []

    private var targetRect: CGRect = .zero
    private var hasCut = false
    private var lastUpdateTime: TimeInterval = 0

    private var firstDirection: CGFloat = 1
    private var secondDirection: CGFloat = -1

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(hex: 0x0E0B07)
        setupScene()
    }

    private func setupScene() {
        removeAllChildren()
        laserNodes.removeAll()

        addGridBackground()
        addWorkbench()
        addTarget()
        addRopeAndPart()
        addLasers()
    }

    private func addGridBackground() {
        let path = CGMutablePath()
        let spacing: CGFloat = 34

        var y: CGFloat = 0
        while y < size.height {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            y += spacing
        }

        let node = SKShapeNode(path: path)
        node.strokeColor = UIColor.white.withAlphaComponent(0.04)
        node.lineWidth = 1
        addChild(node)
    }

    private func addWorkbench() {
        let table = SKShapeNode(rectOf: CGSize(width: size.width * 0.95, height: 120), cornerRadius: 8)
        table.fillColor = UIColor(hex: 0x2A180B)
        table.strokeColor = UIColor(hex: 0x5B3713)
        table.lineWidth = 2
        table.position = CGPoint(x: size.width / 2, y: size.height * 0.16)
        addChild(table)
    }

    private func addTarget() {
        targetRect = CGRect(
            x: size.width * 0.24,
            y: size.height * 0.24,
            width: size.width * 0.52,
            height: 48
        )

        let target = SKShapeNode(rect: targetRect, cornerRadius: 4)
        target.fillColor = UIColor.green.withAlphaComponent(0.08)
        target.strokeColor = UIColor(hex: 0x4CC35A)
        target.lineWidth = 3
        addChild(target)
        targetNode = target
    }

    private func addRopeAndPart() {
        let top = CGPoint(x: size.width / 2, y: size.height * 0.88)
        let bottom = CGPoint(x: size.width / 2, y: size.height * 0.66)

        let ropePath = CGMutablePath()
        ropePath.move(to: top)
        ropePath.addLine(to: bottom)

        let rope = SKShapeNode(path: ropePath)
        rope.strokeColor = UIColor(hex: 0xA56A2A)
        rope.lineWidth = 3
        addChild(rope)
        ropeNode = rope

        let part = SKShapeNode(rectOf: CGSize(width: 150, height: 52), cornerRadius: 8)
        part.fillColor = UIColor(hex: 0x7A4D22)
        part.strokeColor = UIColor(hex: 0xA96A2B)
        part.lineWidth = 2
        part.position = CGPoint(x: size.width / 2, y: size.height * 0.62)
        addChild(part)
        partNode = part
    }

    private func addLasers() {
        switch difficulty {
        case .easy:
            let laser = makeLaser(width: 160)
            laser.position = CGPoint(x: size.width / 2, y: size.height * 0.43)
            addChild(laser)
            laserNodes.append(laser)

        case .medium:
            let laser = makeLaser(width: 130)
            laser.position = CGPoint(x: size.width * 0.2, y: size.height * 0.43)
            addChild(laser)
            laserNodes.append(laser)

        case .hard:
            let first = makeLaser(width: 120)
            first.position = CGPoint(x: size.width * 0.25, y: size.height * 0.46)
            addChild(first)

            let second = makeLaser(width: 120)
            second.position = CGPoint(x: size.width * 0.75, y: size.height * 0.38)
            addChild(second)

            laserNodes.append(contentsOf: [first, second])
        }
    }

    private func makeLaser(width: CGFloat) -> SKShapeNode {
        let laser = SKShapeNode(rectOf: CGSize(width: width, height: 9), cornerRadius: 4)
        laser.fillColor = UIColor(hex: 0xFF2E3A)
        laser.strokeColor = UIColor(hex: 0xFF2E3A)
        laser.glowWidth = 12
        return laser
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !hasCut else { return }
        cutRope()
    }

    private func cutRope() {
        hasCut = true
        ropeNode?.removeFromParent()

        let perfect = isPerfectMoment()

        let destinationX: CGFloat = perfect ? targetRect.midX : size.width * 0.82
        let destinationY: CGFloat = targetRect.midY + 20

        let drop = SKAction.move(to: CGPoint(x: destinationX, y: destinationY), duration: 0.55)
        drop.timingMode = .easeIn

        let rotate = SKAction.rotate(byAngle: perfect ? 0.05 : 0.8, duration: 0.55)
        let group = SKAction.group([drop, rotate])

        let flashColor = SKAction.run { [weak self] in
            guard let self else { return }
            self.backgroundColor = perfect ? UIColor(hex: 0x241D00) : UIColor(hex: 0x200A0A)
        }

        let callback = SKAction.run { [weak self] in
            self?.onFinish?(perfect)
        }

        partNode?.run(.sequence([group, flashColor, .wait(forDuration: 0.25), callback]))
    }

    private func isPerfectMoment() -> Bool {
        let dropX = size.width / 2

        let lasersAreSafe = laserNodes.allSatisfy { laser in
            let isActive = laser.alpha > 0.45
            let distance = abs(laser.position.x - dropX)
            return !isActive || distance > 110
        }

        return lasersAreSafe
    }

    override func update(_ currentTime: TimeInterval) {
        if lastUpdateTime == 0 {
            lastUpdateTime = currentTime
        }

        let dt = CGFloat(currentTime - lastUpdateTime)
        lastUpdateTime = currentTime

        guard !hasCut else { return }

        switch difficulty {
        case .easy:
            let phase = Int(currentTime) % 4
            laserNodes.first?.alpha = phase < 2 ? 1 : 0.2

        case .medium:
            moveLaser(index: 0, dt: dt, speed: 165, direction: &firstDirection)

        case .hard:
            if let first = laserNodes.first {
                let phase = Int(currentTime * 1.5) % 4
                first.alpha = phase < 2 ? 1 : 0.2
            }

            moveLaser(index: 1, dt: dt, speed: 210, direction: &secondDirection)
        }
    }

    private func moveLaser(
        index: Int,
        dt: CGFloat,
        speed: CGFloat,
        direction: inout CGFloat
    ) {
        guard laserNodes.indices.contains(index) else { return }

        let node = laserNodes[index]
        node.position.x += speed * dt * direction

        let minX: CGFloat = 70
        let maxX = size.width - 70

        if node.position.x < minX {
            node.position.x = minX
            direction = 1
        }

        if node.position.x > maxX {
            node.position.x = maxX
            direction = -1
        }
    }
}

// MARK: - Small UI Components

struct StatMiniCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.title2.bold())
                .foregroundColor(.white)

            Text(title)
                .font(.caption)
                .foregroundColor(AppTheme.grayText)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct ProgressRing: View {
    let progress: Double
    let color: Color
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: 7)

            Circle()
                .trim(from: 0, to: max(0, min(1, progress)))
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: 7, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 0) {
                Text("\(Int(progress * 100))%")
                    .font(.caption.bold())
                    .foregroundColor(color)

                Text("done")
                    .font(.system(size: 8).bold())
                    .foregroundColor(AppTheme.grayText)
            }
        }
        .frame(width: size, height: size)
    }
}

struct FlowLayout: View {
    let items: [String]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110))], spacing: 8) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
            }
        }
    }
}

extension Text {
    func primaryButtonStyle(
        color: Color = AppTheme.yellow,
        textColor: Color = .black
    ) -> some View {
        self
            .font(.headline.bold())
            .foregroundColor(textColor)
            .frame(maxWidth: .infinity)
            .padding()
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

extension View {
    func inputStyle() -> some View {
        self
            .padding()
            .foregroundColor(.white)
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

extension Double {
    var clean: String {
        if truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(self))
        }

        return String(format: "%.1f", self)
    }
}

extension DateFormatter {
    static let shortWeekday: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter
    }()
}