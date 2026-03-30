import Foundation

@MainActor
struct MappingStore {
    static let shared = MappingStore()

    private let defaults: UserDefaults
    private let profileKey = "mappingProfile"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> MappingProfile {
        guard
            let data = defaults.data(forKey: profileKey),
            let profile = try? JSONDecoder().decode(MappingProfile.self, from: data)
        else {
            return .default
        }

        return profile
    }

    func save(_ profile: MappingProfile) throws {
        let data = try JSONEncoder().encode(profile)
        defaults.set(data, forKey: profileKey)
    }

    func reset() {
        defaults.removeObject(forKey: profileKey)
    }
}
