import AppKit
import SwiftUI

final class OverlayWindowController {
    private static let size = NSSize(width: 440, height: 258)
    private static let cornerRadius: CGFloat = 18

    private let viewModel = OverlayViewModel()
    private lazy var panel: NSPanel = makePanel()
    private var transientHideWorkItem: DispatchWorkItem?
    private var liquidGlassEnabled = false

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
    }

    func setLiquidGlassEnabled(_ isEnabled: Bool) {
        guard liquidGlassEnabled != isEnabled else {
            return
        }

        liquidGlassEnabled = isEnabled
        installContentView()
    }

    func showWindowCycle(_ result: WindowCycleResult) {
        let matches = result.windows.enumerated().map { index, window in
            OverlayMatch(
                id: window.id,
                name: window.title,
                subtitle: result.appName,
                score: nil,
                isHighlighted: index == result.selectedIndex
            )
        }

        update(title: "Windows", query: result.query.isEmpty ? result.appName : result.query, matches: matches)
        show()
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: Self.size),
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
        hostingView.frame = NSRect(origin: .zero, size: Self.size)
        viewModel.usesNativeGlassEffect = false

        if liquidGlassEnabled {
            if #available(macOS 26.0, *) {
                let glassView = NSGlassEffectView(frame: hostingView.frame)
                glassView.autoresizingMask = [.width, .height]
                glassView.cornerRadius = Self.cornerRadius
                glassView.style = .regular
                glassView.contentView = hostingView
                viewModel.usesNativeGlassEffect = true
                targetPanel.contentView = glassView
                return
            }
        }

        targetPanel.contentView = hostingView
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
