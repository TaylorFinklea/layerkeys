import SwiftUI

struct StatusMenuView: View {
    @ObservedObject var model: AppModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("LayerKeys")
                    .font(.headline)
                Text(model.mode.title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Label(model.permissionState.title, systemImage: model.permissionState.isGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(model.permissionState.isGranted ? .green : .orange)

                Text(model.permissionState.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if !model.permissionState.isGranted {
                    Button("Enable Keyboard Permissions") {
                        model.requestPermission()
                    }
                }
            }

            Divider()

            Text(instructionText)
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let lastError = model.lastError {
                Divider()
                Text(lastError)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Divider()

            Button("Open Settings") {
                openSettings()
            }

            Button("Refresh Permissions") {
                model.refreshPermissionState()
                model.restartEventTap()
            }

            Button("Quit LayerKeys") {
                model.quit()
            }
        }
        .padding()
        .frame(width: 320)
    }

    private var instructionText: String {
        let triggers = model.mappingProfile.triggers
        let chord = triggers.chordSummary
        let sub = triggers.numpadSubTrigger.title
        var parts: [String] = []
        if triggers.tapToEscapeEnabled {
            parts.append("Tap \(chord) for Escape.")
        }
        parts.append("Hold \(chord) for navigation.")
        parts.append("Press \(sub) while the layer is active to switch into numpad.")
        return parts.joined(separator: " ")
    }
}
