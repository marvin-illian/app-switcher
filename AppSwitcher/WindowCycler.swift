import AppKit
import ApplicationServices

struct WindowCycleItem: Identifiable {
    let id: String
    let title: String
}

struct WindowCycleResult {
    let appName: String
    let appIcon: NSImage?
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
    private let preferences: AppPreferences

    private var cycleProcessIdentifier: pid_t?
    private var cycleApplicationName = "Windows"
    private var cycleApplicationIcon: NSImage?
    private var cycleQuery = ""
    private var cycleWindows: [AXUIElement] = []
    private var matchingWindowIndices: [Int] = []
    private var visibleWindowIndices: [Int] = []
    private var selectedMatchIndex = 0
    private var lastCycleDate = Date.distantPast

    init(preferences: AppPreferences) {
        self.preferences = preferences
    }

    func cycleCurrentApplicationWindow(direction: WindowCycleDirection) -> WindowCycleResult? {
        guard let frontmostApplication = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        let processIdentifier = frontmostApplication.processIdentifier
        let appElement = AXUIElementCreateApplication(processIdentifier)
        let latestWindows = cycleableWindows(for: appElement)

        guard !latestWindows.isEmpty else {
            resetCycle()
            return nil
        }

        let shouldContinueCycle = cycleProcessIdentifier == processIdentifier
            && cycleWindows.count == latestWindows.count
            && Date().timeIntervalSince(lastCycleDate) < 2.5

        if !shouldContinueCycle {
            cycleProcessIdentifier = processIdentifier
            cycleApplicationName = frontmostApplication.localizedName ?? "Windows"
            cycleApplicationIcon = frontmostApplication.icon
            cycleQuery = ""
            cycleWindows = latestWindows
            matchingWindowIndices = Array(cycleWindows.indices)
            let focusedWindow = focusedWindow(for: appElement)
            let currentIndex = focusedWindow.flatMap { focused in
                latestWindows.firstIndex { candidate in
                    CFEqual(candidate, focused)
                }
            } ?? 0
            selectedMatchIndex = matchingWindowIndices.firstIndex(of: currentIndex) ?? 0
            refreshVisibleWindowSlice()
        }

        return moveSelection(direction: direction)
    }

    func moveSelection(direction: WindowCycleDirection) -> WindowCycleResult? {
        if !matchingWindowIndices.isEmpty {
            selectedMatchIndex = (selectedMatchIndex + direction.offset + matchingWindowIndices.count) % matchingWindowIndices.count
            refreshVisibleWindowSlice()
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
              !matchingWindowIndices.isEmpty else {
            resetCycle()
            return false
        }

        let selectedWindow = cycleWindows[matchingWindowIndices[selectedMatchIndex]]
        let didFocus = focus(selectedWindow)
        resetCycle()
        return didFocus
    }

    func cancelSelection() {
        resetCycle()
    }

    private func windowElements(for appElement: AXUIElement) -> [AXUIElement] {
        elementArrayAttribute(kAXWindowsAttribute as CFString, for: appElement)
    }

    private func cycleableWindows(for appElement: AXUIElement) -> [AXUIElement] {
        let candidates = windowElements(for: appElement)
            + childWindowElements(for: appElement)
            + [
            focusedWindow(for: appElement),
            mainWindow(for: appElement)
        ].compactMap { $0 }

        return uniqueWindows(candidates.filter(isCycleableWindow))
    }

    private func childWindowElements(for appElement: AXUIElement) -> [AXUIElement] {
        let children = uniqueWindows(
            elementArrayAttribute(kAXChildrenAttribute as CFString, for: appElement)
                + elementArrayAttribute(kAXVisibleChildrenAttribute as CFString, for: appElement)
        )

        return children.flatMap { windowDescendants(of: $0, remainingDepth: 2) }
    }

    private func windowDescendants(of element: AXUIElement, remainingDepth: Int) -> [AXUIElement] {
        if isCycleableWindow(element) {
            return [element]
        }

        guard remainingDepth > 0 else {
            return []
        }

        let children = uniqueWindows(
            elementArrayAttribute(kAXChildrenAttribute as CFString, for: element)
                + elementArrayAttribute(kAXVisibleChildrenAttribute as CFString, for: element)
        )

        return children.flatMap {
            windowDescendants(of: $0, remainingDepth: remainingDepth - 1)
        }
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

    private func mainWindow(for appElement: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            appElement,
            kAXMainWindowAttribute as CFString,
            &value
        ) == .success else {
            return nil
        }

        return value as! AXUIElement?
    }

    private func uniqueWindows(_ windows: [AXUIElement]) -> [AXUIElement] {
        var uniqueWindows: [AXUIElement] = []

        for window in windows where !uniqueWindows.contains(where: { CFEqual($0, window) }) {
            uniqueWindows.append(window)
        }

        return uniqueWindows
    }

    private func isCycleableWindow(_ window: AXUIElement) -> Bool {
        stringAttribute(kAXRoleAttribute as CFString, for: window) == kAXWindowRole
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
        cycleApplicationIcon = nil
        cycleQuery = ""
        cycleWindows = []
        matchingWindowIndices = []
        visibleWindowIndices = []
        selectedMatchIndex = 0
        lastCycleDate = .distantPast
    }

    private func currentResult() -> WindowCycleResult? {
        guard let cycleProcessIdentifier,
              !cycleWindows.isEmpty else {
            return nil
        }

        let selectedWindowIndex = matchingWindowIndices.isEmpty ? nil : matchingWindowIndices[selectedMatchIndex]
        let visibleSelectedIndex = selectedWindowIndex.flatMap { visibleWindowIndices.firstIndex(of: $0) } ?? 0

        return WindowCycleResult(
            appName: cycleApplicationName,
            appIcon: cycleApplicationIcon,
            query: cycleQuery,
            windows: visibleWindowIndices.map { windowIndex in
                WindowCycleItem(
                    id: "\(cycleProcessIdentifier)-\(windowIndex)-\(title(for: cycleWindows[windowIndex]))",
                    title: title(for: cycleWindows[windowIndex])
                )
            },
            selectedIndex: visibleWindowIndices.isEmpty ? 0 : visibleSelectedIndex
        )
    }

    private func refreshVisibleWindows() {
        if cycleQuery.isEmpty {
            matchingWindowIndices = Array(cycleWindows.indices)
        } else {
            matchingWindowIndices = matcher.rankedMatches(
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

        selectedMatchIndex = 0
        refreshVisibleWindowSlice()
    }

    private func refreshVisibleWindowSlice() {
        guard !matchingWindowIndices.isEmpty else {
            visibleWindowIndices = []
            selectedMatchIndex = 0
            return
        }

        selectedMatchIndex = min(max(selectedMatchIndex, 0), matchingWindowIndices.count - 1)

        let visibleLimit = min(preferences.maxListEntries, matchingWindowIndices.count)
        let centeredStart = selectedMatchIndex - visibleLimit / 2
        let maxStart = matchingWindowIndices.count - visibleLimit
        let start = min(max(centeredStart, 0), maxStart)
        visibleWindowIndices = Array(matchingWindowIndices[start..<(start + visibleLimit)])
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

    private func elementArrayAttribute(_ attribute: CFString, for element: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else {
            return []
        }

        return value as? [AXUIElement] ?? []
    }

    private func stringAttribute(_ attribute: CFString, for element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else {
            return nil
        }

        return value as? String
    }
}
