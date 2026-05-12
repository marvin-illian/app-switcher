import AppKit
import SwiftUI

final class SettingsWindowController: NSWindowController {
    init(
        preferences: AppPreferences,
        permissionController: PermissionController,
        loginItemController: LoginItemController,
        quit: @escaping () -> Void
    ) {
        let rootView = SettingsView(
            preferences: preferences,
            permissionController: permissionController,
            loginItemController: loginItemController,
            quit: quit
        )
        let hostingView = NSHostingView(rootView: rootView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 470),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        window.center()
        window.contentView = hostingView
        window.isReleasedWhenClosed = false
        window.title = "AppSwitcher Settings"

        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func show() {
        window?.center()
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
