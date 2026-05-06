import CoreGraphics
import Foundation

typealias KeyCode = CGKeyCode

enum InputKey: String, CaseIterable, Codable, Hashable, Identifiable {
    case a, b, c, d, e, f, g, h, i, j, k, l, m
    case n, o, p, q, r, s, t, u, v, w, x, y, z

    case one, two, three, four, five, six, seven, eight, nine, zero

    case grave
    case minus
    case equal
    case leftBracket
    case rightBracket
    case backslash
    case semicolon
    case quote
    case comma
    case period
    case slash
    case space

    case sectionKey

    var id: String { rawValue }

    enum Category: CaseIterable {
        case letters
        case digits
        case punctuation
        case iso

        var title: String {
            switch self {
            case .letters: return "Letters"
            case .digits: return "Digits"
            case .punctuation: return "Punctuation & Space"
            case .iso: return "ISO"
            }
        }
    }

    var category: Category {
        switch self {
        case .a, .b, .c, .d, .e, .f, .g, .h, .i, .j, .k, .l, .m,
             .n, .o, .p, .q, .r, .s, .t, .u, .v, .w, .x, .y, .z:
            return .letters
        case .one, .two, .three, .four, .five, .six, .seven, .eight, .nine, .zero:
            return .digits
        case .grave, .minus, .equal, .leftBracket, .rightBracket, .backslash,
             .semicolon, .quote, .comma, .period, .slash, .space:
            return .punctuation
        case .sectionKey:
            return .iso
        }
    }

    static func cases(in category: Category) -> [InputKey] {
        allCases.filter { $0.category == category }
    }

    var title: String {
        switch self {
        case .semicolon: return ";"
        case .quote: return "'"
        case .comma: return ","
        case .period: return "."
        case .slash: return "/"
        case .space: return "Space"
        case .grave: return "`"
        case .minus: return "-"
        case .equal: return "="
        case .leftBracket: return "["
        case .rightBracket: return "]"
        case .backslash: return "\\"
        case .one: return "1"
        case .two: return "2"
        case .three: return "3"
        case .four: return "4"
        case .five: return "5"
        case .six: return "6"
        case .seven: return "7"
        case .eight: return "8"
        case .nine: return "9"
        case .zero: return "0"
        case .sectionKey: return "§"
        default:
            return rawValue.uppercased()
        }
    }

    var keyCode: KeyCode {
        switch self {
        case .a: return 0x00
        case .b: return 0x0B
        case .c: return 0x08
        case .d: return 0x02
        case .e: return 0x0E
        case .f: return 0x03
        case .g: return 0x05
        case .h: return 0x04
        case .i: return 0x22
        case .j: return 0x26
        case .k: return 0x28
        case .l: return 0x25
        case .m: return 0x2E
        case .n: return 0x2D
        case .o: return 0x1F
        case .p: return 0x23
        case .q: return 0x0C
        case .r: return 0x0F
        case .s: return 0x01
        case .t: return 0x11
        case .u: return 0x20
        case .v: return 0x09
        case .w: return 0x0D
        case .x: return 0x07
        case .y: return 0x10
        case .z: return 0x06
        case .one: return 0x12
        case .two: return 0x13
        case .three: return 0x14
        case .four: return 0x15
        case .five: return 0x17
        case .six: return 0x16
        case .seven: return 0x1A
        case .eight: return 0x1C
        case .nine: return 0x19
        case .zero: return 0x1D
        case .grave: return 0x32
        case .minus: return 0x1B
        case .equal: return 0x18
        case .leftBracket: return 0x21
        case .rightBracket: return 0x1E
        case .backslash: return 0x2A
        case .semicolon: return 0x29
        case .quote: return 0x27
        case .comma: return 0x2B
        case .period: return 0x2F
        case .slash: return 0x2C
        case .space: return 0x31
        case .sectionKey: return 0x0A
        }
    }
}

enum TriggerModifier: String, CaseIterable, Codable, Hashable, Identifiable {
    case command
    case control
    case option
    case shift

    var id: String { rawValue }

    var title: String {
        switch self {
        case .command: return "\u{2318}"
        case .control: return "\u{2303}"
        case .option:  return "\u{2325}"
        case .shift:   return "\u{21E7}"
        }
    }

    var eventFlag: CGEventFlags {
        switch self {
        case .command: return .maskCommand
        case .control: return .maskControl
        case .option:  return .maskAlternate
        case .shift:   return .maskShift
        }
    }
}

extension Set where Element == TriggerModifier {
    var eventFlags: CGEventFlags {
        reduce(CGEventFlags()) { $0.union($1.eventFlag) }
    }
}

enum NavigationTargetKey: String, CaseIterable, Codable, Hashable, Identifiable {
    case leftArrow
    case downArrow
    case upArrow
    case rightArrow

    var id: String { rawValue }

    var title: String {
        switch self {
        case .leftArrow:
            return "Left Arrow"
        case .downArrow:
            return "Down Arrow"
        case .upArrow:
            return "Up Arrow"
        case .rightArrow:
            return "Right Arrow"
        }
    }

    var keyCode: KeyCode {
        switch self {
        case .leftArrow: return 0x7B
        case .downArrow: return 0x7D
        case .upArrow: return 0x7E
        case .rightArrow: return 0x7C
        }
    }
}

enum NumpadTargetKey: String, CaseIterable, Codable, Hashable, Identifiable {
    case keypad0
    case keypad1
    case keypad2
    case keypad3
    case keypad4
    case keypad5
    case keypad6
    case keypad7
    case keypad8
    case keypad9
    case keypadDecimal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .keypad0: return "0"
        case .keypad1: return "1"
        case .keypad2: return "2"
        case .keypad3: return "3"
        case .keypad4: return "4"
        case .keypad5: return "5"
        case .keypad6: return "6"
        case .keypad7: return "7"
        case .keypad8: return "8"
        case .keypad9: return "9"
        case .keypadDecimal: return "."
        }
    }

    var keyCode: KeyCode {
        switch self {
        case .keypad0: return 0x52
        case .keypad1: return 0x53
        case .keypad2: return 0x54
        case .keypad3: return 0x55
        case .keypad4: return 0x56
        case .keypad5: return 0x57
        case .keypad6: return 0x58
        case .keypad7: return 0x59
        case .keypad8: return 0x5B
        case .keypad9: return 0x5C
        case .keypadDecimal: return 0x41
        }
    }

    var requiresNumericPadFlag: Bool {
        true
    }
}

enum LayerMode: String, Codable, CaseIterable {
    case off
    case nav
    case numpad

    var title: String {
        switch self {
        case .off:
            return "Off"
        case .nav:
            return "Navigation"
        case .numpad:
            return "Numpad"
        }
    }

}

struct NavigationBinding: Identifiable, Codable, Hashable {
    var id: UUID
    var source: InputKey
    var target: NavigationTargetKey

    init(id: UUID = UUID(), source: InputKey, target: NavigationTargetKey) {
        self.id = id
        self.source = source
        self.target = target
    }
}

struct NumpadBinding: Identifiable, Codable, Hashable {
    var id: UUID
    var source: InputKey
    var target: NumpadTargetKey

    init(id: UUID = UUID(), source: InputKey, target: NumpadTargetKey) {
        self.id = id
        self.source = source
        self.target = target
    }
}

struct TriggerProfile: Codable, Hashable {
    var layerKey: InputKey
    var layerModifiers: Set<TriggerModifier>
    var numpadSubTrigger: InputKey
    var tapToEscapeEnabled: Bool

    static let `default` = TriggerProfile(
        layerKey: .space,
        layerModifiers: [.control],
        numpadSubTrigger: .a,
        tapToEscapeEnabled: true
    )

    var chordSummary: String {
        let modifiers = TriggerModifier.allCases
            .filter { layerModifiers.contains($0) }
            .map(\.title)
            .joined()
        return modifiers + layerKey.title
    }
}

enum TriggerValidationIssue: Hashable {
    case triggerNeedsModifiers(InputKey)
    case subTriggerEqualsLayerKey
    case subTriggerConflictsWithNavSource(InputKey)

    var message: String {
        switch self {
        case let .triggerNeedsModifiers(key):
            return "Pressing \(key.title) alone will enter the layer and block normal typing. Add a modifier (\u{2318} \u{2325} \u{2303} \u{21E7}) or choose a different key."
        case .subTriggerEqualsLayerKey:
            return "The numpad sub-trigger is the same as the layer trigger key. Pick a different key so the numpad can activate."
        case let .subTriggerConflictsWithNavSource(key):
            return "\(key.title) is also a Navigation layer source. Pressing it during nav will switch into numpad instead of emitting the nav binding."
        }
    }
}

struct MappingProfile: Codable, Hashable {
    var navigation: [NavigationBinding]
    var numpad: [NumpadBinding]
    var triggers: TriggerProfile

    init(
        navigation: [NavigationBinding],
        numpad: [NumpadBinding],
        triggers: TriggerProfile = .default
    ) {
        self.navigation = navigation
        self.numpad = numpad
        self.triggers = triggers
    }

    private enum CodingKeys: String, CodingKey {
        case navigation
        case numpad
        case triggers
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.navigation = try container.decode([NavigationBinding].self, forKey: .navigation)
        self.numpad = try container.decode([NumpadBinding].self, forKey: .numpad)
        self.triggers = try container.decodeIfPresent(TriggerProfile.self, forKey: .triggers) ?? .default
    }

    static let legacyDefault = MappingProfile(
        navigation: [
            NavigationBinding(source: .h, target: .leftArrow),
            NavigationBinding(source: .j, target: .downArrow),
            NavigationBinding(source: .k, target: .upArrow),
            NavigationBinding(source: .l, target: .rightArrow),
        ],
        numpad: [
            NumpadBinding(source: .u, target: .keypad7),
            NumpadBinding(source: .i, target: .keypad8),
            NumpadBinding(source: .o, target: .keypad9),
            NumpadBinding(source: .j, target: .keypad4),
            NumpadBinding(source: .k, target: .keypad5),
            NumpadBinding(source: .l, target: .keypad6),
            NumpadBinding(source: .m, target: .keypad1),
            NumpadBinding(source: .comma, target: .keypad2),
            NumpadBinding(source: .period, target: .keypad3),
            NumpadBinding(source: .space, target: .keypad0),
            NumpadBinding(source: .semicolon, target: .keypadDecimal),
        ]
    )

    static let `default` = MappingProfile(
        navigation: [
            NavigationBinding(source: .h, target: .leftArrow),
            NavigationBinding(source: .j, target: .downArrow),
            NavigationBinding(source: .k, target: .upArrow),
            NavigationBinding(source: .l, target: .rightArrow),
        ],
        numpad: [
            NumpadBinding(source: .u, target: .keypad7),
            NumpadBinding(source: .i, target: .keypad8),
            NumpadBinding(source: .o, target: .keypad9),
            NumpadBinding(source: .j, target: .keypad4),
            NumpadBinding(source: .k, target: .keypad5),
            NumpadBinding(source: .l, target: .keypad6),
            NumpadBinding(source: .m, target: .keypad1),
            NumpadBinding(source: .comma, target: .keypad2),
            NumpadBinding(source: .period, target: .keypad3),
        ]
    )

    var resolvedMappings: ResolvedMappings {
        var navMap: [KeyCode: KeyCode] = [:]
        for binding in navigation {
            navMap[binding.source.keyCode] = binding.target.keyCode
        }

        var numpadMap: [KeyCode: KeyCode] = [:]
        var numericPadTargets = Set<KeyCode>()
        for binding in numpad {
            numpadMap[binding.source.keyCode] = binding.target.keyCode
            if binding.target.requiresNumericPadFlag {
                numericPadTargets.insert(binding.target.keyCode)
            }
        }

        return ResolvedMappings(
            navigation: navMap,
            numpad: numpadMap,
            numericPadTargets: numericPadTargets
        )
    }

    func validateTriggers() -> [TriggerValidationIssue] {
        var issues: [TriggerValidationIssue] = []

        if triggers.layerModifiers.isEmpty {
            switch triggers.layerKey.category {
            case .letters, .digits, .punctuation, .iso:
                issues.append(.triggerNeedsModifiers(triggers.layerKey))
            }
        }

        if triggers.numpadSubTrigger == triggers.layerKey {
            issues.append(.subTriggerEqualsLayerKey)
        }

        if navigation.contains(where: { $0.source == triggers.numpadSubTrigger }) {
            issues.append(.subTriggerConflictsWithNavSource(triggers.numpadSubTrigger))
        }

        return issues
    }
}

struct ResolvedMappings: Hashable {
    var navigation: [KeyCode: KeyCode]
    var numpad: [KeyCode: KeyCode]
    var numericPadTargets: Set<KeyCode>

    func remappedKeyCode(for source: KeyCode, mode: LayerMode) -> KeyCode? {
        switch mode {
        case .off:
            return nil
        case .nav:
            return navigation[source]
        case .numpad:
            return numpad[source] ?? navigation[source]
        }
    }

    func targetRequiresNumericPadFlag(_ keyCode: KeyCode) -> Bool {
        numericPadTargets.contains(keyCode)
    }
}
