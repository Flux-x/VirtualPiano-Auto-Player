#SingleInstance, Force
#NoEnv
#MaxHotkeysPerInterval 99000000
#HotkeyInterval 99000000
#KeyHistory 0
ListLines Off
Process, Priority, , A
SetBatchLines -1
SetKeyDelay -1, -1
SetMouseDelay -1
SetDefaultMouseSpeed 0
SetWinDelay -1
SetControlDelay -1
SendMode Input

; Yüksek hassasiyetli zamanlayıcıyı başlat
DllCall("winmm\timeBeginPeriod", "uint", 1)

; Global Variables
global isPlaying := false
global isPaused := false
global currentPosition := 0
global totalNotes := 0
global lastPressedKeys := {} ; Changed to object for tracking down state
global playbackStartTime := 0
global noteHistory := []
global BPM := 120
global BPMUpDown
global BPMSlider
global UserInput
global SampleSongs
global ProgressBar
global Status
global RecordingStatusOFF
global RecordingStatusON
global SavedSongPaths := {}
global PathsFile := A_ScriptDir . "\saved_paths.txt"
global ConfigFile := A_ScriptDir . "\config.ini"
global isRecordModeOn := false
global hWnd := 0
global isLoopEnabled := false
global LoopCheckbox
global MouseControlsText
global PlayPauseKeySetting
global StopKeySetting
global NoteDurationMultiplier := 0.8
global isWaitingForKey := false
global waitingForKeyType := ""
global QPC_Freq := 0
global PlaybackQueue := []
global QueuePosition := 0
global PlaybackStartTimeQPC := 0
global PauseTimeQPC := 0
global CurrentBeat := 0
global LastTickQPC := 0

; Control binding settings with defaults
global PlayPauseKey := "F1"
global StopKey := "F2"

; Track active hotkeys to prevent conflicts
global ActiveHotkeys := {}

; Parsed note array (global for VP format)
global ParsedNoteArray := []
global HumanizeLevel := 30
global HumanizeSlider
global HumanizeText
global HoldLevel := 80

LoadSavedPaths()
LoadSettings()
CreateGUI()
SetupAllHotkeys()
OnExit("CleanUp")
return

; ============================================================
; VIRTUALPIANO.NET SHEET PARSER
; Desteklenen format:
;   [6f]        -> 6 basili + f
;   [6fj]       -> 6 basili + f ve j ayni anda (chord)
;   8           -> sadece 8 tusu
;   -           -> kisa rest (1 birim)
;   --          -> orta rest (2 birim)
;   ----        -> uzun rest (4 birim)
;   [:t'r]      -> ozel chord (: t ' r hepsi)
;   [*h]        -> * tusu basili + h
;   [^y]        -> ^ tusu basili + y
;   [$T]        -> $ basili + shift+t (buyuk harf = shift)
;   [^u]        -> ^ basili + u
; ============================================================

; Octave/modifier tuslari (virtualpiano.net) - bunlar NUMPAD veya rakam tusudur
; 1=1, 2=2, ... 0=0, !=!, @=@, #=#, $=$, %=%, ^=^, &=&, *=*, (=(, )=)
; Ama virtualpiano'da modifier tuslari sol elde basili tutulur, sag elle nota basilir
; Bu AHK'da modifier "down" yapilir, nota gonderilir, modifier "up" yapilir

ParseVPSheet(input) {
    ; Nota olmayan teknik talimatları temizle (~accel.~, ~rit.~, TRANS+12 vb.)
    input := RegExReplace(input, "~.*?~", "")
    input := RegExReplace(input, "TRANS[+\-]\d+", "")
    
    ; Satir sonlarini temizle
    input := RegExReplace(input, "[\r\n]+", " ")
    input := RegExReplace(input, "\s+", " ")
    input := Trim(input)
    
    result := []
    pos := 1
    len := StrLen(input)
    
    while (pos <= len) {
        ch := SubStr(input, pos, 1)
        
        ; Bosluk - timing belirteci
        if (ch = " ") {
            token := {}
            token.type := "space"
            result.Push(token)
            pos++
            continue
        }
        
        ; Kose parantez baslangici [ -> chord/modifier token
        if (ch = "[") {
            ; Kapanana kadar oku
            closePos := InStr(input, "]", false, pos+1)
            if (closePos > 0) {
                inner := SubStr(input, pos+1, closePos - pos - 1)
                token := ParseVPToken(inner)
                result.Push(token)
                pos := closePos + 1
            } else {
                pos++
            }
            continue
        }
        
        ; Tire veya Pipe - rest/ölçü çizgisi
        if (ch = "-" || ch = "|") {
            symbol := ch
            restCount := 0
            while (pos <= len && SubStr(input, pos, 1) = symbol) {
                restCount++
                pos++
            }
            token := {}
            token.type := "rest"
            token.symbol := symbol
            token.count := restCount
            result.Push(token)
            continue
        }
        
        ; Tek karakter - ya modifier ya nota
        ; Modifier olabilecekler: 1 2 3 4 5 6 7 8 9 0 ! @ # $ % ^ & * ( )
        ; Nota olabilecekler: a-z A-Z
        ; Ama tek basina gelen rakam/sembol de modifier olarak calinir
        if RegExMatch(ch, "[a-zA-Z0-9!@#$%^&*()\-=+\[\]|;:',./\\]") {
            token := {}
            token.type := "single"
            token.key := ch
            result.Push(token)
            pos++
            continue
        }
        
        ; Bilinmeyen karakter - atla
        pos++
    }
    
    return result
}

; [ ] icindeki stringi parse eder
; Dondurur: {type:"chord", modifier:"6", notes:["f","j"]} gibi bir obje
ParseVPToken(inner) {
    token := {}
    token.type := "chord"
    token.modifier := ""
    token.notes := []
    
    ; Modifier karakterleri: 1-9, 0, !, @, #, $, %, ^, &, *, (, )
    ; Bunlar genellikle bastan gelir
    ; Ornek: "6fj" -> modifier="6", notes=["f","j"]
    ;         "$T" -> modifier="$", notes=["T"]
    ;         ":t'r" -> modifier="", notes=[":", "t", "'", "r"] (hepsi basiliyor)
    ;         "9T" -> modifier="9", notes=["T"]
    
    modifierChars := "0123456789!@#$%^&*()"
    pos := 1
    len := StrLen(inner)
    
    ; Tüm karakterleri nota olarak topla
    while (pos <= len) {
        c := SubStr(inner, pos, 1)
        token.notes.Push(c)
        pos++
    }
    
    ; Tek nota ise tipini guncelle
    if (token.notes.Length() = 1) {
        token.type := "single"
        token.key := token.notes[1]
    }
    
    return token
}

; ============================================================
; NOTA CALISTIRICI
; ============================================================

PlayVPToken(token) {
    if (token.type = "rest") {
        return
    }
    
    if (token.type = "single") {
        SendVPKey(token.key)
        return
    }
    
    if (token.type = "chord") {
        ; Tum notalari simule et (Blind ile modifierlari koru)
        for idx, note in token.notes {
            SendVPKey(note)
        }
        return
    }
}

; Fiziksel tus vurusunu simule eder
SendVPKey(key, state := "both") {
    if (key = "" || key = " ")
        return
        
    downStr := (state = "up") ? " up" : (state = "down") ? " down" : ""
    
    ; Shift Map for symbols
    static shiftMap := {"!":"1", "@":"2", "#":"3", "$":"4", "%":"5", "^":"6", "&":"7", "*":"8", "(":"9", ")":"0", "_":"-", "+":"=", "{":"[", "}":"]", ":":";", """":"'", "<":",", ">":".", "?":"/"}
    
    if (shiftMap.HasKey(key)) {
        baseKey := shiftMap[key]
        if (state = "both") {
            Send +%baseKey%
        } else {
            if (state = "down") {
                Send {Shift down}{%baseKey% down}
            } else {
                Send {%baseKey% up}{Shift up}
            }
        }
    } else if RegExMatch(key, "[A-Z]") {
        lower := Chr(Asc(key) + 32)
        if (state = "both") {
            Send +%lower%
        } else {
            if (state = "down") {
                Send {Shift down}{%lower% down}
            } else {
                Send {%lower% up}{Shift up}
            }
        }
    } else {
        ; Tüm sembolleri {} içine al
        if RegExMatch(key, "[\!\#\^\+\{\}\(\)\|\[\] ]") {
            Send {Blind}{%key%%downStr%}
        } else {
            Send {Blind}{%key%%downStr%}
        }
    }
}

ReleaseVPKeys() {
    for key, state in lastPressedKeys {
        if (state) {
            lower := (Asc(key) >= 65 && Asc(key) <= 90) ? Chr(Asc(key) + 32) : key
            if (Asc(key) >= 65 && Asc(key) <= 90) {
                Send { %lower% up}{Shift up}
            } else {
                Send {Blind}{%key% up}
            }
        }
    }
    lastPressedKeys := {}
}

; ============================================================
; GUI OLUSTURMA
; ============================================================
CreateGUI() {
    Gui, Font, s14 Bold c0x1E90FF
    Gui, Add, Text, x20 y15 w480 Center, VIRTUAL PIANO AUTO PLAYER
    
    Gui, Font, s11 Bold c0xFFFFFF
    Gui, Add, Text, x20 y70, CONTROL PANEL

    Gui, Font, s9 Normal c0xE0E0E0
    Gui, Add, Text, x30 y95, Tempo (BPM):
    Gui, Font, s9 Bold c0x000000
    Gui, Add, Edit, x30 y115 w80 h25 vBPM gBPMChange Number, 120
    Gui, Add, UpDown, vBPMUpDown Range50-1000, 120

    Gui, Font, s9 Normal c0x000000
    Gui, Add, Slider, x120 y115 w200 h25 Range50-1000 vBPMSlider gSliderChange ToolTip, 120

    Gui, Font, s8 Normal c0x000000
    Gui, Add, Button, x330 y110 w40 h15 gSetTempo60, 60
    Gui, Add, Button, x375 y110 w40 h15 gSetTempo120, 120
    Gui, Add, Button, x420 y110 w40 h15 gSetTempo180, 180
    Gui, Add, Button, x330 y130 w40 h15 gSetTempo240, 240
    Gui, Add, Button, x375 y130 w40 h15 gSetTempo500, 500
    Gui, Add, Button, x420 y130 w40 h15 gSetTempo1000, 1000

    Gui, Font, s9 Bold c0x000000
    Gui, Add, Button, x470 y95 w40 h45 gShowSettings, SET

    Gui, Font, s9 Normal c0xE0E0E0
    Gui, Add, Text, x30 y145 w80, Humanize:
    Gui, Font, s9 Normal c0xFFFFFF
    Gui, Add, Slider, x120 y140 w150 h25 vHumanizeSlider gHumanizeChange Range0-100 ToolTip +AltSubmit, %HumanizeLevel%
    Gui, Add, Text, x280 y145 w40 vHumanizeText, % HumanizeLevel "%"

    Gui, Font, s11 Bold c0xFFFFFF
    Gui, Add, Text, x20 y180, SHEET MUSIC

    Gui, Font, s9 Normal c0xE0E0E0
    Gui, Add, Text, x30 y205, Quick Load:
    Gui, Font, s9 Normal c0x000000
    Gui, Add, DropDownList, x100 y202 w200 h200 vSampleSongs gLoadSample, Select Song

    Gui, Font, s9 Bold c0x00FF00
    Gui, Add, Checkbox, x310 y205 w60 h20 vLoopCheckbox gToggleLoop, LOOP

    Gui, Font, s8 Normal c0xFFD700
    Gui, Add, Text, x375 y207 w90 h15, (Off - Single Play)

    UpdateSongsDropdown()

    Gui, Font, s9 Normal c0x000000
    Gui, Add, Edit, x30 y230 w430 h120 vUserInput VScroll +Wrap Background0xFFFFFF c0x000000,

    Gui, Font, s10 Bold c0x000000
    Gui, Add, Button, x30 y365 w80 h35 gPlayPause +Default, PLAY
    Gui, Add, Button, x120 y365 w80 h35 gStopReset, STOP
    Gui, Add, Button, x210 y365 w80 h35 gLoadFromFile, LOAD FILE
    Gui, Add, Button, x300 y365 w80 h35 gSaveToFile, SAVE FILE
    Gui, Add, Button, x390 y365 w80 h35 gShowHelp, HELP

    Gui, Add, Button, x30 y405 w120 h25 gToggleRecordMode, ANTI OBS: OFF

    Gui, Font, s8 Normal c0xFF4500
    Gui, Add, Text, x160 y410 w280 h15 vRecordingStatusOFF, Anti OBS: OFF
    Gui, Font, s8 Normal c0x00FF00
    Gui, Add, Text, x160 y410 w280 h15 vRecordingStatusON Hidden, Anti OBS: ON

    Gui, Font, s9 Normal c0x90EE90
    Gui, Add, Text, x30 y450 w430 h20 vStatus Center, Ready
    
    Gui, Color, 0x2C2C2C
    
    Gui, +AlwaysOnTop +MinimizeBox -MaximizeBox +LastFound
    Gui, Show, w520 h490, Virtual Piano Auto Player
    WinGet, hWnd, ID, Virtual Piano Auto Player

    GuiControl, Focus, UserInput
    UpdateStatus("Ready!", 0)
}

; ============================================================
; PLAYBACK SISTEMI - VP FORMAT
; ============================================================

StartPlayback() {
    Gui, Submit, NoHide

    rawInput := UserInput
    rawInput := Trim(rawInput)

    if (rawInput = "") {
        UpdateStatus("Sheet music is empty!", 3000)
        return
    }

    BPM := BPM ? BPM : 120
    ParsedNoteArray := ParseVPSheet(rawInput)
    totalNotes := ParsedNoteArray.Length()
    
    ; Setup QPC for timing
    DllCall("QueryPerformanceFrequency", "Int64*", QPC_Freq)
    
    ; Build Event Queue (Beats)
    BuildPlaybackQueue()
    
    currentPosition := 0
    isPlaying := true
    isPaused := false
    QueuePosition := 1
    CurrentBeat := 0
    playbackStartTime := A_TickCount
    DllCall("QueryPerformanceCounter", "Int64*", LastTickQPC)
    PlaybackStartTimeQPC := LastTickQPC ; Keep for progress calculation if needed

    GuiControl,, PlayPause, PAUSE
    UpdateProgressBar(0)
    UpdateStatus("Playing...", 0)

    SetTimer, PlaybackTick, 1
}

BuildPlaybackQueue() {
    PlaybackQueue := []
    currentBeatPos := 0
    
    ; Units in Beats (1.0 = one full beat at BPM)
    UnitBeats := 0.50
    SpaceBeats := 0.30
    DashBeats := 0.50
    BarBeats := 1.00
    
    HoldMultiplier := NoteDurationMultiplier
    
    for idx, token in ParsedNoteArray {
        if (token.type = "rest") {
            extra := (token.symbol = "|") ? BarBeats : DashBeats
            currentBeatPos += extra * token.count
            continue
        }
        
        if (token.type = "space") {
            currentBeatPos += SpaceBeats
            continue
        }

        ; Humanization: Add random jitter to the onset
        jitter := 0
        if (HumanizeLevel > 0) {
            ; Max jitter of 0.15 beats at 100% humanize
            jitterRange := (HumanizeLevel / 100) * 0.15
            Random, jitter, -%jitterRange%, %jitterRange%
        }

        ; Nota veya Akor
        holdBeats := UnitBeats * HoldMultiplier
        
        eventDown := {beat: currentBeatPos + jitter, type: "down", token: token, pos: idx}
        eventUp := {beat: currentBeatPos + jitter + holdBeats, type: "up", token: token}
        
        PlaybackQueue.Push(eventDown)
        PlaybackQueue.Push(eventUp)
        
        currentBeatPos += UnitBeats
    }
}

PlaybackTick() {
    if (!isPlaying || isPaused)
        return

    DllCall("QueryPerformanceCounter", "Int64*", now)
    
    ; Calculate Delta Time and advance CurrentBeat
    dtSeconds := (now - LastTickQPC) / QPC_Freq
    CurrentBeat += dtSeconds * (BPM / 60)
    LastTickQPC := now

    while (QueuePosition <= PlaybackQueue.Length() && PlaybackQueue[QueuePosition].beat <= CurrentBeat) {
        event := PlaybackQueue[QueuePosition]
        
        if (event.type = "down") {
            if (event.token.type = "single") {
                SendVPKey(event.token.key, "down")
                lastPressedKeys[event.token.key] := true
            } else if (event.token.type = "chord") {
                for i, note in event.token.notes {
                    SendVPKey(note, "down")
                    lastPressedKeys[note] := true
                    
                    ; Add a tiny random span between notes in a chord (0-15ms)
                    if (HumanizeLevel > 0) {
                        Random, span, 0, % (HumanizeLevel / 100) * 15
                        if (span > 0)
                            DllCall("Sleep", "UInt", span)
                    }
                }
            }
            
            ; Progress update
            currentPosition := event.pos
            if (Mod(currentPosition, 5) = 0) {
                progress := Round((currentPosition / totalNotes) * 100)
                UpdateProgressBar(progress)
            }
        } else {
            if (event.token.type = "single") {
                SendVPKey(event.token.key, "up")
                lastPressedKeys[event.token.key] := false
            } else if (event.token.type = "chord") {
                for i, note in event.token.notes {
                    SendVPKey(note, "up")
                    lastPressedKeys[note] := false
                }
            }
        }
        
        QueuePosition++
    }

    if (QueuePosition > PlaybackQueue.Length()) {
        if (isLoopEnabled) {
            QueuePosition := 1
            CurrentBeat := 0
            UpdateStatus("Loop - Restarting...", 1000)
        } else {
            CompletePlayback()
        }
    }
}

PausePlayback() {
    isPaused := true
    isPlaying := false
    GuiControl,, PlayPause, RESUME
    UpdateStatus("Paused", 0)
    SetTimer, PlaybackTick, Off
    DllCall("QueryPerformanceCounter", "Int64*", PauseTimeQPC)
    ReleaseVPKeys()
}

ResumePlayback() {
    isPaused := false
    isPlaying := true
    GuiControl,, PlayPause, PAUSE
    UpdateStatus("Resuming...", 0)
    
    ; Reset LastTick so we don't jump forward after pause
    DllCall("QueryPerformanceCounter", "Int64*", LastTickQPC)
    SetTimer, PlaybackTick, 1
}

StopPlayback() {
    isPlaying := false
    isPaused := false
    SetTimer, PlaybackTick, Off
    ReleaseVPKeys()
    currentPosition := 0
    QueuePosition := 0
    GuiControl,, PlayPause, PLAY
    UpdateProgressBar(0)
    UpdateStatus("Stopped.", 0)
}

CompletePlayback() {
    ReleaseVPKeys()
    isPlaying := false
    isPaused := false
    currentPosition := 0
    QueuePosition := 0
    SetTimer, PlaybackTick, Off
    GuiControl,, PlayPause, PLAY
    UpdateProgressBar(100)
    playbackTime := Round((A_TickCount - playbackStartTime) / 1000, 1)
    UpdateStatus("Completed!", 0)
    SetTimer, ResetProgress, 3000
}

ResetProgress:
SetTimer, ResetProgress, Off
UpdateProgressBar(0)
return

; Legacy PlaybackTimer silindi

; ============================================================
; SETTINGS GUI
; ============================================================
ShowSettings:
CreateSettingsGUI()
return

CreateSettingsGUI() {
    Gui, Settings:New, +AlwaysOnTop +ToolWindow +LabelSettingsGui, Control Binding Settings
    Gui, Settings:Color, 0x2C2C2C

    Gui, Settings:Font, s12 Bold c0x1E90FF
    Gui, Settings:Add, Text, x20 y15 w300 Center, CONTROL BINDING SETTINGS

    Gui, Settings:Font, s10 Bold c0x00FF00
    Gui, Settings:Add, Text, x20 y50, PLAY/PAUSE CONTROL

    Gui, Settings:Font, s9 Normal c0xE0E0E0
    Gui, Settings:Add, Text, x20 y75, Current Binding:
    Gui, Settings:Add, Edit, x20 y95 w180 h23 ReadOnly vPlayPauseKeySetting, %PlayPauseKey%
    Gui, Settings:Add, Button, x210 y94 w80 h25 gWaitForPlayPauseKey, SET KEY

    Gui, Settings:Font, s10 Bold c0x00FF00
    Gui, Settings:Add, Text, x20 y130, STOP/RESET CONTROL

    Gui, Settings:Font, s9 Normal c0xE0E0E0
    Gui, Settings:Add, Text, x20 y155, Current Binding:
    Gui, Settings:Add, Edit, x20 y175 w180 h23 ReadOnly vStopKeySetting, %StopKey%
    Gui, Settings:Add, Button, x210 y174 w80 h25 gWaitForStopKey, SET KEY

    Gui, Settings:Font, s8 Normal c0xFFD700
    Gui, Settings:Add, Text, x20 y210, Press any key: F1-F12, A-Z, Mouse4/5 supported

    Gui, Settings:Font, s9 Bold c0x000000
    Gui, Settings:Add, Button, x20 y250 w80 h30 gSaveSettings, SAVE
    Gui, Settings:Add, Button, x110 y250 w80 h30 gCancelSettings, CANCEL
    Gui, Settings:Add, Button, x200 y250 w80 h30 gResetSettings, RESET

    Gui, Settings:Show, w320 h300
}

WaitForPlayPauseKey:
if (!isWaitingForKey) {
    isWaitingForKey := true
    waitingForKeyType := "PlayPause"
    GuiControl, Settings:, WaitForPlayPauseKey, PRESS KEY
    SetTimer, KeyWaitTimeout, 10000
}
return

WaitForStopKey:
if (!isWaitingForKey) {
    isWaitingForKey := true
    waitingForKeyType := "Stop"
    GuiControl, Settings:, WaitForStopKey, PRESS KEY
    SetTimer, KeyWaitTimeout, 10000
}
return

KeyWaitTimeout:
SetTimer, KeyWaitTimeout, Off
if (isWaitingForKey) {
    isWaitingForKey := false
    if (waitingForKeyType = "PlayPause")
        GuiControl, Settings:, WaitForPlayPauseKey, SET KEY
    else if (waitingForKeyType = "Stop")
        GuiControl, Settings:, WaitForStopKey, SET KEY
    waitingForKeyType := ""
}
return

~*a::
~*b::
~*c::
~*d::
~*e::
~*f::
~*g::
~*h::
~*i::
~*j::
~*k::
~*l::
~*m::
~*n::
~*o::
~*p::
~*q::
~*r::
~*s::
~*t::
~*u::
~*v::
~*w::
~*x::
~*y::
~*z::
~*1::
~*2::
~*3::
~*4::
~*5::
~*6::
~*7::
~*8::
~*9::
~*0::
~*F1::
~*F2::
~*F3::
~*F4::
~*F5::
~*F6::
~*F7::
~*F8::
~*F9::
~*F10::
~*F11::
~*F12::
~*Space::
~*Tab::
~*Enter::
~*Escape::
~*Backspace::
~*Delete::
~*Insert::
~*Home::
~*End::
~*PgUp::
~*PgDn::
~*Up::
~*Down::
~*Left::
~*Right::
~*XButton1::
~*XButton2::
~*MButton::
if (isWaitingForKey) {
    SetTimer, KeyWaitTimeout, Off
    pressedKey := A_ThisHotkey
    pressedKey := RegExReplace(pressedKey, "~\*", "")

    if (pressedKey = "XButton1")
        pressedKey := "Mouse4"
    else if (pressedKey = "XButton2")
        pressedKey := "Mouse5"
    else if (pressedKey = "MButton")
        pressedKey := "MiddleClick"
    else if (pressedKey = "LButton" || pressedKey = "RButton") {
        UpdateStatus("LMB/RMB cannot be assigned!", 2000)
        isWaitingForKey := false
        waitingForKeyType := ""
        return
    }

    modifiers := ""
    if (pressedKey != "Mouse4" && pressedKey != "Mouse5" && pressedKey != "MiddleClick") {
        if GetKeyState("Ctrl", "P")
            modifiers .= "Ctrl+"
        if GetKeyState("Alt", "P")
            modifiers .= "Alt+"
        if GetKeyState("Shift", "P")
            modifiers .= "Shift+"
    }

    finalKey := modifiers . pressedKey

    if (waitingForKeyType = "PlayPause") {
        PlayPauseKey := finalKey
        GuiControl, Settings:, PlayPauseKeySetting, %finalKey%
        GuiControl, Settings:, WaitForPlayPauseKey, SET KEY
    } else if (waitingForKeyType = "Stop") {
        StopKey := finalKey
        GuiControl, Settings:, StopKeySetting, %finalKey%
        GuiControl, Settings:, WaitForStopKey, SET KEY
    }

    isWaitingForKey := false
    waitingForKeyType := ""
}
return

SaveSettings:
Gui, Settings:Submit
SaveSettingsToFile()
ResetAllHotkeys()
SetupAllHotkeys()
UpdateStatus("Keys updated!", 2000)
return

CancelSettings:
Gui, Settings:Destroy
return

ResetSettings:
PlayPauseKey := "F1"
StopKey := "F2"
SaveSettingsToFile()
ResetAllHotkeys()
SetupAllHotkeys()
Gui, Settings:Destroy
UpdateStatus("Keys reset!", 2000)
return

ToggleLoop:
Gui, Submit, NoHide
isLoopEnabled := LoopCheckbox
if (isLoopEnabled) {
    GuiControl,, Text9, (On - Continuous Loop)
    UpdateStatus("Loop ON - Song will repeat", 2000)
} else {
    GuiControl,, Text9, (Off - Single Play)
    UpdateStatus("Loop OFF - Single play", 2000)
}
SaveSettings()
return

; ============================================================
; HOTKEY SISTEMI
; ============================================================
ResetAllHotkeys() {
    for hotkeyName, isActive in ActiveHotkeys {
        if (isActive)
            Hotkey, %hotkeyName%, Off, UseErrorLevel
    }
    ActiveHotkeys := {}
    ClearAllHotkeys()
    Sleep, 50
}

SetupAllHotkeys() {
    ClearAllHotkeys()
    Sleep, 50
    if (PlayPauseKey != "")
        SetupSingleHotkey(PlayPauseKey, "PlayPauseAction")
    if (StopKey != "" && StopKey != PlayPauseKey)
        SetupSingleHotkey(StopKey, "StopAction")
    SetupSingleHotkey("~F3", "ResetPlayerHotkey")
    SetupSingleHotkey("~F12", "ToggleRecordMode")
    SetupSingleHotkey("~Esc", "EmergencyStop")
    SetupSingleHotkey("~PgUp", "BPMUp")
    SetupSingleHotkey("~PgDn", "BPMDown")
}

SetupSingleHotkey(keyName, labelName) {
    if (ActiveHotkeys.HasKey(keyName) && ActiveHotkeys[keyName]) {
        Hotkey, %keyName%, Off, UseErrorLevel
        ActiveHotkeys[keyName] := false
    }
    ahkKeyName := keyName
    if (keyName = "Mouse4")
        ahkKeyName := "XButton1"
    else if (keyName = "Mouse5")
        ahkKeyName := "XButton2"
    else if (keyName = "MiddleClick")
        ahkKeyName := "MButton"
    Hotkey, %ahkKeyName%, %labelName%, On UseErrorLevel
    if (ErrorLevel = 0) {
        ActiveHotkeys[keyName] := true
    } else {
        if (InStr(ahkKeyName, "~")) {
            altKeyName := RegExReplace(ahkKeyName, "^~", "")
            Hotkey, %altKeyName%, %labelName%, On UseErrorLevel
            if (ErrorLevel = 0)
                ActiveHotkeys[keyName] := true
        }
    }
}

ClearAllHotkeys() {
    Loop, 26 {
        letter := Chr(96 + A_Index)
        Hotkey, ~%letter%, Off, UseErrorLevel
        Hotkey, %letter%, Off, UseErrorLevel
        Hotkey, ~Ctrl+%letter%, Off, UseErrorLevel
        Hotkey, ~Alt+%letter%, Off, UseErrorLevel
        Hotkey, Ctrl+%letter%, Off, UseErrorLevel
        Hotkey, Alt+%letter%, Off, UseErrorLevel
    }
    Loop, 12 {
        fkey := "F" . A_Index
        Hotkey, %fkey%, Off, UseErrorLevel
        Hotkey, ~%fkey%, Off, UseErrorLevel
        Hotkey, Ctrl+%fkey%, Off, UseErrorLevel
        Hotkey, Alt+%fkey%, Off, UseErrorLevel
    }
    Loop, 10 {
        num := A_Index - 1
        Hotkey, ~%num%, Off, UseErrorLevel
        Hotkey, %num%, Off, UseErrorLevel
    }
    Hotkey, XButton1, Off, UseErrorLevel
    Hotkey, ~XButton1, Off, UseErrorLevel
    Hotkey, XButton2, Off, UseErrorLevel
    Hotkey, ~XButton2, Off, UseErrorLevel
    Hotkey, MButton, Off, UseErrorLevel
    Hotkey, ~MButton, Off, UseErrorLevel
    Hotkey, ~Space, Off, UseErrorLevel
    Hotkey, ~Tab, Off, UseErrorLevel
    Hotkey, ~Enter, Off, UseErrorLevel
    Hotkey, ~Esc, Off, UseErrorLevel
    Hotkey, ~PgUp, Off, UseErrorLevel
    Hotkey, ~PgDn, Off, UseErrorLevel
}

PlayPauseAction:
if (isPlaying && !isPaused)
    PausePlayback()
else if (isPaused)
    ResumePlayback()
else
    StartPlayback()
return

StopAction:
StopPlayback()
return



; ============================================================
; AYARLAR KAYIT/YUKLE
; ============================================================
SaveSettingsToFile() {
    IniWrite, %PlayPauseKey%, %ConfigFile%, KeyBindings, PlayPauseKey
    IniWrite, %StopKey%, %ConfigFile%, KeyBindings, StopKey
    IniWrite, %isLoopEnabled%, %ConfigFile%, Settings, LoopEnabled
}

SaveSettings() {
    Gui, Submit, NoHide
    IniWrite, %PlayPauseKey%, %ConfigFile%, KeyBindings, PlayPauseKey
    IniWrite, %StopKey%, %ConfigFile%, KeyBindings, StopKey
    IniWrite, %isLoopEnabled%, %ConfigFile%, Settings, LoopEnabled
    IniWrite, %HumanizeLevel%, %ConfigFile%, Settings, HumanizeLevel
    IniWrite, %HoldLevel%, %ConfigFile%, Settings, HoldLevel
}

LoadSettings() {
    IniRead, PlayPauseKey, %ConfigFile%, KeyBindings, PlayPauseKey, F1
    IniRead, StopKey, %ConfigFile%, KeyBindings, StopKey, F2
    IniRead, isLoopEnabled, %ConfigFile%, Settings, LoopEnabled, 0
    IniRead, HumanizeLevel, %ConfigFile%, Settings, HumanizeLevel, 30
    IniRead, HoldLevel, %ConfigFile%, Settings, HoldLevel, 80
    
    if (isLoopEnabled = "ERROR")
        isLoopEnabled := false
    else
        isLoopEnabled := isLoopEnabled ? true : false
        
    if (HumanizeLevel = "ERROR")
        HumanizeLevel := 30
    if (HoldLevel = "ERROR")
        HoldLevel := 80
        
    GuiControl,, HumanizeSlider, %HumanizeLevel%
    GuiControl,, HumanizeText, % HumanizeLevel "%"
}

; ============================================================
; DOSYA ISLEMLERI
; ============================================================
LoadSavedPaths() {
    SavedSongPaths := {}
    if FileExist(PathsFile) {
        FileRead, FileContent, %PathsFile%
        if (ErrorLevel = 0 && FileContent != "") {
            FileContent := RegExReplace(FileContent, "`r`n", "`n")
            FileContent := RegExReplace(FileContent, "`r", "`n")
            Loop, Parse, FileContent, `n
            {
                CurrentLine := Trim(A_LoopField)
                if (CurrentLine != "") {
                    SeparatorPos := InStr(CurrentLine, "|||")
                    if (SeparatorPos > 0) {
                        SongName := Trim(SubStr(CurrentLine, 1, SeparatorPos - 1))
                        FilePath := Trim(SubStr(CurrentLine, SeparatorPos + 3))
                        
                        ; Check if path is relative or if absolute path doesn't exist
                        if (FilePath != "" && !InStr(FilePath, ":")) {
                            FilePath := A_ScriptDir . "\" . FilePath
                        }
                        
                        if (SongName != "" && FilePath != "" && FileExist(FilePath))
                            SavedSongPaths[SongName] := FilePath
                    }
                }
            }
        }
    }
}

SavePathsToFile() {
    FileDelete, %PathsFile%
    FileContent := ""
    for songName, filePath in SavedSongPaths {
        if FileExist(filePath) {
            ; If file is in the script directory, save as relative path
            savePath := filePath
            if (InStr(filePath, A_ScriptDir) = 1) {
                savePath := SubStr(filePath, StrLen(A_ScriptDir) + 2)
            }
            FileContent .= songName . "|||" . savePath . "`r`n"
        }
    }
    if (FileContent != "")
        FileAppend, %FileContent%, %PathsFile%
}

UpdateSongsDropdown() {
    songList := "Select Song"
    for songName, filePath in SavedSongPaths {
        if FileExist(filePath)
            songList .= "|" . songName
    }
    GuiControl,, SampleSongs, |
    GuiControl,, SampleSongs, %songList%
    GuiControl, Choose, SampleSongs, 1
}

LoadSample:
Gui, Submit, NoHide
if (SampleSongs != "Select Song" && SampleSongs != "") {
    if (SavedSongPaths.HasKey(SampleSongs)) {
        filePath := SavedSongPaths[SampleSongs]
        if FileExist(filePath) {
            FileRead, FileContent, %filePath%
            if (ErrorLevel = 0) {
                GuiControl,, UserInput, %FileContent%
                UpdateStatus("Loaded: " . SampleSongs, 2000)
            }
        } else {
            SavedSongPaths.Delete(SampleSongs)
            SavePathsToFile()
            UpdateSongsDropdown()
            UpdateStatus("File not found, removed from list: " . SampleSongs, 3000)
        }
    }
}
GuiControl, Choose, SampleSongs, 1
return

LoadFromFile:
FileSelectFile, SelectedFile, 3,, Sheet Music Sec, Text Files (*.txt)
if (SelectedFile != "") {
    FileRead, FileContent, %SelectedFile%
    if (ErrorLevel = 0) {
        GuiControl,, UserInput, %FileContent%
        SplitPath, SelectedFile, FileName, , , NameNoExt
        SavedSongPaths[NameNoExt] := SelectedFile
        SavePathsToFile()
        UpdateSongsDropdown()
        UpdateStatus("Loaded: " . NameNoExt, 3000)
    }
}
return

SaveToFile:
Gui, Submit, NoHide
if (UserInput = "") {
    UpdateStatus("No content to save!", 2000)
    return
}
FileSelectFile, SelectedFile, S16,, Sheet Music Kaydet, Text Files (*.txt)
if (SelectedFile != "") {
    if !RegExMatch(SelectedFile, "\.txt$")
        SelectedFile .= ".txt"
    FileAppend, %UserInput%, %SelectedFile%
    if (ErrorLevel = 0) {
        SplitPath, SelectedFile, FileName, , , NameNoExt
        SavedSongPaths[NameNoExt] := SelectedFile
        SavePathsToFile()
        UpdateSongsDropdown()
        UpdateStatus("Saved: " . NameNoExt, 3000)
    }
}
return

; ============================================================
; BPM KONTROLLERI
; ============================================================
BPMChange:
Gui, Submit, NoHide
if (BPM < 50) {
    GuiControl,, BPM, 50
    BPM := 50
} else if (BPM > 1000) {
    GuiControl,, BPM, 1000
    BPM := 1000
}
GuiControl,, BPMSlider, %BPM%
UpdateStatus("BPM: " . BPM, 0)
return

BPMUpDown:
Gui, Submit, NoHide
GuiControl,, BPMSlider, %BPM%
return

SliderChange:
    Gui, Submit, NoHide
    GuiControl,, BPM, %BPMSlider%
    BPM := BPMSlider
    return

HumanizeChange:
    Gui, Submit, NoHide
    HumanizeLevel := HumanizeSlider
    GuiControl,, HumanizeText, % HumanizeLevel "%"
    return

DurationChange:
    return

SetTempo60:
SetTempo(60)
return
SetTempo120:
SetTempo(120)
return
SetTempo180:
SetTempo(180)
return
SetTempo240:
SetTempo(240)
return
SetTempo500:
SetTempo(500)
return
SetTempo1000:
SetTempo(1000)
return

SetTempo(newBPM) {
    GuiControl,, BPM, %newBPM%
    GuiControl,, BPMSlider, %newBPM%
    BPM := newBPM
    UpdateStatus("BPM: " . newBPM, 0)
}

; ============================================================
; KAYIT MODU
; ============================================================
ToggleRecordMode:
if (!hWnd)
    WinGet, hWnd, ID, Virtual Piano Auto Player
if (isRecordModeOn) {
    DllCall("user32.dll\SetWindowDisplayAffinity", "ptr", hWnd, "uint", 0x00)
    GuiControl,, ToggleRecordMode, ANTI OBS: OFF
    GuiControl, Show, RecordingStatusOFF
    GuiControl, Hide, RecordingStatusON
    isRecordModeOn := false
} else {
    DllCall("user32.dll\SetWindowDisplayAffinity", "ptr", hWnd, "uint", 0x11)
    GuiControl,, ToggleRecordMode, ANTI OBS: ON
    GuiControl, Hide, RecordingStatusOFF
    GuiControl, Show, RecordingStatusON
    isRecordModeOn := true
}
return

; ============================================================
; YARDIM
; ============================================================
ShowHelp:
helpText := "VIRTUAL PIANO AUTO PLAYER - VP SHEET FORMAT`n`n"
helpText .= "SUPPORTED FORMAT:`n"
helpText .= "* [6f]      -> 6 modifier held + f key`n"
helpText .= "* [9T]      -> 9 modifier held + Shift+T (upper = shift)`n"
helpText .= "* [6fj]     -> 6 held + f and j simultaneously`n"
helpText .= "* [*h]      -> * modifier + h`n"
helpText .= "* [$T]      -> $ modifier + Shift+T`n"
helpText .= "* [:t'r]    -> special character chords`n"
helpText .= "* 8         -> only the 8 key`n"
helpText .= "* -         -> short rest (1 unit)`n"
helpText .= "* ----      -> long rest (4 units)`n`n"
helpText .= "Paste virtualpiano.net sheet format directly!"
MsgBox, 4096, Virtual Piano Help, %helpText%
return

; ============================================================
; GENEL YARDIMCI FONKSIYONLAR
; ============================================================
ResetPlayer() {
    StopPlayback()
    lastPressedKeys := {}
    ParsedNoteArray := []
    UpdateStatus("Reset.", 0)
}

PlayPause:
if (isPlaying && !isPaused)
    PausePlayback()
else if (isPaused)
    ResumePlayback()
else
    StartPlayback()
return

StopReset:
StopPlayback()
return

ResetPlayerHotkey:
ResetPlayer()
return

EmergencyStop:
if (isPlaying || isPaused) {
    StopPlayback()
    UpdateStatus("EMERGENCY STOP!", 3000)
}
return

BPMUp:
newBPM := BPM + 10
if (newBPM > 1000)
    newBPM := 1000
SetTempo(newBPM)
return

BPMDown:
newBPM := BPM - 10
if (newBPM < 50)
    newBPM := 50
SetTempo(newBPM)
return

IsUpperCase(char) {
    return (Asc(char) >= 65 && Asc(char) <= 90)
}

UpdateStatus(message, autoHide := 0) {
    GuiControl,, Status, %message%
    if (autoHide > 0)
        SetTimer, ClearStatus, %autoHide%
}

ClearStatus:
SetTimer, ClearStatus, Off
UpdateStatus("Ready", 0)
return

UpdateProgressBar(percentage) {
    GuiControl,, ProgressBar, %percentage%
}

GuiClose:
SaveSettings()
ExitApp

SettingsGuiClose:
Gui, Settings:Destroy
return

CleanUp(ExitReason, ExitCode) {
    DllCall("winmm\timeEndPeriod", "uint", 1)
}

