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