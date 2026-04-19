import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        TabView {
            mappingsView
                .tabItem {
                    Label("Mappings", systemImage: "keyboard")
                }

            permissionsView
                .tabItem {
                    Label("Permissions", systemImage: "lock.shield")
                }
        }
        .padding()
        .frame(minWidth: 640, minHeight: 460)
    }

    private var mappingsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Layer Mappings")
                .font(.title2.weight(.semibold))

            Text("Triggers are fixed in v1: hold Control+Space for navigation, tap Control+Space for Escape, and press A after the layer is active to switch from navigation to numpad.")
                .foregroundStyle(.secondary)

            Form {
                Section("Navigation Layer") {
                    ForEach($model.mappingProfile.navigation) { $binding in
                        NavigationBindingRow(
                            binding: $binding,
                            onDelete: { model.removeNavigationBinding(id: binding.id) },
                            onChange: model.saveMappings
                        )
                    }

                    Button("Add Navigation Mapping") {
                        model.addNavigationBinding()
                    }
                }

                Section("Numpad Layer") {
                    ForEach($model.mappingProfile.numpad) { $binding in
                        NumpadBindingRow(
                            binding: $binding,
                            onDelete: { model.removeNumpadBinding(id: binding.id) },
                            onChange: model.saveMappings
                        )
                    }

                    Button("Add Numpad Mapping") {
                        model.addNumpadBinding()
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Reset Defaults") {
                    model.resetMappings()
                }

                Spacer()

                Text("If two entries use the same source key, the lower entry wins.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var permissionsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Permissions")
                .font(.title2.weight(.semibold))

            Label(model.permissionState.title, systemImage: model.permissionState.isGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(model.permissionState.isGranted ? .green : .orange)

            Text(model.permissionState.detail)
                .foregroundStyle(.secondary)

            Text("LayerKeys needs Input Monitoring to read keyboard events globally. Accessibility is optional and only used to replay a normal Escape tap when you release Control+Space without using a layer.")
                .foregroundStyle(.secondary)

            HStack {
                Button("Request Access") {
                    model.requestPermission()
                }

                Button("Refresh Status") {
                    model.refreshPermissionState()
                    model.restartEventTap()
                }
            }

            if let lastError = model.lastError {
                Text(lastError)
                    .foregroundStyle(.red)
            }

            Spacer()
        }
    }
}

private struct NavigationBindingRow: View {
    @Binding var binding: NavigationBinding
    let onDelete: () -> Void
    let onChange: () -> Void

    var body: some View {
        HStack {
            Picker("From", selection: $binding.source) {
                ForEach(InputKey.Category.allCases, id: \.self) { category in
                    Section(category.title) {
                        ForEach(InputKey.cases(in: category)) { key in
                            Text(key.title).tag(key)
                        }
                    }
                }
            }
            .labelsHidden()
            .frame(width: 140)
            .onChange(of: binding.source) { _, _ in
                onChange()
            }

            Image(systemName: "arrow.right")
                .foregroundStyle(.secondary)

            Picker("To", selection: $binding.target) {
                ForEach(NavigationTargetKey.allCases) { key in
                    Text(key.title).tag(key)
                }
            }
            .labelsHidden()
            .frame(width: 160)
            .onChange(of: binding.target) { _, _ in
                onChange()
            }

            Spacer()

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
    }
}

private struct NumpadBindingRow: View {
    @Binding var binding: NumpadBinding
    let onDelete: () -> Void
    let onChange: () -> Void

    var body: some View {
        HStack {
            Picker("From", selection: $binding.source) {
                ForEach(InputKey.Category.allCases, id: \.self) { category in
                    Section(category.title) {
                        ForEach(InputKey.cases(in: category)) { key in
                            Text(key.title).tag(key)
                        }
                    }
                }
            }
            .labelsHidden()
            .frame(width: 140)
            .onChange(of: binding.source) { _, _ in
                onChange()
            }

            Image(systemName: "arrow.right")
                .foregroundStyle(.secondary)

            Picker("To", selection: $binding.target) {
                ForEach(NumpadTargetKey.allCases) { key in
                    Text(key.title).tag(key)
                }
            }
            .labelsHidden()
            .frame(width: 180)
            .onChange(of: binding.target) { _, _ in
                onChange()
            }

            Spacer()

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
    }
}
