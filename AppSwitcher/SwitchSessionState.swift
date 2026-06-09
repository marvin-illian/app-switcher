import AppKit
import ApplicationServices

final class SwitchSessionState {
    private static let nKeyCode: CGKeyCode = 45

    private let appProvider: RunningAppProvider
    private let matcher: FuzzyMatcher
    private let overlay: OverlayWindowController
    private let preferences: AppPreferences

    private var appSnapshot: [RunningAppInfo] = []
    private var rankedMatches: [FuzzyMatch<RunningAppInfo>] = []
    private var selectedIndex = 0
    private var hasTypedQuery = false
    private var hasExplicitEmptySelection = false

    private(set) var isActive = false
    private(set) var query = ""

    var shouldForwardActivationKeyOnFinish: Bool {
        query.isEmpty && !hasTypedQuery
    }

    init(
        appProvider: RunningAppProvider,
        matcher: FuzzyMatcher,
        overlay: OverlayWindowController,
        preferences: AppPreferences
    ) {
        self.appProvider = appProvider
        self.matcher = matcher
        self.overlay = overlay
        self.preferences = preferences
    }

    func begin() {
        guard !isActive else {
            return
        }

        isActive = true
        query = ""
        selectedIndex = 0
        hasTypedQuery = false
        hasExplicitEmptySelection = false
        appSnapshot = appProvider.runningApps()
        refreshMatches()
    }

    func append(_ character: Character) {
        guard isActive else {
            return
        }

        query.append(character)
        selectedIndex = 0
        hasTypedQuery = true
        hasExplicitEmptySelection = false
        refreshMatches()
        showOverlayIfNeeded()
    }

    func backspace() {
        guard isActive, !query.isEmpty else {
            return
        }

        query.removeLast()
        selectedIndex = 0
        hasExplicitEmptySelection = false
        refreshMatches()
        showOverlayIfNeeded()
    }

    func selectNext() {
        moveSelection(by: 1)
    }

    func selectPrevious() {
        moveSelection(by: -1)
    }

    @discardableResult
    func finish() -> Bool {
        guard isActive else {
            return false
        }

        let selectedApplication: NSRunningApplication?
        if !hasTypedQuery {
            selectedApplication = nil
        } else if query.isEmpty {
            selectedApplication = hasExplicitEmptySelection ? selectedVisibleApplication?.application : nil
        } else if rankedMatches.isEmpty {
            selectedApplication = nil
        } else {
            selectedApplication = rankedMatches[visibleSelectedIndex].item.application
        }
        reset()

        guard let selectedApplication else {
            return false
        }

        activate(selectedApplication)
        return true
    }

    private func reset() {
        isActive = false
        query = ""
        selectedIndex = 0
        hasTypedQuery = false
        hasExplicitEmptySelection = false
        appSnapshot = []
        rankedMatches = []
        overlay.hide()
    }

    private func refreshMatches() {
        rankedMatches = matcher.rankedMatches(
            query: query,
            candidates: appSnapshot,
            name: \.name
        )
        clampSelectedIndex()

        let displayMatches: [OverlayMatch]
        if query.isEmpty {
            let range = visibleSelectionRange
            let visibleApps = appSnapshot[range]
            displayMatches = hasTypedQuery ? visibleApps.enumerated().map { offset, app in
                OverlayMatch(
                    id: app.id,
                    name: app.name,
                    subtitle: app.bundleIdentifier,
                    score: nil,
                    isHighlighted: hasExplicitEmptySelection && range.lowerBound + offset == selectedIndex,
                    icon: app.icon
                )
            } : []
        } else {
            let range = visibleSelectionRange
            let visibleMatches = rankedMatches[range]
            displayMatches = visibleMatches.enumerated().map { offset, match in
                OverlayMatch(
                    id: match.item.id,
                    name: match.item.name,
                    subtitle: match.item.bundleIdentifier,
                    score: match.score,
                    isHighlighted: range.lowerBound + offset == selectedIndex,
                    icon: match.item.icon
                )
            }
        }

        overlay.update(title: "Apps", query: query, matches: displayMatches)
    }

    private func showOverlayIfNeeded() {
        if hasTypedQuery {
            overlay.show()
        } else {
            overlay.hide()
        }
    }

    private func moveSelection(by offset: Int) {
        guard isActive, hasTypedQuery else {
            return
        }

        let count = selectionCount
        guard count > 0 else {
            return
        }

        if query.isEmpty, !hasExplicitEmptySelection {
            hasExplicitEmptySelection = true
            selectedIndex = offset > 0 ? 0 : count - 1
        } else {
            selectedIndex = (selectedIndex + offset + count) % count
        }
        refreshMatches()
        overlay.show()
    }

    private var visibleSelectedIndex: Int {
        min(selectedIndex, max(selectionCount - 1, 0))
    }

    private var selectionCount: Int {
        if query.isEmpty {
            return appSnapshot.count
        }

        return rankedMatches.count
    }

    private var visibleSelectionRange: Range<Int> {
        let count = selectionCount
        guard count > 0 else {
            return 0..<0
        }

        let visibleLimit = min(preferences.maxListEntries, count)
        let centeredStart = selectedIndex - visibleLimit / 2
        let maxStart = count - visibleLimit
        let start = min(max(centeredStart, 0), maxStart)
        return start..<(start + visibleLimit)
    }

    private func clampSelectedIndex() {
        guard selectionCount > 0 else {
            selectedIndex = 0
            return
        }

        selectedIndex = min(max(selectedIndex, 0), selectionCount - 1)
    }

    private var selectedVisibleApplication: RunningAppInfo? {
        guard !appSnapshot.isEmpty else {
            return nil
        }

        return appSnapshot[visibleSelectedIndex]
    }

    private func activate(_ application: NSRunningApplication) {
        let hadVisibleWindowsBeforeActivation = hasVisibleApplicationWindows(application)

        if hadVisibleWindowsBeforeActivation == false, reopenApplicationLikeDockClick(application) {
            openNewWindowWhenActive(application)
            return
        }

        activateApplication(application)

        if hadVisibleWindowsBeforeActivation == false {
            openNewWindowWhenActive(application)
        }
    }

    private func activateApplication(_ application: NSRunningApplication) {
        if #available(macOS 14.0, *) {
            application.activate(from: NSRunningApplication.current, options: [])
        } else {
            application.activate(options: [.activateIgnoringOtherApps])
        }
    }

    private func reopenApplicationLikeDockClick(_ application: NSRunningApplication) -> Bool {
        guard let bundleURL = application.bundleURL else {
            return false
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        NSWorkspace.shared.openApplication(at: bundleURL, configuration: configuration) { [weak self, weak application] _, error in
            guard let self,
                  let application,
                  error != nil else {
                return
            }

            DispatchQueue.main.async {
                self.activateApplication(application)
                self.openNewWindowWhenActive(application)
            }
        }

        return true
    }

    private func openNewWindowWhenActive(_ application: NSRunningApplication) {
        scheduleNewWindowFallback(for: application, remainingAttempts: 6, delay: 0.7)
    }

    private func scheduleNewWindowFallback(
        for application: NSRunningApplication,
        remainingAttempts: Int,
        delay: TimeInterval
    ) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self, weak application] in
            guard let self,
                  let application else {
                return
            }

            guard self.hasVisibleApplicationWindows(application) == false else {
                return
            }

            guard application.isActive || NSWorkspace.shared.frontmostApplication?.processIdentifier == application.processIdentifier else {
                if remainingAttempts > 0 {
                    self.scheduleNewWindowFallback(
                        for: application,
                        remainingAttempts: remainingAttempts - 1,
                        delay: 0.25
                    )
                }
                return
            }

            Self.synthesizeCommandN()
        }
    }

    private func hasVisibleApplicationWindows(_ application: NSRunningApplication) -> Bool? {
        guard let windowInfoList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return nil
        }

        return windowInfoList.contains { windowInfo in
            guard let ownerPID = windowInfo[kCGWindowOwnerPID as String] as? NSNumber,
                  ownerPID.int32Value == application.processIdentifier,
                  let layer = windowInfo[kCGWindowLayer as String] as? NSNumber,
                  layer.intValue == 0 else {
                return false
            }

            if let alpha = windowInfo[kCGWindowAlpha as String] as? NSNumber,
               alpha.doubleValue <= 0 {
                return false
            }

            if let boundsDictionary = windowInfo[kCGWindowBounds as String] as? NSDictionary,
               let bounds = CGRect(dictionaryRepresentation: boundsDictionary as CFDictionary),
               bounds.width <= 1 || bounds.height <= 1 {
                return false
            }

            return true
        }
    }

    private static func synthesizeCommandN() {
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            return
        }

        for isKeyDown in [true, false] {
            guard let event = CGEvent(
                keyboardEventSource: source,
                virtualKey: Self.nKeyCode,
                keyDown: isKeyDown
            ) else {
                continue
            }

            event.flags = .maskCommand
            event.post(tap: .cghidEventTap)
        }
    }

}
