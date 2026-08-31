import Foundation
import ServiceManagement
import CoreGraphics

enum ShortcutChoice: String, CaseIterable, Identifiable, Sendable {
    case fnSpace, controlOptionSpace, optionK, optionSpace
    var id: String { rawValue }
    var label: String {
        switch self {
        case .fnSpace: "Fn Space"
        case .controlOptionSpace: "⌃⌥ Space"
        case .optionK: "⌥ K"
        case .optionSpace: "⌥ Space"
        }
    }
    var keyCode: UInt16 { self == .optionK ? 40 : 49 }
    var eventFlags: CGEventFlags {
        switch self {
        case .fnSpace: .maskSecondaryFn
        case .controlOptionSpace: [.maskControl, .maskAlternate]
        case .optionK, .optionSpace: .maskAlternate
        }
    }
}

@MainActor
@Observable
final class Preferences {
    var shortcut: ShortcutChoice { didSet { defaults.set(shortcut.rawValue, forKey: "shortcut") } }
    var language: String { didSet { defaults.set(language, forKey: "language") } }
    var launchAtLogin = false
    var launchAtLoginError: String?
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        shortcut = ShortcutChoice(rawValue: defaults.string(forKey: "shortcut") ?? "") ?? .fnSpace
        language = defaults.string(forKey: "language") ?? "auto"
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            launchAtLogin = enabled; launchAtLoginError = nil
        } catch { launchAtLoginError = error.localizedDescription; launchAtLogin = SMAppService.mainApp.status == .enabled }
    }
}
