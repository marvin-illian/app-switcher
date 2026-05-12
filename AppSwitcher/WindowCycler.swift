import AppKit
import ApplicationServices

struct WindowCycleItem: Identifiable {
    let id: String
    let title: String
}

struct WindowCycleResult {
    let appName: String
    let query: String
    let windows: [WindowCycleItem]
    let selectedIndex: Int
}

enum WindowCycleDirection {
    case forward
    case backward

    var offset: Int {
        switch self {
        case .forward:
            return 1
        case .backward:
            return -1
        }
    }
}

final class WindowCycler {
    private let matcher = FuzzyMatcher()

    private var cycleProcessIdentifier: pid_t?
    private var cycleApplicationName = "Windows"
    private var cycleQuery = ""
    private var cycleWindows: [AXUIElement] = []
    private var visibleWindowIndices: [Int] = []
    private var selectedVisibleIndex = 0
    private var lastCycleDate = Date.distantPast

    func cycleCurrentApplicationWindow(direction: WindowCycleDirection) -> WindowCycleResult? {
        guard let frontmostApplication = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        let processIdentifier = frontmostApplication.processIdentifier
        let appElement = AXUIElementCreateApplication(processIdentifier)
        let latestWindows = windowElements(for: appElement).filter(isCycleableWindow)

        guard !latestWindows.isEmpty else {
            resetCycle()
            return nil
        }

        if latestWindows.count == 1, isMinimized(latestWindows[0]) != true {
            resetCycle()
            return nil
        }

        let shouldContinueCycle = cycleProcessIdentifier == processIdentifier
            && cycleWindows.count == latestWindows.count
            && Date().timeIntervalSince(lastCycleDate) < 2.5

        if !shouldContinueCycle {
            cycleProcessIdentifier = processIdentifier
            cycleApplicationName = frontmostApplication.localizedName ?? "Windows"
            cycleQuery = ""
            cycleWindows = latestWindows
            visibleWindowIndices = Array(cycleWindows.indices)
            let focusedWindow = focusedWindow(for: appElement)
            let currentIndex = focusedWindow.flatMap { focused in
                latestWindows.firstIndex { candidate in
                    CFEqual(candidate, focused)
                }
            } ?? 0
            selectedVisibleIndex = visibleWindowIndices.firstIndex(of: currentIndex) ?? 0
        }

        return moveSelection(direction: direction)
    }

    func moveSelection(direction: WindowCycleDirection) -> WindowCycleResult? {
        if !visibleWindowIndices.isEmpty {
            selectedVisibleIndex = (selectedVisibleIndex + direction.offset + visibleWindowIndices.count) % visibleWindowIndices.count
        }

        lastCycleDate = Date()

        return currentResult()
    }

    func appendQuery(_ character: Character) -> WindowCycleResult? {
        guard !cycleWindows.isEmpty else {
            return nil
        }

        cycleQuery.append(character)
        refreshVisibleWindows()
        return currentResult()
    }

    func backspaceQuery() -> WindowCycleResult? {
        guard !cycleWindows.isEmpty, !cycleQuery.isEmpty else {
            return currentResult()
        }

        cycleQuery.removeLast()
        refreshVisibleWindows()
        return currentResult()
    }

    @discardableResult
    func commitSelection() -> Bool {
        guard !cycleWindows.isEmpty,
              !visibleWindowIndices.isEmpty else {
            resetCycle()
            return false
        }

        let selectedWindow = cycleWindows[visibleWindowIndices[selectedVisibleIndex]]
        let didFocus = focus(selectedWindow)
        resetCycle()
        return didFocus
    }

    func cancelSelection() {
        resetCycle()
    }

    private func windowElements(for appElement: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            appElement,
            kAXWindowsAttribute as CFString,
            &value
        ) == .success else {
            return []
        }

        return value as? [AXUIElement] ?? []
    }

    private func focusedWindow(for appElement: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedWindowAttribute as CFString,
            &value
        ) == .success else {
            return nil
        }

        return value as! AXUIElement?
    }

    private func isCycleableWindow(_ window: AXUIElement) -> Bool {
        if let role = stringAttribute(kAXRoleAttribute as CFString, for: window),
           role != kAXWindowRole {
            return false
        }

        return true
    }

    private func focus(_ window: AXUIElement) -> Bool {
        let unminimized = AXUIElementSetAttributeValue(
            window,
            kAXMinimizedAttribute as CFString,
            kCFBooleanFalse
        ) == .success
        let raised = AXUIElementPerformAction(window, kAXRaiseAction as CFString) == .success
        let madeMain = AXUIElementSetAttributeValue(
            window,
            kAXMainAttribute as CFString,
            kCFBooleanTrue
        ) == .success
        let focused = AXUIElementSetAttributeValue(
            window,
            kAXFocusedAttribute as CFString,
            kCFBooleanTrue
        ) == .success

        return unminimized || raised || madeMain || focused
    }

    private func resetCycle() {
        cycleProcessIdentifier = nil
        cycleApplicationName = "Windows"
        cycleQuery = ""
        cycleWindows = []
        visibleWindowIndices = []
        selectedVisibleIndex = 0
        lastCycleDate = .distantPast
    }

    private func currentResult() -> WindowCycleResult? {
        guard let cycleProcessIdentifier,
              !cycleWindows.isEmpty else {
            return nil
        }

        return WindowCycleResult(
            appName: cycleApplicationName,
            query: cycleQuery,
            windows: visibleWindowIndices.enumerated().map { visibleIndex, windowIndex in
                WindowCycleItem(
                    id: "\(cycleProcessIdentifier)-\(windowIndex)-\(title(for: cycleWindows[windowIndex]))",
                    title: title(for: cycleWindows[windowIndex])
                )
            },
            selectedIndex: visibleWindowIndices.isEmpty ? 0 : min(selectedVisibleIndex, visibleWindowIndices.count - 1)
        )
    }

    private func refreshVisibleWindows() {
        if cycleQuery.isEmpty {
            visibleWindowIndices = Array(cycleWindows.indices)
        } else {
            visibleWindowIndices = matcher.rankedMatches(
                query: cycleQuery,
                candidates: Array(cycleWindows.indices),
                name: { [weak self] index in
                    guard let self else {
                        return ""
                    }

                    return self.title(for: self.cycleWindows[index])
                }
            )
            .map(\.item)
        }

        selectedVisibleIndex = 0
    }

    private func title(for window: AXUIElement) -> String {
        let title = stringAttribute(kAXTitleAttribute as CFString, for: window) ?? ""
        return title.isEmpty ? "Untitled Window" : title
    }

    private func isMinimized(_ window: AXUIElement) -> Bool? {
        boolAttribute(kAXMinimizedAttribute as CFString, for: window)
    }

    private func boolAttribute(_ attribute: CFString, for element: AXUIElement) -> Bool? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else {
            return nil
        }

        return value as? Bool
    }

    private func stringAttribute(_ attribute: CFString, for element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else {
            return nil
        }

        return value as? String
    }
}
