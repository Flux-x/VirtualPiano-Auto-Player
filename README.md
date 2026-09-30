# VirtualPiano Auto Player

A lightweight Windows desktop player for Virtual Piano (`virtualpiano.net`) sheet music automation.

Built to execute complex polyphonic sheet music with precise beat timing, custom humanization variation, and screen-capture privacy.

---

## Features

- **Precise Beat Timing Engine**: Synchronizes note playback against high-resolution hardware timers (`timeBeginPeriod`) to eliminate timing drift on fast passages and complex chords.
- **Full Notation Parser**: Supports Virtual Piano sheet syntax including polyphonic chords (`[6fj]`), modifier key holds (`[:t'r]`), Shift octave notes, and rests (`-`, `--`, `----`, `|`).
- **Humanization & Timing Jitter**: Adjustable humanize percentage (0–100%) adds natural microsecond timing variations and keystroke hold durations so playback sounds like a live performance.
- **Dynamic Tempo Control**: Increase or decrease BPM in real-time using sliders, quick-preset buttons (60, 120, 180, 240, 500, 1000 BPM), or hotkeys during active playback.
- **OBS / Stream Privacy (Anti OBS)**: Built-in `SetWindowDisplayAffinity` (`WDA_EXCLUDEFROMCAPTURE`) toggle renders the application interface invisible to Discord screenshare, OBS Studio, and Twitch streams.
- **15 Bundled Sample Songs**: Comes pre-packaged with verified sheet music files including *Interstellar*, *Rush E*, *Megalovania (Sans)*, *Tetris*, *Izmir Marsi*, *Passacaglia*, and more.

---

## Interface & Controls

```
+-----------------------------------------------------------+
| VIRTUAL PIANO AUTO PLAYER                                 |
+-----------------------------------------------------------+
| [ Control Panel ]                                         |
| Tempo (BPM): [ 120 ] [====|========] (60/120/180/240/500)|
| Humanize:    [ 30% ] [===|=========]                      |
|                                                           |
| [ Sheet Music ]                                           |
| Quick Load: [ Sample Songs v ]                            |
| +-------------------------------------------------------+ |
| | [6f] f [6f] f [6fj] - -- |                              | |
| | [5d] d [5d] d [5dh] - -- |                              | |
| +-------------------------------------------------------+ |
|                                                           |
| [>] Play (F1)   [||] Pause   [X] Stop (F2)                |
| [*] Anti OBS Protection  [x] Loop Track                   |
| Status: Ready                                             |
+-----------------------------------------------------------+
```

### Hotkey Bindings

| Function | Default Key | Mouse Shortcut | Description |
| :--- | :--- | :--- | :--- |
| **Play / Pause** | `F1` | `XButton2` (Mouse 5) | Starts or toggles pause on the active sheet. |
| **Stop** | `F2` | `XButton1` (Mouse 4) | Halts playback and resets sheet position to start. |
| **Settings** | `SET` button | — | Customizes hotkey assignments. |

---

## Notation Guide

| Symbol | Meaning | Behavior |
| :--- | :--- | :--- |
| `f` | Single Note | Triggers key `f`. |
| `[6fj]` | Polyphonic Chord | Plays keys `6`, `f`, and `j` simultaneously. |
| `[ST]` | Shift Octave | Plays uppercase shifted keys in sequence. |
| `-` | Short Rest | Pauses for 1 timing beat. |
| `--` | Medium Rest | Pauses for 2 timing beats. |
| `----` | Full Rest | Pauses for 4 timing beats (measure break). |
| `\|` | Measure Line | Visual measure division indicator. |

---

## Quickstart

### Prerequisites
- **OS**: Windows 10 / 11 (x64)
- **Runtime**: [AutoHotkey v1.1+](https://www.autohotkey.com/)

### Running the Player
1. Download or clone this repository:
   ```cmd
   git clone https://github.com/FLUXXFALCON/VirtualPiano-Auto-Player.git
   cd VirtualPiano-Auto-Player
   ```
2. Double-click `pn.ahk` to launch the control panel.
3. Select a track from **Quick Load** or paste custom sheet music into the editor box.
4. Set desired **Tempo (BPM)** and **Humanize** percentage.
5. Focus your target piano window (e.g., `virtualpiano.net`) and press `F1` to start.

---

## Project Structure

```
VirtualPiano-Auto-Player/
├── sheets/                ← 15 pre-packaged sheet music files
│   ├── Interstellar.txt
│   ├── rush e.txt
│   ├── sans.txt
│   └── ...
├── pn.ahk                 ← Main application entrypoint
├── config.ini             ← User settings and custom keybinds
├── saved_paths.txt        ← Sheet file index
├── LICENSE                ← MIT License
└── README.md              ← Project documentation
```

---

## License

Distributed under the [MIT License](LICENSE).
