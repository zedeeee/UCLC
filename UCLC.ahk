#Requires AutoHotKey v2.0
#SingleInstance Force
; #MaxThreads 20 ; 已废弃异步轮询，不再需要高并发线程
SetTitleMatchMode 2


; === UCLC 核心基础库 ===
#Include Lib\UCLC_System.ahk
#Include Lib\UCLC_Core.ahk
#Include Lib\UCLC_UI.ahk
; === UCLC 核心基础库 ===

AppSettings.Init()
add_coustom_tray_menu()

; 检查 USER-CONFIG文件
check_user_config()

; 创建 计算器 组
GroupAdd "group_calc", "计算器"
GroupAdd "group_calc", "Calculator"

; 从 JSON Map 补充工作台列表
for wb, _ in AppSettings.alias_obj {
    if !AppSettings.workbench_list.Has(wb)
        AppSettings.workbench_list[wb] := ""
}

; 注册热键
HotIfWinActive "ahk_group GroupCATIA"
{
    customize_hotkey_list_dict := Map()

    ; 将内存中所有热键写入字典
    for workbench, keys_map in AppSettings.hotkey_obj {
        for hotkey_str, _ in keys_map {
            if !customize_hotkey_list_dict.Has(hotkey_str) {
                customize_hotkey_list_dict.Set(hotkey_str, "")
            }
        }
    }

    for each_hotkey in customize_hotkey_list_dict {
        Hotkey each_hotkey, register_command
    }
}

check_user_config() {
    alias_ini := AppSettings.alias_ini_path
    hotkey_ini := AppSettings.hotkey_ini_path
    
    if (FileExist(AppSettings.commands_json_path) = "" && FileExist(alias_ini) = "" && FileExist(hotkey_ini) = "") {
        result := MsgBox(
            "未找到配置文件`n"
            "是否从 Github/Gitee 下载示例文件？`n"
            , "配置文件缺失"
            , 51
        )

        switch result {
            case "No":
                MsgBox "
        (
          示例配置文件下载地址：
          https://github.com/zedeeee/UCLC-config
        )"
                ExitApp

            case "Yes":
                config_and_path := [
                    ["CAT_Alias.ini", alias_ini],
                    ["CAT_Hotkey.ini", hotkey_ini]
                ]

                flag := 1
                for config_info in config_and_path {
                    if not download_configurations(config_info[1], config_info[2])
                        flag := 0
                }

                MsgBox("获取配置文件成功，请重新载入脚本")
                Reload()

            default: ExitApp
        }
    }
}

add_group_by_exe("group_autoime", "AutoIME")

volume_control := VolumeController.Call()

; 启动脚本后通过事件钩子监听窗口激活，彻底摒弃无限轮询
WinEventHook.Start()

#HotIf WinActive
{
    ^+r::
    {
        ToolTip "Reloading Script ..."
        Sleep 500
        ToolTip
        Reload		; 设定 Ctrl-Shift-R 热键来重启脚本.
    }

    ; win + c 启动系统自带的计算器
    ; 如果计算器已经打开，则激活它
    #c::
    {
        try
        {
            WinActivate("ahk_group group_calc")
        }
        catch as e {
            Run "Calc"
            WinWait("ahk_group group_calc")
            WinActivate("ahk_group group_calc")
        }
    }

    ~RControl::
    {
        ; 检查功能是否启用
        if !AppSettings.Everything_Enabled {
            return
        }

        ; 双击判断逻辑不变
        if (A_PriorHotkey != "~RControl" or A_TimeSincePriorHotkey > 400) {
            KeyWait "Control"
            return
        }

        ; 如果 Everything 正在运行，直接激活
        if ProcessExist("Everything.exe") {
            Send "#]" ; 仍然依赖用户在 Everything 中设置的快捷键
            return
        }

        ; 如果未运行，检查路径是否有效
        if (AppSettings.Everything_Path and FileExist(AppSettings.Everything_Path)) {
            Run AppSettings.Everything_Path
        }
        else {
            ; --- 核心改进：弹出交互式对话框 ---
            result := MsgBox(
                "“Everything 快速启动”功能已启用，但未找到 Everything.exe。`n`n"
                "请检查 config.ini 中的路径配置是否正确。`n`n"
                "要现在打开设置窗口进行配置吗？"
                , "配置缺失"
                , 36 ; Yes/No buttons + Question icon
            )

            if (result == "Yes") {
                ShowSettingsGUI() ; 直接调用显示设置窗口的函数
            }
        }
    }

    ; Win + 鼠标滚轮上下 切换虚拟桌面
    LWin & WheelDown::
    {
        try {
            if (A_TimeSincePriorHotkey > 200)
                Send "{Ctrl Down}{LWin Down}{Right}{Ctrl Up}{LWin Up}"
        }
    }

    LWin & WheelUp::
    {
        try {
            if (A_TimeSincePriorHotkey > 200)
                Send "{Ctrl Down}{LWin Down}{Left}{Ctrl Up}{LWin Up}"
        }
    }

    ; 右ALT+鼠标滚轮上，音量增大
    RAlt & WheelUp::
    {
        increment := volume_control.get_volume_increment()
        SoundSetVolume "+" . increment
        volume_control.show_volume_status()
        Sleep 5
    }

    ; 右ALT+鼠标滚轮下，音量减小
    RAlt & WheelDown::
    {
        increment := volume_control.get_volume_increment()
        SoundSetVolume "-" . increment
        volume_control.show_volume_status()
        Sleep 5
    }

    ; 右ALT+鼠标中键，静音
    RAlt & MButton::
    {
        SoundSetMute -1
        muteStatus := SoundGetMute() ? "静音" : "解除静音：" . Integer(SoundGetVolume())
        k_ToolTip(muteStatus, 1000)
    }

    ; ^+t::
    ; {

    ; }
}

; 仅 CATIA 窗口生效的 热键/热字串
#HotIf WinActive("ahk_group GroupCATIA")
{

    Space::
    {
        power_input_edit_control_hwnd := get_power_input_edit_hwnd()
        edit_text := ControlGetText(power_input_edit_control_hwnd)

        if (edit_text == "") {
            SendInput "^y"
            Exit
        }

        cat_command_execution(edit_text, "alias", power_input_edit_control_hwnd)
    }

    +Tab::
    {
        GroupActivate "GroupCATIA"
        k_ToolTip(WinGetTitle("A"), 1000)
    }

    ; 清除 CATIA power-input 输入框里的内容
    ~Esc::
    {
        ControlSetText("", get_power_input_edit_hwnd())
    }

}
