@preconcurrency import ApplicationServices
import AppKit
import Foundation

struct FocusTarget {
    let application: NSRunningApplication
    let element: AXUIElement?
}

enum InsertionError: LocalizedError { case noTarget, pasteFailed
    var errorDescription: String? { self == .noTarget ? "The original text field is no longer available. The transcript was copied." : "The transcript could not be pasted. It remains copied." }
}

@MainActor
final class TextInsertionService {
    func captureTarget() -> FocusTarget? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let applicationElement = AXUIElementCreateApplication(app.processIdentifier)
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(applicationElement, kAXFocusedUIElementAttribute as CFString, &value)
        return FocusTarget(application: app, element: result == .success ? (value as! AXUIElement) : nil)
    }

    func insert(_ text: String, into target: FocusTarget?) async throws {
        copyToPasteboard(text)
        guard let target else { throw InsertionError.noTarget }

        target.application.activate()
        try await Task.sleep(for: .milliseconds(100))

        let element = target.element ?? focusedElement(in: target.application)
        if let element {
            AXUIElementSetAttributeValue(element, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        }
        if let element,
           AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, text as CFTypeRef) == .success { return }
        try await paste(text, into: target.application)
    }

    private func paste(_ text: String, into application: NSRunningApplication) async throws {
        copyToPasteboard(text)
        application.activate()
        try await Task.sleep(for: .milliseconds(100))
        guard let source = CGEventSource(stateID: .hidSystemState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
        else { throw InsertionError.pasteFailed }
        down.flags = .maskCommand; up.flags = .maskCommand
        down.post(tap: .cghidEventTap); up.post(tap: .cghidEventTap)
    }

    private func copyToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func focusedElement(in application: NSRunningApplication) -> AXUIElement? {
        let appElement = AXUIElementCreateApplication(application.processIdentifier)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &value) == .success else { return nil }
        return value as! AXUIElement
    }
}
