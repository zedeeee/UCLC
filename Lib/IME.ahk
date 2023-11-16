; 通过调用WinAPI切换输入法
; https://github.com/mudssky/myAHKScripts
;
#Requires AutoHotKey v2.0

IMEmap := map(
    "zh", 0x8040804,
    "en", 0x4090409
)

getCurrentIMEID() {
    winID := WinGetID("A")
    ThreadID := DllCall("GetWindowThreadProcessId", "UInt", WinID, "UInt", 0)
    InputLocaleID := DllCall("GetKeyboardLayout", "Uint", ThreadID, "Uint")
    return InputLocaleID
}


switchIMEbyID(IMEID) {
    PostMessage(0x0050, 0, IMEID, , "A")
}

; loop {
;     WinWaitActive "ahk_exe cnext.exe"
;     currentWinID := WinGetID("A")
;     switchIMEbyID(IMEmap["en"])
;     WinWaitNotActive(currentWinID)
; }
