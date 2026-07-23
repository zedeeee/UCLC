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

about_cb(*)
{
    MsgBox Format("一个CATIA快捷键脚本`n使CATIA的操作体验更接近AutoCAD`n版本：{1}", AppSettings.Version), "UCLC", 0x40
}

update_check_cb(*)
{
}


reload_cb(*) {
    Reload
}

disable_script_cb(ItemName, ItemPos, MyMenu)
{
    menu_toggleCheck_cb(ItemName, ItemPos, MyMenu)
    Suspend(-1)
}

exit_cb(*) {
    ExitApp
}

menu_toggleCheck_cb(ItemName, ItemPos, MyMenu)
{
    MyMenu.ToggleCheck(ItemName)
}

Nothing_cb(*) {
    ; Do Nothing
}

NoAction_cb(*) {
    ; Do Nothing
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

disable_botton_cb(ItemName, ItemPos, MyMenu) {
    MyMenu.Disable(ItemName)
}

add_sub_menu(ItemName, ItemPos, MyMenu) {

}

about_and_updates_menu := [
    ["关于", about_cb, ""],
    ["项目主页", showProjectHomepage_cb, ""],
    ["自定义帮助", help_Homepage_cb, ""],
    ["检查更新", NoAction_cb, ""]
]

dev_sub_menu := [
    ["None", Nothing_cb, ""],
]

/**
 * ["按钮名称", 回调函数, 子菜单数组]
 */
menu_items := [
    ["UCLC " AppSettings.Version, NoAction_cb, about_and_updates_menu],
    ["", NoAction_cb, ""],
    ["打开脚本所在文件夹", open_script_folder_cb, ""],
    ["开发功能", NoAction_cb, dev_sub_menu],
    ["", NoAction_cb, ""],
    ; ["配置", disable_botton_cb, ""],
    ["Windows Spy", run_spy_cb, ""],
    ["重新载入", reload_cb, ""],
    ["禁用脚本", disable_script_cb, ""],
    ["设置...", ShowSettingsGUI, ""],
    ["退出", exit_cb, ""]
]


add_coustom_tray_menu()
{
    TraySetIcon("./icon/color-icon64.png")

    A_IconTip := "UCLC: 像AutoCAD一样使用CATIA"

    cus_tray_menu := Menu()

    A_TrayMenu.Delete()

    for menu_item in menu_items
    {
        button_name := menu_item[1]
        callback_function := menu_item[2]
        sub_menu_items := menu_item[3]

        if button_name == ""
        {
            A_TrayMenu.Add()
            continue
        }

        ; 如果子菜单不为空， 开始注册子菜单
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
    A_TrayMenu.Default := "设置..."
    ; A_TrayMenu.Rename(menu_items[1][1], "UCLC")
}

;-==== [ 原模块: SettingsGUI.ahk ] ====-
show_settings_gui(*) {
    static controller := ""
    if (!controller || !controller.is_valid()) {
        model := SettingsModel()
        view := SettingsView()
        controller := SettingsController(model, view)
    }
    controller.show()
}

ShowSettingsGUI(*) => show_settings_gui()

safe_atomic_write(filepath, content) {
    tmp_path := filepath . ".tmp"
    bak_path := filepath . ".bak"

    if FileExist(tmp_path)
        FileDelete(tmp_path)

    f := FileOpen(tmp_path, "w", "UTF-8")
    f.Write(content)
    f.Close()

    has_orig := FileExist(filepath)
    if (has_orig) {
        FileCopy(filepath, bak_path, 1)
    }

    try {
        FileMove(tmp_path, filepath, 1)
        return true
    } catch Error as err {
        if (has_orig && FileExist(bak_path))
            FileCopy(bak_path, filepath, 1)
        throw Error("文件原子写入失败: " err.Message)
    }
}

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
    hk .= key
    return hk
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
        current_json := JSON.stringify(current_obj)
        return current_json !== this.original_json_str
    }

    get_unsaved_changes_summary(curr_obj) {
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

            for i, cmd in cmds {
                if (i > orig_cmds.Length) {
                    title := cmd.Has("desc") && cmd["desc"] != "" ? cmd["desc"] : cmd["command"]
                    wb_diffs.Push("  + 新增: " title)
                } else {
                    orig_cmd := orig_cmds[i]
                    if (JSON.stringify(cmd) != JSON.stringify(orig_cmd)) {
                        title := cmd.Has("desc") && cmd["desc"] != "" ? cmd["desc"] : cmd["command"]
                        wb_diffs.Push("  * 修改: " title)
                    }
                }
            }
            if (orig_cmds.Length > cmds.Length) {
                loop (orig_cmds.Length - cmds.Length) {
                    orig_cmd := orig_cmds[cmds.Length + A_Index]
                    title := orig_cmd.Has("desc") && orig_cmd["desc"] != "" ? orig_cmd["desc"] : orig_cmd["command"]
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

    flush_commands_json(curr_obj) {
        AppSettings.commands_obj := curr_obj
        try {
            safe_atomic_write(AppSettings.commands_json_path, JSON.stringify(AppSettings.commands_obj))
        } catch Error as e {
            MsgBox("写入 JSON 文件失败: " e.Message, "错误", 16)
        }
    }

    save_general_settings(everythingEnabled, everythingPath, debugEnabled, autoImeEnabled, autoImeMap) {
        try {
            if !AppSettings.config_obj.Has("Everything") {
                AppSettings.config_obj["Everything"] := Map("Enabled", "0", "Path", "")
            }
            AppSettings.config_obj["Everything"]["Enabled"] := String(everythingEnabled)
            AppSettings.config_obj["Everything"]["Path"] := everythingPath

            if !AppSettings.config_obj.Has("通用") {
                AppSettings.config_obj["通用"] := Map("DEBUG", "0")
            }
            AppSettings.config_obj["通用"]["DEBUG"] := String(debugEnabled)

            autoImeMap["Enabled"] := String(autoImeEnabled)
            AppSettings.config_obj["AutoIME"] := autoImeMap

            AppSettings.Everything_Enabled := everythingEnabled
            AppSettings.Everything_Path := everythingPath
            AppSettings.DEBUG_I := debugEnabled
            AppSettings.AutoIME_Enabled := autoImeEnabled

            safe_atomic_write(AppSettings.config_json_path, JSON.stringify(AppSettings.config_obj))
            return true
        } catch Error as e {
            MsgBox("保存失败: " e.Message, "错误", 16)
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

        this.tabs := this.Add("Tab3", "x10 y10 w530 h410", ["命令配置", "系统设置"])

        ; =============== 第一页: 命令配置 ===============
        this.tabs.UseTab(1)

        ; ====================
        ; 左侧：命令树与导入
        ; ====================
        this.tv_alias := this.Add("TreeView", "x20 y45 w190 h330")
        this.Btn_OpenCmdLib := this.Add("Button", "x20 y380 w190 h28", "导入命令ID")

        ; ====================
        ; 右侧上：全局检索区
        ; ====================
        this.Add("Text", "x235 y45 w60", "工作台:")
        this.ddl_workbench := this.Add("DropDownList", "x295 y40 w195 Choose1", ["全部工作台"])

        this.Add("Text", "x235 y75 w60", "搜　索:")
        this.edit_search := this.Add("Edit", "x295 y72 w195")

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
        this.edit_desc := this.Add("Edit", "x295 y168 w195 Hidden ReadOnly", "")

        this.Txt_Cmd := this.Add("Text", "x235 y201 w60 Hidden", "执行指令:")
        this.Edit_Cmd := this.Add("Edit", "x295 y198 w195 Hidden ReadOnly", "")

        this.Txt_Alias := this.Add("Text", "x235 y231 w60 Hidden", "触发别名:")

        this.alias_pool := []
        loop 10 {
            e := this.Add("Edit", "x295 y0 w135 Hidden Uppercase", "")
            btn_add := this.Add("Button", "x440 y0 w24 h24 Hidden", "➕")
            btn_del := this.Add("Button", "x466 y0 w24 h24 Hidden", "➖")
            this.alias_pool.Push({ e: e, add: btn_add, del: btn_del })
        }

        this.Txt_Hotkey := this.Add("Text", "x235 y0 w60 Hidden", "绑定热键:")
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

        ; =============== 第二页: 系统设置 ===============
        this.tabs.UseTab(2)
        this.Add("GroupBox", "x20 y40 w510 h90", "Everything 快速呼出")
        this.Chk_Everything := this.Add("Checkbox", "x35 y61", "启用双击右 Ctrl 唤起 Everything")
        this.Add("Text", "x35 y92 w70", "Program 路径:")
        this.Edit_EverythingPath := this.Add("Edit", "x105 y88 w345 h24", "")
        this.Btn_BrowseEverything := this.Add("Button", "x455 y87 w65 h26", "浏览...")

        this.Add("GroupBox", "x20 y135 w510 h185", "输入法自动切换")
        this.Chk_AutoIME := this.Add("Checkbox", "x30 y135", "激活特定窗口时自动切为英文")

        this.lv_autoime := this.Add("ListView", "x30 y162 w355 h120 Grid -Multi", ["软件名称", "进程名称 (exe)"])
        this.lv_autoime.ModifyCol(1, 150)
        this.lv_autoime.ModifyCol(2, 200)

        this.btn_add_autoime := this.Add("Button", "x395 y162 w120 h26", "➕ 添加规则")
        this.btn_del_autoime := this.Add("Button", "x395 y196 w120 h26", "➖ 删除规则")
        this.btn_edit_autoime := this.Add("Button", "x395 y230 w120 h26", "✏️ 修改规则")
        this.link_ime_guide := this.Add("Link", "x30 y290 w490 cGray", "说明：当匹配的主程序窗口激活时，系统将自动切换至英文输入法（<a id=`"guide`">前提条件</a>）。")

        this.Add("GroupBox", "x20 y330 w510 h60", "日志与调试")
        this.Chk_Debug := this.Add("Checkbox", "x35 y352", "开启详细 Debug 调试日志")

        this.btn_saveGen := this.Add("Button", "x400 y410 w130 h30 Default", "保存系统设置")

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
}


class SettingsController {
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
        this.view.Show("w550 h440")
    }

    BindEvents() {
        this.view.OnEvent("Close", ObjBindMethod(this, "OnClose"))
        this.view.OnEvent("Escape", ObjBindMethod(this, "OnClose"))
        this.on_mouse_move_bound := ObjBindMethod(this, "on_mouse_move")
        OnMessage(0x0200, this.on_mouse_move_bound)

        this.view.ddl_workbench.OnEvent("Change", ObjBindMethod(this, "OnWorkbenchFilter"))
        this.view.edit_search.OnEvent("Change", ObjBindMethod(this, "OnSearchFilter"))
        this.view.tv_alias.OnEvent("ItemSelect", ObjBindMethod(this, "on_command_tree_select"))

        for idx, p in this.view.alias_pool {
            p.add.OnEvent("Click", ObjBindMethod(this, "OnAddAlias", idx))
            p.del.OnEvent("Click", ObjBindMethod(this, "OnDelAlias", idx))
            p.e.OnEvent("Change", ObjBindMethod(this, "OnAliasChange", idx))
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
        this.view.btn_saveGen.OnEvent("Click", ObjBindMethod(this, "SaveGeneralSettings"))

        this.view.Chk_AutoIME.OnEvent("Click", ObjBindMethod(this, "OnToggleAutoIME"))
        this.view.btn_add_autoime.OnEvent("Click", ObjBindMethod(this, "OnAddAutoIME"))
        this.view.btn_del_autoime.OnEvent("Click", ObjBindMethod(this, "OnDeleteAutoIME"))
        this.view.btn_edit_autoime.OnEvent("Click", ObjBindMethod(this, "OnEditAutoIME"))
        this.view.lv_autoime.OnEvent("DoubleClick", ObjBindMethod(this, "OnEditAutoIME"))
        this.view.link_ime_guide.OnEvent("Click", ObjBindMethod(this, "OnShowImeGuide"))

        this.view.Btn_OpenCmdLib.OnEvent("Click", ObjBindMethod(this, "OnOpenCmdLibraryModal"))
    }

    LoadGeneralSettings() {
        this.view.Chk_Everything.Value := AppSettings.Everything_Enabled
        this.view.Edit_EverythingPath.Value := AppSettings.Everything_Path

        this.view.Chk_Debug.Value := AppSettings.DEBUG_I
        this.view.Chk_AutoIME.Value := AppSettings.AutoIME_Enabled

        this.view.lv_autoime.Opt("-Redraw")
        this.view.lv_autoime.Delete()
        if AppSettings.config_obj.Has("AutoIME") {
            for label, exe in AppSettings.config_obj["AutoIME"] {
                if (label != "Enabled") {
                    this.view.lv_autoime.Add("", label, exe)
                }
            }
        }
        this.view.lv_autoime.Opt("+Redraw")
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
            this.view.ddl_import_wb.Delete()
            this.view.ddl_import_wb.Add(wb_list3)
            this.view.ddl_import_wb.Choose(1)
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

    load_command_tree(filter := "") {
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
    }

    OnWorkbenchFilter(CtrlObj, *) {
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

        res := this.view.render_detail_panel(AppSettings.GetWbName(info.category), info.cmd)
        this.alias_edits := res.alias_edits
        this.hotkey_edits := res.hotkey_edits

        this.CheckGlobalDirty()
        this.view.SB.SetText("")
    }

    SaveInputsToCurrentCmd() {
        itemId := this.view.tv_alias.GetSelection()
        if (!itemId || !this.tv_map.Has(itemId) || this.tv_map[itemId].type != "Item") {
            return
        }

        cmd := this.tv_map[itemId].cmd
        cmd["command"] := Trim(this.view.Edit_Cmd.Value)
        cmd["desc"] := Trim(this.view.edit_desc.Value)

        cmd["aliases"] := []
        for e in this.alias_edits {
            v := Trim(e.Value)
            if (v != "")
                cmd["aliases"].Push(v)
        }

        cmd["hotkeys"] := []
        for e in this.hotkey_edits {
            v := Trim(e.Value)
            if (v != "")
                cmd["hotkeys"].Push(parse_hotkey_from_display(v))
        }
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

    CheckGlobalDirty() {
        is_dirty := this.model.check_dirty(AppSettings.commands_obj)
        this.view.btn_save.Opt(is_dirty ? "-Disabled" : "+Disabled")

        for id, info in this.tv_map {
            if (info.type == "Item") {
                orig_cmd := ""
                wb := info.category
                if (this.model.original_commands_obj.Has(wb) && this.model.original_commands_obj[wb].Length >= info.index) {
                    orig_cmd := this.model.original_commands_obj[wb][info.index]
                }

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
    }

    OnDetailChange(*) {
        this.SaveInputsToCurrentCmd()
        this.CheckGlobalDirty()
    }

    OnAliasChange(idx, GuiCtrlObj, *) {
        p := this.view.alias_pool[idx]
        p.add.Opt((Trim(GuiCtrlObj.Value) != "") ? "-Disabled" : "+Disabled")
        this.SaveInputsToCurrentCmd()
        this.CheckGlobalDirty()
    }

    OnHotkeyChange(idx, GuiCtrlObj, *) {
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
    }

    OnInputHookEnd(idx, GuiCtrlObj, ih) {
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
        index := this.tv_map[itemId].index

        orig_cmd := ""
        if (this.model.original_commands_obj.Has(wb) && this.model.original_commands_obj[wb].Length >= index) {
            orig_cmd := this.model.original_commands_obj[wb][index]
        }
        if (orig_cmd != "") {
            restored_cmd := JSON.parse(JSON.stringify(orig_cmd))
            this.tv_map[itemId].cmd := restored_cmd
            if (AppSettings.commands_obj.Has(wb) && AppSettings.commands_obj[wb].Length >= index)
                AppSettings.commands_obj[wb][index] := restored_cmd
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
                orig_cmd := ""
                wb := info.category
                if (this.model.original_commands_obj.Has(wb) && this.model.original_commands_obj[wb].Length >= info.index)
                    orig_cmd := this.model.original_commands_obj[wb][info.index]
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

        this.model.flush_commands_json(AppSettings.commands_obj)
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

    OnToggleAutoIME(*) {
        enabled := this.view.Chk_AutoIME.Value
        opt := enabled ? "-Disabled" : "+Disabled"
        this.view.lv_autoime.Opt(opt)
        this.view.btn_add_autoime.Opt(opt)
        this.view.btn_del_autoime.Opt(opt)
        this.view.btn_edit_autoime.Opt(opt)
        this.view.link_ime_guide.Opt(opt)
    }

    OnShowImeGuide(*) {
        msg := "【自动切换英文输入法前提条件】`n`n"
            . "1. 必须在 Windows 系统语言设置中添加并启用英文输入法（例如：英语(美国) - 美式键盘）。`n`n"
            . "提示：如果系统中仅存在单语言中文输入法，无法通过 Shift 键自动切换中英文状态。"
        MsgBox(msg, "输入法配置说明", "Iconi")
    }

    OnAddAutoIME(*) => this.show_auto_ime_modal()

    OnEditAutoIME(*) {
        row := this.view.lv_autoime.GetNext(0)
        if (row == 0) {
            MsgBox("请先在表格中选择要修改的规则！", "提示", "Iconi")
            return
        }
        label := this.view.lv_autoime.GetText(row, 1)
        exe := this.view.lv_autoime.GetText(row, 2)
        this.show_auto_ime_modal(label, exe, row)
    }

    OnDeleteAutoIME(*) {
        row := this.view.lv_autoime.GetNext(0)
        if (row == 0) {
            MsgBox("请先在表格中选择要删除的规则！", "提示", "Iconi")
            return
        }
        label := this.view.lv_autoime.GetText(row, 1)
        if (MsgBox("移除 " label " 输入法自动切换？", "移除规则", "YesNo Icon?") == "Yes") {
            this.view.lv_autoime.Delete(row)
        }
    }

    show_auto_ime_modal(default_label := "", default_exe := "", edit_row := 0) {
        title := edit_row > 0 ? "修改规则" : "添加规则"
        dlg := Gui("+Owner" this.view.hwnd " -MinimizeBox -MaximizeBox", title)
        this.view.Opt("+Disabled")

        dlg.Add("Text", "x15 y20 h20 Right", "软件名称:")
        edit_label := dlg.Add("Edit", "x85 y16 w240 h24", default_label)

        dlg.Add("Text", "x15 y55 h20 Right", "进程名称:")
        edit_exe := dlg.Add("Edit", "x85 y51 w240 h24 ReadOnly", default_exe)

        btn_capture := dlg.Add("Button", "x85 y83 w240 h26", "指定目标程序")

        close_dlg(*) {
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
                            MsgBox("不能选择桌面或系统资源管理器！", "提示", "Iconi")
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
                MsgBox("请输入软件名称！", "提示", "Iconi")
                edit_label.Focus()
                return
            }
            if (exe == "") {
                MsgBox("请点击【获取目标窗口】以获取进程名称！", "提示", "Iconi")
                return
            }

            if (edit_row > 0) {
                this.view.lv_autoime.Modify(edit_row, "", label, exe)
            } else {
                this.view.lv_autoime.Add("", label, exe)
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

    SaveGeneralSettings(*) {
        auto_ime_map := Map()
        loop this.view.lv_autoime.GetCount() {
            label := this.view.lv_autoime.GetText(A_Index, 1)
            exe := this.view.lv_autoime.GetText(A_Index, 2)
            if (label != "" && exe != "" && label != "Enabled") {
                auto_ime_map[label] := exe
            }
        }

        success := this.model.save_general_settings(
            this.view.Chk_Everything.Value,
            this.view.Edit_EverythingPath.Value,
            this.view.Chk_Debug.Value,
            this.view.Chk_AutoIME.Value,
            auto_ime_map
        )
        if success
            this.view.SB.SetText("通用设置保存成功！请手动重新载入 UCLC 脚本以使其生效。")
    }

    on_mouse_move(wParam, lParam, msg, hwnd) {
        static prev_hwnd := 0
        static hover_timer := 0
        if (hwnd == prev_hwnd) {
            return
        }
        prev_hwnd := hwnd
        if (hover_timer) {
            SetTimer(hover_timer, 0)
            hover_timer := 0
        }
        ToolTip()
        try {
            guiCtrl := GuiCtrlFromHwnd(hwnd)
            if (guiCtrl && guiCtrl.HasProp("ToolTip") && guiCtrl.ToolTip != "") {
                tipText := guiCtrl.ToolTip
                hover_timer := () => ToolTip(tipText)
                SetTimer(hover_timer, -600)
            }
        }
    }

    OnOpenCmdLibraryModal(*) {
        dlg := Gui("+Owner" this.view.hwnd " -MinimizeBox -MaximizeBox", "工作台命令库管理")
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
        this.view.Btn_AddWb := dlg.Add("Button", "x355 y39 w24 h22", "+")
        this.view.Btn_ImportCommands := dlg.Add("Button", "x500 y39 w120 h22", "导入命令")
        this.view.Btn_ReadTxt := dlg.Add("Button", "x630 y39 w120 h22", "从 TXT 导入")

        dlg.Add("GroupBox", "x20 y90 w740 h410", "同步状态视图")
        dlg.Add("Text", "x25 y105 w60 h32 +0x200", "视图筛选:")

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
        this.view.chk_filter_same := dlg.Add("CheckBox", "x471 y105 w60 h32 Checked", "一致`n(0)")

        dlg.SetFont("s9 bold cE81123")
        dlg.Add("Text", "x541 y105 w14 h32 +0x200", "D")
        dlg.SetFont("s9 norm cDefault")
        this.view.chk_filter_delete := dlg.Add("CheckBox", "x555 y105 w75 h32 Checked", "待删除`n(0)")

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
            this.view.Opt("-Disabled")
            dlg.Destroy()
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

    render_import_lv() {
        items := this.model.import_items
        c_new := 0, c_upd := 0, c_ovr := 0, c_sam := 0, c_del := 0, c_ign := 0
        for item in items {
            a := item.action
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
        this.view.chk_filter_same.Text := "一致`n(" c_sam ")"
        this.view.chk_filter_delete.Text := "待删除`n(" c_del ")"
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
            a := item.action
            if ((a == "+" && showNew) || (a == "T" && showUpdate) || (a == "C" && showOverwrite)
                || (a == "=" && showSame) || (a == "D" && showDelete) || (a == "i" && showIgnore)) {
                this.view.lv_import.Add("", item.title, item.local_id, item.imported_id, a)
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
        this.view.btn_mark_delete.Opt(sel_count > 0 ? "-Disabled" : "+Disabled")
        this.view.btn_mark_ignore.Opt(sel_count > 0 ? "-Disabled" : "+Disabled")
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
                if (item.title == title && item.local_id == old_id && item.imported_id == new_id) {
                    item.action := "D"
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
                if (item.title == title && item.local_id == old_id && item.imported_id == new_id) {
                    item.action := "i"
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
        selectedFile := FileSelect(3, , "选择 CATIA 导出的 Workshop Exposition 文件", "Text Documents (*.txt)")
        if (selectedFile = "") {
            return
        }
        this.view.ddl_import_wb.Choose(1)
        try {
            this.model.parse_import_file(selectedFile)
            this.refresh_import_diff("通过导入文件确定")
        } catch Error as e {
            MsgBox(e.Message, "解析错误", "Iconx")
        }
    }

    OnImportCommands(*) {
        cmd_id_dir := A_ScriptDir "\data\command-id"
        if !DirExist(cmd_id_dir) {
            MsgBox("未找到工作台命令库目录：" cmd_id_dir, "错误", "Iconx")
            return
        }

        dlg := Gui("+Owner" this.view.hwnd " -MinimizeBox -MaximizeBox", "导入内置工作台命令")
        this.view.Opt("+Disabled")
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
            this.view.Opt("-Disabled")
            dlg.Destroy()
            this.model.parse_import_file(cmd_id_dir "\" sel_id ".txt")
            this.view.ddl_import_wb.Choose(1)
            this.refresh_import_diff("通过导入文件确定")
        }

        close_dlg(*) {
            this.view.Opt("-Disabled")
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
        target_wb := this.view.ddl_workbench.Text
        if (target_wb == "全部工作台" || target_wb == "") {
            return
        }

        dlg := Gui("+Resize +Owner" this.view.hwnd " +MinSize350x300", "从指定工作台添加命令 - 目标: " target_wb)

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
        dlg.OnEvent("Size", on_dlg_size)
        dlg.OnEvent("Close", (*) => dlg.Destroy())
        dlg.OnEvent("Escape", (*) => dlg.Destroy())
        dlg.Add("Text", "x20 y20 w80 h20", "源工作台:")

        src_wbs := []
        for k, v in AppSettings.commands_obj {
            if (k != "_comment" && k != target_wb) {
                src_wbs.Push(k)
            }
        }
        if (src_wbs.Length == 0) {
            MsgBox("没有其他工作台可供选择！", "提示", "Iconi")
            dlg.Destroy()
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
                this.model.flush_commands_json(AppSettings.commands_obj)
                this.model.init()
                this.load_command_tree(this.view.edit_search.Value)

                msg := "成功添加 " added_count " 个命令到 [" target_wb "]"
                if (skipped_count > 0)
                    msg .= "`n已自动忽略 " skipped_count " 个重复命令"
                MsgBox(msg, "成功", "Iconi T2")
                dlg.Destroy()
            } else {
                MsgBox("未添加任何命令（所选命令在目标工作台均已存在）。", "提示", "Iconi")
            }
        }

        dlg_btn_add.OnEvent("Click", do_add)
        dlg_btn_cancel.OnEvent("Click", (*) => dlg.Destroy())
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
            if !selected_keys.Has(item.title "_" item.local_id "_" item.imported_id)
                continue
            a := item.action
            if (a == "+") {
                c_new++
                strNew .= "- " item.title " (" item.imported_id ")`r`n"
            } else if (a == "T") {
                c_upd++
                strUpd .= "- " item.title " (" item.imported_id ")`r`n"
            } else if (a == "C") {
                c_ovr++
                strOvr .= "- " item.title " (" item.imported_id ")`r`n"
            } else if (a == "D") {
                c_del++
                strDel .= "- " item.title " (" item.local_id ")`r`n"
            }
        }

        if (c_new == 0 && c_upd == 0 && c_ovr == 0 && c_del == 0) {
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
            full_msg .= "【待删除】(数量: " c_del ")`r`n" strDel "`r`n"

        confirm_gui := Gui("+Owner" this.view.hwnd " +ToolWindow -MinimizeBox -MaximizeBox", "确认执行以下操作")
        confirm_gui.Add("Text", "x15 y15 w450 h20", "应用到 [" AppSettings.GetWbName(target_wb) "] 工作台:")
        confirm_gui.Add("Edit", "x15 y40 w450 h300 ReadOnly Multi VScroll", full_msg)

        user_confirmed := false
        close_dialog := (confirmed, *) => (
            user_confirmed := confirmed,
            this.view.Opt("-Disabled"),
            confirm_gui.Destroy()
        )

        btn_ok := confirm_gui.Add("Button", "x250 y350 w100 h30 Default", "确认")
        btn_ok.OnEvent("Click", close_dialog.Bind(true))
        btn_cancel := confirm_gui.Add("Button", "x365 y350 w100 h30", "取消")
        btn_cancel.OnEvent("Click", close_dialog.Bind(false))
        confirm_gui.OnEvent("Close", close_dialog.Bind(false))
        confirm_gui.OnEvent("Escape", close_dialog.Bind(false))

        this.view.Opt("+Disabled")
        confirm_gui.Show("AutoSize Center")
        btn_cancel.Focus()
        WinWaitClose(confirm_gui.hwnd)

        if (!user_confirmed) {
            return
        }

        new_array := []
        for item in this.model.import_items {
            title := item.title
            old_id := item.local_id
            action := item.action
            new_id := item.imported_id

            if !selected_keys.Has(title "_" old_id "_" new_id)
                action := "i"

            if (action == "i" || action == "=") {
                if (old_id != "" && local_by_id.Has(old_id))
                    new_array.Push(local_by_id[old_id])
            } else if (action == "+") {
                new_array.Push(Map("desc", title, "command", new_id, "aliases", [], "hotkeys", []))
            } else if (action == "T") {
                if local_by_id.Has(old_id) {
                    cmd := local_by_id[old_id].Clone()
                    cmd["desc"] := title
                    new_array.Push(cmd)
                }
            } else if (action == "C") {
                if local_by_id.Has(old_id) {
                    cmd := local_by_id[old_id].Clone()
                    cmd["command"] := new_id
                    new_array.Push(cmd)
                }
            } else if (action == "D") {
                ; drop
            }
        }

        AppSettings.commands_obj[target_wb] := new_array
        this.model.flush_commands_json(AppSettings.commands_obj)
        MsgBox("成功！请重新载入UCLC使修改生效。", "成功", "Iconi")
        this.on_reset_import_view()
    }
}