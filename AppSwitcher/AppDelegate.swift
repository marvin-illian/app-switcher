import AppKit
import ApplicationServices

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let preferences = AppPreferences()
    private let permissionController = PermissionController()
    private let loginItemController = LoginItemController()

    private var keyboardMonitor: KeyboardMonitor?
    private var menuBarController: MenuBarController?
    private var overlayWindowController: OverlayWindowController?
    private var settingsWindowController: SettingsWindowController?
    private var switchSessionState: SwitchSessionState?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.applicationIconImage = AppIconFactory.appIcon()
        installMainMenu()

        let overlayWindowController = OverlayWindowController()
        let switchSessionState = SwitchSessionState(
            appProvider: RunningAppProvider(),
            matcher: FuzzyMatcher(),
            overlay: overlayWindowController
        )
        let keyboardMonitor = KeyboardMonitor(
            session: switchSessionState,
            preferences: preferences,
            windowCycler: WindowCycler(),
            onWindowCycle: { [weak overlayWindowController] result in
                overlayWindowController?.showWindowCycle(result)
            },
            onWindowCycleEnd: { [weak overlayWindowController] in
                overlayWindowController?.hide()
            },
            onEventTapFailure: { [weak self] in
                self?.showPermissionsExplanation()
            }
        )
        let menuBarController = MenuBarController(
            openSettings: { [weak self] in self?.showSettings() },
            quit: { NSApp.terminate(nil) }
        )

        self.overlayWindowController = overlayWindowController
        self.switchSessionState = switchSessionState
        self.keyboardMonitor = keyboardMonitor
        self.menuBarController = menuBarController

        preferences.onChange = { [weak self] in
            self?.applyPreferences()
        }

        applyPreferences()
        keyboardMonitor.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        keyboardMonitor?.stop()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        permissionController.refresh()
        loginItemController.refresh()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return true
    }

    private func applyPreferences() {
        let policy: NSApplication.ActivationPolicy = preferences.showDockIcon ? .regular : .accessory
        NSApp.setActivationPolicy(policy)
        menuBarController?.setVisible(preferences.showMenuBarIcon)
        overlayWindowController?.setLiquidGlassEnabled(preferences.enableLiquidGlass)
    }

    @objc private func showSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(
                preferences: preferences,
                permissionController: permissionController,
                loginItemController: loginItemController,
                quit: { NSApp.terminate(nil) }
            )
        }

        settingsWindowController?.show()
    }

    private func showPermissionsExplanation() {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)

        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "AppSwitcher needs keyboard permissions"
        alert.informativeText = "The Escape-hold shortcut uses a macOS event tap. Grant AppSwitcher Accessibility and Input Monitoring permissions in System Settings, then relaunch the app."
        alert.addButton(withTitle: "Open Accessibility")
        alert.addButton(withTitle: "Open Input Monitoring")
        alert.addButton(withTitle: "Quit")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            openPrivacyPane(anchor: "Privacy_Accessibility")
        case .alertSecondButtonReturn:
            openPrivacyPane(anchor: "Privacy_ListenEvent")
        default:
            NSApp.terminate(nil)
        }
    }

    private func openPrivacyPane(anchor: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    private func installMainMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()

        appMenu.addItem(NSMenuItem(
            title: "Settings...",
            action: #selector(showSettings),
            keyEquivalent: ","
        ))
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(
            title: "Quit AppSwitcher",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))

        for item in appMenu.items {
            item.target = item.action == #selector(showSettings) ? self : NSApp
        }

        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)
        NSApp.mainMenu = mainMenu
    }
}
