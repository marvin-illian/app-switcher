import CoreGraphics

struct ActivationKey: Hashable, Identifiable {
    let name: String
    let keyCode: CGKeyCode

    var id: UInt16 {
        keyCode
    }

    static let escape = ActivationKey(name: "Escape", keyCode: 53)

    static let knownKeys: [ActivationKey] = [
        .escape,
        ActivationKey(name: "Tab", keyCode: 48),
        ActivationKey(name: "Space", keyCode: 49),
        ActivationKey(name: "F13", keyCode: 105),
        ActivationKey(name: "F14", keyCode: 107),
        ActivationKey(name: "F15", keyCode: 113),
        ActivationKey(name: "F16", keyCode: 106),
        ActivationKey(name: "F17", keyCode: 64),
        ActivationKey(name: "F18", keyCode: 79),
        ActivationKey(name: "F19", keyCode: 80),
        ActivationKey(name: "F20", keyCode: 90)
    ]

    static func fromStoredKeyCode(_ keyCode: Int) -> ActivationKey {
        knownKeys.first { Int($0.keyCode) == keyCode } ?? ActivationKey(
            name: "Key Code \(keyCode)",
            keyCode: CGKeyCode(keyCode)
        )
    }
}
