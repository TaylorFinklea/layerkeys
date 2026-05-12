import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        TabView {
            mappingsView
                .tabItem {
                    Label("Mappings", systemImage: "keyboard")
                }

            triggersView
                .tabItem {
                    Label("Triggers", systemImage: "hand.tap")
                }

            generalView
                .tabItem {
                    Label("General", systemImage: "gearshape")
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

            Text("Bindings fire while the layer trigger is held. Configure the trigger chord itself in the Triggers tab.")
                .foregroundStyle(.secondary)

            Form {
                Section("Navigation Layer") {
                    ForEach($model.mappingProfile.navigation) { $binding in
                        BindingRow(
                            binding: $binding,
                            targetWidth: 160,
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
                        BindingRow(
                            binding: $binding,
                            targetWidth: 180,
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

    private var triggersView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Triggers")
                .font(.title2.weight(.semibold))

            Text("The layer trigger is the chord you press to activate the navigation layer. While the layer is active, press the numpad sub-trigger to switch into the numpad layer until you release the trigger.")
                .foregroundStyle(.secondary)

            Form {
                Section("Layer trigger") {
                    LabeledContent("Key") {
                        InputKeyPicker(selection: $model.mappingProfile.triggers.layerKey)
                            .onChange(of: model.mappingProfile.triggers.layerKey) { _, _ in
                                model.saveMappings()
                            }
                    }

                    LabeledContent("Modifiers") {
                        HStack(spacing: 8) {
                            ForEach(TriggerModifier.allCases) { modifier in
                                Toggle(modifier.title, isOn: Binding(
                                    get: { model.mappingProfile.triggers.layerModifiers.contains(modifier) },
                                    set: { isOn in
                                        if isOn {
                                            model.mappingProfile.triggers.layerModifiers.insert(modifier)
                                        } else {
                                            model.mappingProfile.triggers.layerModifiers.remove(modifier)
                                        }
                                        model.saveMappings()
                                    }
                                ))
                                .toggleStyle(.button)
                            }
                        }
                    }
                }

                Section("Numpad sub-trigger") {
                    LabeledContent("Key") {
                        InputKeyPicker(selection: $model.mappingProfile.triggers.numpadSubTrigger)
                            .onChange(of: model.mappingProfile.triggers.numpadSubTrigger) { _, _ in
                                model.saveMappings()
                            }
                    }
                }

                Section("Tap to Escape") {
                    Toggle(
                        "Emit Escape when the trigger is tapped without another key",
                        isOn: $model.mappingProfile.triggers.tapToEscapeEnabled
                    )
                    .onChange(of: model.mappingProfile.triggers.tapToEscapeEnabled) { _, _ in
                        model.saveMappings()
                    }
                }
            }
            .formStyle(.grouped)

            HStack(spacing: 6) {
                Text("Current trigger:")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(model.mappingProfile.triggers.chordSummary)
                    .font(.footnote.monospaced())
            }

            let issues = model.mappingProfile.validateTriggers()
            if !issues.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(issues, id: \.self) { issue in
                        Label(issue.message, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
    }

    private var generalView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("General")
                .font(.title2.weight(.semibold))

            Form {
                Section("Startup") {
                    Toggle(
                        "Start LayerKeys at login",
                        isOn: Binding(
                            get: { model.launchAtLoginEnabled },
                            set: { model.setLaunchAtLogin($0) }
                        )
                    )

                    Text("LayerKeys will register itself as a login item via macOS Service Management. You can also remove it from System Settings → General → Login Items.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Updates") {
                    Text("LayerKeys checks for new releases automatically once a day and prompts you when one is available. Use the menu-bar Check for Updates… button to check manually.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)

            Spacer()
        }
    }

    private var permissionsView: some View {
        let inputGranted = model.permissionState != .denied
        let accessibilityGranted = model.accessibilityGranted

        return VStack(alignment: .leading, spacing: 16) {
            Text("Permissions")
                .font(.title2.weight(.semibold))

            Text("LayerKeys needs Input Monitoring to read keyboard events globally. Accessibility is required to replay a plain Escape tap when you release the trigger without using a layer.")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                permissionRow(
                    title: "Input Monitoring",
                    granted: inputGranted,
                    action: { model.requestInputMonitoring() }
                )

                permissionRow(
                    title: "Accessibility",
                    granted: accessibilityGranted,
                    action: { model.requestAccessibility() }
                )
            }

            if !(inputGranted && accessibilityGranted) {
                Text("After granting access in System Settings, restart LayerKeys so the global event tap picks up the new permissions.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button("Restart LayerKeys") {
                    model.relaunch()
                }
            }

            if let lastError = model.lastError {
                Text(lastError)
                    .foregroundStyle(.red)
            }

            Spacer()
        }
    }

    @ViewBuilder
    private func permissionRow(
        title: String,
        granted: Bool,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            Label(
                title,
                systemImage: granted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
            )
            .foregroundStyle(granted ? .green : .orange)

            Spacer()

            if !granted {
                Button("Enable \(title)") {
                    action()
                }
            }
        }
    }
}

private protocol LayerTargetKey: CaseIterable, Hashable, Identifiable {
    var title: String { get }
}

extension NavigationTargetKey: LayerTargetKey {}
extension NumpadTargetKey: LayerTargetKey {}

private protocol LayerBindingModel: Identifiable {
    associatedtype Target: LayerTargetKey
    var source: InputKey { get set }
    var target: Target { get set }
}

extension NavigationBinding: LayerBindingModel {}
extension NumpadBinding: LayerBindingModel {}

private struct InputKeyPicker: View {
    @Binding var selection: InputKey
    var width: CGFloat = 160

    var body: some View {
        Picker("Key", selection: $selection) {
            ForEach(InputKey.Category.allCases, id: \.self) { category in
                Section(category.title) {
                    ForEach(InputKey.cases(in: category)) { key in
                        Text(key.title).tag(key)
                    }
                }
            }
        }
        .labelsHidden()
        .frame(width: width)
    }
}

private struct BindingRow<Model: LayerBindingModel>: View {
    @Binding var binding: Model
    let targetWidth: CGFloat
    let onDelete: () -> Void
    let onChange: () -> Void

    var body: some View {
        HStack {
            InputKeyPicker(selection: $binding.source, width: 140)
                .onChange(of: binding.source) { _, _ in
                    onChange()
                }

            Image(systemName: "arrow.right")
                .foregroundStyle(.secondary)

            Picker("To", selection: $binding.target) {
                ForEach(Array(Model.Target.allCases)) { key in
                    Text(key.title).tag(key)
                }
            }
            .labelsHidden()
            .frame(width: targetWidth)
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
