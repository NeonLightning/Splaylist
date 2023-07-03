#Requires AutoHotkey v1.1

; Version: 2023.06.18.1
; Usages and information: https://redd.it/orzend

class Spotify extends Spotify.Controls {

    static _hWnd := 0, _OnExit := ""

    Restore() {
        this._Win()
        WinShow
        WinActivate
        Spotify._hWnd := 0
        if (IsObject(Spotify._OnExit)) {
            OnExit(Spotify._OnExit, 0)
            Spotify._OnExit := ""
        }
    }

    _Win(Stash := false) {
        static title := "-|Spotify ahk_exe i)Spotify\.exe"
        DetectHiddenWindows On
        SetTitleMatchMode RegEx
        hWnd := WinExist(title)
        if (hWnd = 0) {
            MsgBox 0x40010, Error, Spotify is not running...
            Exit
        }
        if (Spotify._hWnd = hWnd) {
            return
        }
        Spotify._hWnd := hWnd
        visible := DllCall("IsWindowVisible", "Ptr", hWnd, "Int")
        RunWait Spotify:
        WinWait % title
        if (Stash && !visible) {
            WinWaitActive
            WinHide
            if (!IsObject(Spotify._OnExit)) {
                Spotify._OnExit := ObjBindMethod(Spotify, "Restore")
                OnExit(Spotify._OnExit, 1)
            }
        }
    }

    class Controls {

        static _shortcuts := { Next: "^{Right}", Previous: "^{Left}", Repeat: "^r", SeekBackward: "+{Left}", SeekForward: "+{Right}", Shuffle: "^s", TogglePlay: "{Space}", VolumeDown: "^{Down}", VolumeUp: "^{Up}" }

        __Call(Action, _*) {
            static WM_APPCOMMAND := 793
            if (!this._shortcuts.HasKey(Action)) {
                throw Exception("Invalid action." Action, -1)
            }
            shortcut := this._shortcuts[Action]
            hActive := WinExist("A")
            this._Win(true)
            ControlFocus Chrome Legacy Window
            ControlSend Chrome Legacy Window, % shortcut
            if (Action ~= "i)^(Next|Previous|TogglePlay)$") {
                hWnd := DllCall("FindWindow", "Str", "NativeHWNDHost", "Ptr", 0)
                try PostMessage WM_APPCOMMAND, 0x000C, 0xA0000, , % "ahk_id" hWnd
            }
            WinActivate % "ahk_id" hActive
        }

    }

}