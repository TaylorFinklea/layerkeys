import AppKit
import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published var mode: LayerMode = .off
    @Published var permissionState: InputMonitoringPermissionState
    @Published var accessibilityGranted: Bool
    @Published var mappingProfile: MappingProfile
    @Published var lastError: String?
    @Published private(set) var launchAtLoginEnabled: Bool
    @Published private(set) var tapErrorActive: Bool = false
    @Published private(set) var updateAvailable: Bool = false

    private let mappingStore: MappingStore
    private let eventTapService: EventTapService
    private let launchAtLoginController: LaunchAtLoginController
    private let userDefaults: UserDefaults

    static let didShowLaunchAtLoginPromptKey = "didShowLaunchAtLoginPrompt"

    init(
        mappingStore: MappingStore = .shared,
        eventTapService: EventTapService? = nil,
        launchAtLoginController: LaunchAtLoginController? = nil,
        userDefaults: UserDefaults = .standard
    ) {
        self.mappingStore = mappingStore
        self.userDefaults = userDefaults
        let profile = mappingStore.load()
        mappingProfile = profile
        permissionState = PermissionController.currentState()
        accessibilityGranted = PermissionController.hasPostEventAccess

        let service = eventTapService ?? EventTapService(profile: profile)
        self.eventTapService = service

        let controller = launchAtLoginController ?? LaunchAtLoginController()
        self.launchAtLoginController = controller
        launchAtLoginEnabled = controller.isEnabled

        service.onModeChange = { [weak self] mode in
            Task { @MainActor in
                self?.mode = mode
            }
        }
        service.onTapError = { [weak self] message in
            Task { @MainActor in
                self?.lastError = message
                self?.tapErrorActive = true
            }
        }
        service.onTapRecovered = { [weak self] in
            Task { @MainActor in
                self?.tapErrorActive = false
            }
        }

        if permissionState.isGranted {
            if !service.start() {
                lastError = "LayerKeys could not start the global event tap."
            }
        }

        if !didShowLaunchAtLoginPrompt && !Self.isRunningUnderXCTest {
            Task { @MainActor [weak self] in
                self?.showLaunchAtLoginPromptIfNeeded()
            }
        }
    }

    /// True when the host process is the XCTest runner. We skip the
    /// first-launch NSAlert in that case because `runModal()` blocks the host
    /// app's run loop, which makes the test runner time out before it can
    /// start executing tests on a fresh CI runner where
    /// `didShowLaunchAtLoginPrompt` is still false.
    private static var isRunningUnderXCTest: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    func showLaunchAtLoginPromptIfNeeded() {
        guard !didShowLaunchAtLoginPrompt else { return }

        let alert = NSAlert()
        alert.messageText = "Start LayerKeys at login?"
        alert.informativeText = "Run LayerKeys automatically when you sign in. You can change this anytime in Settings → General."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Start at Login")
        alert.addButton(withTitle: "Not Now")

        let response = alert.runModal()
        markLaunchAtLoginPromptShown()
        if response == .alertFirstButtonReturn {
            setLaunchAtLogin(true)
        }
    }

    var didShowLaunchAtLoginPrompt: Bool {
        userDefaults.bool(forKey: Self.didShowLaunchAtLoginPromptKey)
    }

    func markLaunchAtLoginPromptShown() {
        userDefaults.set(true, forKey: Self.didShowLaunchAtLoginPromptKey)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try launchAtLoginController.setEnabled(enabled)
            launchAtLoginEnabled = launchAtLoginController.isEnabled
            lastError = nil
        } catch {
            lastError = "Couldn't change launch-at-login: \(error.localizedDescription)"
        }
    }

    func toggleLaunchAtLogin() {
        setLaunchAtLogin(!launchAtLoginEnabled)
    }

    /// Backwards-compatible entry point — requests both permissions. Kept
    /// for any caller that still wants a single nudge; new UI uses the
    /// per-permission methods below so each row has its own button.
    func requestPermission() {
        requestInputMonitoring()
        requestAccessibility()
    }

    func requestInputMonitoring() {
        // First call triggers the system prompt and registers LayerKeys in
        // the Input Monitoring list. Subsequent calls return false silently
        // once the user has denied — macOS won't re-prompt — so we also
        // deep-link to the Settings pane as a recovery path.
        let granted = PermissionController.requestListenAccess()
        refreshPermissionState()
        if granted {
            restartEventTap()
            return
        }
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }

    func requestAccessibility() {
        // CGRequestPostEventAccess prompts the first time; after a denial
        // it just returns false. Deep-link to the Accessibility pane so the
        // user can toggle LayerKeys on manually — the typical recovery
        // path after the first prompt has been dismissed.
        let granted = PermissionController.requestPostAccess()
        refreshPermissionState()
        if granted {
            restartEventTap()
            return
        }
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Relaunches LayerKeys. The kernel binds an event tap's permission
    /// snapshot at creation time and won't upgrade it even after TCC says
    /// yes, so granting Input Monitoring or Accessibility to a running
    /// instance still produces a dead tap. A fresh process is the only
    /// reliable way to pick the new permissions up.
    func relaunch() {
        let bundlePath = Bundle.main.bundlePath
        let task = Process()
        task.launchPath = "/bin/sh"
        // Brief delay so the current process is fully gone before `open`
        // looks for a duplicate; otherwise LaunchServices reuses the
        // dying instance and silently no-ops.
        task.arguments = ["-c", "sleep 0.4 && /usr/bin/open \"\(bundlePath)\""]
        do {
            try task.run()
        } catch {
            lastError = "Couldn't relaunch LayerKeys: \(error.localizedDescription)"
            return
        }
        NSApp.terminate(nil)
    }

    func refreshPermissionState() {
        permissionState = PermissionController.currentState()
        accessibilityGranted = PermissionController.hasPostEventAccess
    }

    func restartEventTap() {
        mode = .off
        eventTapService.updateProfile(mappingProfile)
        guard permissionState.isGranted else {
            eventTapService.stop()
            return
        }

        if !eventTapService.start() {
            lastError = "LayerKeys could not start the global event tap."
        } else {
            lastError = nil
        }
    }

    func saveMappings() {
        do {
            try mappingStore.save(mappingProfile)
            lastError = nil
            restartEventTap()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func resetMappings() {
        mappingProfile = .default
        do {
            try mappingStore.save(mappingProfile)
            lastError = nil
            restartEventTap()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func addNavigationBinding() {
        let nextSource = nextAvailableInputKey(excluding: mappingProfile.navigation.map(\.source)) ?? .a
        let nextTarget = NavigationTargetKey.allCases.first(where: { candidate in
            !mappingProfile.navigation.contains(where: { $0.target == candidate })
        }) ?? .leftArrow

        mappingProfile.navigation.append(NavigationBinding(source: nextSource, target: nextTarget))
        saveMappings()
    }

    func removeNavigationBinding(id: UUID) {
        mappingProfile.navigation.removeAll { $0.id == id }
        saveMappings()
    }

    func updateNavigationBinding(_ binding: NavigationBinding) {
        guard let index = mappingProfile.navigation.firstIndex(where: { $0.id == binding.id }) else {
            return
        }
        mappingProfile.navigation[index] = binding
        saveMappings()
    }

    func addNumpadBinding() {
        let nextSource = nextAvailableInputKey(excluding: mappingProfile.numpad.map(\.source)) ?? .a
        let nextTarget = NumpadTargetKey.allCases.first(where: { candidate in
            !mappingProfile.numpad.contains(where: { $0.target == candidate })
        }) ?? .keypad0

        mappingProfile.numpad.append(NumpadBinding(source: nextSource, target: nextTarget))
        saveMappings()
    }

    func removeNumpadBinding(id: UUID) {
        mappingProfile.numpad.removeAll { $0.id == id }
        saveMappings()
    }

    func updateNumpadBinding(_ binding: NumpadBinding) {
        guard let index = mappingProfile.numpad.firstIndex(where: { $0.id == binding.id }) else {
            return
        }
        mappingProfile.numpad[index] = binding
        saveMappings()
    }

    func updateTriggerProfile(_ triggers: TriggerProfile) {
        mappingProfile.triggers = triggers
        saveMappings()
    }

    var menuBarVariant: (variant: MenuBarIconView.Variant, badge: Bool) {
        resolveMenuBarVariant(
            mode: mode,
            perm: permissionState,
            tapErrorActive: tapErrorActive,
            updateAvailable: updateAvailable
        )
    }

    func setUpdateAvailable(_ available: Bool) {
        updateAvailable = available
    }

    func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func nextAvailableInputKey(excluding usedKeys: [InputKey]) -> InputKey? {
        InputKey.allCases.first { !usedKeys.contains($0) }
    }
}
