#Requires AutoHotkey v2.0

k_ToolTip(Message, delay)
{
  ToolTip Message
  SetTimer ToolTip, delay
}