import Combine
import Foundation

final class AppPreferences: ObservableObject {
    private enum Key {
        static let activationKeyCode = "activationKeyCode"
        static let showMenuBarIcon = "showMenuBarIcon"
        static let showDockIcon = "showDockIcon"
        static let enableWindowCycling = "enableWindowCycling"
        static let enableLiquidGlass = "enableLiquidGlass"
    }

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

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let activationKeyCode = defaults.object(forKey: Key.activationKeyCode) as? Int
            ?? Int(ActivationKey.escape.keyCode)
        activationKey = ActivationKey.fromStoredKeyCode(activationKeyCode)

        showMenuBarIcon = defaults.object(forKey: Key.showMenuBarIcon) as? Bool ?? true
        showDockIcon = defaults.object(forKey: Key.showDockIcon) as? Bool ?? false
        enableWindowCycling = defaults.object(forKey: Key.enableWindowCycling) as? Bool ?? true
        enableLiquidGlass = defaults.object(forKey: Key.enableLiquidGlass) as? Bool ?? false
    }
}
