import AppKit
import SwiftUI

final class OverlayWindowController {
    private let viewModel = OverlayViewModel()
    private lazy var panel: NSPanel = makePanel()
    private var transientHideWorkItem: DispatchWorkItem?
    private var liquidGlassEnabled = false
    private var currentSize = NSSize(
        width: OverlayLayout.width,
        height: OverlayLayout.height(rowCount: AppPreferences.defaultMaxListEntries, showsIcons: false)
    )

    func show() {
        transientHideWorkItem?.cancel()
        transientHideWorkItem = nil
        centerPanel()
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }

    func update(title: String = "Apps", query: String, matches: [OverlayMatch]) {
        viewModel.title = title
        viewModel.query = query
        viewModel.matches = matches
        resizePanel(rowCount: matches.count)
    }

    func setLiquidGlassEnabled(_ isEnabled: Bool) {
        guard liquidGlassEnabled != isEnabled else {
            return
        }

        liquidGlassEnabled = isEnabled
        installContentView()
    }

    func setShowsIcons(_ showsIcons: Bool) {
        guard viewModel.showsIcons != showsIcons else {
            return
        }

        viewModel.showsIcons = showsIcons
        resizePanel(rowCount: viewModel.matches.count)
    }

    func showWindowCycle(_ result: WindowCycleResult) {
        let matches = result.windows.enumerated().map { index, window in
            OverlayMatch(
                id: window.id,
                name: window.title,
                subtitle: result.appName,
                score: nil,
                isHighlighted: index == result.selectedIndex,
                icon: result.appIcon
            )
        }

        update(title: "Windows", query: result.query.isEmpty ? result.appName : result.query, matches: matches)
        show()
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: currentSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.backgroundColor = .clear
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.isFloatingPanel = true
        panel.isOpaque = false
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        installContentView(on: panel)

        return panel
    }

    private func installContentView(on targetPanel: NSPanel? = nil) {
        let targetPanel = targetPanel ?? panel
        let hostingView = NSHostingView(rootView: OverlayView(viewModel: viewModel))
        hostingView.frame = NSRect(origin: .zero, size: currentSize)
        viewModel.usesNativeGlassEffect = false

        if liquidGlassEnabled {
            if #available(macOS 26.0, *) {
                let glassView = NSGlassEffectView(frame: hostingView.frame)
                glassView.autoresizingMask = [.width, .height]
                glassView.cornerRadius = OverlayLayout.cornerRadius
                glassView.style = .regular
                glassView.contentView = hostingView
                viewModel.usesNativeGlassEffect = true
                targetPanel.contentView = glassView
                return
            }
        }

        targetPanel.contentView = hostingView
    }

    private func resizePanel(rowCount: Int) {
        let newSize = NSSize(
            width: OverlayLayout.width,
            height: OverlayLayout.height(rowCount: rowCount, showsIcons: viewModel.showsIcons)
        )
        guard newSize != currentSize else {
            return
        }

        currentSize = newSize
        viewModel.windowHeight = newSize.height

        let oldFrame = panel.frame
        let newOrigin = NSPoint(
            x: oldFrame.midX - newSize.width / 2,
            y: oldFrame.midY - newSize.height / 2
        )
        panel.setFrame(NSRect(origin: newOrigin, size: newSize), display: true)
        panel.contentView?.frame = NSRect(origin: .zero, size: newSize)
    }

    private func centerPanel() {
        let screen = activeScreen()
        let visibleFrame = screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        let panelSize = panel.frame.size
        let origin = NSPoint(
            x: visibleFrame.midX - panelSize.width / 2,
            y: visibleFrame.midY - panelSize.height / 2
        )

        panel.setFrameOrigin(origin)
    }

    private func activeScreen() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { screen in
            NSMouseInRect(mouseLocation, screen.frame, false)
        } ?? NSScreen.main ?? NSScreen.screens.first
    }

    private func hideAfterDelay() {
        let workItem = DispatchWorkItem { [weak self] in
            self?.hide()
        }
        transientHideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9, execute: workItem)
    }
}
