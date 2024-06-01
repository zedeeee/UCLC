#Requires AutoHotkey v2.0

#Include stdio.ahk

; 打印日志（information）
AHK_LOGI(Message)
{
    if !DEBUG_I
        return
    k_ToolTip(Message, 3000)
}

; 开发功能启用提示
; 1. 检查标记值
; 2. 根据情况弹出提示框, 返回按键状态
; 3. 修改值
; 4. 重载
init_dev_func_prompt(ini_path, key, describe) {
    dev_func_section := "DevFunc"
    dev_func_flag := IniRead(ini_path, dev_func_section, key)

    AHK_LOGI("开发功能（" . key . "）启用状态：" . dev_func_flag)

    if dev_func_flag == -1
    {
        user_chooise := MsgBox("是否需要启用开发功能 : `n" . describe, "UCLC 开发功能启用", 0x233)
        switch user_chooise
        {
            case "Yes": IniWrite(1, ini_path, dev_func_section, key)
            case "No": IniWrite(0, ini_path, dev_func_section, key)
            default: MsgBox("未启用 " . describe . "`n下次启动脚本会再次询问", "UCLC 开发功能启用", 0x30)
        }
    }

    return IniRead(ini_path, dev_func_section, key)
}