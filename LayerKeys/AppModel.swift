import AppKit
import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published var mode: LayerMode = .off
    @Published var permissionState: InputMonitoringPermissionState
    @Published var mappingProfile: MappingProfile
    @Published var lastError: String?

    private let mappingStore: MappingStore
    private let eventTapService: EventTapService

    init(
        mappingStore: MappingStore = .shared,
        eventTapService: EventTapService? = nil
    ) {
        self.mappingStore = mappingStore
        let profile = mappingStore.load()
        mappingProfile = profile
        permissionState = PermissionController.currentState()

        let service = eventTapService ?? EventTapService(profile: profile)
        self.eventTapService = service

        service.onModeChange = { [weak self] mode in
            Task { @MainActor in
                self?.mode = mode
            }
        }
        service.onTapError = { [weak self] message in
            Task { @MainActor in
                self?.lastError = message
            }
        }

        if permissionState.isGranted {
            if !service.start() {
                lastError = "LayerKeys could not start the global event tap."
            }
        }
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

    func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func nextAvailableInputKey(excluding usedKeys: [InputKey]) -> InputKey? {
        InputKey.allCases.first { !usedKeys.contains($0) }
    }
}
