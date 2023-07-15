OSD(text, number)
{
    ; Customize the OSD appearance and position
    Gui +AlwaysOnTop +ToolWindow +E0x20 -Caption -SysMenu -Owner
    Gui, Color, 000000
    Gui, Font, s16, Fixedsys
    Gui, Add, Text, x10 y10 h40 c888800, %text%
    Gui, Show, NoActivate x10 y10 h35, OSD

    SetTimer, RemoveToolTip, %number%
    return

    RemoveToolTip:
    SetTimer, RemoveToolTip, Off
    Gui, Destroy
    return
}

GainOsd(Strip6Gain, Strip7Gain, Strip8Gain)
{
	debounceDelay := 100  ; Debounce delay in milliseconds
	
	; Clear previous OSD timers
	SetTimer, DisplayOsdTimer, Off
	SetTimer, RemoveToolTip, Off
	
	; Set a timer to display the OSD after the debounce period has passed
	SetTimer, DisplayOsdTimer, %debounceDelay%
	return
	
	DisplayOsdTimer:
	SetTimer, DisplayOsdTimer, Off
	sleep, 75
	Strip6Gain := vmr.strip[6].Gain
	Strip7Gain := vmr.strip[7].Gain
	Strip8Gain := vmr.strip[8].Gain
	RoundDecimal := 1  ; Rounded to the nearest hundredth decimal place
	FormattedStrip6Gain := Format("{:+.0f}", Round(Strip6Gain, RoundDecimal))
	FormattedStrip7Gain := Format("{:+.0f}", Round(Strip7Gain, RoundDecimal))
	FormattedStrip8Gain := Format("{:+.0f}", Round(Strip8Gain, RoundDecimal))
	
	OSDText := "Gain: " . FormattedStrip6Gain . " | " . FormattedStrip7Gain . " | " . FormattedStrip8Gain
	OSD(OSDText, 500)
	return
}

ReadTrackFromFile()
{
    FileRead, TrackText, track.txt
    return TrackText
}

WaitForFileChange(file, timeout)
{
    startTime := A_TickCount
    previousContents := ReadFileContents(file)
    while (true) {
        currentContents := ReadFileContents(file)
        if (currentContents <> previousContents) {
            return
        }
        if (A_TickCount - startTime >= timeout) {
            return
        }
        Sleep 50  ; Adjust the sleep duration as needed
    }
}

ReadFileContents(file)
{
    FileRead, contents, %file%
    return contents
}

#SingleInstance force
#Include VMR.ahk
#include Spotify.ahk

spoofy := new Spotify

If Not A_IsAdmin
{
    Run *RunAs "%A_AhkPath%" "%A_ScriptFullPath%"
    ExitApp
}

#MaxThreadsPerHotkey 1

SetWorkingDir %A_ScriptDir%

vmr := new VMR()
vmr.login()

OutputMode := 1  ; 1 for A1, 2 for A2

; Get OutputStrip8A3 value
OutputStrip8A3 := vmr.GetOutputStrip8A4()

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

Sleep 25
GainOsd(Strip6Gain, Strip7Gain, Strip8Gain)
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

Sleep 25
GainOsd(Strip6Gain, Strip7Gain, Strip8Gain)
return

; Toggle output mode if F24 key is pressed
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

    Sleep 100
return

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
	CurrentPlayback := spoofy.Player.GetCurrentPlaybackInfo().progress_ms
	CurrentPlayback += 10000
	spoofy.Player.SeekTime(CurrentPlayback)
return

; F18 + Media prev key for track backward
F18 & Media_Prev::
	CurrentPlayback := spoofy.Player.GetCurrentPlaybackInfo().progress_ms
	CurrentPlayback -= 10000
	spoofy.Player.SeekTime(CurrentPlayback)
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

$Media_Next::
    spoofy.Player.NextTrack()
    Sleep 500
    RunSplaylist("-s")
    WaitForFileChange("track.txt", 7000)  ; Wait for file change with a timeout of 5000 milliseconds (5 seconds)
    OutputText := ReadFileContents("track.txt")
    if (OutputText = "")
    {
        OSD("No track is currently playing.", 2000)
    }
    else
    {
        OSD(OutputText, 2000)
    }
return

$Media_Prev::
    global pressCount  ; Declare pressCount as a global variable to remember its value across function calls

    if (pressCount >= 2)  ; Check if the button is pressed once or more
    {
		spoofy.Player.LastTrack()
        Sleep 199
        RunSplaylist("-s")
        WaitForFileChange("track.txt", 7000)  ; Wait for file change with a timeout of 7000 milliseconds (7 seconds)
        SetTimer, ResetPressCount, -500  ; Reset pressCount after 200ms
    }
    else
    {
		spoofy.Player.LastTrack()
        Sleep 100
    }

    pressCount++  ; Increment pressCount each time the hotkey is triggered

    OutputText := ReadFileContents("track.txt")
    if (OutputText = "")
    {
        OSD("No track is currently playing.", 2000)
    }
    else
    {
        OSD(OutputText, 2000)
    }
return

ResetPressCount:
    pressCount := 0  ; Reset pressCount to 0
return



; Show hotkey popup when F18 + "?" are pressed
F18 & ?::
    HotkeyText =
    (
    Volume Up: Increase gain for all three sliders
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