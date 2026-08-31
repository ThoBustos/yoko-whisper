# MVP clean-machine checklist

Run on a clean macOS 14+ Apple Silicon account with network available for the first model download.

- Launch: app has no Dock icon; menu item and settings open; VoiceOver names the dictation control.
- Permissions: test grant, deny, revoke, and recovery for microphone and Accessibility.
- Model: test first download, interruption/retry, offline relaunch, cold and warm transcription.
- Recording: hold the shortcut, confirm recording starts on key-down and stops on key-up; test a <180 ms accidental press, silence, <1 second speech, background noise, Escape, 10 repeated cycles, overlapping triggers, and input disconnect.
- Languages: automatic plus English, French, Spanish, and German representative phrases.
- Insertion: mid-sentence and empty fields in TextEdit, Notes, browser textarea/contenteditable, Terminal, Electron input, and a code editor.
- Recovery: close/change target during transcription; confirm the HUD says `Copied`, Copy Last Transcript works, and the final transcript remains on the clipboard.
- Secure fields: confirm Yoko never injects text and reports `Copied` without exposing transcript contents in logs.
- Shortcut: test every preset, modifier-first release ordering, key repeat, and collisions; confirm both key events are consumed and Escape cancels.
- HUD: confirm the 148×36 pill stays top-center, never takes focus, follows the pointer display at recording start, joins full-screen Spaces, animates with input, and becomes static with Reduce Motion.
- Preferences: relaunch after changing shortcut/language and launch-at-login; verify invalid input falls back to the system default.
- Accessibility: keyboard navigation, VoiceOver, increased contrast, and Reduce Motion.
- Privacy: confirm no audio remains in the temporary directory after success, failure, or cancellation; inspect network activity after model download.
- Performance: record cold and warm model latency, peak memory, CPU, and Energy Log results on each available Apple Silicon generation; compare before changing models or concurrency.

Signing/notarization requires a Developer ID Application certificate and Apple notary credentials and is intentionally not automated with private credentials.
