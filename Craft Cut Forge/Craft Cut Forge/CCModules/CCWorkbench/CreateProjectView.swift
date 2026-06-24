//
//  CreateProjectView.swift
//  Craft Cut Forge
//
//

import SwiftUI
import PhotosUI
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
    
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var coverImageData: Data?
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

                        group("Project Cover Photo") {
                            PhotosPicker(
                                selection: $selectedPhotoItem,
                                matching: .images,
                                photoLibrary: .shared()
                            ) {
                                if let coverImageData,
                                   let uiImage = UIImage(data: coverImageData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(height: 180)
                                        .frame(maxWidth: .infinity)
                                        .clipShape(RoundedRectangle(cornerRadius: 18))
                                } else {
                                    Image(.placeholderCoverPhotoCC)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(height: 180)
                                }
                            }
                            .onChange(of: selectedPhotoItem) { newItem in
                                Task {
                                    guard let data = try? await newItem?.loadTransferable(type: Data.self) else {
                                        return
                                    }

                                    await MainActor.run {
                                        coverImageData = data
                                    }
                                }
                            }
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
                                coverImageData: coverImageData,
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

#Preview {
    CreateProjectView()
        .environmentObject(WorkshopStore())
}
