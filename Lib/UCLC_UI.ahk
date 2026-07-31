#Requires AutoHotkey v2.0

#Include "UCLC_Core.ahk"
#Include "UCLC_System.ahk"

;-==== [ 原模块: tray_menu.ahk ] ====-
showProjectHomepage_cb(*) {
    Run "https://github.com/zedeeee/UCLC"
}

help_Homepage_cb(*) {
    Run "https://github.com/zedeeee/UCLC-config"
}

open_script_folder_cb(*)
{
    Run A_ScriptDir
}

reload_cb(*) {
    Reload
}

disable_script_cb(ItemName, ItemPos, MyMenu)
{
    menu_toggleCheck_cb(ItemName, ItemPos, MyMenu)
    Suspend(-1)
    if A_IsSuspended {
        if FileExist(A_ScriptDir "\icon\UCLC_gray.ico")
            TraySetIcon(A_ScriptDir "\icon\UCLC_gray.ico", , true)
    } else {
        if FileExist(A_ScriptDir "\icon\UCLC.ico")
            TraySetIcon(A_ScriptDir "\icon\UCLC.ico", , true)
    }
}

exit_cb(*) {
    ExitApp
}

menu_toggleCheck_cb(ItemName, ItemPos, MyMenu)
{
    MyMenu.ToggleCheck(ItemName)
}

NoAction_cb(*) {
    Logger.tooltip("功能未开放", 2000)
}

run_spy_cb(*)
{
    SplitPath A_AhkPath, , &ahk_dir
    spy_paths := [
        ahk_dir "\..\UX\WindowSpy.ahk",
        ahk_dir "\..\WindowSpy.ahk",
        ahk_dir "\WindowSpy.ahk"
    ]

    try spy_paths.Push(RegRead("HKEY_LOCAL_MACHINE\SOFTWARE\AutoHotkey", "InstallDir") "\UX\WindowSpy.ahk")
    try spy_paths.Push(RegRead("HKEY_CURRENT_USER\SOFTWARE\AutoHotkey", "InstallDir") "\UX\WindowSpy.ahk")

    for path in spy_paths {
        if FileExist(path) {
            Run('"' path '"')
            return
        }
    }
    MsgBox("无法找到 WindowSpy.ahk，请确认 AutoHotkey 是否完整安装。", "UCLC", 0x10)
}

about_cb(*) => ShowAboutGUI()

tools_sub_menu := [
    ["打开脚本所在文件夹", open_script_folder_cb, ""],
    ["Windows Spy", run_spy_cb, ""]
]

class AboutGUI extends Gui {
    __New() {
        super.__New("-Resize -MaximizeBox", "关于 UCLC")
        this.OnEvent("Escape", (*) => this.Destroy())
        this.SetFont("s9", "Microsoft YaHei UI")

        ; 图标与标题
        if FileExist(A_ScriptDir "\icon\UCLC.ico")
            this.Add("Picture", "x20 y20 w48 h48", A_ScriptDir "\icon\UCLC.ico")

        this.SetFont("s14 bold", "Microsoft YaHei UI")
        this.Add("Text", "x80 y18 w320 h28", "UCLC")

        this.SetFont("s9 norm c888888", "Microsoft YaHei UI")
        ver_str := "版本: " . (IsSet(AppSettings) && AppSettings.HasProp("Version") ? AppSettings.Version : "v3.0.0")
        this.Add("Text", "x80 y46 w320 h20", ver_str)

        ; 分割线
        this.Add("Text", "x20 y75 w380 h1 0x10")

        ; 描述说明（优化后的版本）
        this.SetFont("s9 norm c333333", "Microsoft YaHei UI")
        descText := "提供简单直观的命令别名与快捷确认执行方式，`n同时全面支持自定义键盘快捷键与防呆兼容，`n显著提升 CATIA 绘图与建模效率。"
        this.Add("Text", "x20 y88 w380 h55", descText)

        ; 运行环境与许可信息 GroupBox
        this.Add("GroupBox", "x20 y148 w380 h65", "运行环境与许可")
        this.SetFont("s8 c666666", "Microsoft YaHei UI")
        this.Add("Text", "x32 y168 w350 h18", "AHK 内核: AutoHotkey " . A_AhkVersion . " (" . (A_PtrSize * 8) . "位)")
        this.Add("Text", "x32 y188 w350 h18", "开源协议: MIT License  |  © 2026 zedeeee")

        ; 底部操作按钮
        this.SetFont("s9 norm", "Microsoft YaHei UI")
        btnRepo := this.Add("Button", "x170 y228 w110 h28", "🌐 项目主页")
        btnRepo.OnEvent("Click", (*) => Run("https://github.com/zedeeee/UCLC"))

        btnClose := this.Add("Button", "x290 y228 w110 h28 Default", "确定")
        btnClose.OnEvent("Click", (*) => this.Destroy())
    }
}

show_about_gui(*) {
    static about_dlg := ""
    try {
        if (about_dlg && WinExist(about_dlg.Hwnd)) {
            about_dlg.Show()
            return
        }
    }
    about_dlg := AboutGUI()
    about_dlg.Show()
}
ShowAboutGUI(*) => show_about_gui()

add_coustom_tray_menu()
{
    if A_IsSuspended && FileExist(A_ScriptDir "\icon\UCLC_gray.ico")
        TraySetIcon(A_ScriptDir "\icon\UCLC_gray.ico", , true)
    else if FileExist(A_ScriptDir "\icon\UCLC.ico")
        TraySetIcon(A_ScriptDir "\icon\UCLC.ico", , true)

    A_IconTip := "UCLC: 像AutoCAD一样使用CATIA"

    dyn_menu_items := [
        ["设置...", ShowSettingsGUI, ""],
        ["", NoAction_cb, ""],
        ["挂起快捷键", disable_script_cb, ""],
        ["重新载入", reload_cb, ""],
        ["", NoAction_cb, ""],
        ["工具", NoAction_cb, tools_sub_menu],
        ["", NoAction_cb, ""],
        ["关于 UCLC", ShowAboutGUI, ""],
        ["", NoAction_cb, ""],
        ["退出", exit_cb, ""]
    ]

    cus_tray_menu := Menu()
    A_TrayMenu.Delete()

    for menu_item in dyn_menu_items
    {
        button_name := menu_item[1]
        callback_function := menu_item[2]
        sub_menu_items := menu_item[3]

        if button_name == ""
        {
            A_TrayMenu.Add()
            continue
        }

        ; 如果子菜单不为空，开始注册子菜单
        if sub_menu_items != ""
        {
            parent_button_name := button_name
            sub_menu_name := [button_name . "_sub_menu"]
            sub_menu_name[1] := Menu()

            for sub_menu_item in sub_menu_items
            {
                sub_button_name := sub_menu_item[1]
                sub_callback_function := sub_menu_item[2]
                sub_menu_name[1].Add(sub_button_name, sub_callback_function)
            }
            A_TrayMenu.Add(parent_button_name, sub_menu_name[1])
            continue
        }
        A_TrayMenu.Add(button_name, callback_function)
    }

    A_TrayMenu.Default := "关于 UCLC"

    ; 为重点菜单项配置原生图标
    try {
        if FileExist(A_ScriptDir "\icon\UCLC.ico")
            A_TrayMenu.SetIcon("关于 UCLC", A_ScriptDir "\icon\UCLC.ico")
    }
}

;-==== [ 原模块: SettingsGUI.ahk ] ====-
show_settings_gui(*) {
    if (!SettingsController.instance || !SettingsController.instance.is_valid()) {
        model := SettingsModel()
        view := SettingsView()
        SettingsController.instance := SettingsController(model, view)
    }
    SettingsController.instance.show()
}

ShowSettingsGUI(*) => show_settings_gui()


is_array_equal(arr1, arr2) {
    if (arr1.Length != arr2.Length)
        return false
    for idx, item in arr1 {
        if (item != arr2[idx])
            return false
    }
    return true
}

format_hotkey_for_display(hk) {
    if (hk == "")
        return ""
    display := ""
    if InStr(hk, "^")
        display .= "Ctrl + "
    if InStr(hk, "!")
        display .= "Alt + "
    if InStr(hk, "+")
        display .= "Shift + "
    if InStr(hk, "#")
        display .= "Win + "
    key := RegExReplace(hk, "[\^!\+#]", "")
    display .= StrUpper(key)
    return display
}

parse_hotkey_from_display(display) {
    if (display == "")
        return ""
    hk := ""
    if InStr(display, "Ctrl + ")
        hk .= "^"
    if InStr(display, "Alt + ")
        hk .= "!"
    if InStr(display, "Shift + ")
        hk .= "+"
    if InStr(display, "Win + ")
        hk .= "#"
    key := StrReplace(display, "Ctrl + ", "")
    key := StrReplace(key, "Alt + ", "")
    key := StrReplace(key, "Shift + ", "")
    key := StrReplace(key, "Win + ", "")
    if (StrLen(key) > 1 && !InStr(key, "{"))
        key := "{" . key . "}"
    hk .= key
    return hk
}

normalize_hotkey_for_cmp(hk) {
    if (hk == "")
        return ""
    if (InStr(hk, " + ") || InStr(hk, "Ctrl") || InStr(hk, "Alt") || InStr(hk, "Shift") || InStr(hk, "Win"))
        hk := parse_hotkey_from_display(hk)
    return StrLower(parse_hotkey_from_display(format_hotkey_for_display(hk)))
}

class SettingsModel {
    __New() {
        this.original_json_str := ""
        this.original_commands_obj := ""
        this.parsed_import_data := Map()
        this.parsed_import_wb_id := ""
        this.import_items := []
    }

    init() {
        AppSettings.init()
        this.original_json_str := JSON.stringify(AppSettings.commands_obj)
        this.original_commands_obj := JSON.parse(this.original_json_str)
    }

    check_dirty(current_obj) {
        AppSettings.StripEmptyCommandKeys(current_obj)
        current_json := JSON.stringify(current_obj)
        return current_json !== this.original_json_str
    }

    get_unsaved_changes_summary(curr_obj) {
        AppSettings.StripEmptyCommandKeys(curr_obj)
        try {
            orig_obj := JSON.parse(this.original_json_str)
        } catch {
            return "无法解析数据以生成变更列表。"
        }

        diffs := []
        for wb, cmds in curr_obj {
            wb_name := AppSettings.GetWbName(wb)
            wb_diffs := []
            orig_cmds := orig_obj.Has(wb) ? orig_obj[wb] : []

            matched_orig := Map()

            for cmd in cmds {
                cmd_id := cmd.Has("command") ? cmd["command"] : ""
                cmd_desc := cmd.Has("desc") ? cmd["desc"] : ""
                title := (cmd_desc != "") ? cmd_desc : cmd_id

                matched_idx := 0
                ; 优先按 command + desc 精确匹配未使用的原始项
                for i, orig in orig_cmds {
                    if (matched_orig.Has(i))
                        continue
                    if (orig.Has("command") && orig["command"] == cmd_id && (orig.Has("desc") ? orig["desc"] : "") == cmd_desc) {
                        matched_idx := i
                        break
                    }
                }
                ; 若没有，退而按 command 匹配未使用的原始项
                if (matched_idx == 0 && cmd_id != "") {
                    for i, orig in orig_cmds {
                        if (matched_orig.Has(i))
                            continue
                        if (orig.Has("command") && orig["command"] == cmd_id) {
                            matched_idx := i
                            break
                        }
                    }
                }

                if (matched_idx == 0) {
                    wb_diffs.Push("  + 新增: " title)
                } else {
                    matched_orig[matched_idx] := true
                    orig_cmd := orig_cmds[matched_idx]
                    if (JSON.stringify(cmd) != JSON.stringify(orig_cmd)) {
                        wb_diffs.Push("  * 修改: " title)
                    }
                }
            }

            for i, orig in orig_cmds {
                if (!matched_orig.Has(i)) {
                    title := orig.Has("desc") && orig["desc"] != "" ? orig["desc"] : (orig.Has("command") ? orig["command"] : "未知")
                    wb_diffs.Push("  - 删除: " title)
                }
            }

            if (wb_diffs.Length > 0) {
                diffs.Push("【工作台: " wb_name "】")
                diffs.Push(wb_diffs*)
            }
        }

        for wb, cmds in orig_obj {
            if !curr_obj.Has(wb) {
                wb_name := AppSettings.GetWbName(wb)
                diffs.Push("【工作台: " wb_name "】")
                diffs.Push("  - 整个工作台被移除")
            }
        }

        if (diffs.Length == 0)
            return "检测到深层属性变更，无命令级差异。"

        summary := ""
        count := 0
        for item in diffs {
            if (count >= 15) {
                summary .= "  ... 以及其他未显示的修改`n"
                break
            }
            summary .= item "`n"
            count++
        }
        return Trim(summary, "`n")
    }

    validate_no_duplicates(curr_obj) {
        owner_opt := "Icon! 16" . (SettingsController.instance && SettingsController.instance.is_valid() ? " Owner" . SettingsController.instance.view.Hwnd : "")
        for wb, cmdArray in curr_obj {
            wb_name := AppSettings.GetWbName(wb)
            used_aliases := Map()
            used_hotkeys := Map()
            for idx, cmd in cmdArray {
                title := (cmd.Has("desc") && cmd["desc"] != "") ? cmd["desc"] : (cmd.Has("command") ? cmd["command"] : "未知命令")
                if (cmd.Has("aliases")) {
                    for al in cmd["aliases"] {
                        al_clean := Trim(al)
                        if (al_clean == "")
                            continue
                        al_lower := StrLower(al_clean)
                        if (used_aliases.Has(al_lower)) {
                            prev_title := used_aliases[al_lower]
                            MsgBox("在工作台「" . wb_name . "」内发现重复别名！`n`n别名：「" . al_clean . "」`n冲突命令 1：「" . prev_title . "」`n冲突命令 2：「" . title . "」`n`n同一个工作台内的别名不允许重复，请修改为唯一别名后再保存。", "用户别名已存在", owner_opt)
                            return false
                        }
                        used_aliases[al_lower] := title
                    }
                }
                if (cmd.Has("hotkeys")) {
                    for hk in cmd["hotkeys"] {
                        hk_clean := Trim(hk)
                        if (hk_clean == "")
                            continue
                        hk_norm := normalize_hotkey_for_cmp(hk_clean)
                        if (used_hotkeys.Has(hk_norm)) {
                            prev_title := used_hotkeys[hk_norm]
                            MsgBox("在工作台「" . wb_name . "」内发现重复快捷键！`n`n快捷键：「" . format_hotkey_for_display(hk_clean) . "」`n冲突命令 1：「" . prev_title . "」`n冲突命令 2：「" . title . "」`n`n同一个工作台内的快捷键不允许重复，请修改为唯一快捷键后再保存。", "快捷键已存在", owner_opt)
                            return false
                        }
                        used_hotkeys[hk_norm] := title
                    }
                }
            }
        }
        return true
    }

    flush_commands_json(curr_obj) {
        if (!this.validate_no_duplicates(curr_obj)) {
            return false
        }
        AppSettings.commands_obj := curr_obj
        try {
            AppSettings.FlushCommands()
            return true
        } catch Error as e {
            MsgBox("写入 JSON 文件失败: " e.Message, "错误", 16)
            return false
        }
    }

    save_integration_settings(autoImeEnabled, everythingEnabled, everythingPath, everythingHotkey, volumeEnabled, calcEnabled, calcHotkey, catiaMButtonEnabled) {
        try {
            if !AppSettings.config_obj.Has("AutoIME") {
                AppSettings.config_obj["AutoIME"] := Map()
            }
            AppSettings.config_obj["AutoIME"]["Enabled"] := String(autoImeEnabled)
            AppSettings.AutoIME_Enabled := autoImeEnabled

            if !AppSettings.config_obj.Has("Everything") {
                AppSettings.config_obj["Everything"] := Map("Enabled", "0", "Path", "", "Hotkey", "")
            }
            AppSettings.config_obj["Everything"]["Enabled"] := String(everythingEnabled)
            AppSettings.config_obj["Everything"]["Path"] := everythingPath
            AppSettings.config_obj["Everything"]["Hotkey"] := everythingHotkey
            AppSettings.Everything_Enabled := everythingEnabled
            AppSettings.Everything_Path := everythingPath
            AppSettings.Everything_Hotkey := everythingHotkey

            if !AppSettings.config_obj.Has("Volume") {
                AppSettings.config_obj["Volume"] := Map("Enabled", "0")
            }
            AppSettings.config_obj["Volume"]["Enabled"] := String(volumeEnabled)

            if !AppSettings.config_obj.Has("Calculator") {
                AppSettings.config_obj["Calculator"] := Map("Enabled", "0", "Hotkey", "")
            }
            AppSettings.config_obj["Calculator"]["Enabled"] := String(calcEnabled)
            AppSettings.config_obj["Calculator"]["Hotkey"] := calcHotkey

            if !AppSettings.config_obj.Has("CatiaMButton") {
                AppSettings.config_obj["CatiaMButton"] := Map("Enabled", "0")
            }
            AppSettings.config_obj["CatiaMButton"]["Enabled"] := String(catiaMButtonEnabled)

            AppSettings.FlushConfig()
            return true
        } catch Error as e {
            MsgBox("保存集成设置失败: " e.Message, "错误", 16)
            return false
        }
    }

    save_general_settings(startupEnabled, desktopShortcutEnabled, updaterEnabled, updaterChannel, configDir := "") {
        try {
            StartupManager.SetStartup(startupEnabled)
            if (desktopShortcutEnabled) {
                ShortcutManager.CreateDesktopShortcut()
            } else if FileExist(A_Desktop "\UCLC.lnk") {
                try FileDelete(A_Desktop "\UCLC.lnk")
            }
            targetDir := Trim(configDir) == "" ? AppSettings.DefaultConfigDir : Trim(configDir)
            if (targetDir != AppSettings.ConfigDir) {
                AppSettings.SaveConfigDir(targetDir)
            }

            if !AppSettings.config_obj.Has("Updater") {
                AppSettings.config_obj["Updater"] := Map()
            }
            AppSettings.config_obj["Updater"]["Enabled"] := String(updaterEnabled)
            AppSettings.config_obj["Updater"]["Channel"] := updaterChannel
            AppSettings.Updater_Enabled := Integer(updaterEnabled)
            AppSettings.Updater_Channel := updaterChannel

            AppSettings.FlushConfig()
            return true
        } catch Error as e {
            MsgBox("保存常规设置失败: " e.Message, "错误", 16)
            return false
        }
    }

    save_advanced_settings(debugEnabled) {
        try {
            if !AppSettings.config_obj.Has("通用") {
                AppSettings.config_obj["通用"] := Map("DEBUG", "0")
            }
            AppSettings.config_obj["通用"]["DEBUG"] := String(debugEnabled)
            AppSettings.DEBUG_I := debugEnabled

            AppSettings.FlushConfig()
            return true
        } catch Error as e {
            MsgBox("保存高级设置失败: " e.Message, "错误", 16)
            return false
        }
    }

    parse_import_file(filepath) {
        content := FileRead(filepath, "UTF-8")
        if (!InStr(content, "Workshop Exposition") || InStr(content, Chr(0xFFFD))) {
            content := FileRead(filepath, "CP0")
            if !InStr(content, "Workshop Exposition") {
                throw Error("所选文件非有效的 Workshop Exposition 导出文件！")
            }
        }

        parsed_commands := Map()
        wb_id := ""
        current_title := ""

        loop parse content, "`n", "`r" {
            line := Trim(A_LoopField)
            if RegExMatch(line, "^Workshop Exposition of\s+(.+)$", &match) {
                if (wb_id == "")
                    wb_id := Trim(match[1])
            } else if RegExMatch(line, "^Title=\s*(.+)$", &match) {
                current_title := Trim(match[1])
            } else if RegExMatch(line, "^Id\s*=\s*(.+)$", &match) {
                if (current_title != "") {
                    parsed_commands[Trim(match[1])] := current_title
                    current_title := ""
                }
            }
        }

        this.parsed_import_data := parsed_commands
        this.parsed_import_wb_id := wb_id
        return { data: parsed_commands, wb_id: wb_id }
    }

    calculate_import_diff(target_wb) {
        parsed_commands := this.parsed_import_data
        if (!parsed_commands || parsed_commands.Count == 0) {
            this.import_items := []
            return []
        }

        local_array := AppSettings.commands_obj.Has(target_wb) ? AppSettings.commands_obj[target_wb] : []

        local_by_id := Map()
        local_by_title := Map()
        for cmd in local_array {
            local_by_id[cmd["command"]] := cmd
            desc := (cmd.Has("desc") && cmd["desc"] != "") ? cmd["desc"] : cmd["command"]
            if desc != ""
                local_by_title[desc] := cmd
        }

        import_items := []
        matched_local_ids := Map()

        for id, title in parsed_commands {
            if local_by_id.Has(id) {
                local_desc := (local_by_id[id].Has("desc") && local_by_id[id]["desc"] != "") ? local_by_id[id]["desc"] : local_by_id[id]["command"]
                if (local_desc == title) {
                    import_items.Push({ title: title, local_id: id, action: "=", imported_id: id })
                } else {
                    import_items.Push({ title: title, local_id: local_by_id[id]["command"], action: "T", imported_id: id })
                }
                matched_local_ids[id] := true
            } else if local_by_title.Has(title) {
                old_id := local_by_title[title]["command"]
                import_items.Push({ title: title, local_id: old_id, action: "C", imported_id: id })
                matched_local_ids[old_id] := true
            } else {
                import_items.Push({ title: title, local_id: "", action: "+", imported_id: id })
            }
        }

        for cmd in local_array {
            id := cmd["command"]
            if !matched_local_ids.Has(id) {
                desc := (cmd.Has("desc") && cmd["desc"] != "") ? cmd["desc"] : cmd["command"]
                import_items.Push({ title: desc, local_id: id, action: "D", imported_id: "" })
            }
        }

        this.import_items := import_items
        return import_items
    }
}


class SettingsView extends Gui {
    __New() {
        super.__New("-Resize -MaximizeBox", "UCLC 配置管理")

        this.tabs := this.Add("Tab3", "x10 y10 w530 h460", ["命令", "集成", "常规", "高级"])

        ; =============== 第一页: 命令配置 ===============
        this.tabs.UseTab(1)

        ; ====================
        ; 左侧：命令树与导入
        ; ====================
        this.tv_alias := this.Add("TreeView", "x20 y45 w190 h330")
        this.Btn_OpenCmdLib := this.Add("Button", "x20 y380 w190 h28", "导入命令ID")
        this.Btn_OpenCmdLib.ToolTip := "从本地文件批量导入新的命令"

        ; ====================
        ; 右侧上：全局检索区
        ; ====================
        this.Add("Text", "x235 y45 w60", "工作台:")
        this.ddl_workbench := this.Add("DropDownList", "x295 y40 w195 Choose1", ["全部工作台"])
        this.ddl_workbench.ToolTip := "按所属工作台过滤左侧命令列表"

        this.Add("Text", "x235 y75 w60", "搜　索:")
        this.edit_search := this.Add("Edit", "x295 y72 w195")
        this.edit_search.ToolTip := "支持拼音首字母模糊匹配"

        ; 分割线
        this.Add("Text", "x230 y100 w270 h1 0x10")

        ; ====================
        ; 右侧下：详情编辑区
        ; ====================
        this.Add("Text", "x230 y115 w270 c0055AA", "■ 命令详细属性")

        this.tabs.UseTab(1)
        this.Txt_Cat := this.Add("Text", "x235 y141 w60 Hidden", "所属模块:")
        this.Txt_CatVal := this.Add("Text", "x295 y141 w195 cBlue Hidden", "")

        this.Txt_Desc := this.Add("Text", "x235 y171 w60 Hidden", "功能描述:")
        this.Txt_Desc.ToolTip := "显示该命令的具体功能说明"
        this.edit_desc := this.Add("Edit", "x295 y168 w195 Hidden ReadOnly", "")
        this.edit_desc.ToolTip := "显示该命令的具体功能说明"

        this.Txt_Cmd := this.Add("Text", "x235 y201 w60 Hidden", "执行指令:")
        this.Txt_Cmd.ToolTip := "底层 CATIA 命令标识符，通常自动导入生成，无需手动修改"
        this.Edit_Cmd := this.Add("Edit", "x295 y198 w195 Hidden ReadOnly", "")
        this.Edit_Cmd.ToolTip := "底层 CATIA 命令标识符，通常自动导入生成，无需手动修改"

        this.Txt_Alias := this.Add("Text", "x235 y231 w60 Hidden", "触发别名:")
        this.Txt_Alias.ToolTip := "在 CATIA 绘图区内直接输入这些字母即可快速触发该命令"

        this.alias_pool := []
        loop 10 {
            e := this.Add("Edit", "x295 y0 w135 Hidden Uppercase", "")
            btn_add := this.Add("Button", "x440 y0 w24 h24 Hidden", "➕")
            btn_del := this.Add("Button", "x466 y0 w24 h24 Hidden", "➖")
            this.alias_pool.Push({ e: e, add: btn_add, del: btn_del })
        }

        this.Txt_Hotkey := this.Add("Text", "x235 y0 w60 Hidden", "绑定热键:")
        this.Txt_Hotkey.ToolTip := "绑定全局键盘快捷键（例如：Ctrl+Shift+A），按下即触发"
        this.hotkey_pool := []
        loop 10 {
            e := this.Add("Edit", "x295 y0 w135 Hidden", "")
            SendMessage(0x1501, 1, StrPtr("直接按键录入"), e.Hwnd)
            btn_add := this.Add("Button", "x440 y0 w24 h24 Hidden", "➕")
            btn_del := this.Add("Button", "x466 y0 w24 h24 Hidden", "➖")
            this.hotkey_pool.Push({ e: e, add: btn_add, del: btn_del })
        }

        this.Btn_Revert := this.Add("Button", "x250 y285 w105 h28 Hidden Disabled", "撤销修改")
        this.btn_save := this.Add("Button", "x385 y285 w105 h28 Disabled", "保存修改")
        this.SB := this.Add("StatusBar")
        version_str := AppSettings.Version
        ; 动态计算分段位置（收紧字宽：英文约 6.5px，加上 15px 边距）
        part1_width := 550 - (StrLen(RegExReplace(version_str, "[^\x00-\xff]", "xx")) * 6.5 + 15)
        this.SB.SetParts(part1_width)
        this.SB.SetText(version_str, 2)

        ; =============== 第二页: 集成 (Integration) ===============
        this.tabs.UseTab(2)

        ; ====================
        ; 左侧：集成分类列表
        ; ====================
        this.lb_integration := this.Add("ListBox", "x20 y45 w180 h330 Choose1", ["1. CATIA 中键增强", "2. 输入法自动切换", "3. Everything 快速呼出", "4. 系统快捷键"])
        this.lb_integration.ToolTip := "点击左侧类别，右侧切换显示对应的配置面板"

        ; ====================
        ; 右侧上：分类标题与分割线
        ; ====================
        this.lbl_intTitle := this.Add("Text", "x220 y45 w300 c0055AA", "■ CATIA 中键增强设置")
        this.lbl_intTitle.SetFont("w700")
        this.Add("Text", "x220 y65 w300 h1 0x10")

        ; ====================
        ; 右侧下：分类动态设置面板
        ; ====================
        this.int_panes := [[], [], [], []]

        ; [1] CATIA 面板
        c1_chk := this.Chk_CatiaMButton := this.Add("Checkbox", "x225 y85", "中键功能增强")
        c1_chk.ToolTip := "在 CATIA 弹窗中：Alt + 中键 = 确认，Shift + 中键 = 预览"
        c1_desc := this.Add("Text", "x225 y120 w290 c666666", "说明：增强 CATIA 弹窗中的鼠标中键组合快捷键：`n`n• Alt ＋ 中键 ＝ 确认 (OK)`n• Shift ＋ 中键 ＝ 预览 (Preview)")
        this.int_panes[1].Push(c1_chk, c1_desc)

        ; [2] 输入法自动切换面板
        c2_chk := this.Chk_AutoIME := this.Add("Checkbox", "x225 y85", "输入法自动切换")
        c2_chk.ToolTip := "保持英文状态可避免在使用命令别名时误触中文输入法"
        c2_btn := this.Btn_ManageIME := this.Add("Button", "x355 y81 w80 h24", "配置")
        c2_desc := this.Add("Text", "x225 y125 w290 c666666", "说明：切换至设定的 CAD/建模软件（如 CATIA、SolidWorks）时，自动切换为英文输入法，避免输入命令时被拼音打断。")
        this.int_panes[2].Push(c2_chk, c2_btn, c2_desc)

        ; [3] Everything 快速呼出面板
        c3_chk := this.Chk_Everything := this.Add("Checkbox", "x225 y85", "Everything 快速呼出")
        c3_chk.ToolTip := "双击右 Ctrl 键或按下设定快捷键唤起 Everything"
        c3_lbl := this.Add("Text", "x225 y120 w290", "Everything.exe 可执行文件路径:")
        c3_edit := this.Edit_EverythingPath := this.Add("Edit", "x225 y140 w255 h24", "")
        c3_btn := this.Btn_BrowseEverything := this.Add("Button", "x485 y139 w35 h24", "...")
        c3_btn.ToolTip := "选择 Everything.exe 所在路径"
        c3_lbl2 := this.Add("Text", "x225 y178 w150", "显示窗口快捷键 (热键):")
        c3_hkedit := this.Edit_EverythingHotkey := this.Add("Edit", "x380 y175 w140 h24", "")
        c3_desc := this.Add("Text", "x225 y210 w290 h140 c666666", "说明：支持双击【右 Ctrl】或按设定的热键唤起 Everything。`n`n💡 提示：本软件仅读取热键配置。如需修改，请在 Everything「选项」->「键盘」->「显示窗口」中设置，完成后重新载入本脚本生效。")
        this.int_panes[3].Push(c3_chk, c3_lbl, c3_edit, c3_btn, c3_lbl2, c3_hkedit, c3_desc)

        ; [4] 系统快捷键面板
        c4_chk1 := this.Chk_Volume := this.Add("Checkbox", "x225 y85", "音量快速调节")
        c4_chk1.ToolTip := "按住 右Alt 键并滚动鼠标滚轮调节音量，点击鼠标中键静音"
        c4_desc1 := this.Add("Text", "x240 y110 w275 c666666", "• 按住【右Alt】＋ 鼠标滚轮：上下调节系统音量`n• 点击【鼠标滚轮（中键）】：一键静音/解除静音")
        c4_div := this.Add("Text", "x225 y160 w290 h1 0x10")
        c4_chk2 := this.Chk_Calc := this.Add("Checkbox", "x225 y175", "打开计算器")
        c4_chk2.ToolTip := "快捷唤起系统自带计算器，多次按下可在前后台间捞起窗口"
        c4_edit := this.Edit_CalcHotkey := this.Add("Edit", "x315 y172 w140 h24", "")
        c4_edit.ToolTip := "鼠标点进热键录入框里，直接按下你想绑定的快捷键组合"
        SendMessage(0x1501, 1, StrPtr("点击录入热键"), c4_edit.Hwnd)
        c4_desc2 := this.Add("Text", "x225 y215 w290 c666666", "说明：录入组合快捷键（如 Win + C）。按下即可快速呼出或隐藏系统计算器，方便切换使用。")
        this.int_panes[4].Push(c4_chk1, c4_desc1, c4_div, c4_chk2, c4_edit, c4_desc2)

        this.SwitchIntegrationPane(1)
        this.btn_saveIntegration := this.Add("Button", "x385 y385 w145 h30 Default", "保存集成设置")

        ; =============== 第三页: 常规 (General) ===============
        this.tabs.UseTab(3)
        this.Add("GroupBox", "x20 y40 w510 h70", "启动选项")
        this.Chk_Startup := this.Add("Checkbox", "x40 y68", "跟随系统启动")
        this.Chk_DesktopShortcut := this.Add("Checkbox", "x220 y68", "桌面快捷方式")
        this.Chk_DesktopShortcut.Value := FileExist(A_Desktop "\UCLC.lnk") ? 1 : 0

        this.Add("GroupBox", "x20 y125 w510 h115", "个人配置")
        this.Add("Text", "x40 y153 w65", "存储路径:")
        this.Edit_ConfigDir := this.Add("Edit", "x105 y150 w320 h24", AppSettings.ConfigDir)
        this.Edit_ConfigDir.ToolTip := "  配置文件的存放路径，点击【选择...】可自定义目标目录"
        this.Btn_BrowseConfigDir := this.Add("Button", "x435 y149 w65 h25", "选择...")
        this.Btn_ImportConfig := this.Add("Button", "x40 y192 w140 h26 +Disabled", "📥 导入备份配置")
        this.Btn_ExportConfig := this.Add("Button", "x190 y192 w140 h26 +Disabled", "📤 导出备份配置")

        this.Add("GroupBox", "x20 y255 w510 h85", "软件更新")
        this.Chk_Updater := this.Add("Checkbox", "x40 y282", "启用自动检查更新")
        this.Add("Text", "x220 y283 w65", "更新分支:")
        choose_idx := (AppSettings.Updater_Channel == "Preview") ? 2 : 1
        this.Ddl_UpdaterChannel := this.Add("DropDownList", "x285 y279 w150 Choose" . choose_idx, ["稳定版", "预览版"])
        this.Btn_CheckUpdate := this.Add("Button", "x440 y278 w65 h25", "检查更新")
        avail_ver := ""
        try avail_ver := StateManager.Get("AvailableUpdateVersion", "")
        has_notice := (AppSettings.Updater_Enabled && avail_ver != "")
        is_preview := (InStr(avail_ver, "-") || InStr(avail_ver, "dev") || InStr(avail_ver, "beta") || InStr(avail_ver, "alpha") || InStr(avail_ver, "rc") || InStr(avail_ver, "preview"))
        ver_tag := is_preview ? " [预览版]" : " [稳定版]"
        this.Lbl_UpdateNotice := this.Add("Text", "x40 y312 w340 cRed w700" . (has_notice ? "" : " Hidden"), has_notice ? "✨ 发现新版本 " avail_ver ver_tag "！" : "")
        this.Link_ViewUpdate := this.Add("Link", "x390 y312 w130" . (has_notice ? "" : " Hidden"), '<a id="view_update">查看更新内容</a>')

        this.btn_saveGeneral := this.Add("Button", "x385 y385 w145 h30 Default", "保存常规设置")

        ; =============== 第四页: 高级 (Advanced) ===============
        this.tabs.UseTab(4)
        this.Add("GroupBox", "x20 y40 w510 h110", "调试与运行诊断")
        this.Chk_Debug := this.Add("Checkbox", "x35 y65 +Disabled", "开启详细 Debug 调试日志")
        this.Chk_Debug.ToolTip := "警告：仅在排查软件 Bug 时开启，日常使用请务必关闭以防产生大量冗余日志文件"

        this.btn_saveAdvanced := this.Add("Button", "x385 y385 w145 h30 Default", "保存高级设置")

        ; =============== (原第三页工作台命令库已重构成弹窗) ===============
    }

    clear_detail_pane() {
        this.Txt_Cat.Opt("Hidden")
        this.Txt_CatVal.Opt("Hidden")
        this.Txt_Desc.Opt("Hidden")
        this.edit_desc.Opt("Hidden")
        this.Txt_Cmd.Opt("Hidden")
        this.Edit_Cmd.Opt("Hidden")
        this.Txt_Alias.Opt("Hidden")

        for p in this.alias_pool {
            p.e.Opt("Hidden")
            p.add.Opt("Hidden")
            p.del.Opt("Hidden")
        }

        this.Txt_Hotkey.Opt("Hidden")
        for p in this.hotkey_pool {
            p.e.Opt("Hidden")
            p.add.Opt("Hidden")
            p.del.Opt("Hidden")
        }

        this.Btn_Revert.Opt("Hidden")
    }

    render_detail_panel(wb_name, cmd) {
        this.Txt_CatVal.Value := wb_name
        this.edit_desc.Value := cmd.Has("desc") ? cmd["desc"] : ""
        this.Edit_Cmd.Value := cmd.Has("command") ? cmd["command"] : ""

        this.Txt_Cat.Opt("-Hidden")
        this.Txt_CatVal.Opt("-Hidden")
        this.Txt_Desc.Opt("-Hidden")
        this.edit_desc.Opt("-Hidden")
        this.Txt_Cmd.Opt("-Hidden")
        this.Edit_Cmd.Opt("-Hidden")
        this.Txt_Alias.Opt("-Hidden")

        cur_y := 228
        aliases := (cmd.Has("aliases") && cmd["aliases"].Length > 0) ? cmd["aliases"] : [""]
        alias_edits := []

        for idx, al in aliases {
            if (idx > 10)
                break
            p := this.alias_pool[idx]
            p.e.Value := al
            p.e.Move(, cur_y)
            p.add.Move(, cur_y)
            p.del.Move(, cur_y)

            p.e.Opt("-Hidden")
            p.add.Opt("-Hidden")
            p.del.Opt("-Hidden")

            p.add.Opt((Trim(al) != "") ? "-Disabled" : "+Disabled")
            p.del.Opt((aliases.Length > 1) ? "-Disabled" : "+Disabled")
            alias_edits.Push(p.e)
            cur_y += 28
        }

        cur_y += 6
        this.Txt_Hotkey.Move(, cur_y + 3)
        this.Txt_Hotkey.Opt("-Hidden")

        hotkeys := (cmd.Has("hotkeys") && cmd["hotkeys"].Length > 0) ? cmd["hotkeys"] : [""]
        hotkey_edits := []

        for idx, hk in hotkeys {
            if (idx > 10)
                break
            p := this.hotkey_pool[idx]
            try p.e.Value := format_hotkey_for_display(hk)
            catch
                p.e.Value := ""
            p.e.Move(, cur_y)
            p.add.Move(, cur_y)
            p.del.Move(, cur_y)

            p.e.Opt("-Hidden")
            p.add.Opt("-Hidden")
            p.del.Opt("-Hidden")

            p.add.Opt((Trim(hk) != "") ? "-Disabled" : "+Disabled")
            p.del.Opt((hotkeys.Length > 1) ? "-Disabled" : "+Disabled")
            hotkey_edits.Push(p.e)
            cur_y += 28
        }

        cur_y += 12
        this.Btn_Revert.Move(250, cur_y)
        this.btn_save.Move(385, cur_y)
        this.Btn_Revert.Opt("-Hidden")

        return { alias_edits: alias_edits, hotkey_edits: hotkey_edits }
    }

    SwitchIntegrationPane(idx) {
        titles := ["■ CATIA 中键增强设置", "■ 输入法自动化控制", "■ Everything 快速呼出", "■ 系统级全局快捷键"]
        if (idx >= 1 && idx <= titles.Length)
            this.lbl_intTitle.Text := titles[idx]
        for i, pane in this.int_panes {
            for ctrl in pane {
                ctrl.Visible := (i == idx)
            }
        }
    }
}


class SettingsController {
    static instance := ""

    __New(model, view) {
        this.model := model
        this.view := view
        this.BindEvents()

        this.tv_map := Map()
        this.alias_edits := []
        this.hotkey_edits := []
    }

    is_valid() {
        try return this.HasProp("view") && this.view && WinExist(this.view.Hwnd) != 0
        catch
            return false
    }

    show() {
        this.model.init()
        this.LoadGeneralSettings()
        this.load_command_tree()
        this.OnLButtonDownBound := ObjBindMethod(this, "on_lbutton_down")
        OnMessage(0x0201, this.OnLButtonDownBound)
        this.OnKeyDownBound := ObjBindMethod(this, "OnKeyDown")
        OnMessage(0x0100, this.OnKeyDownBound)

        tips_file := A_ScriptDir "\data\tips.json"
        if FileExist(tips_file) {
            try {
                tips_array := JSON.parse(FileRead(tips_file, "UTF-8"))
                if (tips_array.Length > 0)
                    this.view.SB.SetText(" " . tips_array[Random(1, tips_array.Length)])
            }
        }

        this.view.Show("w550 h440")
    }

    OnKeyDown(wParam, lParam, msg, hwnd) {
        if (wParam == 0x2E && this.HasProp("view") && this.view && this.view.tv_alias && hwnd == this.view.tv_alias.Hwnd) {
            selected_item := this.view.tv_alias.GetSelection()
            if (selected_item && this.tv_map.Has(selected_item) && this.tv_map[selected_item].type == "Item") {
                this.delete_command_item(selected_item)
                return 0
            }
        }
    }

    BindEvents() {
        this.view.OnEvent("Close", ObjBindMethod(this, "OnClose"))
        this.view.Ddl_UpdaterChannel.OnEvent("Change", ObjBindMethod(this, "OnUpdaterChannelChange"))
        this.view.Btn_CheckUpdate.OnEvent("Click", (*) => UCLCUpdater.CheckForUpdate(true, this.view))
        this.view.Link_ViewUpdate.OnEvent("Click", ObjBindMethod(this, "OnViewUpdateClick"))
        this.view.OnEvent("Escape", ObjBindMethod(this, "OnClose"))
        this.on_mouse_move_bound := ObjBindMethod(this, "on_mouse_move")
        OnMessage(0x0200, this.on_mouse_move_bound)

        this.view.ddl_workbench.OnEvent("Change", ObjBindMethod(this, "OnWorkbenchFilter"))
        this.view.edit_search.OnEvent("Change", ObjBindMethod(this, "OnSearchFilter"))
        this.view.tv_alias.OnEvent("ItemSelect", ObjBindMethod(this, "on_command_tree_select"))
        this.view.tv_alias.OnEvent("ContextMenu", ObjBindMethod(this, "on_command_tree_context_menu"))

        for idx, p in this.view.alias_pool {
            p.add.OnEvent("Click", ObjBindMethod(this, "OnAddAlias", idx))
            p.del.OnEvent("Click", ObjBindMethod(this, "OnDelAlias", idx))
            p.e.OnEvent("Change", ObjBindMethod(this, "OnAliasChange", idx))
            p.e.OnEvent("LoseFocus", ObjBindMethod(this, "OnAliasLoseFocus", idx))
        }

        for idx, p in this.view.hotkey_pool {
            p.add.OnEvent("Click", ObjBindMethod(this, "OnAddHotkey", idx))
            p.del.OnEvent("Click", ObjBindMethod(this, "OnDelHotkey", idx))
            p.e.OnEvent("Change", ObjBindMethod(this, "OnHotkeyChange", idx))
            p.e.OnEvent("Focus", ObjBindMethod(this, "OnHotkeyFocus", idx))
            p.e.OnEvent("LoseFocus", ObjBindMethod(this, "OnHotkeyLoseFocus", idx))
        }

        this.view.Btn_Revert.OnEvent("Click", ObjBindMethod(this, "OnRevertChanges"))
        this.view.btn_save.OnEvent("Click", ObjBindMethod(this, "SaveCurrentItem"))

        this.view.Btn_BrowseEverything.OnEvent("Click", ObjBindMethod(this, "BrowseEverything"))
        this.view.Btn_BrowseConfigDir.OnEvent("Click", ObjBindMethod(this, "BrowseConfigDir"))
        this.view.btn_saveIntegration.OnEvent("Click", ObjBindMethod(this, "SaveIntegrationSettings"))
        this.view.btn_saveGeneral.OnEvent("Click", ObjBindMethod(this, "SaveGeneralSettings"))
        this.view.btn_saveAdvanced.OnEvent("Click", ObjBindMethod(this, "SaveAdvancedSettings"))
        this.view.Btn_ImportConfig.OnEvent("Click", ObjBindMethod(this, "ImportConfigFile"))
        this.view.Btn_ExportConfig.OnEvent("Click", ObjBindMethod(this, "ExportConfigFile"))
        this.view.Ddl_UpdaterChannel.OnEvent("Change", ObjBindMethod(this, "OnUpdaterChannelChange"))

        this.view.Edit_CalcHotkey.OnEvent("Focus", ObjBindMethod(this, "OnCalcHotkeyFocus"))
        this.view.Edit_CalcHotkey.OnEvent("LoseFocus", ObjBindMethod(this, "OnCalcHotkeyLoseFocus"))
        this.view.Edit_EverythingHotkey.OnEvent("Focus", ObjBindMethod(this, "OnEverythingHotkeyFocus"))
        this.view.Edit_EverythingHotkey.OnEvent("LoseFocus", ObjBindMethod(this, "OnEverythingHotkeyLoseFocus"))

        this.view.lb_integration.OnEvent("Change", ObjBindMethod(this, "OnIntegrationSelect"))
        this.view.Chk_AutoIME.OnEvent("Click", ObjBindMethod(this, "OnToggleAutoIME"))
        this.view.Btn_ManageIME.OnEvent("Click", ObjBindMethod(this, "OnOpenImeRulesModal"))

        this.view.Btn_OpenCmdLib.OnEvent("Click", ObjBindMethod(this, "OnOpenCmdLibraryModal"))
    }

    LoadGeneralSettings() {
        this.view.Chk_Everything.Value := AppSettings.Everything_Enabled
        this.view.Edit_EverythingPath.Value := AppSettings.Everything_Path
        this.view.Edit_EverythingHotkey.Value := AppSettings.Everything_Hotkey

        this.view.Chk_Debug.Value := 0
        this.view.Chk_Debug.Opt("+Disabled")
        this.view.Chk_AutoIME.Value := AppSettings.AutoIME_Enabled

        this.view.Chk_Updater.Value := AppSettings.Updater_Enabled
        this.view.Ddl_UpdaterChannel.Choose(AppSettings.Updater_Channel == "Preview" ? 2 : 1)

        this.view.Chk_Startup.Value := StartupManager.IsEnabled()
        this.view.Edit_ConfigDir.Value := AppSettings.ConfigDir

        if AppSettings.config_obj.Has("Volume")
            this.view.Chk_Volume.Value := Integer(AppSettings.config_obj["Volume"]["Enabled"])
        if AppSettings.config_obj.Has("Calculator") {
            this.view.Chk_Calc.Value := Integer(AppSettings.config_obj["Calculator"]["Enabled"])
            this.view.Edit_CalcHotkey.Value := AppSettings.config_obj["Calculator"]["Hotkey"]
            if (this.view.Edit_CalcHotkey.Value == "") {
                this.view.Chk_Calc.Opt("+Disabled")
                this.view.Chk_Calc.Value := 0
            } else {
                this.view.Chk_Calc.Opt("-Disabled")
            }
        }
        if AppSettings.config_obj.Has("CatiaMButton") {
            this.view.Chk_CatiaMButton.Value := Integer(AppSettings.config_obj["CatiaMButton"]["Enabled"])
        }

        this.OnToggleAutoIME()

        sort_str := ""
        for k, v in AppSettings.commands_obj {
            if (k != "_comment") {
                sort_str .= AppSettings.GetWbName(k) "|||" k "`n"
            }
        }
        sort_str := Sort(Trim(sort_str, "`n"))

        wb_list := ["全部工作台"]
        this.workbench_ids := [""]
        this.import_wb_ids := [""]
        wb_list3 := ["通过导入文件确定"]
        loop parse sort_str, "`n", "`r" {
            if (A_LoopField == "") {
                continue
            }
            parts := StrSplit(A_LoopField, "|||")
            wb_list.Push(parts[1])
            this.workbench_ids.Push(parts[2])
            wb_list3.Push(parts[1])
            this.import_wb_ids.Push(parts[2])
        }

        this.view.ddl_workbench.Delete()
        this.view.ddl_workbench.Add(wb_list)
        this.view.ddl_workbench.Choose(1)

        if (this.view.HasProp("ddl_import_wb") && this.view.ddl_import_wb) {
            try {
                this.view.ddl_import_wb.Delete()
                this.view.ddl_import_wb.Add(wb_list3)
                this.view.ddl_import_wb.Choose(1)
            }
        }
    }

    OnClose(*) {
        if (this.HasProp("model") && this.model && this.model.original_json_str != "") {
            this.SaveInputsToCurrentCmd()
            if (this.model.check_dirty(AppSettings.commands_obj)) {
                summary := this.model.get_unsaved_changes_summary(AppSettings.commands_obj)
                this.view.Opt("+OwnDialogs")
                result := MsgBox("当前配置有未保存的修改：`n`n" summary "`n`n是否在退出前保存？", "未保存的修改", "YesNoCancel Icon?")
                if (result == "Cancel") {
                    return true
                } else if (result == "Yes") {
                    this.SaveCurrentItem()
                }
            }
        }
        this._release_all()
    }

    _release_all() {
        ; --- 1. 注销全局消息钩子 ---
        if this.HasProp("OnLButtonDownBound") && this.OnLButtonDownBound {
            OnMessage(0x0201, this.OnLButtonDownBound, 0)
            this.OnLButtonDownBound := ""
        }
        if this.HasProp("on_mouse_move_bound") && this.on_mouse_move_bound {
            OnMessage(0x0200, this.on_mouse_move_bound, 0)
            this.on_mouse_move_bound := ""
        }
        if this.HasProp("OnKeyDownBound") && this.OnKeyDownBound {
            OnMessage(0x0100, this.OnKeyDownBound, 0)
            this.OnKeyDownBound := ""
        }

        ; --- 2. 停止 InputHook ---
        if this.HasProp("ih") && this.ih {
            this.ih.Stop()
            this.ih := ""
        }

        ; --- 3. 销毁物理窗口 & 断开对象引用 ---
        if this.HasProp("view") && this.view {
            this.view.Destroy()
        }

        this.view := ""
        this.model := ""
        this.alias_edits := ""
        this.hotkey_edits := ""
        this.tv_map := ""
    }

    ClearRightPane() {
        this.view.clear_detail_pane()
        this.alias_edits := []
        this.hotkey_edits := []
    }

    GetTreeViewScrollState() {
        if (!this.view || !this.view.tv_alias)
            return { top_cmd: "", hpos: 0 }
        tv_hwnd := this.view.tv_alias.Hwnd
        ; 0x110A = TVM_GETNEXTITEM, 0x0005 = TVGN_FIRSTVISIBLE
        top_hItem := SendMessage(0x110A, 0x0005, 0, tv_hwnd)
        top_cmd := ""
        if (top_hItem && this.tv_map.Has(top_hItem)) {
            info := this.tv_map[top_hItem]
            if (info.type == "Item")
                top_cmd := info.cmd
        }
        hpos := DllCall("GetScrollPos", "ptr", tv_hwnd, "int", 0, "int") ; SB_HORZ
        return { top_cmd: top_cmd, hpos: hpos }
    }

    load_command_tree(filter := "", select_cmd := "", top_cmd := "", hpos := 0) {
        this.ClearRightPane()
        this.view.tv_alias.Delete()
        this.tv_map.Clear()

        wb_filter_id := ""
        if (this.view.ddl_workbench.Value > 1) {
            wb_filter_id := this.workbench_ids[this.view.ddl_workbench.Value]
        }

        for category, cmdArray in AppSettings.commands_obj {
            if (category == "_comment") {
                continue
            }
            if (wb_filter_id != "" && category != wb_filter_id) {
                continue
            }

            catId := 0
            for index, cmd in cmdArray {
                display_name := (cmd.Has("desc") && cmd["desc"] != "") ? cmd["desc"] : (cmd.Has("command") ? cmd["command"] : "未知")

                if (filter != "") {
                    matched := false
                    if InStr(display_name, filter) || (cmd.Has("command") && InStr(cmd["command"], filter))
                        matched := true
                    if (!matched && cmd.Has("aliases")) {
                        for al in cmd["aliases"] {
                            if InStr(al, filter) {
                                matched := true
                                break
                            }
                        }
                    }
                    if (!matched && cmd.Has("hotkeys")) {
                        for hk in cmd["hotkeys"] {
                            if InStr(hk, filter) {
                                matched := true
                                break
                            }
                        }
                    }
                    if (!matched) {
                        continue
                    }
                }

                if (catId == 0) {
                    catId := this.view.tv_alias.Add(AppSettings.GetWbName(category))
                    this.tv_map[catId] := { type: "Category", name: category }
                }

                itemId := this.view.tv_alias.Add(display_name, catId)
                this.tv_map[itemId] := { type: "Item", category: category, index: index, cmd: cmd }
            }

            if (catId != 0)
                this.view.tv_alias.Modify(catId, "Expand")
        }

        this.CheckGlobalDirty()

        ; 1. 优先还原视口最顶部的第一行可见项目 (Top Visible Item)
        top_item_id := 0
        if (top_cmd != "") {
            for id, info in this.tv_map {
                if (info.type == "Item" && info.cmd == top_cmd) {
                    top_item_id := id
                    break
                }
            }
        }

        if (top_item_id != 0) {
            this.view.tv_alias.Modify(top_item_id, "VisFirst")
        } else {
            first_cat := this.view.tv_alias.GetNext()
            if (first_cat) {
                this.view.tv_alias.Modify(first_cat, "VisFirst")
            }
        }

        ; 2. 选中目标命令项 (Select Target Item)
        target_item_id := 0
        if (select_cmd != "") {
            for id, info in this.tv_map {
                if (info.type == "Item" && info.cmd == select_cmd) {
                    target_item_id := id
                    break
                }
            }
        }

        if (target_item_id != 0) {
            this.view.tv_alias.Modify(target_item_id, "Select")
            this.on_command_tree_select(this.view.tv_alias, target_item_id)
        }

        ; 3. 还原水平滚动条位置
        if (hpos > 0) {
            tv_hwnd := this.view.tv_alias.Hwnd
            DllCall("SetScrollPos", "ptr", tv_hwnd, "int", 0, "int", hpos, "int", 1)
            SendMessage(0x0114, 4 | (hpos << 16), 0, tv_hwnd) ; WM_HSCROLL (SB_THUMBPOSITION)
        }
    }

    OnWorkbenchFilter(CtrlObj, *) {
        if (CtrlObj.Text != "")
            CtrlObj.ToolTip := CtrlObj.Text
        this.load_command_tree(this.view.edit_search.Value)
    }

    OnSearchFilter(CtrlObj, *) {
        this.load_command_tree(CtrlObj.Value)
    }

    on_command_tree_select(GuiCtrlObj, Item) {
        this.ClearRightPane()
        if (!this.tv_map.Has(Item)) {
            return
        }
        info := this.tv_map[Item]
        if (info.type != "Item") {
            return
        }

        this.is_rendering := true
        res := this.view.render_detail_panel(AppSettings.GetWbName(info.category), info.cmd)
        this.alias_edits := res.alias_edits
        this.hotkey_edits := res.hotkey_edits
        this.is_rendering := false

        this.CheckGlobalDirty()
        this.view.SB.SetText("")
    }

    on_command_tree_context_menu(GuiCtrlObj, Item, IsRightClick, X, Y) {
        if (!Item || !this.tv_map.Has(Item)) {
            return
        }
        info := this.tv_map[Item]
        if (info.type != "Item") {
            return
        }

        if (GuiCtrlObj.GetSelection() != Item) {
            GuiCtrlObj.Modify(Item, "Select")
            this.on_command_tree_select(GuiCtrlObj, Item)
        }

        title := (info.cmd.Has("desc") && info.cmd["desc"] != "") ? info.cmd["desc"] : (info.cmd.Has("command") ? info.cmd["command"] : "该命令")
        m := Menu()
        m.Add("删除命令 (" . title . ")", ObjBindMethod(this, "delete_command_item", Item))
        
        if (AppSettings.commands_obj.Count > 1) {
            menu_copy := Menu()
            menu_move := Menu()
            has_other := false
            for wb_id, _ in AppSettings.commands_obj {
                if (wb_id == info.category)
                    continue
                wb_name := AppSettings.GetWbName(wb_id)
                menu_copy.Add(wb_name, ObjBindMethod(this, "copy_command_item", Item, wb_id))
                menu_move.Add(wb_name, ObjBindMethod(this, "move_command_item", Item, wb_id))
                has_other := true
            }
            if (has_other) {
                m.Add()
                m.Add("复制到", menu_copy)
                m.Add("移动到", menu_move)
            }
        }
        
        m.Show()
    }

    resolve_move_collision(new_cmd, target_wb) {
        if (!AppSettings.commands_obj.Has(target_wb))
            return true
            
        target_cmds := AppSettings.commands_obj[target_wb]
        cmd_id := new_cmd.Has("command") ? Trim(new_cmd["command"]) : ""
        
        ; 1. 检查命令ID重复：极简排版提示并停止
        for t_cmd in target_cmds {
            if (cmd_id != "" && t_cmd.Has("command") && Trim(t_cmd["command"]) == cmd_id) {
                t_title := (t_cmd.Has("desc") && t_cmd["desc"] != "") ? t_cmd["desc"] : (t_cmd.Has("command") ? t_cmd["command"] : "未知")
                wb_name := AppSettings.GetWbName(target_wb)
                
                msg := "目标工作台已存在相同命令，无需重复添加。`n`n"
                    . "• 目标工作台：" . wb_name . "`n"
                    . "• 命令 ID：" . cmd_id . "`n"
                    . "• 现有命令：" . t_title
                
                this.view.Opt("+OwnDialogs")
                MsgBox(msg, "命令已存在", "Iconi")
                return false
            }
        }
        
        removed_aliases := []
        removed_hotkeys := []
        
        ; 2. 检查并过滤别名重复：清空/剔除冲突项
        if (new_cmd.Has("aliases") && Type(new_cmd["aliases"]) == "Array") {
            safe_aliases := []
            for al in new_cmd["aliases"] {
                al_clean := Trim(al)
                if (al_clean == "")
                    continue
                conflict := false
                for t_cmd in target_cmds {
                    if (t_cmd.Has("aliases") && Type(t_cmd["aliases"]) == "Array") {
                        for t_al in t_cmd["aliases"] {
                            if (StrLower(al_clean) == StrLower(Trim(t_al))) {
                                conflict := true
                                break
                            }
                        }
                    }
                    if (conflict)
                        break
                }
                if (conflict) {
                    removed_aliases.Push(al_clean)
                } else {
                    safe_aliases.Push(al_clean)
                }
            }
            new_cmd["aliases"] := safe_aliases
        }
        
        ; 3. 检查并过滤热键重复：清空/剔除冲突项
        if (new_cmd.Has("hotkeys") && Type(new_cmd["hotkeys"]) == "Array") {
            safe_hotkeys := []
            for hk in new_cmd["hotkeys"] {
                hk_clean := Trim(hk)
                if (hk_clean == "")
                    continue
                conflict := false
                for t_cmd in target_cmds {
                    if (t_cmd.Has("hotkeys") && Type(t_cmd["hotkeys"]) == "Array") {
                        for t_hk in t_cmd["hotkeys"] {
                            if (StrLower(hk_clean) == StrLower(Trim(t_hk))) {
                                conflict := true
                                break
                            }
                        }
                    }
                    if (conflict)
                        break
                }
                if (conflict) {
                    removed_hotkeys.Push(hk_clean)
                } else {
                    safe_hotkeys.Push(hk_clean)
                }
            }
            new_cmd["hotkeys"] := safe_hotkeys
        }
        
        ; 如果有别名或热键被剔除，给予结构化排版的轻量提示
        if (removed_aliases.Length > 0 || removed_hotkeys.Length > 0) {
            msg := "已完成跨工作台操作，部分冲突配置项已自动重置：`n"
            if (removed_aliases.Length > 0) {
                al_str := ""
                for item in removed_aliases
                    al_str .= (al_str == "" ? "" : "、") . item
                msg .= "`n• 清空的重复别名：" . al_str
            }
            if (removed_hotkeys.Length > 0) {
                hk_str := ""
                for item in removed_hotkeys
                    hk_str .= (hk_str == "" ? "" : "、") . item
                msg .= "`n• 清空的重复热键：" . hk_str
            }
            msg .= "`n`n如有需要，请前往目标工作台重新配置。"
            this.view.Opt("+OwnDialogs")
            MsgBox(msg, "配置项自动重置提示", "Iconi")
        }
        
        return true
    }

    copy_command_item(Item, target_wb, ItemName, ItemPos, MyMenu) {
        if (!Item || !this.tv_map.Has(Item))
            return
        info := this.tv_map[Item]
        cmd := info.cmd
        
        new_cmd := Map()
        for k, v in cmd {
            if (Type(v) == "Array") {
                new_arr := []
                for e in v
                    new_arr.Push(e)
                new_cmd[k] := new_arr
            } else {
                new_cmd[k] := v
            }
        }
        
        if (!this.resolve_move_collision(new_cmd, target_wb))
            return
        
        if (!AppSettings.commands_obj.Has(target_wb))
            AppSettings.commands_obj[target_wb] := []
        AppSettings.commands_obj[target_wb].Push(new_cmd)
        AppSettings.FlushCommands()
        
        title := (new_cmd.Has("desc") && new_cmd["desc"] != "") ? new_cmd["desc"] : (new_cmd.Has("command") ? new_cmd["command"] : "该命令")
        wb_name := AppSettings.GetWbName(target_wb)
        
        scroll_state := this.GetTreeViewScrollState()
        this.load_command_tree(this.view.edit_search.Value, info.cmd, scroll_state.top_cmd, scroll_state.hpos)
        this.view.SB.SetText("已复制命令「" title "」到工作台「" wb_name "」")
    }

    move_command_item(Item, target_wb, ItemName, ItemPos, MyMenu) {
        if (!Item || !this.tv_map.Has(Item))
            return
        info := this.tv_map[Item]
        cmd := info.cmd
        src_wb := info.category
        
        if (src_wb == target_wb)
            return
            
        new_cmd := Map()
        for k, v in cmd {
            if (Type(v) == "Array") {
                new_arr := []
                for e in v
                    new_arr.Push(e)
                new_cmd[k] := new_arr
            } else {
                new_cmd[k] := v
            }
        }
        
        if (!this.resolve_move_collision(new_cmd, target_wb))
            return
            
        if (!AppSettings.commands_obj.Has(target_wb))
            AppSettings.commands_obj[target_wb] := []
        AppSettings.commands_obj[target_wb].Push(new_cmd)
        
        if (AppSettings.commands_obj.Has(src_wb)) {
            cmdArray := AppSettings.commands_obj[src_wb]
            for idx, c in cmdArray {
                if (c == cmd) {
                    cmdArray.RemoveAt(idx)
                    break
                }
            }
        }
        
        AppSettings.FlushCommands()
        
        title := (new_cmd.Has("desc") && new_cmd["desc"] != "") ? new_cmd["desc"] : (new_cmd.Has("command") ? new_cmd["command"] : "该命令")
        wb_name := AppSettings.GetWbName(target_wb)
        
        scroll_state := this.GetTreeViewScrollState()
        this.load_command_tree(this.view.edit_search.Value, new_cmd, scroll_state.top_cmd, scroll_state.hpos)
        this.view.SB.SetText("已移动命令「" title "」到工作台「" wb_name "」")
    }

    delete_command_item(Item, *) {
        if (!Item || !this.tv_map.Has(Item)) {
            return
        }
        info := this.tv_map[Item]
        if (info.type != "Item") {
            return
        }

        cmd := info.cmd
        wb := info.category
        del_idx := info.index
        title := (cmd.Has("desc") && cmd["desc"] != "") ? cmd["desc"] : (cmd.Has("command") ? cmd["command"] : "该命令")

        this.view.Opt("+OwnDialogs")
        res := MsgBox("确定删除命令「" . title . "」？", "确认删除命令", "OKCancel Icon?")
        if (res != "OK") {
            return
        }

        scroll_state := this.GetTreeViewScrollState()
        top_cmd := scroll_state.top_cmd
        hpos := scroll_state.hpos

        select_cmd := ""
        if (AppSettings.commands_obj.Has(wb)) {
            cmdArray := AppSettings.commands_obj[wb]
            removed_idx := 0
            for idx, c in cmdArray {
                if (c == cmd) {
                    cmdArray.RemoveAt(idx)
                    removed_idx := idx
                    break
                }
            }
            if (removed_idx == 0 && del_idx <= cmdArray.Length) {
                cmdArray.RemoveAt(del_idx)
                removed_idx := del_idx
            }

            if (cmdArray.Length > 0 && removed_idx > 0) {
                next_idx := (removed_idx <= cmdArray.Length) ? removed_idx : cmdArray.Length
                select_cmd := cmdArray[next_idx]
            }

            if (top_cmd == cmd) {
                top_cmd := select_cmd
            }
        }

        this.load_command_tree(this.view.edit_search.Value, select_cmd, top_cmd, hpos)
        this.view.SB.SetText("已删除命令：" . title)
    }

    SaveInputsToCurrentCmd() {
        if (this.HasProp("is_rendering") && this.is_rendering)
            return
        itemId := this.view.tv_alias.GetSelection()
        if (!itemId || !this.tv_map.Has(itemId) || this.tv_map[itemId].type != "Item") {
            return
        }

        cmd := this.tv_map[itemId].cmd
        cmd["command"] := Trim(this.view.Edit_Cmd.Value)

        desc_val := Trim(this.view.edit_desc.Value)
        if (desc_val != "")
            cmd["desc"] := desc_val
        else if (cmd.Has("desc"))
            cmd.Delete("desc")

        new_aliases := []
        for e in this.alias_edits {
            v := Trim(e.Value)
            if (v != "")
                new_aliases.Push(v)
        }
        if (new_aliases.Length > 0)
            cmd["aliases"] := new_aliases
        else if (cmd.Has("aliases"))
            cmd.Delete("aliases")

        new_hotkeys := []
        for e in this.hotkey_edits {
            v := Trim(e.Value)
            if (v != "")
                new_hotkeys.Push(parse_hotkey_from_display(v))
        }
        if (new_hotkeys.Length > 0)
            cmd["hotkeys"] := new_hotkeys
        else if (cmd.Has("hotkeys"))
            cmd.Delete("hotkeys")
    }

    OnAddAlias(idx, *) {
        this.SaveInputsToCurrentCmd()
        itemId := this.view.tv_alias.GetSelection()
        cmd := this.tv_map[itemId].cmd
        if (!cmd.Has("aliases")) {
            cmd["aliases"] := []
        }
        cmd["aliases"].InsertAt(idx + 1, "")
        this.on_command_tree_select(this.view.tv_alias, itemId)
    }

    OnDelAlias(idx, *) {
        this.SaveInputsToCurrentCmd()
        itemId := this.view.tv_alias.GetSelection()
        cmd := this.tv_map[itemId].cmd
        if (cmd.Has("aliases") && cmd["aliases"].Length >= idx)
            cmd["aliases"].RemoveAt(idx)
        this.on_command_tree_select(this.view.tv_alias, itemId)
    }

    OnAddHotkey(idx, *) {
        this.SaveInputsToCurrentCmd()
        itemId := this.view.tv_alias.GetSelection()
        cmd := this.tv_map[itemId].cmd
        if (!cmd.Has("hotkeys")) {
            cmd["hotkeys"] := []
        }
        cmd["hotkeys"].InsertAt(idx + 1, "")
        this.on_command_tree_select(this.view.tv_alias, itemId)
    }

    OnDelHotkey(idx, *) {
        this.SaveInputsToCurrentCmd()
        itemId := this.view.tv_alias.GetSelection()
        cmd := this.tv_map[itemId].cmd
        if (cmd.Has("hotkeys") && cmd["hotkeys"].Length >= idx)
            cmd["hotkeys"].RemoveAt(idx)
        this.on_command_tree_select(this.view.tv_alias, itemId)
    }

    update_right_pane_styles(info, orig_cmd) {
        if (orig_cmd == "") {
            desc_bold := "bold", cmd_bold := "bold", alias_bold := "bold", hk_bold := "bold"
        } else {
            desc_bold := ((info.cmd.Has("desc") ? info.cmd["desc"] : "") != (orig_cmd.Has("desc") ? orig_cmd["desc"] : "")) ? "bold" : "norm"
            cmd_bold := (info.cmd["command"] != orig_cmd["command"]) ? "bold" : "norm"
            alias_bold := !is_array_equal(info.cmd.Has("aliases") ? info.cmd["aliases"] : [], orig_cmd.Has("aliases") ? orig_cmd["aliases"] : []) ? "bold" : "norm"
            hk_bold := !is_array_equal(info.cmd.Has("hotkeys") ? info.cmd["hotkeys"] : [], orig_cmd.Has("hotkeys") ? orig_cmd["hotkeys"] : []) ? "bold" : "norm"
        }
        try {
            this.view.Txt_Desc.SetFont(desc_bold)
            this.view.edit_desc.SetFont(desc_bold)
            this.view.Txt_Cmd.SetFont(cmd_bold)
            this.view.Edit_Cmd.SetFont(cmd_bold)
            this.view.Txt_Alias.SetFont(alias_bold)
            for e in this.alias_edits
                e.SetFont(alias_bold)
            this.view.Txt_Hotkey.SetFont(hk_bold)
            for e in this.hotkey_edits
                e.SetFont(hk_bold)
        }
    }

    GetOriginalCmd(wb, cmd, index := 0) {
        if (!this.model.original_commands_obj || !this.model.original_commands_obj.Has(wb))
            return ""
        orig_list := this.model.original_commands_obj[wb]
        if (orig_list.Length == 0)
            return ""

        cmd_name := cmd.Has("command") ? cmd["command"] : ""
        cmd_desc := cmd.Has("desc") ? cmd["desc"] : ""

        ; 1. 优先按原索引位置精确比对 (command + desc 完全一致)
        if (index >= 1 && index <= orig_list.Length) {
            cand := orig_list[index]
            cand_name := cand.Has("command") ? cand["command"] : ""
            cand_desc := cand.Has("desc") ? cand["desc"] : ""
            if (cand_name == cmd_name && cand_desc == cmd_desc) {
                return cand
            }
        }

        ; 2. 全局按 (command + desc) 精确查找
        for cand in orig_list {
            cand_name := cand.Has("command") ? cand["command"] : ""
            cand_desc := cand.Has("desc") ? cand["desc"] : ""
            if (cand_name == cmd_name && cand_desc == cmd_desc) {
                return cand
            }
        }

        ; 3. 按 command 在原索引位置比对
        if (index >= 1 && index <= orig_list.Length) {
            cand := orig_list[index]
            cand_name := cand.Has("command") ? cand["command"] : ""
            if (cand_name == cmd_name) {
                return cand
            }
        }

        ; 4. 退而按 command 全局查找
        for cand in orig_list {
            cand_name := cand.Has("command") ? cand["command"] : ""
            if (cand_name == cmd_name) {
                return cand
            }
        }

        return ""
    }

    CheckGlobalDirty() {
        is_dirty := this.model.check_dirty(AppSettings.commands_obj)
        this.view.btn_save.Opt(is_dirty ? "-Disabled" : "+Disabled")

        for id, info in this.tv_map {
            if (info.type == "Item") {
                wb := info.category
                orig_cmd := this.GetOriginalCmd(wb, info.cmd, info.index)

                item_dirty := false
                if (orig_cmd == "") {
                    item_dirty := true
                } else {
                    item_dirty := (info.cmd["command"] != orig_cmd["command"])
                        || (info.cmd.Has("desc") ? info.cmd["desc"] : "") != (orig_cmd.Has("desc") ? orig_cmd["desc"] : "")
                        || !is_array_equal(info.cmd.Has("aliases") ? info.cmd["aliases"] : [], orig_cmd.Has("aliases") ? orig_cmd["aliases"] : [])
                        || !is_array_equal(info.cmd.Has("hotkeys") ? info.cmd["hotkeys"] : [], orig_cmd.Has("hotkeys") ? orig_cmd["hotkeys"] : [])
                }

                if (item_dirty) {
                    this.view.tv_alias.Modify(id, "Bold")
                    if (id == this.view.tv_alias.GetSelection()) {
                        this.view.Btn_Revert.Opt("-Disabled")
                        this.update_right_pane_styles(info, orig_cmd)
                    }
                } else {
                    this.view.tv_alias.Modify(id, "-Bold")
                    if (id == this.view.tv_alias.GetSelection()) {
                        this.view.Btn_Revert.Opt("+Disabled")
                        this.update_right_pane_styles(info, orig_cmd)
                    }
                }
            }
        }
        this.update_workbench_ddl()
    }

    get_workbench_diff_stats() {
        stats_map := Map()
        try {
            if (!this.HasProp("model") || !this.model || this.model.original_json_str == "")
                return stats_map
            orig_obj := JSON.parse(this.model.original_json_str)
        } catch {
            return stats_map
        }

        curr_obj := AppSettings.commands_obj

        for wb, cmds in curr_obj {
            added := 0
            modified := 0
            deleted := 0
            
            orig_cmds := orig_obj.Has(wb) ? orig_obj[wb] : []
            matched_orig := Map()

            for cmd in cmds {
                cmd_id := cmd.Has("command") ? cmd["command"] : ""
                cmd_desc := cmd.Has("desc") ? cmd["desc"] : ""

                matched_idx := 0
                for i, orig in orig_cmds {
                    if (matched_orig.Has(i))
                        continue
                    if (orig.Has("command") && orig["command"] == cmd_id && (orig.Has("desc") ? orig["desc"] : "") == cmd_desc) {
                        matched_idx := i
                        break
                    }
                }
                if (matched_idx == 0 && cmd_id != "") {
                    for i, orig in orig_cmds {
                        if (matched_orig.Has(i))
                            continue
                        if (orig.Has("command") && orig["command"] == cmd_id) {
                            matched_idx := i
                            break
                        }
                    }
                }

                if (matched_idx == 0) {
                    added++
                } else {
                    matched_orig[matched_idx] := true
                    orig_cmd := orig_cmds[matched_idx]
                    if (JSON.stringify(cmd) != JSON.stringify(orig_cmd)) {
                        modified++
                    }
                }
            }

            for i, orig in orig_cmds {
                if (!matched_orig.Has(i)) {
                    deleted++
                }
            }

            if (added > 0 || modified > 0 || deleted > 0) {
                stats_map[wb] := { added: added, modified: modified, deleted: deleted }
            }
        }

        for wb, orig_cmds in orig_obj {
            if (!curr_obj.Has(wb) && orig_cmds.Length > 0) {
                stats_map[wb] := { added: 0, modified: 0, deleted: orig_cmds.Length }
            }
        }

        return stats_map
    }

    update_workbench_ddl() {
        if (!this.HasProp("workbench_ids") || !this.workbench_ids || !this.view.HasProp("ddl_workbench"))
            return

        stats_map := this.get_workbench_diff_stats()

        wb_list := ["全部工作台"]
        for idx, wb_id in this.workbench_ids {
            if (idx == 1)
                continue
            wb_name := AppSettings.GetWbName(wb_id)
            if (stats_map.Has(wb_id)) {
                st := stats_map[wb_id]
                tags := []
                if (st.added > 0)
                    tags.Push("+" . st.added)
                if (st.modified > 0)
                    tags.Push("*" . st.modified)
                if (st.deleted > 0)
                    tags.Push("-" . st.deleted)
                
                tag_str := ""
                for t in tags
                    tag_str .= (tag_str == "" ? "" : " ") . t
                
                wb_list.Push("* " . wb_name . " (" . tag_str . ")")
            } else {
                wb_list.Push(wb_name)
            }
        }

        curr_choice := this.view.ddl_workbench.Value
        curr_items_str := ""
        max_len := 0
        for item in wb_list {
            curr_items_str .= item . "`n"
            if (StrLen(item) > max_len)
                max_len := StrLen(item)
        }

        if (!this.HasProp("last_ddl_items_str") || this.last_ddl_items_str !== curr_items_str) {
            this.last_ddl_items_str := curr_items_str
            this.view.ddl_workbench.Delete()
            this.view.ddl_workbench.Add(wb_list)
            if (curr_choice > 0 && curr_choice <= wb_list.Length)
                this.view.ddl_workbench.Choose(curr_choice)
            else
                this.view.ddl_workbench.Choose(1)
        }

        ; 紧凑自适应计算展开列表的像素宽度（CB_SETDROPPEDWIDTH = 0x0160）
        dropped_width := Max(195, Integer(max_len * 7.2 + 30))
        SendMessage(0x0160, dropped_width, 0, this.view.ddl_workbench.Hwnd)

        if (this.view.ddl_workbench.Text != "")
            this.view.ddl_workbench.ToolTip := this.view.ddl_workbench.Text
    }

    OnDetailChange(*) {
        if (this.HasProp("is_rendering") && this.is_rendering)
            return
        this.SaveInputsToCurrentCmd()
        this.CheckGlobalDirty()
    }

    OnAliasChange(idx, GuiCtrlObj, *) {
        if (this.HasProp("is_rendering") && this.is_rendering)
            return
        p := this.view.alias_pool[idx]
        p.add.Opt((Trim(GuiCtrlObj.Value) != "") ? "-Disabled" : "+Disabled")
        this.SaveInputsToCurrentCmd()
        this.CheckGlobalDirty()
    }

    OnAliasLoseFocus(idx, GuiCtrlObj, *) {
        this.ValidateFieldLoseFocus("alias", idx, GuiCtrlObj)
    }

    OnHotkeyChange(idx, GuiCtrlObj, *) {
        if (this.HasProp("is_rendering") && this.is_rendering)
            return
        p := this.view.hotkey_pool[idx]
        p.add.Opt((Trim(GuiCtrlObj.Value) != "") ? "-Disabled" : "+Disabled")
        this.SaveInputsToCurrentCmd()
        this.CheckGlobalDirty()
    }

    OnHotkeyFocus(idx, GuiCtrlObj, *) {
        if this.HasProp("ih") && this.ih {
            this.ih.Stop()
            this.ih := ""
        }
        ih := InputHook("L1 M")
        ih.KeyOpt("{All}", "E")
        ih.KeyOpt("{LCtrl}{RCtrl}{LAlt}{RAlt}{LShift}{RShift}{LWin}{RWin}", "-E")
        ih.OnEnd := ObjBindMethod(this, "OnInputHookEnd", idx, GuiCtrlObj)
        this.ih := ih
        ih.Start()
    }

    OnHotkeyLoseFocus(idx, GuiCtrlObj, *) {
        if this.HasProp("ih") && this.ih {
            this.ih.Stop()
            this.ih := ""
        }
        this.ValidateFieldLoseFocus("hotkey", idx, GuiCtrlObj)
    }

    OnInputHookEnd(idx, GuiCtrlObj, ih) {
        try {
            _ := GuiCtrlObj.Hwnd
        } catch {
            return
        }
        if (ih.EndReason = "EndKey") {
            key := ih.EndKey
            if (key = "Backspace" || key = "Delete") {
                GuiCtrlObj.Value := ""
            } else if (key = "Escape" || key = "Tab" || key = "Enter" || key = "NumpadEnter") {
                ; pass
            } else {
                if (StrLen(key) == 1)
                    key := StrUpper(key)
                mods := ""
                if GetKeyState("Ctrl", "P")
                    mods .= "^"
                if GetKeyState("Alt", "P")
                    mods .= "!"
                if GetKeyState("Shift", "P")
                    mods .= "+"
                if GetKeyState("LWin", "P") or GetKeyState("RWin", "P")
                    mods .= "#"
                GuiCtrlObj.Value := this.FormatHotkeyForDisplay(mods . key)
            }
            this.OnHotkeyChange(idx, GuiCtrlObj)
        }
        try {
            if (this.view.focused_ctrl == GuiCtrlObj)
                this.OnHotkeyFocus(idx, GuiCtrlObj)
        }
    }

    ValidateFieldLoseFocus(type, idx, GuiCtrlObj) {
        if (this.HasProp("is_rendering") && this.is_rendering)
            return
        if (this.HasProp("is_validating") && this.is_validating)
            return
        val := Trim(GuiCtrlObj.Value)
        if (val == "")
            return

        itemId := this.view.tv_alias.GetSelection()
        if (!itemId || !this.tv_map.Has(itemId) || this.tv_map[itemId].type != "Item")
            return
        info := this.tv_map[itemId]
        wb := info.category
        wb_name := AppSettings.GetWbName(wb)
        curr_title := (info.cmd.Has("desc") && info.cmd["desc"] != "") ? info.cmd["desc"] : (info.cmd.Has("command") ? info.cmd["command"] : "当前命令")

        is_alias := (type == "alias")
        typeName := is_alias ? "别名" : "快捷键"
        dlgTitle := is_alias ? "用户别名已存在" : "快捷键已存在"
        edits := is_alias ? this.alias_edits : this.hotkey_edits
        propKey := is_alias ? "aliases" : "hotkeys"
        val_display := is_alias ? val : format_hotkey_for_display(val)

        norm_func := (v) => is_alias ? StrLower(Trim(v)) : normalize_hotkey_for_cmp(v)
        target_norm := norm_func(val)
        if (target_norm == "")
            return

        for i, e in edits {
            if (i != idx && norm_func(e.Value) == target_norm) {
                this.is_validating := true
                GuiCtrlObj.Value := ""
                this.SaveInputsToCurrentCmd()
                this.CheckGlobalDirty()
                this.ShowDuplicateMsgBox(wb_name, typeName, val_display, curr_title, curr_title, dlgTitle, is_alias)
                this.is_validating := false
                return
            }
        }

        if (AppSettings.commands_obj.Has(wb)) {
            for c in AppSettings.commands_obj[wb] {
                if (c == info.cmd)
                    continue
                if (c.Has(propKey)) {
                    for item_val in c[propKey] {
                        if (norm_func(item_val) == target_norm) {
                            title := (c.Has("desc") && c["desc"] != "") ? c["desc"] : (c.Has("command") ? c["command"] : "未知命令")
                            this.is_validating := true
                            GuiCtrlObj.Value := ""
                            this.SaveInputsToCurrentCmd()
                            this.CheckGlobalDirty()
                            this.ShowDuplicateMsgBox(wb_name, typeName, val_display, title, curr_title, dlgTitle, is_alias)
                            this.is_validating := false
                            return
                        }
                    }
                }
            }
        }
    }

    ShowDuplicateMsgBox(wb_name, typeName, val, t1, t2, dlgTitle, is_alias) {
        tail_tip := is_alias ? "请重新输入。" : "请选择其他快捷键。"
        owner_opt := "Icon! 16 Owner" . this.view.Hwnd
        MsgBox("在工作台「" . wb_name . "」内发现重复" . typeName . "！`n`n" . typeName . "：「" . val . "」`n冲突命令 1：「" . t1 . "」`n冲突命令 2：「" . t2 . "」`n`n同一个工作台内的" . typeName . "不允许重复，" . tail_tip, dlgTitle, owner_opt)
    }


    OnCalcHotkeyFocus(GuiCtrlObj, *) {
        if this.HasProp("ih") && this.ih {
            this.ih.Stop()
            this.ih := ""
        }
        ih := InputHook("L1 M")
        ih.KeyOpt("{All}", "E")
        ih.KeyOpt("{LCtrl}{RCtrl}{LAlt}{RAlt}{LShift}{RShift}{LWin}{RWin}", "-E")
        ih.OnEnd := ObjBindMethod(this, "OnCalcInputHookEnd", GuiCtrlObj)
        this.ih := ih
        ih.Start()
    }

    OnCalcHotkeyLoseFocus(GuiCtrlObj, *) {
        if this.HasProp("ih") && this.ih {
            this.ih.Stop()
            this.ih := ""
        }
    }

    OnCalcInputHookEnd(GuiCtrlObj, ih) {
        try {
            _ := GuiCtrlObj.Hwnd
        } catch {
            return
        }
        if (ih.EndReason = "EndKey") {
            key := ih.EndKey
            if (key = "Backspace" || key = "Delete") {
                GuiCtrlObj.Value := ""
            } else if (key = "Escape" || key = "Tab" || key = "Enter" || key = "NumpadEnter") {
                ; pass
            } else {
                if (StrLen(key) == 1)
                    key := StrUpper(key)
                mods := ""
                if GetKeyState("Ctrl", "P")
                    mods .= "^"
                if GetKeyState("Alt", "P")
                    mods .= "!"
                if GetKeyState("Shift", "P")
                    mods .= "+"
                if GetKeyState("LWin", "P") or GetKeyState("RWin", "P")
                    mods .= "#"
                GuiCtrlObj.Value := this.FormatHotkeyForDisplay(mods . key)
            }
        }

        if (GuiCtrlObj.Value == "") {
            this.view.Chk_Calc.Opt("+Disabled")
            this.view.Chk_Calc.Value := 0
        } else {
            this.view.Chk_Calc.Opt("-Disabled")
        }

        try {
            if (this.view.focused_ctrl == GuiCtrlObj)
                this.OnCalcHotkeyFocus(GuiCtrlObj)
        }
    }

    OnEverythingHotkeyFocus(GuiCtrlObj, *) {
        if this.HasProp("ih") && this.ih {
            this.ih.Stop()
            this.ih := ""
        }
        ih := InputHook("L1 M")
        ih.KeyOpt("{All}", "E")
        ih.KeyOpt("{LCtrl}{RCtrl}{LAlt}{RAlt}{LShift}{RShift}{LWin}{RWin}", "-E")
        ih.OnEnd := ObjBindMethod(this, "OnEverythingInputHookEnd", GuiCtrlObj)
        this.ih := ih
        ih.Start()
    }

    OnEverythingHotkeyLoseFocus(GuiCtrlObj, *) {
        if this.HasProp("ih") && this.ih {
            this.ih.Stop()
            this.ih := ""
        }
    }

    OnEverythingInputHookEnd(GuiCtrlObj, ih) {
        try {
            _ := GuiCtrlObj.Hwnd
        } catch {
            return
        }
        if (ih.EndReason = "EndKey") {
            key := ih.EndKey
            if (key = "Backspace" || key = "Delete") {
                GuiCtrlObj.Value := ""
            } else if (key = "Escape" || key = "Tab" || key = "Enter" || key = "NumpadEnter") {
                ; pass
            } else {
                if (StrLen(key) == 1)
                    key := StrUpper(key)
                mods := ""
                if GetKeyState("Ctrl", "P")
                    mods .= "^"
                if GetKeyState("Alt", "P")
                    mods .= "!"
                if GetKeyState("Shift", "P")
                    mods .= "+"
                if GetKeyState("LWin", "P") or GetKeyState("RWin", "P")
                    mods .= "#"
                GuiCtrlObj.Value := this.FormatHotkeyForDisplay(mods . key)
            }
        }
        try {
            if (this.view.focused_ctrl == GuiCtrlObj)
                this.OnEverythingHotkeyFocus(GuiCtrlObj)
        }
    }

    FormatHotkeyForDisplay(hk) => format_hotkey_for_display(hk)
    ParseHotkeyFromDisplay(display) => parse_hotkey_from_display(display)

    on_lbutton_down(wParam, lParam, msg, hwnd) {
        if (this.HasProp("view") && this.view) {
            try {
                ctrl := this.view.focused_ctrl
                if (!ctrl || Type(ctrl) != "Gui.Edit") {
                    return
                }
                class := WinGetClass(hwnd)
                if (class == "Edit" || class == "SysTreeView32" || class == "ComboBox") {
                    return
                }
                if (class == "Button") {
                    style := WinGetStyle(hwnd)
                    if ((style & 0xF) != 0x7) {
                        return
                    }
                }
                SetTimer(ObjBindMethod(this, "do_blur"), -10)
            }
        }
    }

    do_blur() {
        if (this.view.tabs)
            try this.view.tabs.Focus()
    }

    OnRevertChanges(*) {
        itemId := this.view.tv_alias.GetSelection()
        if (!itemId || !this.tv_map.Has(itemId) || this.tv_map[itemId].type != "Item") {
            return
        }
        wb := this.tv_map[itemId].category
        info := this.tv_map[itemId]

        orig_cmd := this.GetOriginalCmd(wb, info.cmd, info.index)
        if (orig_cmd != "") {
            restored_cmd := JSON.parse(JSON.stringify(orig_cmd))
            this.tv_map[itemId].cmd := restored_cmd
            if (AppSettings.commands_obj.Has(wb) && info.index <= AppSettings.commands_obj[wb].Length) {
                AppSettings.commands_obj[wb][info.index] := restored_cmd
            }
            this.on_command_tree_select(this.view.tv_alias, itemId)
            this.CheckGlobalDirty()
            this.view.SB.SetText("当前命令已恢复到初始状态。")
        }
    }

    SaveCurrentItem(*) {
        this.SaveInputsToCurrentCmd()
        itemId := this.view.tv_alias.GetSelection()
        saved_cmd_id := ""
        saved_cat := ""
        if (itemId && this.tv_map.Has(itemId) && this.tv_map[itemId].type == "Item") {
            cmd := this.tv_map[itemId].cmd
            saved_cmd_id := cmd["command"]
            saved_cat := this.tv_map[itemId].category
        }

        hotkey_changed := false
        for id, info in this.tv_map {
            if (info.type == "Item") {
                wb := info.category
                orig_cmd := this.GetOriginalCmd(wb, info.cmd, info.index)
                if (orig_cmd == "") {
                    hotkey_changed := true
                    break
                } else {
                    h1 := JSON.stringify(info.cmd.Has("hotkeys") ? info.cmd["hotkeys"] : [])
                    h2 := JSON.stringify(orig_cmd.Has("hotkeys") ? orig_cmd["hotkeys"] : [])
                    if (h1 != h2) {
                        hotkey_changed := true
                        break
                    }
                }
            }
        }

        if (!this.model.flush_commands_json(AppSettings.commands_obj)) {
            return false
        }
        this.model.init()
        this.load_command_tree(this.view.edit_search.Value)

        if (saved_cmd_id != "") {
            for id, info in this.tv_map {
                if (info.type == "Item" && info.cmd["command"] == saved_cmd_id && info.category == saved_cat) {
                    this.view.tv_alias.Modify(id, "Select Vis")
                    this.on_command_tree_select(this.view.tv_alias, id)
                    break
                }
            }
        }
        this.CheckGlobalDirty()
        this.view.SB.SetText(hotkey_changed ? "修改成功！请手动重新载入 UCLC 以应用最新配置。" : "修改成功。")
    }

    BrowseEverything(*) {
        path := FileSelect(, , "请选择 Everything.exe", "程序 (*.exe)")
        if path
            this.view.Edit_EverythingPath.Value := path
    }

    CreateShortcut(*) {
        ShortcutManager.CreateDesktopShortcut()
    }

    BrowseConfigDir(*) {
        path := DirSelect("*" . AppSettings.ConfigDir, 3, "请选择自定义同步/备份目录 (支持网盘文件夹)")
        if path {
            this.view.Edit_ConfigDir.Value := path
        }
    }

    OnIntegrationSelect(*) {
        idx := this.view.lb_integration.Value
        if (idx >= 1 && idx <= 4)
            this.view.SwitchIntegrationPane(idx)
    }

    OnToggleAutoIME(*) {
        enabled := this.view.Chk_AutoIME.Value
        this.view.Btn_ManageIME.Opt(enabled ? "-Disabled" : "+Disabled")
    }

    OnShowImeGuide(*) {
        msg := "【前提条件】`n`n"
            . "需在 Windows 语言设置中添加并启用英文输入法（如：英语(美国) - 美式键盘）。`n`n"
            . "提示：单语言中文输入法无法自动切换中英文。"
        MsgBox(msg, "UCLC - 输入法自动切换", "Iconi")
    }

    OnOpenImeRulesModal(*) {
        dlg := Gui("+Owner" this.view.hwnd " -MinimizeBox -MaximizeBox", "管理输入法自动切换规则")
        this.view.Opt("+Disabled")

        dlg.Add("Text", "x20 y15 w350 cBlue", "规则列表：当匹配的进程窗口激活时自动切换至英文")
        lv_rules := dlg.Add("ListView", "x20 y40 w350 h200 Grid -Multi", ["软件名称", "进程名称 (exe)"])
        lv_rules.ModifyCol(1, 140)
        lv_rules.ModifyCol(2, 205)

        if AppSettings.config_obj.Has("AutoIME") {
            for label, exe in AppSettings.config_obj["AutoIME"] {
                if (label != "Enabled") {
                    lv_rules.Add("", label, exe)
                }
            }
        }

        btn_add := dlg.Add("Button", "x385 y40 w110 h28", "➕ 添加规则")
        btn_del := dlg.Add("Button", "x385 y80 w110 h28", "➖ 删除规则")
        btn_edit := dlg.Add("Button", "x385 y120 w110 h28", "✏️ 修改规则")

        link_guide := dlg.Add("Link", "x20 y255 w350 cGray", "说明：需在 Windows 中已添加英文输入法（<a id=`"guide`">查看前提</a>）。")

        btn_save_rules := dlg.Add("Button", "x385 y250 w110 h30 Default", "保存并关闭")

        close_rules_dlg(*) {
            this.view.Opt("-Disabled")
            dlg.Destroy()
        }

        do_save_rules(*) {
            auto_ime_map := Map()
            auto_ime_map["Enabled"] := String(this.view.Chk_AutoIME.Value)
            loop lv_rules.GetCount() {
                label := lv_rules.GetText(A_Index, 1)
                exe := lv_rules.GetText(A_Index, 2)
                if (label != "" && exe != "" && label != "Enabled") {
                    auto_ime_map[label] := exe
                }
            }
            AppSettings.config_obj["AutoIME"] := auto_ime_map
            AppSettings.FlushConfig()
            this.OnToggleAutoIME()
            this.view.SB.SetText("输入法自动切换规则已保存并应用！")
            close_rules_dlg()
        }

        do_add(*) => this.show_auto_ime_modal("", "", 0, lv_rules, dlg)

        do_edit(*) {
            row := lv_rules.GetNext(0)
            if (row == 0) {
                MsgBox("请先在表格中选择要修改的规则！", "UCLC - 输入法自动切换", "Iconi")
                return
            }
            label := lv_rules.GetText(row, 1)
            exe := lv_rules.GetText(row, 2)
            this.show_auto_ime_modal(label, exe, row, lv_rules, dlg)
        }

        do_del(*) {
            row := lv_rules.GetNext(0)
            if (row == 0) {
                MsgBox("请先在表格中选择要删除的规则！", "UCLC - 输入法自动切换", "Iconi")
                return
            }
            label := lv_rules.GetText(row, 1)
            if (MsgBox("确定移除 " label " 的输入法切换规则？", "UCLC - 输入法自动切换", "YesNo Icon?") == "Yes") {
                lv_rules.Delete(row)
            }
        }

        btn_add.OnEvent("Click", do_add)
        btn_edit.OnEvent("Click", do_edit)
        btn_del.OnEvent("Click", do_del)
        lv_rules.OnEvent("DoubleClick", do_edit)
        link_guide.OnEvent("Click", ObjBindMethod(this, "OnShowImeGuide"))
        btn_save_rules.OnEvent("Click", do_save_rules)
        dlg.OnEvent("Close", close_rules_dlg)
        dlg.OnEvent("Escape", close_rules_dlg)

        dlg.Show("w515 h300")
    }

    show_auto_ime_modal(default_label := "", default_exe := "", edit_row := 0, target_lv := 0, parent_dlg := 0) {
        title := edit_row > 0 ? "修改规则" : "添加规则"
        owner_hwnd := parent_dlg ? parent_dlg.Hwnd : this.view.hwnd
        dlg := Gui("+Owner" owner_hwnd " -MinimizeBox -MaximizeBox", title)
        if parent_dlg
            parent_dlg.Opt("+Disabled")
        else
            this.view.Opt("+Disabled")

        dlg.Add("Text", "x15 y20 h20 Right", "软件名称:")
        edit_label := dlg.Add("Edit", "x85 y16 w240 h24", default_label)

        dlg.Add("Text", "x15 y55 h20 Right", "进程名称:")
        edit_exe := dlg.Add("Edit", "x85 y51 w240 h24 ReadOnly", default_exe)

        btn_capture := dlg.Add("Button", "x85 y83 w240 h26", "指定目标程序")

        close_dlg(*) {
            if parent_dlg
                parent_dlg.Opt("-Disabled")
            else
                this.view.Opt("-Disabled")
            dlg.Destroy()
        }

        do_capture(*) {
            dlg.Hide()
            ToolTip("请左键点击目标软件窗口以获取进程名称 (按 Esc 取消)...")

            cancelled := false
            loop {
                if GetKeyState("Escape", "P") {
                    cancelled := true
                    break
                }
                if GetKeyState("LButton", "P") {
                    break
                }
                Sleep 20
            }
            ToolTip()

            if (cancelled) {
                dlg.Show()
                WinActivate(dlg.Hwnd)
                return
            }

            KeyWait("LButton")
            MouseGetPos , , &target_hwnd
            if (target_hwnd) {
                try {
                    exe_name := WinGetProcessName(target_hwnd)
                    if (exe_name != "") {
                        if (StrLower(exe_name) == "explorer.exe") {
                            MsgBox("不能选择桌面或系统资源管理器！", "UCLC - 输入法自动切换", "Iconi")
                        } else {
                            edit_exe.Value := exe_name
                            if (edit_label.Value == "") {
                                edit_label.Value := RegExReplace(exe_name, "(?i)\.exe$", "")
                            }
                        }
                    }
                }
            }
            dlg.Show()
            WinActivate(dlg.Hwnd)
            btn_confirm.Focus()
        }

        do_confirm(*) {
            label := Trim(edit_label.Value)
            exe := Trim(edit_exe.Value)
            if (label == "") {
                MsgBox("请输入软件名称！", "UCLC - 输入法自动切换", "Iconi")
                edit_label.Focus()
                return
            }
            if (exe == "") {
                MsgBox("请点击【获取目标窗口】以获取进程名称！", "UCLC - 输入法自动切换", "Iconi")
                return
            }

            if (edit_row > 0 && target_lv) {
                target_lv.Modify(edit_row, "", label, exe)
            } else if target_lv {
                target_lv.Add("", label, exe)
            }
            close_dlg()
        }

        btn_capture.OnEvent("Click", do_capture)
        btn_confirm := dlg.Add("Button", "x85 y118 w110 h28 Default", "确认")
        btn_cancel := dlg.Add("Button", "x215 y118 w110 h28", "取消")

        btn_confirm.OnEvent("Click", do_confirm)
        btn_cancel.OnEvent("Click", close_dlg)
        dlg.OnEvent("Close", close_dlg)
        dlg.OnEvent("Escape", close_dlg)

        dlg.Show("w345 h158")
        if (default_label == "")
            edit_label.Focus()
        else
            btn_confirm.Focus()
    }

    SaveIntegrationSettings(*) {
        success := this.model.save_integration_settings(
            this.view.Chk_AutoIME.Value,
            this.view.Chk_Everything.Value,
            this.view.Edit_EverythingPath.Value,
            this.view.Edit_EverythingHotkey.Value,
            this.view.Chk_Volume.Value,
            this.view.Chk_Calc.Value,
            this.view.Edit_CalcHotkey.Value,
            this.view.Chk_CatiaMButton.Value
        )
        if success {
            this.view.SB.SetText("集成设置保存成功！请重新载入脚本或重启软件使其生效。")
            if (this.view.Chk_Everything.Value && this.view.Edit_EverythingHotkey.Value == "") {
                MsgBox("未配置 Everything 热键。`n`n请在 Everything「选项」->「键盘」->「显示窗口」中设置，完成后重新载入 UCLC 生效。", "UCLC - Everything 快速呼出", 48)
            }
        }
    }

    OnUpdaterChannelChange(*) {
        new_channel := InStr(this.view.Ddl_UpdaterChannel.Text, "预览") ? "Preview" : "Release"
        if (new_channel != AppSettings.Updater_Channel) {
            AppSettings.SaveUpdaterConfig("Channel", new_channel)
            try StateManager.Set("AvailableUpdateVersion", "")
            try StateManager.Set("LastPromptVersion", "")
            try StateManager.Set("LastPromptDate", "")
            try StateManager.Set("LastCheckTime", "")
            SettingsController.RefreshUpdateNotice()
            if (this.view.Chk_Updater.Value) {
                SetTimer(() => UCLCUpdater.CheckForUpdate(false), -100)
            }
        }
        if (new_channel == "Preview")
            this.view.SB.SetText("  预览版 — 适合尝鲜，优先体验最新功能与修复。")
        else
            this.view.SB.SetText("  稳定版 — 推荐日常使用。")
    }

    OnViewUpdateClick(*) {
        avail_ver := StateManager.Get("AvailableUpdateVersion", "")
        if (avail_ver != "") {
            ShowUpdateGUI(avail_ver, UCLC_VERSION, StateManager.Get("LatestReleaseNotes", "暂无更新说明。"), StateManager.Get("LatestDownloadUrl", ""), this.view)
        } else {
            UCLCUpdater.CheckForUpdate(true, this.view)
        }
    }

    static RefreshUpdateNotice() {
        if (this.instance && this.instance.is_valid() && this.instance.view) {
            avail_ver := ""
            try avail_ver := StateManager.Get("AvailableUpdateVersion", "")
            has_notice := (AppSettings.Updater_Enabled && avail_ver != "")
            try {
                is_preview := (InStr(avail_ver, "-") || InStr(avail_ver, "dev") || InStr(avail_ver, "beta") || InStr(avail_ver, "alpha") || InStr(avail_ver, "rc") || InStr(avail_ver, "preview"))
                ver_tag := is_preview ? " [预览版]" : " [稳定版]"
                this.instance.view.Lbl_UpdateNotice.Text := has_notice ? "✨ 发现新版本 " avail_ver ver_tag "！" : ""
                this.instance.view.Lbl_UpdateNotice.Opt(has_notice ? "-Hidden" : "+Hidden")
                if (this.instance.view.HasProp("Link_ViewUpdate")) {
                    this.instance.view.Link_ViewUpdate.Opt(has_notice ? "-Hidden" : "+Hidden")
                    if (has_notice) {
                        try this.instance.view.Link_ViewUpdate.Text := '<a id="view_update">查看更新内容</a>'
                        try this.instance.view.Link_ViewUpdate.Redraw()
                    }
                }
            }
        }
    }

    SaveGeneralSettings(*) {
        old_channel := AppSettings.Updater_Channel
        channel := InStr(this.view.Ddl_UpdaterChannel.Text, "预览") ? "Preview" : "Release"
        if (!this.view.Chk_Updater.Value || channel != old_channel) {
            try StateManager.Set("AvailableUpdateVersion", "")
            try StateManager.Set("LastPromptVersion", "")
            try StateManager.Set("LastPromptDate", "")
            try StateManager.Set("LastCheckTime", "")
            SettingsController.RefreshUpdateNotice()
            if IsSet(add_coustom_tray_menu)
                try add_coustom_tray_menu()
            if (this.view.Chk_Updater.Value && channel != old_channel) {
                SetTimer(() => UCLCUpdater.CheckForUpdate(false), -100)
            }
        }
        success := this.model.save_general_settings(
            this.view.Chk_Startup.Value,
            this.view.Chk_DesktopShortcut.Value,
            this.view.Chk_Updater.Value,
            channel,
            this.view.Edit_ConfigDir.Value
        )
        if success
            this.view.SB.SetText("常规设置保存成功！请重新载入脚本或重启软件使其生效。")
    }

    SaveAdvancedSettings(*) {
        success := this.model.save_advanced_settings(
            this.view.Chk_Debug.Value
        )
        if success
            this.view.SB.SetText("高级设置保存成功！请重新载入脚本或重启软件使其生效。")
    }

    ImportConfigFile(*) {
        source_dir := DirSelect("*" . AppSettings.ConfigDir, 3, "请选择要导入的 UCLC 备份文件夹 (应包含 config.json / commands.json)")
        if !source_dir
            return
        if (MsgBox("导入备份配置将覆盖当前的系统设置与命令库，是否继续？", "导入确认", "YesNo Icon?") != "Yes")
            return
        try {
            if AppSettings.ImportConfig(source_dir) {
                MsgBox("配置与命令数据导入成功！界面即将重新载入新设置。", "成功", "Iconi")
                this.LoadGeneralSettings()
            }
        } catch Error as e {
            MsgBox("导入失败: " e.Message, "错误", 16)
        }
    }

    ExportConfigFile(*) {
        target_dir := DirSelect("*" . AppSettings.ConfigDir, 3, "请选择或新建一个文件夹以保存 UCLC 配置备份")
        if !target_dir
            return
        try {
            if AppSettings.ExportConfig(target_dir) {
                MsgBox("配置成功备份至：`n" target_dir "`n`n包含 config.json 与 commands.json。", "导出成功", "Iconi")
            }
        } catch Error as e {
            MsgBox("导出失败: " e.Message, "错误", 16)
        }
    }


    on_mouse_move(wParam, lParam, msg, hwnd) {
        static prev_hwnd := 0
        static last_tip := ""
        if (hwnd == prev_hwnd) {
            return
        }
        prev_hwnd := hwnd
        try {
            guiCtrl := GuiCtrlFromHwnd(hwnd)
            if (guiCtrl && guiCtrl.HasProp("ToolTip") && guiCtrl.ToolTip != "") {
                this.view.SB.SetText(guiCtrl.ToolTip)
                last_tip := guiCtrl.ToolTip
            } else if (last_tip != "") {
                this.view.SB.SetText("")
                last_tip := ""
            }
        } catch {
            if (last_tip != "") {
                this.view.SB.SetText("")
                last_tip := ""
            }
        }
    }

    GetActiveModalOwner() {
        return (this.HasProp("cmd_lib_dlg") && this.cmd_lib_dlg) ? this.cmd_lib_dlg : this.view
    }

    OnOpenCmdLibraryModal(*) {
        dlg := Gui("+Owner" this.view.hwnd " -MinimizeBox -MaximizeBox", "导入命令ID")
        this.cmd_lib_dlg := dlg
        this.view.Opt("+Disabled")

        dlg.Add("GroupBox", "x20 y15 w740 h65", "数据源获取")
        dlg.Add("Text", "x30 y43 w70", "目标工作台:")

        sort_str := ""
        for k, v in AppSettings.commands_obj {
            if (k != "_comment") {
                sort_str .= AppSettings.GetWbName(k) "|||" k "`n"
            }
        }
        sort_str := Sort(Trim(sort_str, "`n"))

        wb_list3 := ["通过导入文件确定"]
        this.import_wb_ids := [""]
        loop parse sort_str, "`n", "`r" {
            if (A_LoopField == "") {
                continue
            }
            parts := StrSplit(A_LoopField, "|||")
            wb_list3.Push(parts[1])
            this.import_wb_ids.Push(parts[2])
        }

        this.view.ddl_import_wb := dlg.Add("DropDownList", "x100 y39 w250 Choose1", wb_list3)
        this.view.Btn_AddWb := dlg.Add("Button", "x355 y39 w24 h22 +Disabled", "+")
        this.view.Btn_ImportCommands := dlg.Add("Button", "x480 y39 w140 h22", "从预设导入命令")
        this.view.Btn_ReadTxt := dlg.Add("Button", "x630 y39 w120 h22 +Disabled", "从 TXT 导入")

        dlg.Add("GroupBox", "x20 y90 w740 h410", "同步状态视图")
        dlg.Add("Text", "x25 y105 w60 h32 +0x200", "  筛选:")

        this.view.chk_filter_all := dlg.Add("CheckBox", "x85 y105 w60 h32 Checked", "全部`n(0)")
        dlg.SetFont("s9 bold c107C10")
        dlg.Add("Text", "x155 y105 w14 h32 +0x200", "+")
        dlg.SetFont("s9 norm cDefault")
        this.view.chk_filter_new := dlg.Add("CheckBox", "x169 y105 w60 h32 Checked", "新增`n(0)")

        dlg.SetFont("s9 bold c0078D7")
        dlg.Add("Text", "x239 y105 w14 h32 +0x200", "T")
        dlg.SetFont("s9 norm cDefault")
        this.view.chk_filter_update := dlg.Add("CheckBox", "x253 y105 w85 h32 Checked", "更新标题`n(0)")

        dlg.SetFont("s9 bold c0078D7")
        dlg.Add("Text", "x348 y105 w14 h32 +0x200", "C")
        dlg.SetFont("s9 norm cDefault")
        this.view.chk_filter_overwrite := dlg.Add("CheckBox", "x362 y105 w85 h32 Checked", "更新命令`n(0)")

        dlg.SetFont("s9 bold c107C10")
        dlg.Add("Text", "x457 y105 w14 h32 +0x200", "=")
        dlg.SetFont("s9 norm cDefault")
        this.view.chk_filter_same := dlg.Add("CheckBox", "x471 y105 w60 h32 Checked", "已有`n(0)")

        dlg.SetFont("s9 bold cE81123")
        dlg.Add("Text", "x541 y105 w14 h32 +0x200", "D")
        dlg.SetFont("s9 norm cDefault")
        this.view.chk_filter_delete := dlg.Add("CheckBox", "x555 y105 w75 h32 Checked", "删除`n(0)")

        dlg.SetFont("s9 bold cE81123")
        dlg.Add("Text", "x640 y105 w14 h32 +0x200", "i")
        dlg.SetFont("s9 norm cDefault")
        this.view.chk_filter_ignore := dlg.Add("CheckBox", "x654 y105 w60 h32 Checked", "忽略`n(0)")

        this.view.lv_import := dlg.Add("ListView", "x30 y140 w720 h310 Grid", ["标题", "命令 ID", "导入的命令 ID", "操作"])
        this.view.lv_import.ModifyCol(1, 160)
        this.view.lv_import.ModifyCol(2, 240)
        this.view.lv_import.ModifyCol(3, 253)
        this.view.lv_import.ModifyCol(4, 50)
        this.view.lv_import.ModifyCol(4, "Center")

        this.view.txt_empty_lv := dlg.Add("Text", "x250 y280 w280 h30 Center c808080 BackgroundTrans", "请点击上方按钮获取数据")

        this.view.btn_mark_delete := dlg.Add("Button", "x30 y460 w80 h24 Disabled", "删除选中")
        this.view.btn_mark_ignore := dlg.Add("Button", "x120 y460 w80 h24 Disabled", "忽略选中")
        this.view.txt_sel_count := dlg.Add("Text", "x220 y464 w150 h20", "已选中: 0 项")

        this.view.btn_resetView := dlg.Add("Button", "x30 y510 w150 h28", "重置视图")
        this.view.Btn_ApplyAll := dlg.Add("Button", "x600 y510 w150 h28 Default", "应用修改")

        this.view.ddl_import_wb.OnEvent("Change", ObjBindMethod(this, "on_target_workbench_changed"))
        this.view.Btn_AddWb.OnEvent("Click", ObjBindMethod(this, "OnAddTargetWorkbench"))
        this.view.Btn_ImportCommands.OnEvent("Click", ObjBindMethod(this, "OnImportCommands"))
        this.view.Btn_ReadTxt.OnEvent("Click", ObjBindMethod(this, "OnReadExportedTxt"))

        this.view.chk_filter_all.OnEvent("Click", ObjBindMethod(this, "on_filter_all"))
        this.view.chk_filter_new.OnEvent("Click", ObjBindMethod(this, "on_filter_new"))
        this.view.chk_filter_update.OnEvent("Click", ObjBindMethod(this, "on_filter_update"))
        this.view.chk_filter_overwrite.OnEvent("Click", ObjBindMethod(this, "on_filter_overwrite"))
        this.view.chk_filter_same.OnEvent("Click", ObjBindMethod(this, "on_filter_same"))
        this.view.chk_filter_delete.OnEvent("Click", ObjBindMethod(this, "on_filter_delete"))
        this.view.chk_filter_ignore.OnEvent("Click", ObjBindMethod(this, "on_filter_ignore"))

        this.view.lv_import.OnEvent("Click", ObjBindMethod(this, "on_import_list_view_click"))
        this.view.lv_import.OnEvent("ItemSelect", ObjBindMethod(this, "on_import_list_view_item_select"))
        this.view.lv_import.OnEvent("DoubleClick", ObjBindMethod(this, "on_import_list_view_double_click"))
        this.view.lv_import.OnEvent("ContextMenu", ObjBindMethod(this, "on_import_list_view_context_menu"))

        this.view.btn_mark_delete.OnEvent("Click", ObjBindMethod(this, "on_mark_items_to_delete"))
        this.view.btn_mark_ignore.OnEvent("Click", ObjBindMethod(this, "on_mark_items_to_ignore"))
        this.view.btn_resetView.OnEvent("Click", ObjBindMethod(this, "on_reset_import_view"))
        this.view.Btn_ApplyAll.OnEvent("Click", ObjBindMethod(this, "on_apply_import_all"))

        close_dlg(*) {
            this.cmd_lib_dlg := ""
            try this.view.Opt("-Disabled")
            try dlg.Destroy()
            for prop in ["ddl_import_wb", "Btn_AddWb", "Btn_ImportCommands", "Btn_ReadTxt", "chk_filter_all", "chk_filter_new", "chk_filter_update", "chk_filter_overwrite", "chk_filter_same", "chk_filter_delete", "chk_filter_ignore", "lv_import", "txt_empty_lv", "btn_mark_delete", "btn_mark_ignore", "txt_sel_count", "btn_resetView", "Btn_ApplyAll"] {
                if this.view.HasProp(prop)
                    try this.view.DeleteProp(prop)
            }
        }

        dlg.OnEvent("Close", close_dlg)
        dlg.OnEvent("Escape", close_dlg)

        dlg.Show("w780 h550")
    }

    on_target_workbench_changed(ctrl, *) {
        target_wb := (ctrl.Value > 1) ? this.import_wb_ids[ctrl.Value] : ctrl.Text
        this.refresh_import_diff(target_wb)
    }

    refresh_import_diff(target_wb) {
        if (target_wb == "通过导入文件确定") {
            if (this.model.parsed_import_wb_id != "") {
                target_wb := this.model.parsed_import_wb_id
                found_idx := 0
                for i, id in this.import_wb_ids {
                    if (id == target_wb) {
                        found_idx := i
                        break
                    }
                }
                if (found_idx > 0) {
                    this.view.ddl_import_wb.Choose(found_idx)
                } else {
                    this.view.ddl_import_wb.Add([AppSettings.GetWbName(target_wb)])
                    this.import_wb_ids.Push(target_wb)
                    this.view.ddl_import_wb.Choose(this.import_wb_ids.Length)
                }
            } else {
                this.view.txt_empty_lv.Value := "无法从文件中解析出工作台 ID，请手动选择目标工作台"
                return
            }
        }

        this.model.calculate_import_diff(target_wb)
        this.render_import_lv()
    }

    get_item_attr(item, attr_name, default_val := "") {
        if !IsObject(item)
            return default_val
        if HasProp(item, attr_name)
            return item.%attr_name%
        if (Type(item) == "Map" && item.Has(attr_name))
            return item[attr_name]
        return default_val
    }

    render_import_lv() {
        items := this.model.import_items
        c_new := 0, c_upd := 0, c_ovr := 0, c_sam := 0, c_del := 0, c_ign := 0
        for item in items {
            a := this.get_item_attr(item, "action")
            if (a == "+") {
                c_new++
            } else if (a == "T") {
                c_upd++
            } else if (a == "C") {
                c_ovr++
            } else if (a == "=") {
                c_sam++
            } else if (a == "D") {
                c_del++
            } else if (a == "i") {
                c_ign++
            }
        }
        c_all := c_new + c_upd + c_ovr + c_sam + c_del + c_ign

        this.view.chk_filter_all.Text := "全部`n(" c_all ")"
        this.view.chk_filter_new.Text := "新增`n(" c_new ")"
        this.view.chk_filter_update.Text := "更新标题`n(" c_upd ")"
        this.view.chk_filter_overwrite.Text := "更新命令`n(" c_ovr ")"
        this.view.chk_filter_same.Text := "已有`n(" c_sam ")"
        this.view.chk_filter_delete.Text := "删除`n(" c_del ")"
        this.view.chk_filter_ignore.Text := "忽略`n(" c_ign ")"

        showNew := this.view.chk_filter_new.Value
        showUpdate := this.view.chk_filter_update.Value
        showOverwrite := this.view.chk_filter_overwrite.Value
        showSame := this.view.chk_filter_same.Value
        showDelete := this.view.chk_filter_delete.Value
        showIgnore := this.view.chk_filter_ignore.Value

        this.view.lv_import.Opt("-Redraw")
        this.view.lv_import.Delete()
        this.view.txt_empty_lv.Visible := false

        for item in items {
            a := this.get_item_attr(item, "action")
            if ((a == "+" && showNew) || (a == "T" && showUpdate) || (a == "C" && showOverwrite)
                || (a == "=" && showSame) || (a == "D" && showDelete) || (a == "i" && showIgnore)) {
                title := this.get_item_attr(item, "title")
                local_id := this.get_item_attr(item, "local_id")
                imported_id := this.get_item_attr(item, "imported_id")
                this.view.lv_import.Add("", title, local_id, imported_id, a)
            }
        }
        if (this.view.lv_import.GetCount() == 0) {
            this.view.txt_empty_lv.Visible := true
        }
        this.view.lv_import.Opt("+Redraw")
        this.view.lv_import.ModifyCol(1, "Sort")
        this.view.txt_sel_count.Value := "已选中: 0 项"
    }

    handle_filter_click(ctrl) {
        if GetKeyState("Alt", "P") {
            this.view.chk_filter_new.Value := (ctrl == this.view.chk_filter_new)
            this.view.chk_filter_update.Value := (ctrl == this.view.chk_filter_update)
            this.view.chk_filter_overwrite.Value := (ctrl == this.view.chk_filter_overwrite)
            this.view.chk_filter_same.Value := (ctrl == this.view.chk_filter_same)
            this.view.chk_filter_delete.Value := (ctrl == this.view.chk_filter_delete)
            this.view.chk_filter_ignore.Value := (ctrl == this.view.chk_filter_ignore)
        }
        allChecked := this.view.chk_filter_new.Value && this.view.chk_filter_update.Value && this.view.chk_filter_overwrite.Value && this.view.chk_filter_same.Value && this.view.chk_filter_delete.Value && this.view.chk_filter_ignore.Value
        this.view.chk_filter_all.Value := allChecked
        this.render_import_lv()
    }

    on_filter_all(ctrl, *) {
        state := ctrl.Value
        this.view.chk_filter_new.Value := state
        this.view.chk_filter_update.Value := state
        this.view.chk_filter_overwrite.Value := state
        this.view.chk_filter_same.Value := state
        this.view.chk_filter_delete.Value := state
        this.view.chk_filter_ignore.Value := state
        this.render_import_lv()
    }

    on_filter_new(ctrl, *) {
        this.handle_filter_click(ctrl)
    }
    on_filter_update(ctrl, *) {
        this.handle_filter_click(ctrl)
    }
    on_filter_overwrite(ctrl, *) {
        this.handle_filter_click(ctrl)
    }
    on_filter_same(ctrl, *) {
        this.handle_filter_click(ctrl)
    }
    on_filter_delete(ctrl, *) {
        this.handle_filter_click(ctrl)
    }
    on_filter_ignore(ctrl, *) {
        this.handle_filter_click(ctrl)
    }

    on_import_list_view_click(*) {

    }
    on_import_list_view_item_select(*) {
        sel_count := this.view.lv_import.GetCount("S")
        ; this.view.btn_mark_delete.Opt(sel_count > 0 ? "-Disabled" : "+Disabled")
        ; this.view.btn_mark_ignore.Opt(sel_count > 0 ? "-Disabled" : "+Disabled")
        this.view.txt_sel_count.Value := "已选中: " sel_count " 项"
    }
    on_import_list_view_double_click(*) {

    }
    on_import_list_view_context_menu(*) {

    }

    on_mark_items_to_delete(*) {
        selected := []
        row := 0
        while (row := this.view.lv_import.GetNext(row))
            selected.Push(row)
        if (selected.Length == 0) {
            return
        }

        for r in selected {
            this.view.lv_import.Modify(r, "Col4", "D")
            title := this.view.lv_import.GetText(r, 1)
            old_id := this.view.lv_import.GetText(r, 2)
            new_id := this.view.lv_import.GetText(r, 3)
            for item in this.model.import_items {
                if (this.get_item_attr(item, "title") == title && this.get_item_attr(item, "local_id") == old_id && this.get_item_attr(item, "imported_id") == new_id) {
                    if HasProp(item, "action")
                        item.action := "D"
                    else if (Type(item) == "Map")
                        item["action"] := "D"
                    break
                }
            }
        }
        this.render_import_lv()
    }

    on_mark_items_to_ignore(*) {
        selected := []
        row := 0
        while (row := this.view.lv_import.GetNext(row))
            selected.Push(row)
        if (selected.Length == 0) {
            return
        }

        for r in selected {
            this.view.lv_import.Modify(r, "Col4", "i")
            title := this.view.lv_import.GetText(r, 1)
            old_id := this.view.lv_import.GetText(r, 2)
            new_id := this.view.lv_import.GetText(r, 3)
            for item in this.model.import_items {
                if (this.get_item_attr(item, "title") == title && this.get_item_attr(item, "local_id") == old_id && this.get_item_attr(item, "imported_id") == new_id) {
                    if HasProp(item, "action")
                        item.action := "i"
                    else if (Type(item) == "Map")
                        item["action"] := "i"
                    break
                }
            }
        }
        this.render_import_lv()
    }

    on_reset_import_view(*) {
        target_wb := (this.view.ddl_import_wb.Value > 1) ? this.import_wb_ids[this.view.ddl_import_wb.Value] : this.view.ddl_import_wb.Text
        this.refresh_import_diff(target_wb)
    }

    OnAddTargetWorkbench(*) {

    }

    OnReadExportedTxt(*) {
        owner_win := this.GetActiveModalOwner()
        try owner_win.Opt("+OwnDialogs")
        selectedFile := FileSelect(3, , "选择 CATIA 导出的 Workshop Exposition 文件", "Text Documents (*.txt)")
        if (selectedFile = "") {
            return
        }
        this.view.ddl_import_wb.Choose(1)
        try {
            this.model.parse_import_file(selectedFile)
            this.refresh_import_diff("通过导入文件确定")
        } catch Error as e {
            try owner_win.Opt("+OwnDialogs")
            MsgBox(e.Message, "解析错误", "Iconx")
        }
    }

    OnImportCommands(*) {
        owner_win := this.GetActiveModalOwner()
        cmd_id_dir := A_ScriptDir "\data\command-id"
        if !DirExist(cmd_id_dir) {
            try owner_win.Opt("+OwnDialogs")
            MsgBox("未找到工作台命令库目录：" cmd_id_dir, "错误", "Iconx")
            return
        }

        dlg := Gui("+Owner" owner_win.hwnd " -MinimizeBox -MaximizeBox", "导入内置工作台命令")
        owner_win.Opt("+Disabled")
        dlg.Add("Text", "x15 y15 w80 h20", "搜索工作台:")
        edit_search := dlg.Add("Edit", "x100 y11 w325 h24")
        lv := dlg.Add("ListView", "x15 y45 w410 h340 +Grid -Multi", ["工作台名称", "ID"])
        lv.ModifyCol(1, 260)
        lv.ModifyCol(2, 120)

        all_items := []
        loop files, cmd_id_dir "\*.txt" {
            id := StrReplace(A_LoopFileName, ".txt", "")
            all_items.Push({ name: AppSettings.GetWbName(id), id: id })
        }

        default_wb := (this.view.ddl_import_wb.Value > 1) ? this.import_wb_ids[this.view.ddl_import_wb.Value] : ""

        fill_lv(filter_str := "") {
            lv.Opt("-Redraw")
            lv.Delete()
            default_row := 0
            for item in all_items {
                if (filter_str != "" && !InStr(item.name, filter_str) && !InStr(item.id, filter_str)) {
                    continue
                }
                row := lv.Add("", item.name, item.id)
                if (default_wb != "" && item.id == default_wb)
                    default_row := row
            }
            lv.ModifyCol(1, "Sort")
            if (default_row > 0) {
                loop lv.GetCount() {
                    if (lv.GetText(A_Index, 2) == default_wb) {
                        lv.Modify(A_Index, "Select Focus Vis")
                        break
                    }
                }
            } else if (lv.GetCount() > 0) {
                lv.Modify(1, "Select Focus Vis")
            }
            lv.Opt("+Redraw")
        }
        fill_lv()
        edit_search.OnEvent("Change", (ctrl, *) => fill_lv(ctrl.Value))

        do_confirm(*) {
            row := lv.GetNext(0)
            if (row == 0) {
                MsgBox("请先选择一个工作台！", "提示", "Iconi")
                return
            }
            sel_id := lv.GetText(row, 2)
            try owner_win.Opt("-Disabled")
            dlg.Destroy()
            this.model.parse_import_file(cmd_id_dir "\" sel_id ".txt")
            this.view.ddl_import_wb.Choose(1)
            this.refresh_import_diff("通过导入文件确定")
        }

        close_dlg(*) {
            try owner_win.Opt("-Disabled")
            dlg.Destroy()
        }

        btn_confirm := dlg.Add("Button", "x110 y405 w100 h30 Default", "确认导入")
        btn_cancel := dlg.Add("Button", "x230 y405 w100 h30", "取消")
        btn_confirm.OnEvent("Click", do_confirm)
        lv.OnEvent("DoubleClick", do_confirm)
        btn_cancel.OnEvent("Click", close_dlg)
        dlg.OnEvent("Close", close_dlg)
        dlg.OnEvent("Escape", close_dlg)
        dlg.Show("w440 h450")
    }

    on_add_cmd_from_other(*) {
        wb_idx := this.view.ddl_workbench.Value
        target_wb := (wb_idx > 1 && wb_idx <= this.workbench_ids.Length) ? AppSettings.GetWbName(this.workbench_ids[wb_idx]) : ""
        if (target_wb == "") {
            return
        }

        owner_win := this.GetActiveModalOwner()
        dlg := Gui("+Resize +Owner" owner_win.hwnd " +MinSize350x300", "从指定工作台添加命令 - 目标: " target_wb)
        owner_win.Opt("+Disabled")

        on_dlg_size(GuiObj, MinMax, Width, Height) {
            if (MinMax == -1)
                return
            try {
                dlg_ddl_src.Move(, , Width - 120)
                dlg_edit_filter.Move(, , Width - 120)
                dlg_lv.Move(, , Width - 40, Height - 140)
                btn_w := (Width - 60) // 2
                dlg_btn_add.Move(20, Height - 45, btn_w)
                dlg_btn_cancel.Move(20 + btn_w + 20, Height - 45, btn_w)
            }
        }
        close_other_dlg(*) {
            try owner_win.Opt("-Disabled")
            try dlg.Destroy()
        }
        dlg.OnEvent("Size", on_dlg_size)
        dlg.OnEvent("Close", close_other_dlg)
        dlg.OnEvent("Escape", close_other_dlg)
        dlg.Add("Text", "x20 y20 w80 h20", "源工作台:")

        src_wbs := []
        for k, v in AppSettings.commands_obj {
            if (k != "_comment" && k != target_wb) {
                src_wbs.Push(k)
            }
        }
        if (src_wbs.Length == 0) {
            try owner_win.Opt("+OwnDialogs")
            MsgBox("没有其他工作台可供选择！", "提示", "Iconi")
            close_other_dlg()
            return
        }

        dlg_ddl_src := dlg.Add("DropDownList", "x100 y16 w330 Choose1", src_wbs)
        dlg.Add("Text", "x20 y52 w80 h20", "快速过滤:")
        dlg_edit_filter := dlg.Add("Edit", "x100 y48 w330 h22")
        dlg_lv := dlg.Add("ListView", "x20 y85 w410 h360", ["功能描述", "命令 ID"])
        dlg_lv.ModifyCol(1, 140)
        dlg_lv.ModifyCol(2, 200)
        dlg_btn_add := dlg.Add("Button", "x20 y455 w195 h30 Default", "添加")
        dlg_btn_cancel := dlg.Add("Button", "x235 y455 w195 h30", "取消")

        load_dlg_cmds(*) {
            dlg_lv.Delete()
            src_wb := dlg_ddl_src.Text
            if (src_wb == "")
                return

            filter := Trim(dlg_edit_filter.Value)
            target_cmds := Map()
            if AppSettings.commands_obj.Has(target_wb) {
                for cmd in AppSettings.commands_obj[target_wb] {
                    if cmd.Has("command")
                        target_cmds[cmd["command"]] := 1
                }
            }

            if AppSettings.commands_obj.Has(src_wb) {
                dlg_lv.Opt("-Redraw")
                for cmd in AppSettings.commands_obj[src_wb] {
                    desc := cmd.Has("desc") ? cmd["desc"] : ""
                    command := cmd.Has("command") ? cmd["command"] : ""
                    if (filter != "" && !InStr(desc, filter) && !InStr(command, filter)) {
                        continue
                    }
                    is_dup := target_cmds.Has(command)
                    dlg_lv.Add("", is_dup ? desc " (已存在)" : desc, command)
                }
                dlg_lv.Opt("+Redraw")
            }
        }

        dlg_ddl_src.OnEvent("Change", load_dlg_cmds)
        dlg_edit_filter.OnEvent("Change", load_dlg_cmds)

        do_add(*) {
            selected_indices := []
            row := 0
            while (row := dlg_lv.GetNext(row)) {
                selected_indices.Push(row)
            }

            if (selected_indices.Length == 0) {
                MsgBox("请先选择要添加的命令！", "提示", "Iconi")
                return
            }

            if !AppSettings.commands_obj.Has(target_wb)
                AppSettings.commands_obj[target_wb] := []

            target_cmd_list := AppSettings.commands_obj[target_wb]
            existing_cmds := Map()
            for c in target_cmd_list {
                if c.Has("command")
                    existing_cmds[c["command"]] := 1
            }

            src_wb := dlg_ddl_src.Text
            src_cmd_list := AppSettings.commands_obj[src_wb]
            added_count := 0
            skipped_count := 0

            for idx in selected_indices {
                cmd_id := dlg_lv.GetText(idx, 2)
                src_cmd := ""
                for c in src_cmd_list {
                    if (c.Has("command") && c["command"] == cmd_id) {
                        src_cmd := c
                        break
                    }
                }
                if (!src_cmd)
                    continue

                if (existing_cmds.Has(cmd_id)) {
                    skipped_count++
                    continue
                }

                new_cmd := Map()
                for k, v in src_cmd {
                    if (k == "aliases" || k == "hotkeys") {
                        arr_copy := []
                        for item in v {
                            arr_copy.Push(item)
                        }
                        new_cmd[k] := arr_copy
                    } else {
                        new_cmd[k] := v
                    }
                }
                target_cmd_list.Push(new_cmd)
                added_count++
            }

            if (added_count > 0) {
                if (!this.model.flush_commands_json(AppSettings.commands_obj)) {
                    return
                }
                this.model.init()
                this.load_command_tree(this.view.edit_search.Value)

                msg := "成功添加 " added_count " 个命令到 [" target_wb "]"
                if (skipped_count > 0)
                    msg .= "`n已自动忽略 " skipped_count " 个重复命令"
                try owner_win.Opt("+OwnDialogs")
                MsgBox(msg, "成功", "Iconi T2")
                close_other_dlg()
            } else {
                try owner_win.Opt("+OwnDialogs")
                MsgBox("未添加任何命令（所选命令在目标工作台均已存在）。", "提示", "Iconi")
            }
        }

        dlg_btn_add.OnEvent("Click", do_add)
        dlg_btn_cancel.OnEvent("Click", close_other_dlg)
        load_dlg_cmds()
        dlg.Show("w450 h500")
    }

    on_apply_import_all(*) {
        target_wb := (this.view.ddl_import_wb.Value > 1) ? this.import_wb_ids[this.view.ddl_import_wb.Value] : this.view.ddl_import_wb.Text
        if (target_wb == "通过导入文件确定" || target_wb == "") {
            MsgBox("请先选择目标工作台或导入文件", "提示", "Iconi")
            return
        }

        if !AppSettings.commands_obj.Has(target_wb)
            AppSettings.commands_obj[target_wb] := []
        local_array := AppSettings.commands_obj[target_wb]

        local_by_id := Map()
        for cmd in local_array
            local_by_id[cmd["command"]] := cmd

        selected_keys := Map()
        row := 0
        while (row := this.view.lv_import.GetNext(row)) {
            title := this.view.lv_import.GetText(row, 1)
            old_id := this.view.lv_import.GetText(row, 2)
            new_id := this.view.lv_import.GetText(row, 3)
            selected_keys[title "_" old_id "_" new_id] := true
        }

        c_new := 0, c_upd := 0, c_ovr := 0, c_del := 0
        strNew := "", strUpd := "", strOvr := "", strDel := ""

        for item in this.model.import_items {
            item_title := this.get_item_attr(item, "title")
            item_local := this.get_item_attr(item, "local_id")
            item_imported := this.get_item_attr(item, "imported_id")
            if !selected_keys.Has(item_title "_" item_local "_" item_imported)
                continue
            a := this.get_item_attr(item, "action")
            if (a == "+") {
                c_new++
                strNew .= "- " item_title " (" item_imported ")`r`n"
            } else if (a == "T") {
                c_upd++
                strUpd .= "- " item_title " (" item_imported ")`r`n"
            } else if (a == "C") {
                c_ovr++
                strOvr .= "- " item_title " (" item_imported ")`r`n"
            } else if (a == "D") {
                c_del++
                strDel .= "- " item_title " (" item_local ")`r`n"
            }
        }

        owner_win := this.GetActiveModalOwner()
        if (c_new == 0 && c_upd == 0 && c_ovr == 0 && c_del == 0) {
            try owner_win.Opt("+OwnDialogs")
            MsgBox("没有实质性的修改需要应用。", "提示", "Iconi")
            return
        }

        full_msg := ""
        if c_new > 0
            full_msg .= "【新增】(数量: " c_new ")`r`n" strNew "`r`n"
        if c_upd > 0
            full_msg .= "【更新标题】(数量: " c_upd ")`r`n" strUpd "`r`n"
        if c_ovr > 0
            full_msg .= "【更新命令】(数量: " c_ovr ")`r`n" strOvr "`r`n"
        if c_del > 0
            full_msg .= "【删除】(数量: " c_del ")`r`n" strDel "`r`n"

        confirm_gui := Gui("+Owner" owner_win.hwnd " +ToolWindow -MinimizeBox -MaximizeBox", "确认执行以下操作")
        confirm_gui.Add("Text", "x15 y15 w450 h20", "应用到 [" AppSettings.GetWbName(target_wb) "] 工作台:")
        confirm_gui.Add("Edit", "x15 y40 w450 h300 ReadOnly Multi VScroll", full_msg)

        user_confirmed := false
        close_dialog(confirmed, *) {
            user_confirmed := confirmed
            try owner_win.Opt("-Disabled")
            confirm_gui.Destroy()
        }

        btn_ok := confirm_gui.Add("Button", "x250 y350 w100 h30 Default", "确认")
        btn_ok.OnEvent("Click", close_dialog.Bind(true))
        btn_cancel := confirm_gui.Add("Button", "x365 y350 w100 h30", "取消")
        btn_cancel.OnEvent("Click", close_dialog.Bind(false))
        confirm_gui.OnEvent("Close", close_dialog.Bind(false))
        confirm_gui.OnEvent("Escape", close_dialog.Bind(false))

        owner_win.Opt("+Disabled")
        confirm_gui.Show("AutoSize Center")
        btn_cancel.Focus()
        WinWaitClose(confirm_gui.hwnd)

        if (!user_confirmed) {
            return
        }

        new_array := []
        added_command_ids := Map()
        replaced_old_ids := Map()

        for item in this.model.import_items {
            title := this.get_item_attr(item, "title")
            old_id := this.get_item_attr(item, "local_id")
            action := this.get_item_attr(item, "action")
            new_id := this.get_item_attr(item, "imported_id")

            if selected_keys.Has(title "_" old_id "_" new_id) && action == "C" {
                if (old_id != "" && old_id != new_id)
                    replaced_old_ids[old_id] := true
            }
        }

        for item in this.model.import_items {
            title := this.get_item_attr(item, "title")
            old_id := this.get_item_attr(item, "local_id")
            action := this.get_item_attr(item, "action")
            new_id := this.get_item_attr(item, "imported_id")

            if !selected_keys.Has(title "_" old_id "_" new_id)
                action := "i"

            cmd_to_push := ""
            if (action == "i" || action == "=") {
                if (old_id != "" && !replaced_old_ids.Has(old_id) && local_by_id.Has(old_id))
                    cmd_to_push := local_by_id[old_id]
            } else if (action == "+") {
                if (new_id != "")
                    cmd_to_push := Map("desc", title, "command", new_id, "aliases", [], "hotkeys", [])
            } else if (action == "T") {
                if (old_id != "" && local_by_id.Has(old_id)) {
                    cmd_to_push := local_by_id[old_id].Clone()
                    cmd_to_push["desc"] := title
                }
            } else if (action == "C") {
                if (old_id != "" && local_by_id.Has(old_id)) {
                    cmd_to_push := local_by_id[old_id].Clone()
                    cmd_to_push["command"] := new_id
                    cmd_to_push["desc"] := title
                }
            } else if (action == "D") {
                ; drop
            }

            if IsObject(cmd_to_push) {
                cmd_id := (Type(cmd_to_push) == "Map") ? (cmd_to_push.Has("command") ? cmd_to_push["command"] : "") : (HasProp(cmd_to_push, "command") ? cmd_to_push.command : "")
                if (cmd_id != "" && !added_command_ids.Has(cmd_id)) {
                    added_command_ids[cmd_id] := true
                    new_array.Push(cmd_to_push)
                }
            }
        }

        AppSettings.commands_obj[target_wb] := new_array
        if (!this.model.flush_commands_json(AppSettings.commands_obj)) {
            return
        }
        try owner_win.Opt("+OwnDialogs")
        MsgBox("成功！请重新载入UCLC使修改生效。", "成功", "Iconi")
        this.on_reset_import_view()
    }
}

class UpdateGUI extends Gui {
    __New(latestVersion, currentVersion, releaseNotes, downloadUrl, parentGui := "") {
        super.__New("-MinimizeBox +MaximizeBox +Resize" . (parentGui ? " +Owner" . parentGui.Hwnd : ""), "UCLC 软件更新")
        this.Opt("+MinSize500x380")

        this.parentGui := parentGui
        this.latestVersion := latestVersion
        this.downloadUrl := downloadUrl

        is_preview := (InStr(latestVersion, "-") || InStr(latestVersion, "dev") || InStr(latestVersion, "beta") || InStr(latestVersion, "alpha") || InStr(latestVersion, "rc") || InStr(latestVersion, "preview"))
        ver_tag := is_preview ? " [预览版]" : " [稳定版]"
        this.SetFont("s13 bold c0078D7", "Segoe UI Emoji")
        this.txt_latest := this.Add("Text", "x25 y20 w470 h25", "✨ 发现新版本 " latestVersion ver_tag)
        this.SetFont("s9.5 norm c666666", "Segoe UI Emoji")
        this.txt_current := this.Add("Text", "x25 y48 w470 h20", "当前版本: " currentVersion)
        this.SetFont("s9 norm cDefault", "Segoe UI Emoji")

        this.gb_notes := this.Add("GroupBox", "x20 y78 w480 h245", " 📋 版本更新说明与日志 ")
        this.edit_notes := this.Add("Edit", "x32 y102 w456 h208 ReadOnly Multi +VScroll -E0x200 -Tabstop", releaseNotes)

        this.btn_skip := this.Add("Button", "x20 y338 w100 h34", "跳过此版本")
        this.btn_cancel := this.Add("Button", "x245 y338 w100 h34", "暂不更新")
        this.SetFont("bold", "Segoe UI Emoji")
        this.btn_download := this.Add("Button", "x355 y338 w145 h34 Default", "🚀 前往下载更新")
        this.SetFont("norm", "Default")

        this.btn_download.OnEvent("Click", ObjBindMethod(this, "OnDownload"))
        this.btn_skip.OnEvent("Click", ObjBindMethod(this, "OnSkip"))
        this.btn_cancel.OnEvent("Click", ObjBindMethod(this, "OnCancel"))
        this.OnEvent("Close", ObjBindMethod(this, "OnCancel"))
        this.OnEvent("Escape", ObjBindMethod(this, "OnCancel"))
        this.OnEvent("Size", ObjBindMethod(this, "OnSize"))
    }

    UpdateData(latestVersion, currentVersion, releaseNotes, downloadUrl) {
        this.latestVersion := latestVersion
        this.downloadUrl := downloadUrl
        is_preview := (InStr(latestVersion, "-") || InStr(latestVersion, "dev") || InStr(latestVersion, "beta") || InStr(latestVersion, "alpha") || InStr(latestVersion, "rc") || InStr(latestVersion, "preview"))
        ver_tag := is_preview ? " [预览版]" : " [稳定版]"
        this.txt_latest.Value := "✨ 发现新版本 " latestVersion ver_tag
        this.txt_current.Value := "当前版本: " currentVersion
        this.edit_notes.Value := releaseNotes
    }

    OnSize(guiObj, minMax, width, height, *) {
        if (minMax == -1)
            return
        try {
            this.txt_latest.Move(, , width - 50)
            this.txt_current.Move(, , width - 50)
            this.gb_notes.Move(, , width - 40, height - 145)
            this.edit_notes.Move(, , width - 64, height - 182)
            btnY := height - 52
            this.btn_skip.Move(, btnY)
            this.btn_cancel.Move(width - 275, btnY)
            this.btn_download.Move(width - 165, btnY)
        }
    }

    CloseModal() {
        if (this.HasProp("parentGui") && this.parentGui) {
            try this.parentGui.Opt("-Disabled")
            try WinActivate(this.parentGui.Hwnd)
        }
        this.Destroy()
        UpdateGUI.instance := ""
    }

    OnDownload(*) {
        if (this.downloadUrl != "")
            Run(this.downloadUrl)
        this.CloseModal()
    }

    OnSkip(*) {
        AppSettings.SaveUpdaterConfig("SkippedVersion", this.latestVersion)
        this.CloseModal()
    }

    OnCancel(*) {
        this.CloseModal()
    }

    static instance := ""
}

ShowUpdateGUI(latestVersion, currentVersion, releaseNotes, downloadUrl, parentGui := "") {
    if (UpdateGUI.instance && WinExist(UpdateGUI.instance.Hwnd)) {
        UpdateGUI.instance.UpdateData(latestVersion, currentVersion, releaseNotes, downloadUrl)
        if (UpdateGUI.instance.HasProp("parentGui") && UpdateGUI.instance.parentGui)
            try UpdateGUI.instance.parentGui.Opt("+Disabled")
        UpdateGUI.instance.Show()
        try UpdateGUI.instance.btn_download.Focus()
        try SendMessage(0x00B1, 0, 0, UpdateGUI.instance.edit_notes.Hwnd)
        return
    }
    if (parentGui)
        try parentGui.Opt("+Disabled")
    UpdateGUI.instance := UpdateGUI(latestVersion, currentVersion, releaseNotes, downloadUrl, parentGui)
    UpdateGUI.instance.Show("w660 h500 Center")
    try UpdateGUI.instance.btn_download.Focus()
    try SendMessage(0x00B1, 0, 0, UpdateGUI.instance.edit_notes.Hwnd)
}