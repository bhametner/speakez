# Speakez 🎙️

A macOS menu bar app for instant voice-to-text. Hold a key, speak, release — your words appear at the cursor.

**100% local. 100% private. No internet required.**

[![macOS](https://img.shields.io/badge/macOS-13.0+-blue)](https://www.apple.com/macos/)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange)](https://swift.org/)

---

## Features

- **Hold-to-record** — Hold Option (⌥) to record, release to transcribe
- **Works everywhere** — Inserts text into any app via clipboard
- **Fully offline** — Uses [whisper.cpp](https://github.com/ggml-org/whisper.cpp) for local AI transcription
- **Privacy-focused** — Your audio never leaves your device
- **Lightweight** — Sits quietly in your menu bar

## Demo

<!-- TODO: Add GIF/screenshot -->

## Requirements

- macOS 13.0 (Ventura) or later
- Intel or Apple Silicon Mac
- ~50MB disk space (including model)

## Installation

### Option 1: Download Release
<!-- TODO: Add releases -->
Download the latest `.dmg` from [Releases](https://github.com/bhametner/speakez/releases).

### Option 2: Build from Source

```bash
# Clone
git clone https://github.com/bhametner/speakez.git
cd speakez

# Setup (fetches whisper.cpp, builds libs, downloads model)
./setup.sh

# Generate Xcode project (requires xcodegen)
brew install xcodegen
xcodegen generate

# Open and build
open Speakez.xcodeproj
```

## Usage

1. **Launch Speakez** — appears in your menu bar as 🎙️
2. **Grant permissions** — Microphone and Accessibility (required for global hotkey)
3. **Hold Option (⌥)** — speak your text
4. **Release** — text appears at your cursor

### Menu Bar Icons

| Icon | State |
|------|-------|
| 🎙️ Gray | Ready |
| 🔴 Red | Recording |
| ⏳ Blue | Transcribing |
| ✅ Green | Success |
| ⚠️ Yellow | Error |

## Performance

Speakez uses the `tiny.en` Whisper model by default, optimized for speed:

| Mac | Speed | Notes |
|-----|-------|-------|
| Apple Silicon (M1/M2/M3) | ~10-20x realtime | Excellent |
| Intel i5/i7 | ~2-3x realtime | Good for short clips |

*"2x realtime" = 5 seconds of audio transcribes in ~2.5 seconds*

## Configuration

Access preferences from the menu bar:

- **Hotkey** — Option, Right Option, or Control
- **Model** — Switch between Whisper models (tiny/base/small)
- **Audio** — Select input device

## Troubleshooting

### "Accessibility permission required"
1. System Settings → Privacy & Security → Accessibility
2. Add Speakez.app
3. Restart Speakez

### "Microphone permission denied"
1. System Settings → Privacy & Security → Microphone
2. Enable Speakez
3. Restart Speakez

### Transcription is slow
- Make sure you're using the `tiny.en` model
- On Intel Macs, expect 2-3 seconds for 5 seconds of audio
- Close CPU-intensive apps

## Architecture

```
Speakez/
├── SpeakezApp.swift          # App entry, menu bar, state
├── Models/
│   └── AppSettings.swift     # User preferences
├── Views/
│   ├── MenuBarView.swift     # Status menu
│   ├── PreferencesView.swift # Settings window
│   └── SetupWizardView.swift # First-run wizard
└── Services/
    ├── HotkeyService.swift         # Global hotkey (CGEventTap)
    ├── AudioCaptureService.swift   # Mic capture (AVAudioEngine)
    ├── TranscriptionService.swift  # Whisper wrapper
    └── TextInsertionService.swift  # Clipboard + paste
```

## Contributing

Contributions welcome! See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT — see [LICENSE](LICENSE).

## Credits

- [whisper.cpp](https://github.com/ggml-org/whisper.cpp) — Whisper inference in C/C++
- [OpenAI Whisper](https://github.com/openai/whisper) — Original Whisper models

---

Made with 🎤 by [Brent Hametner](https://github.com/bhametner)
