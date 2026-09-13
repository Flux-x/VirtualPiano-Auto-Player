# VirtualPiano Auto Player

```
  __   _____ ___ _____ _   _   _    _      ___ ___   _   _  _  ___ 
  \ \ / /_ _| _ \_   _| | | | /_\  | |    | _ \_ _| /_\ | \| |/ _ \
   \ V / | ||   / | | | |_| |/ _ \ | |__  |  _/| | / _ \| .` | (_) |
    \_/ |___|_|_\ |_|  \___//_/ \_\|____| |_| |___/_/ \_\_|\_|\___/ 
                                AUTO PLAYER ENGINE
```

> **High-precision, microsecond-accurate sheet playback automation for Virtual Piano.**  
> Built with low-level Windows QueryPerformanceCounter (QPC) timing, dynamic humanization, and native stream-safe privacy.

---

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg?style=flat-square)](LICENSE)
[![Language](https://img.shields.io/badge/Language-AutoHotkey%20v1.1+-334455.svg?style=flat-square)](https://www.autohotkey.com/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011-0078D6.svg?style=flat-square)](https://microsoft.com/windows)
[![Timing Engine](https://img.shields.io/badge/Timing-Hardware%20QPC%20(1ms)-00c853.svg?style=flat-square)](#architecture--engine)
[![Stream Privacy](https://img.shields.io/badge/Privacy-WDA%20Stream--Safe-9c27b0.svg?style=flat-square)](#screen-capture-invisibility-wda)

---

## Overview

**VirtualPiano Auto Player** is a lightweight desktop automation tool designed to execute complex Virtual Piano (`virtualpiano.net`) sheet music with studio-grade timing precision. 

Standard software macros suffer from Windows thread scheduling jitter (15–16ms latency spikes), causing notes and chords to desynchronize during fast passages. This engine utilizes Windows **QueryPerformanceCounter (QPC)** and hardware multimedia timers (`timeBeginPeriod(1)`) to achieve sub-millisecond accuracy, even during multi-octave chord sequences at 200+ BPM.

---

## Core Capabilities

```
  [ Sheet Input ] ──▸ [ Tokenizer ] ──▸ [ QPC Beat Engine ] ──▸ [ Low-level SendInput ]
                             │                      │
                             ▼                      ▼
                    [ Chord & Rest Matrix ]  [ Humanize & Jitter ]
```

- **Hardware QPC Timing Engine**  
  Eliminates timing drift by synchronizing playback beats directly against CPU performance frequency counters rather than standard sleep loops.

- **Full VP Notation Tokenizer**  
  Parses complex multi-key polyphonic chords (`[6fj]`), sequential modifiers (`[:t'r]`), Shift octaves, and musical rests (`-`, `--`, `|`).

- **Humanization & Hold Variance**  
  Configurable micro-jitter and keystroke hold multipliers prevent robotic playback, emulating the natural velocity and acoustic decay of a live pianist.

- **Stream & Recording Invisibility (WDA)**  
  Integrates Windows `SetWindowDisplayAffinity` (`WDA_EXCLUDEFROMCAPTURE`), rendering the application GUI completely invisible to OBS Studio, Discord screenshare, and Twitch broadcasts.

- **On-the-Fly Dynamic BPM Scaling**  
  Accelerate or decelerate tempo in real time during live playback via dedicated GUI sliders or assigned hotkeys.

- **Hardware Mouse & Keyboard Remapping**  
  Assign controls to secondary mouse buttons (`XButton1`, `XButton2`) or custom keyboard keybinds without hotkey conflicts.

---

## Notation Syntax Guide

The built-in parser supports standard Virtual Piano notation formatting:

| Notation | Type | Playback Behavior |
| :--- | :--- | :--- |
| `f` | Single Note | Fires single key `f`. |
| `[6fj]` | Polyphonic Chord | Plays `6`, `f`, and `j` simultaneously as a chord. |
| `[6f]` | Modifier Chord | Holds modifier `6` while triggering note `f`. |
| `[ST]` | Shift Octave | Triggers shifted uppercase note sequence. |
| `-` | Short Rest | Pauses for 1 timing unit. |
| `--` | Medium Rest | Pauses for 2 timing units. |
| `----` | Full Rest | Pauses for 4 timing units (measure break). |
| `\|` | Measure Line | Structural measure separator. |
| ` ` | Space | Beat division delimiter. |

---

## Bundled Sheet Music Library

The project comes pre-packaged with 15 verified sheet music files in the `sheets/` directory:

| Track Name | Genre / Origin | Complexity |
| :--- | :--- | :--- |
| **Interstellar** | Hans Zimmer (Film OST) | High (Chords & Polyphony) |
| **Rush E** | Sheet Music Boss | Extreme (High BPM) |
| **Megalovania (Sans)** | Toby Fox (Undertale) | High (Rapid syncopation) |
| **Passacaglia** | Handel / Halvorsen | Advanced (Classical) |
| **Tetris Theme** | Korobeiniki (Folk / Game) | Medium |
| **Katyusha & Kalinka** | Russian Folk Classics | Medium |
| **La Maritza** | Sylvie Vartan | Intermediate |
| **Valse** | Romantic Waltz | Medium |
| **Izmir Marsi** | Historical March | Intermediate |
| **The Rose Garden** | Atmospheric | Intermediate |
| **Kambulat** | Contemporary | Intermediate |

---

## Default Controls

| Action | Primary Keyboard | Primary Mouse | Description |
| :--- | :--- | :--- | :--- |
| **Play / Pause** | `F1` | `XButton2` (Mouse 5) | Starts or pauses current playback queue. |
| **Stop** | `F2` | `XButton1` (Mouse 4) | Halts playback and resets cursor to start. |
| **Record Mode** | `GUI Toggle` | — | Toggles display capture invisibility (WDA). |
| **Loop Mode** | `GUI Checkbox` | — | Automatically restarts track upon completion. |

---

## Quickstart

### Prerequisites
- **Operating System:** Windows 10 or Windows 11 (x64)
- **Runtime:** [AutoHotkey v1.1+](https://www.autohotkey.com/) installed

### Installation & Launch
```powershell
# 1. Clone the repository
git clone https://github.com/FLUXXFALCON/VirtualPiano-Auto-Player.git

# 2. Navigate to project directory
cd VirtualPiano-Auto-Player

# 3. Launch application
start pn.ahk
```

1. Select a song from the **SAMPLE SONGS** dropdown or paste custom sheet music into the editor box.
2. Configure desired **BPM** (Tempo) and **Humanize** percentage.
3. Switch focus to your target piano application or `virtualpiano.net`.
4. Press `F1` (or your assigned hotkey) to commence playback.

---

## Project Structure

```
VirtualPiano-Auto-Player/
├── .github/
│   ├── workflows/
│   │   └── security.yml       ← Automated credential & integrity scan
│   ├── dependabot.yml         ← Weekly action dependency maintenance
│   └── SECURITY.md            ← Vulnerability disclosure policy
├── sheets/                    ← Pre-packaged sheet music library
│   ├── Interstellar.txt
│   ├── rush e.txt
│   ├── sans.txt
│   └── ... (15 bundled songs)
├── pn.ahk                     ← Core engine and automation runtime
├── config.ini                 ← Saved user keybinds and engine settings
├── saved_paths.txt            ← Indexed sheet path registry
├── .gitignore                 ← Repository hygiene and ignore rules
├── SECURITY.md                ← Root security policy
├── LICENSE                    ← MIT License
└── README.md                  ← Project documentation
```

---

## Security & Privacy

- **100% Local Execution:** No outbound network connections, tracking telemetry, or remote command execution.
- **Display Privacy:** Windows `SetWindowDisplayAffinity` prevents accidental UI leakage while recording or streaming.
- **Resource Hygiene:** Properly releases high-resolution timer allocations (`timeEndPeriod`) upon script termination.
- For vulnerability reports and disclosure procedures, please refer to [SECURITY.md](SECURITY.md).

---

## License

This project is licensed under the **[MIT License](LICENSE)**.
