import SwiftUI

@main
struct LayerKeysApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            StatusMenuView(model: model)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: model.permissionState.isGranted ? model.mode.symbolName : "exclamationmark.triangle.fill")
                Text(model.mode.menuBarLabel)
                    .monospacedDigit()
            }
            .foregroundStyle(model.permissionState.isGranted ? Color.primary : .orange)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(model: model)
        }
    }
}
