import SwiftUI

@main
struct YokoWhisperApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        MenuBarExtra("Yoko Whisper", systemImage: "waveform") {
            MenuContentView(model: model)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(model: model)
        }
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
    private let shortcuts = ShortcutService()
    private var hud: HUDController?
    let permissions = PermissionService()
    var onboardingComplete = UserDefaults.standard.bool(forKey: "onboardingComplete")

    init(transcriptionEngine: (any TranscriptionEngine)? = nil) {
        dictation = DictationCoordinator(transcriptionEngine: transcriptionEngine)
    }

    func startIntegrations() {
        guard hud == nil else { return }
        hud = HUDController(model: self)
        dictation.onStateChange = { [weak self] state in self?.hud?.update(for: state) }
        shortcuts.onPress = { [weak self] in self?.dictation.beginRecording() }
        shortcuts.onRelease = { [weak self] in
            guard let self else { return }
            self.dictation.finishRecording(language: self.preferences.transcriptionLanguage)
        }
        shortcuts.onCancel = { [weak self] in
            self?.dictation.cancelRecording()
        }
        shortcuts.start(choice: preferences.shortcut)
    }

    func finishOnboarding() {
        onboardingComplete = true
        UserDefaults.standard.set(true, forKey: "onboardingComplete")
    }

    func toggleRecordingFromMenu() {
        if case .recording = state {
            dictation.finishRecording(language: preferences.transcriptionLanguage)
        } else {
            dictation.beginRecording()
        }
    }

    func finishRecordingFromHUD() {
        guard case .recording = state else { return }
        toggleRecordingFromMenu()
    }

    func cancel() { dictation.cancelRecording() }

    func copyLastTranscript() { dictation.copyLastTranscript() }

    func clearLastTranscript() { dictation.clearLastTranscript() }

    func applyShortcutPreference() {
        shortcuts.start(choice: preferences.shortcut)
    }
}
