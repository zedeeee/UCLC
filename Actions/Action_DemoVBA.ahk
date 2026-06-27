#Requires AutoHotkey v2.0
#Include %A_LineFile%\..\..\Lib\VBABridge.ahk

; 此脚本演示如何通过 UCLC 唤起 CATIA VBA 并获取返回值
; 确保在 CATIA 中注册了别名 c:my_vba_macro 指向 UCLC_Bridge.catvbs

try {
    ; 向 VBA 发送 payload 参数，超时设为 10000ms
    payload := Map("action", "get_selected_object", "version", "1.0")
    result := VBABridge.CallMacro("my_vba_macro", payload, 10000)
    
    ; 打印 VBA 返回的结果
    MsgBox("VBA 执行成功！返回结果:`n" JSON.stringify(result), "UCLC VBA Bridge")
} catch Error as e {
    MsgBox("执行 VBA 宏失败:`n" e.Message, "UCLC 错误", 16)
}

ExitApp
