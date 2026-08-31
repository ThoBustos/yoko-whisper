import SwiftUI
import CoreGraphics

@main
struct YokoWhisperApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(model: model)
        } label: {
            Image(systemName: "waveform")
                .accessibilityLabel("Yoko Whisper")
                .onAppear { model.startIntegrations() }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(model: model)
        }
    }
}

struct IntegrationLifecycle {
    private(set) var hasStarted = false

    mutating func beginIfNeeded() -> Bool {
        guard !hasStarted else { return false }
        hasStarted = true
        return true
    }
}

enum ShortcutPermissionGuidance {
    static func message(accessibilityGranted: Bool, listenGranted: Bool) -> String {
        if !accessibilityGranted {
            return "Accessibility access is required for the active global shortcut. Grant it in System Settings, then retry."
        }
        if !listenGranted {
            return "Input Monitoring access may be required to receive global key events. Grant it in System Settings, then retry."
        }
        return "The global shortcut listener could not start. Check for a shortcut conflict, then retry."
    }
}

@MainActor
@Observable
final class AppModel {
    var state: DictationState { dictation.state }
    var status: String { state.label }
    var recorder: AudioRecorder { dictation.recorder }
    var lastTranscript: String? { dictation.lastTranscript }
    let preferences = Preferences()
    let dictation: DictationCoordinator
    private let soundPlayer: any AppSoundPlaying
    private let shortcuts = ShortcutService()
    private var hud: HUDController?
    private var integrationLifecycle = IntegrationLifecycle()
    private(set) var shortcutError: String?
    let permissions = PermissionService()
    var onboardingComplete = UserDefaults.standard.bool(forKey: "onboardingComplete")

    init(
        transcriptionEngine: (any TranscriptionEngine)? = nil,
        soundPlayer: any AppSoundPlaying = AppSoundPlayer()
    ) {
        dictation = DictationCoordinator(transcriptionEngine: transcriptionEngine)
        self.soundPlayer = soundPlayer
    }

    func startIntegrations() {
        guard integrationLifecycle.beginIfNeeded() else { return }
        hud = HUDController(model: self)
        dictation.onStateChange = { [weak self] state in self?.hud?.update(for: state) }
        shortcuts.onPress = { [weak self] in self?.beginRecording() }
        shortcuts.onRelease = { [weak self] in
            guard let self else { return }
            self.finishRecording()
        }
        shortcuts.onCancel = { [weak self] in self?.dictation.cancelRecording() }
        startShortcutListener()
    }

    func finishOnboarding() {
        onboardingComplete = true
        UserDefaults.standard.set(true, forKey: "onboardingComplete")
    }

    func toggleRecordingFromMenu() {
        if case .recording = state {
            finishRecording()
        } else {
            beginRecording()
        }
    }

    func finishRecordingFromHUD() {
        guard case .recording = state else { return }
        finishRecording()
    }

    func cancel() { dictation.cancelRecording() }

    func copyLastTranscript() { dictation.copyLastTranscript() }

    func clearLastTranscript() { dictation.clearLastTranscript() }

    func applyShortcutPreference() {
        dictation.cancelRecording()
        startShortcutListener()
    }

    func requestShortcutAccess() {
        dictation.cancelRecording()
        if !AXIsProcessTrusted() {
            permissions.requestAccessibility()
        } else if !CGPreflightListenEventAccess() {
            CGRequestListenEventAccess()
        }
        startShortcutListener()
    }

    private func startShortcutListener() {
        shortcutError = shortcuts.start(choice: preferences.shortcut) ? nil : ShortcutPermissionGuidance.message(
            accessibilityGranted: AXIsProcessTrusted(),
            listenGranted: CGPreflightListenEventAccess()
        )
    }

    private func beginRecording() {
        dictation.beginRecording()
        guard case .recording = state else { return }
        soundPlayer.play(.recordingBegan)
    }

    private func finishRecording() {
        guard case .recording = state else { return }
        soundPlayer.play(.recordingReleased)
        dictation.finishRecording(language: preferences.transcriptionLanguage)
    }
}
