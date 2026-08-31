import AppKit
import CoreGraphics

private let shortcutFlagsMask: CGEventFlags = [
    .maskCommand, .maskShift, .maskAlternate, .maskControl, .maskSecondaryFn,
]

enum ShortcutTapLifecycle {
    static func shouldReenable(after type: CGEventType) -> Bool {
        type == .tapDisabledByTimeout || type == .tapDisabledByUserInput
    }
}

private func shortcutEventCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let service = Unmanaged<ShortcutService>.fromOpaque(userInfo).takeUnretainedValue()
    return service.handle(type: type, event: event) ? nil : Unmanaged.passUnretained(event)
}

/// Consumes the configured shortcut so it cannot also type into the target.
final class ShortcutService: @unchecked Sendable {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var escapeMonitor: Any?
    private let lock = NSLock()
    private var activeChoice: ShortcutChoice = .fnSpace
    private var pressState = ShortcutPressState()
    var onPress: (@MainActor @Sendable () -> Void)?
    var onRelease: (@MainActor @Sendable () -> Void)?
    var onCancel: (@MainActor @Sendable () -> Void)?

    @MainActor
    @discardableResult
    func start(choice: ShortcutChoice) -> Bool {
        stop()
        lock.withLock {
            activeChoice = choice
            pressState = ShortcutPressState()
        }
        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: shortcutEventCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )
        if let eventTap {
            let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
            runLoopSource = source
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
            CGEvent.tapEnable(tap: eventTap, enable: true)
        }
        escapeMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return }
            Task { @MainActor in self?.onCancel?() }
        }
        return eventTap != nil
    }

    @MainActor
    func stop() {
        if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: false) }
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
        if let escapeMonitor { NSEvent.removeMonitor(escapeMonitor) }
        eventTap = nil; runLoopSource = nil; escapeMonitor = nil
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Bool {
        if ShortcutTapLifecycle.shouldReenable(after: type) {
            if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: true) }
            return false
        }
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let transition = lock.withLock { () -> ShortcutTransition? in
            guard keyCode == activeChoice.keyCode else { return nil }
            let phase: ShortcutKeyPhase
            switch type {
            case .keyDown:
                guard event.flags.intersection(shortcutFlagsMask) == activeChoice.eventFlags else { return nil }
                phase = .down
            case .keyUp:
                phase = .up
            default:
                return nil
            }
            return pressState.transition(
                phase,
                isRepeat: event.getIntegerValueField(.keyboardEventAutorepeat) != 0
            )
        }
        switch transition {
        case .pressed:
            // A serial FIFO queue preserves press/release order while keeping
            // recording work out of the event-tap callback.
            DispatchQueue.main.async { @MainActor [weak self] in self?.onPress?() }
        case .released:
            DispatchQueue.main.async { @MainActor [weak self] in self?.onRelease?() }
        case nil:
            break
        }
        return transition != nil || lock.withLock { pressState.isPressed && keyCode == activeChoice.keyCode }
    }
}

enum ShortcutKeyPhase: Sendable { case down, up }
enum ShortcutTransition: Equatable, Sendable { case pressed, released }

struct ShortcutPressState: Sendable {
    private(set) var isPressed = false

    mutating func transition(_ phase: ShortcutKeyPhase, isRepeat: Bool = false) -> ShortcutTransition? {
        switch phase {
        case .down where !isPressed && !isRepeat:
            isPressed = true
            return .pressed
        case .up where isPressed:
            isPressed = false
            return .released
        default:
            return nil
        }
    }
}
