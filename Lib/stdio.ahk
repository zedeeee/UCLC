#Requires AutoHotkey v2.0

; ToolTip 的封装函数，简化函数调用
; - string: Message
; - int: Delay_ms
k_ToolTip(Message, Delay_ms)
{
  ToolTip Message
  SetTimer ToolTip, Delay_ms
}