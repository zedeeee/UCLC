#Requires AutoHotKey v2.0
SetTitleMatchMode "RegEx"

#Include ../Lib/stdio.ahk

^+t::
{
    ; FileAppend WinGetTextFast(false), ".\detWorkbench.txt"
    visible_text := WinGetTextFast_A(false)
    ; MsgBox visible_text(visible_text.Length-2)
    ; MsgBox visible_text.Length
    names := WinGetTextFast_A(false)
    loop names.Length {
        FileAppend A_Index ": " names.Get(A_Index) "`n", ".\detWorkbench.txt"
        ; FileAppend names(1), ".\detWorkbench.txt"
    }


}

^+a::
{
    WinExist("A")
    visible_text := WinGetTextFast_A(false)
    for value1 in WORKBENCH_LIST
        for value2 in visible_text {
            if (value1 != value2)
            {
                continue
            }
            k_ToolTip "value1: " value1 "`n" "value2: " value2 "`n" "A_index: " A_Index, 1000
            return
        }

}

WORKBENCH_LIST := ["装配设计", "零件设计", "创成式外形设计",
    "Generative Sheetmetal Design", "草图编辑器", "工程制图",
    "Electrical Harness Assembly", "自由样式"]


; 获取窗口文字 输出字符串
WinGetTextFast(detect_hidden) {
    controls := WinGetControlsHwnd()

    static WINDOW_TEXT_SIZE := 32767 ; Defined in AutoHotkey source.

    buf := Buffer(WINDOW_TEXT_SIZE * 2, 0)

    text := ""

    Loop controls.Length {
        hCtl := controls[A_Index]
        if !detect_hidden && !DllCall("IsWindowVisible", "ptr", hCtl)
            continue
        if !DllCall("GetWindowText", "ptr", hCtl, "Ptr", buf.ptr, "int", WINDOW_TEXT_SIZE)
            continue

        text .= StrGet(buf) "`r`n" ; text .= buf "`r`n"
    }
    return text
}

; 获取窗口文字 输出数组
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