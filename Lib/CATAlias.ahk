#Requires AutoHotKey v2.0
#include stdio.ahk
#Include AHK_LOG.ahk

; 读取CATAlias.ini配置文件中的别名
readAlias(k_Section, k_Key) {
    try {
        ; 返回 CATAlias.ini 内 Key 的对应值
        AHK_LOGI("调用 " k_Section,DEBUG_I)
        return StrSplit(IniRead(A_ScriptDir "/Lib/CATAlias.ini", k_Section, k_Key), ";")[1]
    }
    catch as e {
        if e
        {
            try {
                AHK_LOGI("调用 通用", DEBUG_I)
                return StrSplit(IniRead(A_ScriptDir "/Lib/CATAlias.ini", "通用", k_Key), ";")[1]
            }
            catch as e {
                k_ToolTip("没有找到与" k_Key "对应的命令", 1000)
                Exit
            }
        }
    }
}

; 查找 ini 文件，发送对应的别名，Hotkey 调用
SendAliasCommand(ThisHotkey) {
    try {
        ControlSetText("", FocuseHwnd)
        SendInput("c:" readAlias("HotKey_cn", ThisHotkey) "{Enter}")
        ; SendInput("c:" IniRead(A_ScriptDir "/Lib/CATAlias.ini", "HotKey_cn", ThisHotkey) "{Enter}")
    }
    catch as e {
        k_ToolTip("控件获取失败，请至少执行一次任意命令输入", 2000)
        Exit
    }
}

; 自动获取焦点Hwnd 未成功
; getFocuseHwnd() {
;     SendInput "fwefwfow"
;     FocuseHwnd := ControlGetFocus("A")
;     ControlSetText("aaa", FocuseHwnd)
;     MsgBox ("1nd=" FocuseHwnd)
;     return FocuseHwnd
; }
