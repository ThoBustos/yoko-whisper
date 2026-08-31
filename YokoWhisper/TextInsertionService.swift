@preconcurrency import ApplicationServices
import AppKit
import Foundation

struct FocusTarget {
    let application: NSRunningApplication
    let element: AXUIElement?
}

enum InsertionResult: Equatable, Sendable {
    case insertedDirectly
    case pasteRequested
    case copiedOnly
}

enum InsertionStrategy: Equatable, Sendable {
    case direct
    case paste
    case copy
}

enum InsertionPolicy {
    static func strategy(
        hasTarget: Bool,
        isSecure: Bool,
        supportsDirectInsertion: Bool,
        hasEditableRole: Bool
    ) -> InsertionStrategy {
        guard hasTarget, !isSecure else { return .copy }
        if supportsDirectInsertion { return .direct }
        return hasEditableRole ? .paste : .copy
    }

    static func allowsSyntheticPaste(
        applicationIsFrontmost: Bool,
        focusMatches: Bool,
        isSecure: Bool,
        hasEditableRole: Bool
    ) -> Bool {
        applicationIsFrontmost && focusMatches && !isSecure && hasEditableRole
    }
}

@MainActor
final class TextInsertionService {
    func captureTarget() -> FocusTarget? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        return FocusTarget(application: app, element: focusedElement(in: app))
    }

    func insert(_ text: String, into target: FocusTarget?) async -> InsertionResult {
        copyToPasteboard(text)
        guard let target, !target.application.isTerminated else { return .copiedOnly }

        target.application.activate()
        try? await Task.sleep(for: .milliseconds(100))

        let element = restoredElement(for: target)
        let strategy = InsertionPolicy.strategy(
            hasTarget: element != nil,
            isSecure: element.map(isSecureField) ?? false,
            supportsDirectInsertion: element.map(supportsDirectInsertion) ?? false,
            hasEditableRole: element.map(hasEditableRole) ?? false
        )

        switch strategy {
        case .direct:
            guard let element else { return .copiedOnly }
            if AXUIElementSetAttributeValue(
                element,
                kAXSelectedTextAttribute as CFString,
                text as CFTypeRef
            ) == .success {
                return .insertedDirectly
            }
            return await paste(text, into: target.application, expectedElement: element)
        case .paste:
            guard let element else { return .copiedOnly }
            return await paste(text, into: target.application, expectedElement: element)
        case .copy:
            return .copiedOnly
        }
    }

    private func restoredElement(for target: FocusTarget) -> AXUIElement? {
        if let element = target.element,
           AXUIElementSetAttributeValue(
            element,
            kAXFocusedAttribute as CFString,
            kCFBooleanTrue
           ) == .success {
            return element
        }
        return nil
    }

    private func paste(
        _ text: String,
        into application: NSRunningApplication,
        expectedElement: AXUIElement
    ) async -> InsertionResult {
        copyToPasteboard(text)
        application.activate()
        try? await Task.sleep(for: .milliseconds(100))
        guard let focusedElement = focusedElement(in: application),
              InsertionPolicy.allowsSyntheticPaste(
                applicationIsFrontmost: NSWorkspace.shared.frontmostApplication?.processIdentifier == application.processIdentifier,
                focusMatches: CFEqual(focusedElement, expectedElement),
                isSecure: isSecureField(focusedElement),
                hasEditableRole: hasEditableRole(focusedElement)
              ),
              let source = CGEventSource(stateID: .hidSystemState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
        else { return .copiedOnly }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        // Quartz confirms that the events were posted, not that the target
        // accepted them. Keep the recovery claim conservative.
        return .pasteRequested
    }

    private func copyToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func focusedElement(in application: NSRunningApplication) -> AXUIElement? {
        let appElement = AXUIElementCreateApplication(application.processIdentifier)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &value
        ) == .success,
              let value,
              CFGetTypeID(value) == AXUIElementGetTypeID()
        else { return nil }
        return (value as! AXUIElement)
    }

    private func supportsDirectInsertion(_ element: AXUIElement) -> Bool {
        var settable = DarwinBoolean(false)
        return AXUIElementIsAttributeSettable(
            element,
            kAXSelectedTextAttribute as CFString,
            &settable
        ) == .success && settable.boolValue
    }

    private func hasEditableRole(_ element: AXUIElement) -> Bool {
        guard let role = stringAttribute(kAXRoleAttribute, of: element) else { return false }
        return ["AXTextField", "AXTextArea", "AXComboBox"].contains(role)
    }

    private func isSecureField(_ element: AXUIElement) -> Bool {
        stringAttribute(kAXSubroleAttribute, of: element) == "AXSecureTextField"
    }

    private func stringAttribute(_ attribute: String, of element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        return value as? String
    }
}
