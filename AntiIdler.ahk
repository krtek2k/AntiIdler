; Script:    AntiIdler.ahk
; License:   The Unlicense
; Author:    krtek2k
; Github:    https://github.com/krtek2k/AntiIdler
; Date:      2024-02-04
; Version:   1.2

/*
 * Prevents from Windows idling for more than predetermined cooldown.
 * Useful to never go into inactive status or lock down Windows due inactivity.
 */
 
#Requires Autohotkey v2.0+
#SingleInstance Force

AntiIdler()

class AntiIdler {
	
	static Monitors:=[]
	static HeartbeatCooldown := 30000 ; lowest possible value is clamped to 1000
	;//https://docs.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-setthreadexecutionstate
	static WS_ES_CONTINUOUS			:= 0x80000000 ; Allows standby again.
	static WS_ES_DISPLAY_REQUIRED	:= 0x00000002 ; Prevents system and monitor to go standby
	static WS_ES_SYSTEM_REQUIRED	:= 0x00000001 ; Prevents system but not monitor to go standby
	static IsCounting := true
	static MainGui := Gui()
	
	__New(*) {
		loop MonitorGetCount()
		{
			local Left, Top, Right, Bottom
			MonitorGet(A_Index, &Left, &Top, &Right, &Bottom)
			AntiIdler.Monitors.Push({l:Left,t:Top,r:Right,b:Bottom})
		}
		
		MouseMove 0, 0 ; out of center screen
		OnMessage(0x0020, ObjBindMethod(this, "WM_SETCURSOR")) ; use this to get mouseOver event
		OnMessage(0x0201, ObjBindMethod(this, "WM_LBUTTONDOWN")) ; drag & move
		title := "Anti idler"
		AntiIdler.MainGui.Title := title
		AntiIdler.MainGui.Opt("AlwaysOnTop -SysMenu -caption +Border ")
		AntiIdler.MainGui.WordWrap := true
		AntiIdler.MainGui.HasFocus := true
		AntiIdler.MainGui.MarginX := 10
		AntiIdler.MainGui.MarginY := 10
	    AntiIdler.MainGui.SetFont("Q5 s10 cWhite", "Verdana")
		appTitle := AntiIdler.MainGui.Add("Text", "xm w160 h35 -E0x200 Center", title)
		appTitle.SetFont("Q5 underline s22 cWhite", "impact")
		AntiIdler.MainGui.BackColor := "c237FD5"
		this._ChkAntiIdle := AntiIdler.MainGui.Add("CheckBox", "Checked", "Keep display active")
		this._ChkAntiSleep := AntiIdler.MainGui.Add("CheckBox", "Checked", "Move mouse 1px")
		this._ChkAntiAfk := AntiIdler.MainGui.Add("CheckBox", "Checked", "Press modifier keys")
		AntiIdler.MainGui.OnEvent("Escape", ObjBindMethod(this, "GuiClose"))
		submitBtn := AntiIdler.MainGui.AddButton("+default", "&Confirm && Start")
		submitBtn.OnEvent("Click", ObjBindMethod(this, "Submit"))
		submitBtn.Focus()
		countdownText := AntiIdler.MainGui.AddText("x+3 yp+5 w20", "xx")
		AntiIdler.MainGui.Show("Center AutoSize")
		
		count := 5
		while (AntiIdler.IsCounting) {
		    AntiIdler.MainGui.Flash()
			countdownText.Text := "(" count ")" ;% (StrLen(count) > 1) ? "(" SubStr(count, 1, 1) "," SubStr(count, 2, 2) ")" : "(" 0 "," SubStr(count, 1, 1) ")" 
			if (count = 0) {	
				this.Heartbeat()
				break
			}
		    Sleep 1000
			count := count-1
		}
		countdownText.Text := ""
	}
	__Delete() {
		DllCall("Kernel32.dll\SetThreadExecutionState", "UInt", AntiIdler.WS_ES_CONTINUOUS) ; Allows standby again.
	}
	GuiClose(gui) {
		this.Heartbeat()
	}
	Submit(gui, info) {
		this.Heartbeat()
	}
	
	Heartbeat() {
		WinHide(AntiIdler.MainGui.hwnd)
		while(true) {
			if (A_TimeIdle > ((AntiIdler.HeartbeatCooldown < 1000 ? 1000 : AntiIdler.HeartbeatCooldown) -1000) && !this.IsFullScreen()) {
				if (this._ChkAntiIdle.Value)
					this.AntiIdle()
				if (this._ChkAntiSleep.Value)
					this.AntiSleep()
				if (this._ChkAntiAfk.Value)
					this.AntiAfk()
			}

			sleep AntiIdler.HeartbeatCooldown
		}
	}
	
	AntiSleep() {
	    DllCall("Kernel32.dll\SetThreadExecutionState", "UInt", AntiIdler.WS_ES_DISPLAY_REQUIRED | AntiIdler.WS_ES_SYSTEM_REQUIRED)
	}
	
	AntiIdle() {
	    MouseMove 0, 1, 0, "R" ; left
	    Sleep 5
	    MouseMove 0, -1, 0, "R"	; back
	}
	
	AntiAfk() {
	    Send "{Shift}"
	    Send "{Ctrl}"
	}
	
	IsWindowFullScreen() {
		;checks if the active window is full screen
		WinID := WinExist("A") 
		if (!WinID)
			return false	
		style := WinGetStyle(WinID)
		; 0x800000 is WS_BORDER.
		; 0x20000000 is WS_MINIMIZE.
		; no border and not minimized
		return (style & 0x20800000) ? false : true	
	}
	
	IsFullScreen() {
		;checks if the active window is full screen
		local uid:=WinExist("A")
		if(!uid)
			return false
			
		local wid:="ahk_id " uid
		c:=WinGetClass(wid)
		If (uid = DllCall("GetDesktopWindow") Or (c = "Progman") Or (c = "WorkerW"))
			return false
			
		local cx, cy, cw, ch
		WinGetClientPos(&cx,&cy,&cw,&ch,wid)
		cl:=cx
		ct:=cy
		cr:=cx+cw
		cb:=cy+ch
		For , v in AntiIdler.Monitors
		{
			if(cl==v.l and ct==v.t and cr==v.r and cb==v.b)
				Return True
		}
		return false
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
