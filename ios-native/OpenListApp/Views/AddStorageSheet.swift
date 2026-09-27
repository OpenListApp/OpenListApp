import SwiftUI

/// 添加存储:选择驱动并填写 通用/附加 配置。
struct AddStorageSheet: View {
    let api: APIClient
    var onSaved: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var drivers: [String: DriverInfo] = [:]
    @State private var selectedDriver = ""
    @State private var loadingDrivers = false
    @State private var saving = false
    @State private var errorText: String?
    @State private var commonValues: [String: String] = [:]
    @State private var commonBools: [String: Bool] = [:]
    @State private var additionalValues: [String: String] = [:]
    @State private var additionalBools: [String: Bool] = [:]

    var body: some View {
        NavigationStack {
            Group {
                if loadingDrivers {
                    ProgressView()
                } else if selectedDriver.isEmpty {
                    ContentUnavailableView(
                        "选择驱动",
                        systemImage: "shippingbox",
                        description: Text("先选择一个存储驱动")
                    )
                } else {
                    form
                }
            }
            .navigationTitle("添加存储")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if saving {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("添加")
                        }
                    }
                    .disabled(selectedDriver.isEmpty || saving)
                }
            }
            .task { await loadDrivers() }
            .errorAlert($errorText)
        }
        .presentationDetents([.large])
    }

    private var info: DriverInfo? {
        drivers[selectedDriver]
    }

    private var form: some View {
        Form {
            Section("驱动") {
                Picker("驱动类型", selection: $selectedDriver) {
                    ForEach(drivers.keys.sorted(), id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
            }

            if let common = info?.common, !common.isEmpty {
                Section("通用配置") {
                    ForEach(common) { field in
                        fieldRow(field, values: $commonValues, bools: $commonBools)
                    }
                }
            }

            if let additional = info?.additional, !additional.isEmpty {
                Section("附加配置") {
                    ForEach(additional) { field in
                        fieldRow(field, values: $additionalValues, bools: $additionalBools)
                    }
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private func fieldRow(
        _ field: DriverField,
        values: Binding<[String: String]>,
        bools: Binding<[String: Bool]>
    ) -> some View {
        let label = field.isRequired ? field.name + " *" : field.name
        switch field.fieldType {
        case "bool":
            Toggle(label, isOn: Binding(
                get: { bools.wrappedValue[field.name] ?? field.default?.boolValue ?? false },
                set: { bools.wrappedValue[field.name] = $0 }
            ))
        case "select":
            Picker(label, selection: Binding(
                get: { values.wrappedValue[field.name] ?? field.default?.stringValue ?? "" },
                set: { values.wrappedValue[field.name] = $0 }
            )) {
                ForEach(field.selectOptions, id: \.self) { option in
                    Text(option).tag(option)
                }
            }
        default:
            VStack(alignment: .leading, spacing: 4) {
                Text(label).font(.caption).foregroundStyle(.secondary)
                TextField(
                    field.help ?? field.name,
                    text: Binding(
                        get: { values.wrappedValue[field.name] ?? field.default?.stringValue ?? "" },
                        set: { values.wrappedValue[field.name] = $0 }
                    )
                )
                .keyboardType(field.fieldType == "number" || field.fieldType == "float" ? .numbersAndPunctuation : .default)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            }
        }
    }

    private func loadDrivers() async {
        loadingDrivers = true
        defer { loadingDrivers = false }
        do {
            drivers = try await api.driverList()
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func collect(_ fields: [DriverField]?, values: [String: String], bools: [String: Bool]) -> [String: Any] {
        var result: [String: Any] = [:]
        guard let fields else { return result }
        for field in fields {
            switch field.fieldType {
            case "bool":
                result[field.name] = bools[field.name] ?? field.default?.boolValue ?? false
            case "number":
                let raw = values[field.name] ?? field.default?.stringValue ?? ""
                result[field.name] = Double(raw) ?? 0
            case "float":
                let raw = values[field.name] ?? field.default?.stringValue ?? ""
                result[field.name] = Double(raw) ?? 0
            default:
                result[field.name] = values[field.name] ?? field.default?.stringValue ?? ""
            }
        }
        return result
    }

    private func save() async {
        guard let info else { return }
        saving = true
        defer { saving = false }
        let common = collect(info.common, values: commonValues, bools: commonBools)
        let additional = collect(info.additional, values: additionalValues, bools: additionalBools)
        var payload = common
        payload["driver"] = selectedDriver
        payload["addition"] = (try? String(data: JSONSerialization.data(withJSONObject: additional), encoding: .utf8)) ?? "{}"
        do {
            try await api.createStorage(payload)
            dismiss()
            await onSaved()
        } catch {
            errorText = error.localizedDescription
        }
    }
}
