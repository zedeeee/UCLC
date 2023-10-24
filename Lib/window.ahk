#Requires AutoHotkey v2.0

; 获取最近找到窗口的所有控件名称 并返回数组
WinGetTextFast_A(detect_hidden) {
    controls := WinGetControlsHwnd()

    static WINDOW_TEXT_SIZE := 32767 ; Defined in AutoHotkey source.

    buf := Buffer(WINDOW_TEXT_SIZE * 2, 0)

    names := Array()


    Loop controls.Length {
        hCtl := controls[A_Index]
        if !detect_hidden && !DllCall("IsWindowVisible", "ptr", hCtl)
            continue
        if !DllCall("GetWindowText", "ptr", hCtl, "Ptr", buf.ptr, "int", WINDOW_TEXT_SIZE)
            continue

        name := StrGet(buf)
        names.Push(name)
    }
    return names
}