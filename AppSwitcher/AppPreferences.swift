import Combine
import Foundation

final class AppPreferences: ObservableObject {
    private enum Key {
        static let activationKeyCode = "activationKeyCode"
        static let showMenuBarIcon = "showMenuBarIcon"
        static let showDockIcon = "showDockIcon"
        static let enableWindowCycling = "enableWindowCycling"
        static let enableLiquidGlass = "enableLiquidGlass"
        static let showOverlayIcons = "showOverlayIcons"
        static let maxListEntries = "maxListEntries"
    }

    static let defaultMaxListEntries = 5
    static let maxListEntriesRange = 1...12

    private let defaults: UserDefaults

    var onChange: (() -> Void)?

    @Published var activationKey: ActivationKey {
        didSet {
            defaults.set(Int(activationKey.keyCode), forKey: Key.activationKeyCode)
            onChange?()
        }
    }

    @Published var showMenuBarIcon: Bool {
        didSet {
            defaults.set(showMenuBarIcon, forKey: Key.showMenuBarIcon)
            onChange?()
        }
    }

    @Published var showDockIcon: Bool {
        didSet {
            defaults.set(showDockIcon, forKey: Key.showDockIcon)
            onChange?()
        }
    }

    @Published var enableWindowCycling: Bool {
        didSet {
            defaults.set(enableWindowCycling, forKey: Key.enableWindowCycling)
            onChange?()
        }
    }

    @Published var enableLiquidGlass: Bool {
        didSet {
            defaults.set(enableLiquidGlass, forKey: Key.enableLiquidGlass)
            onChange?()
        }
    }

    @Published var showOverlayIcons: Bool {
        didSet {
            defaults.set(showOverlayIcons, forKey: Key.showOverlayIcons)
            onChange?()
        }
    }

    @Published var maxListEntries: Int {
        didSet {
            let clampedValue = Self.clampListEntries(maxListEntries)
            if maxListEntries != clampedValue {
                maxListEntries = clampedValue
            }

            defaults.set(clampedValue, forKey: Key.maxListEntries)
            onChange?()
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let activationKeyCode = defaults.object(forKey: Key.activationKeyCode) as? Int
            ?? Int(ActivationKey.escape.keyCode)
        activationKey = ActivationKey.fromStoredKeyCode(activationKeyCode)

        showMenuBarIcon = defaults.object(forKey: Key.showMenuBarIcon) as? Bool ?? true
        showDockIcon = defaults.object(forKey: Key.showDockIcon) as? Bool ?? false
        enableWindowCycling = defaults.object(forKey: Key.enableWindowCycling) as? Bool ?? true
        enableLiquidGlass = defaults.object(forKey: Key.enableLiquidGlass) as? Bool ?? false
        showOverlayIcons = defaults.object(forKey: Key.showOverlayIcons) as? Bool ?? false

        let storedMaxListEntries = defaults.object(forKey: Key.maxListEntries) as? Int
            ?? Self.defaultMaxListEntries
        maxListEntries = Self.clampListEntries(storedMaxListEntries)
    }

    private static func clampListEntries(_ value: Int) -> Int {
        min(max(value, maxListEntriesRange.lowerBound), maxListEntriesRange.upperBound)
    }
}
