import AppKit

final class MenuBarController {
    private var statusItem: NSStatusItem?
    private let openSettings: () -> Void
    private let quit: () -> Void

    init(openSettings: @escaping () -> Void, quit: @escaping () -> Void) {
        self.openSettings = openSettings
        self.quit = quit
    }

    func setVisible(_ isVisible: Bool) {
        if isVisible {
            installIfNeeded()
        } else {
            removeIfNeeded()
        }
    }

    private func installIfNeeded() {
        guard statusItem == nil else {
            return
        }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = AppIconFactory.menuBarIcon()
        item.button?.toolTip = "AppSwitcher"

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettingsItem), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit AppSwitcher", action: #selector(quitItem), keyEquivalent: "q"))

        for menuItem in menu.items {
            menuItem.target = self
        }

        item.menu = menu
        statusItem = item
    }

    private func removeIfNeeded() {
        guard let statusItem else {
            return
        }

        NSStatusBar.system.removeStatusItem(statusItem)
        self.statusItem = nil
    }

    @objc private func openSettingsItem() {
        openSettings()
    }

    @objc private func quitItem() {
        quit()
    }
}
