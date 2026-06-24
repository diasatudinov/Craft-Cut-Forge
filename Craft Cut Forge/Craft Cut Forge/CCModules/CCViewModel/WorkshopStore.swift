//
//  WorkshopStore.swift
//  Craft Cut Forge
//
//

import SwiftUI

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

    private let storageKey = "craft_cut_forge_storage_v2"

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
        unit: MaterialUnit,
        imageData: Data?
    ) {
        let imageFileName: String?

        if let imageData {
            imageFileName = ProjectImageStorage.saveImageData(imageData)
        } else {
            imageFileName = nil
        }

        let material = InventoryMaterial(
            name: name,
            category: category,
            quantity: quantity,
            unit: unit,
            imageFileName: imageFileName
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
        coverImageData: Data?,
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

        let imageFileName: String?

        if let coverImageData {
            imageFileName = ProjectImageStorage.saveImageData(coverImageData)
        } else {
            imageFileName = nil
        }

        let project = CraftProject(
            name: name,
            category: requirements.first?.category.rawValue ?? "DIY",
            coverImageFileName: imageFileName,
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
