#Requires AutoHotkey v2.0
#Include %A_LineFile%\..\..\Lib\stdio.ahk

if A_Args.Length < 1 {
    MsgBox("Action_QuickManipulation 需要提供方向参数 (如 X轴, Y轴 等)")
    ExitApp
}
diraction := A_Args[1]

GroupAdd "Manipulation", "操作参数"

manipulation_hwnd := WinWait("ahk_group Manipulation", , 5)
if manipulation_hwnd == 0
    ExitApp

diract_button := ControlGetHwnd(diraction, manipulation_hwnd)

SendMessage(0xF5, 0, 0, diract_button, manipulation_hwnd)
ExitApp
