import AppKit
import CoreGraphics

private let shortcutFlagsMask: CGEventFlags = [
    .maskCommand, .maskShift, .maskAlternate, .maskControl, .maskSecondaryFn,
]

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
    var onToggle: (@MainActor @Sendable () -> Void)?
    var onCancel: (@MainActor @Sendable () -> Void)?

    @MainActor
    func start(choice: ShortcutChoice) {
        stop()
        lock.withLock { activeChoice = choice }
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
    }

    @MainActor
    func stop() {
        if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: false) }
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
        if let escapeMonitor { NSEvent.removeMonitor(escapeMonitor) }
        eventTap = nil; runLoopSource = nil; escapeMonitor = nil
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Bool {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: true) }
            return false
        }
        let choice = lock.withLock { activeChoice }
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        guard keyCode == choice.keyCode,
              event.flags.intersection(shortcutFlagsMask) == choice.eventFlags
        else { return false }
        if type == .keyDown, event.getIntegerValueField(.keyboardEventAutorepeat) == 0 {
            Task { @MainActor [weak self] in self?.onToggle?() }
        }
        return true
    }
}
