# Privacy

Yoko Whisper is designed for local dictation.

- Microphone audio is captured only during an active dictation.
- Audio is stored in a temporary local file and deleted after transcription or failure.
- Transcription runs on the Mac with WhisperKit; recorded audio is not sent to Yoko Whisper servers or OpenAI.
- The completed transcript is inserted through macOS Accessibility APIs when an editable target is available and copied to the system clipboard for recovery.
- The latest transcript is also stored in local app preferences for recovery across relaunches until it is replaced or the user clears it. No transcript history is retained or synchronized by Yoko Whisper.
- Secure fields and sessions without an editable cursor are clipboard-only.
- Transcript contents and recordings are not intentionally written to application logs.
- The app has no account system, analytics, advertising, or telemetry.
- The first run may download model files required by WhisperKit. This network activity downloads the model; it does not upload microphone audio.

Because the transcript is copied to the macOS clipboard, it may be visible to other software with clipboard access and to clipboard synchronization features configured by the user.
