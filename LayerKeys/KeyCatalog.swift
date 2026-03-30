import CoreGraphics
import Foundation

typealias KeyCode = CGKeyCode

enum InputKey: String, CaseIterable, Codable, Hashable, Identifiable {
    case a, b, c, d, e, f, g, h, i, j, k, l, m
    case n, o, p, q, r, s, t, u, v, w, x, y, z
    case semicolon
    case comma
    case period
    case slash
    case space

    var id: String { rawValue }

    var title: String {
        switch self {
        case .semicolon:
            return ";"
        case .comma:
            return ","
        case .period:
            return "."
        case .slash:
            return "/"
        case .space:
            return "Space"
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
        case .semicolon: return 0x29
        case .comma: return 0x2B
        case .period: return 0x2F
        case .slash: return 0x2C
        case .space: return 0x31
        }
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
        case .keypad0: return "Keypad 0"
        case .keypad1: return "Keypad 1"
        case .keypad2: return "Keypad 2"
        case .keypad3: return "Keypad 3"
        case .keypad4: return "Keypad 4"
        case .keypad5: return "Keypad 5"
        case .keypad6: return "Keypad 6"
        case .keypad7: return "Keypad 7"
        case .keypad8: return "Keypad 8"
        case .keypad9: return "Keypad 9"
        case .keypadDecimal: return "Keypad Decimal"
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

    var menuBarLabel: String {
        switch self {
        case .off:
            return "LK"
        case .nav:
            return "NAV"
        case .numpad:
            return "NUM"
        }
    }

    var symbolName: String {
        switch self {
        case .off:
            return "circle"
        case .nav:
            return "arrow.up.left.and.arrow.down.right"
        case .numpad:
            return "number.square"
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

struct MappingProfile: Codable, Hashable {
    var navigation: [NavigationBinding]
    var numpad: [NumpadBinding]

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
            NumpadBinding(source: .space, target: .keypad0),
            NumpadBinding(source: .semicolon, target: .keypadDecimal),
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
            numericPadTargets.insert(binding.target.keyCode)
        }

        return ResolvedMappings(
            navigation: navMap,
            numpad: numpadMap,
            numericPadTargets: numericPadTargets
        )
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
