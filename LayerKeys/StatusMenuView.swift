import Sparkle
import SwiftUI

struct StatusMenuView: View {
    @ObservedObject var model: AppModel
    let updater: SPUUpdater
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

            if !model.allPermissionsGranted {
                permissionsSection

                Divider()
            }

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
                // LSUIElement: true makes LayerKeys a background process,
                // which means SwiftUI's openSettings() creates the window
                // but doesn't bring our process to the front. Activate
                // explicitly so the Settings window comes forward.
                NSApp.activate(ignoringOtherApps: true)
                openSettings()
            }

            CheckForUpdatesView(updater: updater)

            Button("Quit LayerKeys") {
                model.quit()
            }
        }
        .padding()
        .frame(width: 320)
    }

    /// Per-permission status + enable buttons. macOS treats Input
    /// Monitoring and Accessibility as separate TCC permissions with
    /// separate prompts; surfacing them as one combined "Keyboard
    /// Permissions" row obscured which one needed attention. Also
    /// shows a Restart button whenever something is missing — the
    /// kernel-cached event tap won't pick up newly-granted permissions
    /// without a fresh process.
    @ViewBuilder
    private var permissionsSection: some View {
        let inputGranted = model.permissionState != .denied
        let accessibilityGranted = model.accessibilityGranted
        let allGranted = inputGranted && accessibilityGranted

        VStack(alignment: .leading, spacing: 10) {
            permissionRow(
                title: "Input Monitoring",
                granted: inputGranted,
                deniedDetail: "Listen for the layer trigger and remap keys globally.",
                action: { model.requestInputMonitoring() }
            )

            permissionRow(
                title: "Accessibility",
                granted: accessibilityGranted,
                deniedDetail: "Replay the plain Escape tap when you release the trigger without using a layer.",
                action: { model.requestAccessibility() }
            )

            if !allGranted {
                Text("After granting access, restart LayerKeys so the global event tap picks up the new permissions.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button("Restart LayerKeys") {
                    model.relaunch()
                }
            }
        }
    }

    @ViewBuilder
    private func permissionRow(
        title: String,
        granted: Bool,
        deniedDetail: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(
                title,
                systemImage: granted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
            )
            .foregroundStyle(granted ? .green : .orange)

            if !granted {
                Text(deniedDetail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button("Enable \(title)") {
                    action()
                }
            }
        }
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
