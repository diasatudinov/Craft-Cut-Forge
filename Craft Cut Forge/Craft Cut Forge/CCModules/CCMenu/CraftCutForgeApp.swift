//
//  CraftCutForgeApp.swift
//  Craft Cut Forge
//
//


import SwiftUI
import SpriteKit
import UIKit

#Preview {
    RootView()
        .environmentObject(WorkshopStore())
}

// MARK: - Theme

enum AppTheme {
    static let background = Color.background
    static let card = Color.white.opacity(0.05)
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

enum AppTab: Hashable, CaseIterable {
    case workbench
    case craft
    case inventory
    case analytics

    var title: String {
        switch self {
        case .workbench: return "Workbench"
        case .craft: return "Craft"
        case .inventory: return "Inventory"
        case .analytics: return "Analytics"
        }
    }

    var icon: String {
        switch self {
        case .workbench: return "hammer"
        case .craft: return "scissors"
        case .inventory: return "shippingbox"
        case .analytics: return "chart.bar"
        }
    }

    var selectedIcon: String {
        switch self {
        case .workbench: return "hammer.fill"
        case .craft: return "scissors"
        case .inventory: return "shippingbox.fill"
        case .analytics: return "chart.bar.fill"
        }
    }
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
    var imageFileName: String?
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
    var coverImageFileName: String?
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



// MARK: - Root

struct RootView: View {
    @EnvironmentObject private var store: WorkshopStore

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                ZStack {
                    tabContent(.workbench) {
                        NavigationStack {
                            WorkbenchView()
                        }
                    }
                    
                    tabContent(.craft) {
                        NavigationStack {
                            CraftHubView()
                        }
                    }
                    
                    tabContent(.inventory) {
                        NavigationStack {
                            InventoryView()
                        }
                    }
                    
                    tabContent(.analytics) {
                        NavigationStack {
                            AnalyticsView()
                        }
                    }
                }
                
                CustomTabBar(selectedTab: $store.selectedTab)
            }
        }
        
    }

    @ViewBuilder
    private func tabContent<Content: View>(
        _ tab: AppTab,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .opacity(store.selectedTab == tab ? 1 : 0)
            .allowsHitTesting(store.selectedTab == tab)
    }
}

struct CustomTabBar: View {
    @Binding var selectedTab: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                CustomTabBarItem(
                    tab: tab,
                    isSelected: selectedTab == tab
                ) {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                        selectedTab = tab
                    }
                }
            }
        }
        .padding(.top, 10)
        .padding(.horizontal, 8)
        .background(.tabBg)
    }
}

struct CustomTabBarItem: View {
    let tab: AppTab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                ZStack {

                    Image(systemName: isSelected ? tab.selectedIcon : tab.icon)
                        .font(.system(size: 19, weight: isSelected ? .bold : .regular))
                        .foregroundColor(isSelected ? AppTheme.yellow : AppTheme.grayText)
                }

                Text(tab.title)
                    .font(.system(size: 10, weight: isSelected ? .bold : .regular))
                    .foregroundColor(isSelected ? AppTheme.yellow : AppTheme.grayText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
