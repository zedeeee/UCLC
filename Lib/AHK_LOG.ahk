#Requires AutoHotkey v2.0

#Include stdio.ahk

; 打印日志（information）
AHK_LOGI(Message, active)
{
    if !active
        return
    k_ToolTip(Message, 1000)
}