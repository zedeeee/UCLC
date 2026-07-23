#Requires AutoHotKey v2.0
#SingleInstance Force
SetTitleMatchMode 2

; === UCLC 核心基础库 ===
#Include Lib\UCLC_System.ahk
#Include Lib\UCLC_Core.ahk
#Include Lib\UCLC_UI.ahk
; === UCLC 核心基础库 ===

class UCLCApp {
    __New() {
        this.volume_control := VolumeController()
    }

    Run() {
        AppSettings.Init()
        add_coustom_tray_menu()

        this.check_user_config()

        GroupAdd "group_calc", "计算器"
        GroupAdd "group_calc", "Calculator"
        WindowManager.add_group_by_exe("group_autoime", "AutoIME")

        if (AppSettings.Calc_Enabled && AppSettings.Calc_Hotkey != "") {
            try {
                hk := parse_hotkey_from_display(AppSettings.Calc_Hotkey)
                Hotkey(hk, ObjBindMethod(UCLCApp, "run_calc"), "On")
            } catch Error as e {
                Logger.info("计算器快捷键绑定失败：" . e.Message)
            }
        }

        for wb, _ in AppSettings.alias_obj {
            if !AppSettings.workbench_list.Has(wb)
                AppSettings.workbench_list[wb] := ""
        }

        this.register_hotkeys()

        WinEventHook.Start()
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
                        if not Downloader.download_configurations(config_info[1], config_info[2])
                            flag := 0
                    }

                    MsgBox("获取配置文件成功，请重新载入脚本")
                    Reload()

                default: ExitApp
            }
        }
    }

    register_hotkeys() {
        HotIfWinActive("ahk_group GroupCATIA")

        customize_hotkey_list_dict := Map()

        for workbench, keys_map in AppSettings.hotkey_obj {
            for hotkey_str, _ in keys_map {
                if !customize_hotkey_list_dict.Has(hotkey_str) {
                    customize_hotkey_list_dict.Set(hotkey_str, "")
                }
            }
        }

        for each_hotkey in customize_hotkey_list_dict {
            Hotkey(each_hotkey, ObjBindMethod(CommandEngine, "register_command"))
        }
    }

    static run_calc(*) {
        try {
            WinActivate("ahk_group group_calc")
        }
        catch as e {
            Run "Calc"
            WinWait("ahk_group group_calc")
            WinActivate("ahk_group group_calc")
        }
    }
}

app := UCLCApp()
app.Run()

#HotIf WinActive
{
    ^+r::
    {
        Logger.tooltip("重新载入 UCLC", 1000)
        Sleep 1000
        Logger.tooltip("", 0)
        Reload
    }

    ~RControl::
    {
        if !AppSettings.Everything_Enabled {
            return
        }

        if (A_PriorHotkey != "~RControl" or A_TimeSincePriorHotkey > 400) {
            KeyWait "Control"
            return
        }

        if ProcessExist("Everything.exe") {
            Send "#]"
            return
        }

        if (AppSettings.Everything_Path and FileExist(AppSettings.Everything_Path)) {
            Run AppSettings.Everything_Path
        }
        else {
            result := MsgBox(
                "“Everything 快速启动”功能已启用，但未找到 Everything.exe。`n`n"
                "请检查 config.ini 中的路径配置是否正确。`n`n"
                "要现在打开设置窗口进行配置吗？"
                , "配置缺失"
                , 36
            )

            if (result == "Yes") {
                ShowSettingsGUI()
            }
        }
    }

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
}

#HotIf AppSettings.Volume_Enabled
RAlt & WheelUp::
{
    increment := app.volume_control.get_volume_increment()
    SoundSetVolume "+" . increment
    app.volume_control.show_volume_status()
    Sleep 5
}

RAlt & WheelDown::
{
    increment := app.volume_control.get_volume_increment()
    SoundSetVolume "-" . increment
    app.volume_control.show_volume_status()
    Sleep 5
}

RAlt & MButton::
{
    SoundSetMute -1
    muteStatus := SoundGetMute() ? "静音" : "解除静音：" . Integer(SoundGetVolume())
    Logger.tooltip(muteStatus, 1000)
}
#HotIf

#HotIf WinActive("ahk_group GroupCATIA")
{
    Space::
    {
        power_input_edit_control_hwnd := CATIAWindow.get_power_input_edit_hwnd()
        edit_text := ControlGetText(power_input_edit_control_hwnd)

        if (edit_text == "") {
            SendInput "^y"
            return
        }

        CommandEngine.execute(edit_text, "alias", power_input_edit_control_hwnd)
    }

    +Tab::
    {
        GroupActivate "GroupCATIA"
        Logger.tooltip(WinGetTitle("A"), 1000)
    }

    ~Esc::
    {
        ControlSetText("", CATIAWindow.get_power_input_edit_hwnd())
    }
}