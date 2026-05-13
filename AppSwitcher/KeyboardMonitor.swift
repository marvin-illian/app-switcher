import AppKit
import ApplicationServices

final class KeyboardMonitor {
    private static let deleteKeyCode: CGKeyCode = 51
    private static let backtickKeyCode: CGKeyCode = 50
    private static let downArrowKeyCode: CGKeyCode = 125
    private static let upArrowKeyCode: CGKeyCode = 126
    private static let syntheticEventMarker: Int64 = 0x4150535749544348

    private let session: SwitchSessionState
    private let preferences: AppPreferences
    private let windowCycler: WindowCycler
    private let onWindowCycle: (WindowCycleResult) -> Void
    private let onWindowCycleEnd: () -> Void
    private let onEventTapFailure: () -> Void

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var activeActivationKeyCode: CGKeyCode?
    private var shouldConsumeBacktickKeyUp = false
    private var isWindowCycleOverlayVisible = false

    init(
        session: SwitchSessionState,
        preferences: AppPreferences,
        windowCycler: WindowCycler,
        onWindowCycle: @escaping (WindowCycleResult) -> Void,
        onWindowCycleEnd: @escaping () -> Void,
        onEventTapFailure: @escaping () -> Void
    ) {
        self.session = session
        self.preferences = preferences
        self.windowCycler = windowCycler
        self.onWindowCycle = onWindowCycle
        self.onWindowCycleEnd = onWindowCycleEnd
        self.onEventTapFailure = onEventTapFailure
    }

    @discardableResult
    func start() -> Bool {
        guard eventTap == nil else {
            return true
        }

        let eventMask =
            (CGEventMask(1) << CGEventType.keyDown.rawValue) |
            (CGEventMask(1) << CGEventType.keyUp.rawValue) |
            (CGEventMask(1) << CGEventType.flagsChanged.rawValue)

        // A session event tap can suppress only the events we return nil for.
        // We pass normal keyboard traffic through unless Escape switch mode is active.
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: KeyboardMonitor.eventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            onEventTapFailure()
            return false
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }

        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }

        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }

        runLoopSource = nil
        eventTap = nil
    }

    private static let eventTapCallback: CGEventTapCallBack = { _, type, event, userInfo in
        guard let userInfo else {
            return Unmanaged.passUnretained(event)
        }

        let monitor = Unmanaged<KeyboardMonitor>.fromOpaque(userInfo).takeUnretainedValue()
        return monitor.handle(type: type, event: event)
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return nil
        }

        if type == .flagsChanged {
            return handleFlagsChanged(event: event)
        }

        guard type == .keyDown || type == .keyUp else {
            return pass(event)
        }

        if event.getIntegerValueField(.eventSourceUserData) == Self.syntheticEventMarker {
            return pass(event)
        }

        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))

        switch type {
        case .keyDown:
            return handleKeyDown(event: event, keyCode: keyCode)
        case .keyUp:
            return handleKeyUp(event: event, keyCode: keyCode)
        default:
            return pass(event)
        }
    }

    private func handleKeyDown(event: CGEvent, keyCode: CGKeyCode) -> Unmanaged<CGEvent>? {
        let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
        let activationKeyCode = preferences.activationKey.keyCode

        if handleWindowCycleKeyDown(event: event, keyCode: keyCode) {
            return nil
        }

        if keyCode == activationKeyCode, isPlainActivationKey(event) {
            if isRepeat {
                return session.isActive ? nil : pass(event)
            }

            if !session.isActive {
                activeActivationKeyCode = activationKeyCode
                session.begin()
            }

            return nil
        }

        guard session.isActive else {
            return pass(event)
        }

        if keyCode == Self.deleteKeyCode {
            session.backspace()
            return nil
        }

        if keyCode == Self.downArrowKeyCode {
            session.selectNext()
            return nil
        }

        if keyCode == Self.upArrowKeyCode {
            session.selectPrevious()
            return nil
        }

        if let character = queryCharacter(from: event) {
            session.append(character)
        }

        return nil
    }

    private func handleKeyUp(event: CGEvent, keyCode: CGKeyCode) -> Unmanaged<CGEvent>? {
        guard session.isActive else {
            if keyCode == Self.backtickKeyCode, shouldConsumeBacktickKeyUp {
                shouldConsumeBacktickKeyUp = false
                return nil
            }

            if isWindowCycleOverlayVisible, isWindowCycleNavigationKey(keyCode) {
                return nil
            }

            if isWindowCycleOverlayVisible,
               queryCharacter(from: event, ignoringCommandModifier: true) != nil {
                return nil
            }

            return pass(event)
        }

        if keyCode == activeActivationKeyCode {
            let shouldForwardEscape = session.shouldForwardActivationKeyOnFinish
            let activationKeyCode = activeActivationKeyCode
            let didSwitch = session.finish()
            activeActivationKeyCode = nil

            if shouldForwardEscape && !didSwitch {
                synthesizeKeyPress(keyCode: activationKeyCode ?? preferences.activationKey.keyCode)
            }

            return nil
        }

        return nil
    }

    private func handleWindowCycleKeyDown(event: CGEvent, keyCode: CGKeyCode) -> Bool {
        guard !session.isActive,
              preferences.enableWindowCycling else {
            return false
        }

        if isWindowCycleOverlayVisible {
            if keyCode == Self.backtickKeyCode, isCommandBacktick(event) {
                updateWindowCycleSelection(direction: windowCycleDirection(for: event))
                shouldConsumeBacktickKeyUp = true
                return true
            }

            if keyCode == Self.downArrowKeyCode {
                updateWindowCycleSelection(direction: .forward)
                return true
            }

            if keyCode == Self.upArrowKeyCode {
                updateWindowCycleSelection(direction: .backward)
                return true
            }

            if keyCode == Self.deleteKeyCode {
                updateWindowCycleQuery { cycler in
                    cycler.backspaceQuery()
                }
                return true
            }

            if let character = queryCharacter(from: event, ignoringCommandModifier: true) {
                updateWindowCycleQuery { cycler in
                    cycler.appendQuery(character)
                }
                return true
            }
        }

        guard keyCode == Self.backtickKeyCode,
              isCommandBacktick(event) else {
            return false
        }

        guard let result = windowCycler.cycleCurrentApplicationWindow(direction: windowCycleDirection(for: event)) else {
            return false
        }

        shouldConsumeBacktickKeyUp = true
        isWindowCycleOverlayVisible = true
        onWindowCycle(result)
        return true
    }

    private func handleFlagsChanged(event: CGEvent) -> Unmanaged<CGEvent>? {
        if isWindowCycleOverlayVisible, !event.flags.contains(.maskCommand) {
            commitWindowCycleSelection()
        }

        return pass(event)
    }

    private func updateWindowCycleSelection(direction: WindowCycleDirection) {
        guard let result = windowCycler.moveSelection(direction: direction) else {
            return
        }

        onWindowCycle(result)
    }

    private func updateWindowCycleQuery(_ update: (WindowCycler) -> WindowCycleResult?) {
        guard let result = update(windowCycler) else {
            return
        }

        onWindowCycle(result)
    }

    private func commitWindowCycleSelection() {
        guard isWindowCycleOverlayVisible else {
            return
        }

        windowCycler.commitSelection()
        isWindowCycleOverlayVisible = false
        onWindowCycleEnd()
    }

    private func isWindowCycleNavigationKey(_ keyCode: CGKeyCode) -> Bool {
        keyCode == Self.upArrowKeyCode
            || keyCode == Self.downArrowKeyCode
            || keyCode == Self.deleteKeyCode
    }

    private func isCommandBacktick(_ event: CGEvent) -> Bool {
        let flags = event.flags
        return flags.contains(.maskCommand)
            && !flags.contains(.maskControl)
            && !flags.contains(.maskAlternate)
    }

    private func windowCycleDirection(for event: CGEvent) -> WindowCycleDirection {
        event.flags.contains(.maskShift) ? .backward : .forward
    }

    private func isPlainActivationKey(_ event: CGEvent) -> Bool {
        let flags = event.flags
        return !flags.contains(.maskCommand)
            && !flags.contains(.maskShift)
            && !flags.contains(.maskControl)
            && !flags.contains(.maskAlternate)
    }

    private func queryCharacter(from event: CGEvent, ignoringCommandModifier: Bool = false) -> Character? {
        let textEvent: CGEvent
        if ignoringCommandModifier, let eventCopy = event.copy() {
            var flags = eventCopy.flags
            flags.remove(.maskCommand)
            flags.remove(.maskControl)
            flags.remove(.maskAlternate)
            eventCopy.flags = flags
            textEvent = eventCopy
        } else {
            textEvent = event
        }

        var length = 0
        var characters = [UniChar](repeating: 0, count: 4)

        textEvent.keyboardGetUnicodeString(
            maxStringLength: characters.count,
            actualStringLength: &length,
            unicodeString: &characters
        )

        guard length == 1,
              let scalar = UnicodeScalar(characters[0]),
              CharacterSet.alphanumerics.contains(scalar) else {
            return nil
        }

        return Character(String(scalar).lowercased())
    }

    private func synthesizeKeyPress(keyCode: CGKeyCode) {
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            return
        }

        // The marker lets our tap pass these replacement Escape events through
        // instead of interpreting them as a fresh switch-mode activation.
        for isKeyDown in [true, false] {
            guard let event = CGEvent(
                keyboardEventSource: source,
                virtualKey: keyCode,
                keyDown: isKeyDown
            ) else {
                continue
            }

            event.setIntegerValueField(.eventSourceUserData, value: Self.syntheticEventMarker)
            event.post(tap: .cghidEventTap)
        }
    }

    private func pass(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        Unmanaged.passUnretained(event)
    }
}
