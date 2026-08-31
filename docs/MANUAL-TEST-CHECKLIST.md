# MVP clean-machine checklist

Run on a clean macOS 14+ Apple Silicon account with network available for the first model download.

- Launch: app has no Dock icon; menu item and settings open; VoiceOver names the dictation control.
- Permissions: test grant, deny, revoke, and recovery for microphone and Accessibility.
- Model: test first download, interruption/retry, offline relaunch, cold and warm transcription.
- Recording: test silence, <1 second speech, background noise, cancel, 10 repeated cycles, overlapping triggers, and input disconnect.
- Languages: automatic plus English, French, Spanish, and German representative phrases.
- Insertion: mid-sentence and empty fields in TextEdit, Notes, browser textarea/contenteditable, Terminal, Electron input, and a code editor.
- Recovery: close/change target during transcription; verify Copy Last Transcript and clipboard restoration with text, image, and file contents.
- Shortcut: test both choices for collisions; confirm the HUD never takes focus and Escape cancels.
- Preferences: relaunch after changing shortcut/language and launch-at-login; verify invalid input falls back to the system default.
- Accessibility: keyboard navigation, VoiceOver, increased contrast, and Reduce Motion.
- Privacy: confirm no audio remains in the temporary directory after success, failure, or cancellation; inspect network activity after model download.

Signing/notarization requires a Developer ID Application certificate and Apple notary credentials and is intentionally not automated with private credentials.
