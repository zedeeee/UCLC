#Requires AutoHotKey v2.0
#SingleInstance Force
SetTitleMatchMode 2

; === UCLC 核心基础库 ===
#Include Lib\UCLC_System.ahk
#Include Lib\UCLC_Core.ahk
#Include Lib\UCLC_UI.ahk
#Include Lib\UCLC_Updater.ahk
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
        KeyboardController.register_anti_sticky_hotkeys()

        WinEventHook.Start()

        ; 启动版本更新检查 (延时3秒执行首次检查，之后每 1 小时循环检查一次)
        SetTimer(() => UCLCUpdater.CheckForUpdate(false), -3000)
        SetTimer(() => UCLCUpdater.CheckForUpdate(false), 3600000)
    }

    start_tips_timer() {
        this.tips_array := []
        tips_file := A_ScriptDir "\data\tips.json"
        if FileExist(tips_file) {
            try {
                this.tips_array := JSON.parse(FileRead(tips_file, "UTF-8"))
            } catch Error as e {
                Logger.info("解析 tips.json 失败：" . e.Message)
            }
        }
        if (this.tips_array.Length > 0) {
            this.rotate_tray_tip()
            SetTimer(ObjBindMethod(this, "rotate_tray_tip"), 300000) ; 5分钟更换一次
        } else {
            A_IconTip := "UCLC - " . AppSettings.Version
        }
    }

    rotate_tray_tip() {
        if (this.tips_array.Length == 0)
            return
        idx := Random(1, this.tips_array.Length)
        A_IconTip := this.tips_array[idx]
    }

    check_user_config() {
        if (!FileExist(AppSettings.commands_json_path)) {
            MsgBox(
                "未找到主配置文件 (commands.json)，且默认配置模板 (data\commands.example.json) 也缺失！`n"
                "请检查程序包完整性后重试。", "UCLC - 配置文件缺失", 16
            )
            ExitApp
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

FeatureMatcher.Init(A_AppData "\UCLC\vector_nodes.json")
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

        KeyWait "Control"
        Sleep 30
        if (AppSettings.Everything_Hotkey == "") {
            MsgBox("未配置 Everything 热键。`n`n请在 Everything「选项」->「键盘」->「显示窗口」中设置，完成后重新载入 UCLC 生效。", "UCLC - Everything 快速呼出", 48)
            return
        }

        if ProcessExist("Everything.exe") {
            hk_send := parse_hotkey_from_display(AppSettings.Everything_Hotkey)
            if (hk_send != "")
                SendEvent hk_send
            return
        }

        if (AppSettings.Everything_Path and FileExist(AppSettings.Everything_Path)) {
            Run AppSettings.Everything_Path
        }
        else {
            result := MsgBox(
                "已启用 Everything 快速呼出，但未找到 Everything.exe。`n`n"
                "是否现在打开 UCLC 设置窗口进行配置？"
                , "UCLC - Everything 快速呼出"
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

#HotIf (AppSettings.config_obj.Has("CatiaMButton") && Integer(AppSettings.config_obj["CatiaMButton"]["Enabled"]) && CATIAInstance.is_catia_dialog_context())
!MButton:: CATIAInstance.click_dialog_confirm_button()
+MButton:: CATIAInstance.click_dialog_preview_button()