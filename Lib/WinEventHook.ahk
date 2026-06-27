#Requires AutoHotkey v2.0
#Include "%A_LineFile%\..\CAT_Automatic.ahk"

class WinEventHook {
    static hook_ptr := 0
    static cb_ptr := 0

    static Start() {
        if (this.hook_ptr)
            return

        ; Callback 参数：hHook, event, hwnd, idObject, idChild, dwEventThread, dwmsEventTime
        this.cb_ptr := CallbackCreate(ObjBindMethod(this, "OnWinEvent"), "F")
        ; 0x0003 = EVENT_SYSTEM_FOREGROUND
        this.hook_ptr := DllCall("SetWinEventHook"
            , "UInt", 0x0003
            , "UInt", 0x0003
            , "Ptr", 0
            , "Ptr", this.cb_ptr
            , "UInt", 0
            , "UInt", 0
            , "UInt", 0
            , "Ptr")
    }

    static Stop() {
        if (this.hook_ptr) {
            DllCall("UnhookWinEvent", "Ptr", this.hook_ptr)
            this.hook_ptr := 0
        }
        if (this.cb_ptr) {
            CallbackFree(this.cb_ptr)
            this.cb_ptr := 0
        }
    }

    static OnWinEvent(hHook, event, hwnd, idObject, idChild, dwEventThread, dwmsEventTime) {
        if (event != 3) ; EVENT_SYSTEM_FOREGROUND
            return

        try {
            ; 检查 CATIA 窗口
            catia_window_hwnd := identify_catia_window(hwnd)

            if catia_window_hwnd {
                GroupAdd("GroupCATIA", "ahk_class " catia_window_hwnd)
            }

            ; 自动切换输入法逻辑
            if (WinActive("ahk_group group_autoime")) {
                switchIMEbyID(IMEmap["en"])
                SetTimer(confirmIME, -5000)
            }
        }
        catch Error as err {
            AHK_LOGI("WinEventHook: 处理前台切换事件失败")
        }
    }
}
