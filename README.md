# Yoko Whisper

Fast, private, on-device voice-to-text for Apple Silicon Macs. Yoko Whisper records only while you dictate, transcribes locally with WhisperKit, and inserts the result at the cursor in the app you were using. Every completed transcript is also left on the clipboard for recovery.

## Features

- Local batch transcription with the `openai_whisper-small` model through WhisperKit
- Global, configurable start/stop shortcut
- Direct Accessibility insertion with paste fallback
- Clipboard recovery when an app does not support direct insertion
- Microphone level HUD, Escape cancellation, and optional launch at login
- No account, backend, telemetry, or cloud upload

## Requirements

- macOS 14 or newer
- Apple Silicon Mac
- Xcode 16 or newer for development
- Microphone and Accessibility permissions

The transcription model is downloaded on first use, so the first dictation takes longer than later runs.

## Build

Clone the repository and open `YokoWhisper.xcodeproj` in Xcode, or run:

```sh
xcodebuild \
  -project YokoWhisper.xcodeproj \
  -scheme YokoWhisper \
  -destination 'platform=macOS,arch=arm64' \
  CODE_SIGNING_ALLOWED=NO \
  test
```

To run microphone and Accessibility flows, select your own development team for the `YokoWhisper` target in Xcode. No development-team identifier is committed.

`project.yml` is the XcodeGen source of truth when regenerating the project.

## Test dictation

1. Run Yoko Whisper and grant Microphone and Accessibility access.
2. Focus a text field in TextEdit.
3. Press the configured shortcut (`Fn Space` by default).
4. Speak, then press the shortcut again.
5. Confirm the transcript appears at the original cursor and remains available with Paste.

Do not click the menu-bar microphone when testing cursor restoration; doing so changes the active UI away from the intended target. See the [manual test checklist](docs/MANUAL-TEST-CHECKLIST.md) for broader coverage.

## Privacy

Audio is written only to a temporary local file, processed on device, and removed after transcription or failure. Yoko Whisper does not include analytics, accounts, or a network transcription service. See [PRIVACY.md](PRIVACY.md).

## Security

Please report vulnerabilities privately as described in [SECURITY.md](SECURITY.md). Do not open a public issue containing a credential or sensitive recording.

## Dependencies and license

Yoko Whisper uses [WhisperKit](https://github.com/argmaxinc/WhisperKit) through Argmax's `argmax-oss-swift` package. That dependency and OpenAI Whisper are MIT-licensed. Dependency versions are pinned in `Package.resolved`.

Yoko Whisper is available under the [MIT License](LICENSE).
