; Script:    AntiIdler.ahk
; License:   The Unlicense
; Author:    krtek2k
; Github:    https://github.com/krtek2k/AntiIdler
; Date:      2024-02-04
; Version:   1.0

/*
 * Prevents from Windows idling for more than predetermined cooldown.
 * Useful to never go into inactive status or lock down Windows due inactivity
 */
 
#Requires Autohotkey v2.0+
#SingleInstance Force
#WinActivateForce

AntiIdler()

class AntiIdler {
	static IsCounting := true
	static MainGui := Gui()
	__New(*) {
		OnMessage(0x0020, ObjBindMethod(this, "WM_SETCURSOR")) ; use this to get mouseOver event
		OnMessage(0x0201, ObjBindMethod(this, "WM_LBUTTONDOWN")) ; drag & move
		title := "Anti idler"
		AntiIdler.MainGui.Title := title
		AntiIdler.MainGui.Opt("AlwaysOnTop -SysMenu -caption +Border ")
		AntiIdler.MainGui.WordWrap := true
		AntiIdler.MainGui.HasFocus := true
		AntiIdler.MainGui.MarginX := 10,
		AntiIdler.MainGui.MarginY := 10,
	    AntiIdler.MainGui.SetFont("Q5 s10 cWhite", "Verdana")
		appTitle := AntiIdler.MainGui.Add("Text", "xm w160 h35 -E0x200 Center", title)
		appTitle.SetFont("Q5 underline s22 cWhite", "impact")
		AntiIdler.MainGui.BackColor := "c237FD5"
		this._ChkAntiIdle := AntiIdler.MainGui.Add("CheckBox", "Checked vChkAntiIdle", "Keep display active")
		this._ChkAntiSleep := AntiIdler.MainGui.Add("CheckBox", "Checked vChkAntiSleep", "Move mouse 1px")
		this._ChkAntiAfk := AntiIdler.MainGui.Add("CheckBox", "vChkAntiAfk", "Press modifier keys")
		AntiIdler.MainGui.OnEvent("Escape", ObjBindMethod(this, "GuiClose"))
		submitBtn := AntiIdler.MainGui.AddButton("+default", "&Confirm && Start")
		submitBtn.OnEvent("Click", ObjBindMethod(this, "Submit"))
		submitBtn.Focus()
		countdownText := AntiIdler.MainGui.AddText("x+3 yp+5 w20", "xx")
		AntiIdler.MainGui.Show("Center AutoSize")
		
		count := 6
		while (AntiIdler.IsCounting) {
		    AntiIdler.MainGui.Flash()
			countdownText.Text := "(" count ")" ;% (StrLen(count) > 1) ? "(" SubStr(count, 1, 1) "," SubStr(count, 2, 2) ")" : "(" 0 "," SubStr(count, 1, 1) ")" 
			if (count = 0) {	
				this.Proceed()
				break
			}
		    Sleep 1000
			count := count-1
		}
		countdownText.Text := ""
	}
	GuiClose(gui) {
		this.Proceed()
	}
	Submit(gui, info) {
		this.Proceed()
	}
	
	Proceed() {
		WinHide(AntiIdler.MainGui.hwnd)
		
		while(true) {
			if (A_TimeIdle > 59000 && !this.IsWindowFullScreen) {
				if (this._ChkAntiIdle.Value)
					this.AntiIdle()
				if (this._ChkAntiSleep.Value)
					this.AntiSleep()
				if (this._ChkAntiAfk.Value)
					this.AntiAfk()
			}
			sleep 60000 ; minute check
		}
	}
	
	AntiSleep() {
	    DllCall("SetThreadExecutionState", "UInt", 0x80000003)
	}
	
	AntiIdle() {
	    MouseMove 0, 1, 0, "R"
	    Sleep 5
	    MouseMove 0, -1, 0, "R"
	}
	
	AntiAfk() {
	    Send("Shift")
	    Send("Ctrl")
	}
	
	IsWindowFullScreen() {
		;checks if the active window is full screen
		WinID := WinExist("A") 
		if (!WinID)
			return		
		style := WinGetStyle(WinID)
		; 0x800000 is WS_BORDER.
		; 0x20000000 is WS_MINIMIZE.
		; no border and not minimized
		return (style & 0x20800000) ? false : true	
	}
	
	WM_SETCURSOR(wParam, lParam, msg, hwnd) {
		AntiIdler.IsCounting:=false
		DllCall("User32.dll\SetCursor", "Ptr", this.LoadCursor(32649)) ; IDC_HAND = 32649
		return true
	}
	
	LoadCursor(cursorId) {
		static IMAGE_CURSOR := 2, flags := (LR_DEFAULTSIZE := 0x40) | (LR_SHARED := 0x8000)
		return DllCall( "LoadImage", "Ptr", 0, "UInt", cursorId, "UInt", IMAGE_CURSOR, "Int", 0, "Int", 0, "UInt", flags, "Ptr" )
	}
	
	WM_LBUTTONDOWN(wParam, lParam, Msg, Hwnd) {
		If (Hwnd = AntiIdler.MainGui.Hwnd) {
			; extract where we first clicked on the control
			rmX := lParam & 0xFFFF
			rmY := lParam >> 16

			while GetKeyState("Lbutton","P") {
				CoordMode("mouse", "Client")
				MouseGetPos(&mX, &mY)
				AntiIdler.MainGui.GetPos(&gX, &gY)
				AntiIdler.MainGui.Move(gX + mX - rmX, gY + mY - rmY)
			}
			return true
		}
	}
}

; script auto reload on save in debug mode
#HotIf WinActive("ahk_class Notepad++") ; Reload ahk on CTRL+S when debugging
    ~^s:: {
		Send "^s"
		winTitle := WinGetTitle("A")  ; "A" matches "Active" window
		if (InStr(winTitle, A_Scriptdir) or InStr(winTitle, A_ScriptName)) { ; Only when the script dir/filename is in the titlebar
		  Reload
		  return
		}
		
		SplitPath(A_Scriptdir, &topDir) ; Only when the top dir name is in the titlebar
		if (InStr(winTitle, topDir)) {
		  Reload
		  return
		}
    }
#HotIf