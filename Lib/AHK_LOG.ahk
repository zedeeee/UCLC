#Requires AutoHotkey v2.0

#Include stdio.ahk

; 打印日志（information）
AHK_LOGI(Message)
{
    if !DEBUG_I
        return
    k_ToolTip(Message, 1000)
}