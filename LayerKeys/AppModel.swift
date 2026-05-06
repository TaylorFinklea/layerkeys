import AppKit
import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published var mode: LayerMode = .off
    @Published var permissionState: InputMonitoringPermissionState
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

    func requestPermission() {
        let granted = PermissionController.requestListenAccess()
        refreshPermissionState()
        if granted {
            restartEventTap()
        }
    }

    func refreshPermissionState() {
        permissionState = PermissionController.currentState()
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
