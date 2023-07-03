#SingleInstance force
#Include VMR.ahk
#include Spotify.ahk

If Not A_IsAdmin
{
    Run *RunAs "%A_AhkPath%" "%A_ScriptFullPath%"
    ExitApp
}

#MaxThreadsPerHotkey 1

SetWorkingDir %A_ScriptDir%

vmr := new VMR()
vmr.login()

; Get OutputMode value
OutputMode := vmr.GetOutputMode()

; Get OutputStrip8A3 value
OutputStrip8A3 := vmr.GetOutputStrip8A3()

; Increase gain
$Volume_Up::
    Strip6Gain := vmr.strip[6].Gain
    Strip7Gain := vmr.strip[7].Gain
    Strip8Gain := vmr.strip[8].Gain

    if (Strip6Gain < 12)
        Strip6Gain += 0.5
    if (Strip7Gain < 12)
        Strip7Gain += 0.5
    if (Strip8Gain < 12)
        Strip8Gain += 0.5

    vmr.strip[6].Gain := Strip6Gain
    vmr.strip[7].Gain := Strip7Gain
    vmr.strip[8].Gain := Strip8Gain

    Sleep 50
return

; Decrease gain
$Volume_Down::
    Strip6Gain := vmr.strip[6].Gain
    Strip7Gain := vmr.strip[7].Gain
    Strip8Gain := vmr.strip[8].Gain

    if (Strip6Gain > -60)
        Strip6Gain -= 0.5
    if (Strip7Gain > -60)
        Strip7Gain -= 0.5
    if (Strip8Gain > -60)
        Strip8Gain -= 0.5

    vmr.strip[6].Gain := Strip6Gain
    vmr.strip[7].Gain := Strip7Gain
    vmr.strip[8].Gain := Strip8Gain

    Sleep 50
return

F24::
    OutputMode := 3 - OutputMode  ; Toggle between 1 and 2

    if (OutputMode = 2) {
        vmr.strip[6].A1 := 0
        vmr.strip[6].A2 := 1
        vmr.strip[7].A1 := 0
        vmr.strip[7].A2 := 1
        vmr.strip[8].A1 := 0
        vmr.strip[8].A2 := 1
    } else {
        vmr.strip[6].A1 := 1
        vmr.strip[6].A2 := 0
        vmr.strip[7].A1 := 1
        vmr.strip[7].A2 := 0
        vmr.strip[8].A1 := 1
        vmr.strip[8].A2 := 0
    }

; Toggle output for strip[8].A3 if F23 key is pressed
F23::
    OutputStrip8A3 := !OutputStrip8A3

    if (OutputStrip8A3) {
        vmr.strip[8].A3 := 1
    } else {
        vmr.strip[8].A3 := 0
    }

    Sleep 100
return

; F18 + Media next key for track forward
F18 & Media_Next::
    Spotify.SeekForward()
    Spotify.SeekForward()
return

; F18 + Media prev key for track backward
F18 & Media_Prev::
    Spotify.SeekBackward()
    Spotify.SeekBackward()
return

; Run Splaylist.exe
RunSplaylist(Arguments := "")
{
    Run, %A_ScriptDir%\Splaylist.exe %Arguments%
}

; Media stop key
Media_Stop::
    RunSplaylist()
return

; F18 + Media stop key
F18 & Media_Stop::
    RunSplaylist("-a")
return

; F17 + Media stop key
F17 & Media_Stop::
    RunSplaylist("-r")
return

F18 & Media_Play_Pause::
    RunSplaylist("-l")
return

F17 & Media_Play_Pause::
    RunSplaylist("-dl")
return

; Show hotkey popup when F18 + "?" are pressed
F18 & ?::
    HotkeyText =
    (
    HotkeF18 + Volume Up: Increase gain for all three sliders
    Volume Down: Decrease gain for all 3 sliders
    F24: Toggle output between speakers and headphones
    F23: Toggle output for TV
    F18 + Media Next: Seek forward in Spotify by 10s
    F18 + Media Prev: Seek backward in Spotify by 10s
    Media Stop: Display Spotify Song info
    F18 + Media Stop: Add song to current playlist
    F17 + Media Stop: Remove song from current playlist
    F18 + Media Play/Pause: Like Current song
    F17 + Media Play/Pause: Unlike Current song
    )

    MsgBox, %HotkeyText%
return
