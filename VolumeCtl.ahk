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

OSD(text, number)
{
    ; Read color values from the config.ini file
    configFile := "config.ini"
    textColor := ""
    bgColor := ""

    if FileExist(configFile)
    {
        IniRead, textColor, %configFile%, OSDSettings, TextColor
        IniRead, bgColor, %configFile%, OSDSettings, BackgroundColor
    }

    ; If color values are not found in the config, use defaults
    if (textColor = "")
        textColor := "888800"
    if (bgColor = "")
        bgColor := "000000"

    ; Destroy the previous GUI if it exists
    Gui, Destroy

    ; Customize the OSD appearance and position
    Gui +AlwaysOnTop +ToolWindow +E0x20 -Caption -SysMenu -Owner
    Gui, Color, %bgColor%
    Gui, Font, s16, Fixedsys
    Gui, Add, Text, x10 y10 h40 c%textColor%, %text%
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
        Sleep 10  ; Adjust the sleep duration as needed
    }
}

ReadFileContents(file)
{
    FileRead, contents, %file%
    return contents
}

ToggleMute() {
    mute1 := vmr.strip[8].mute
    if (mute1 == 0) {
        OSD("Muted.", 1000)
		vmr.strip[6].mute := 1
		vmr.strip[7].mute := 1
		vmr.strip[8].mute := 1
    } else {
        OSD("Unmuted.", 1000)
        vmr.strip[6].mute := 0
        vmr.strip[7].mute := 0
        vmr.strip[8].mute := 0
    }
}


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
	   OSD("speakers on",500)
        vmr.strip[6].A1 := 0
        vmr.strip[6].A2 := 1
        vmr.strip[7].A1 := 0
        vmr.strip[7].A2 := 1
        vmr.strip[8].A1 := 0
        vmr.strip[8].A2 := 1
    } else {
	   OSD("headphones on",500)
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
		OSD("tv on",500)
		vmr.strip[6].A3 := 1
		vmr.strip[7].A3 := 1
		vmr.strip[8].A3 := 1
	} else {
		OSD("tv off",500)
		vmr.strip[6].A3 := 0
		vmr.strip[7].A3 := 0
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
    RunSplaylist("-s")
    WaitForFileChange("track.txt", 7000)  ; Wait for file change with a timeout
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
	spoofy.Next()
Return

$Media_Prev::
	spoofy.Previous()
Return

F16 & Media_Stop::
    vmr.command.restart()
    OSD("Audio Engine Restarted", 2000)
return


Shift & Media_Next::
    spoofy.Next()
    Sleep 500
    RunSplaylist("-s")
    WaitForFileChange("track.txt", 7000)  ; Wait for file change with a timeout
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

Shift & Media_Prev::
	spoofy.Previous()
     Sleep 200
     RunSplaylist("-s")
     WaitForFileChange("track.txt", 7000)  ; Wait for file change with a timeout
	 
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

Volume_Mute::
    ToggleMute()
return

Media_Play_Pause::
	spoofy.TogglePlay()
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