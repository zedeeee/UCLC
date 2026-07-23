#Requires AutoHotkey v2.0
#Include AppSettings.ahk

show_settings_gui(*) {
    static controller := ""
    if (!controller) {
        model := SettingsModel()
        view := SettingsView()
        controller := SettingsController(model, view)
    }
    controller.show()
}

ShowSettingsGUI(*) => show_settings_gui()

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
            FileDelete(AppSettings.commands_json_path)
            FileAppend(JSON.stringify(AppSettings.commands_obj), AppSettings.commands_json_path, "UTF-8")
        } catch as e {
            MsgBox("写入 JSON 文件失败: " e.Message, "错误", 16)
        }
    }

    save_general_settings(everythingEnabled, everythingPath) {
        try {
            if !AppSettings.config_obj.Has("Everything") {
                AppSettings.config_obj["Everything"] := Map("Enabled", "0", "Path", "")
            }
            AppSettings.config_obj["Everything"]["Enabled"] := String(everythingEnabled)
            AppSettings.config_obj["Everything"]["Path"] := everythingPath

            AppSettings.Everything_Enabled := everythingEnabled
            AppSettings.Everything_Path := everythingPath

            FileDelete(AppSettings.config_json_path)
            FileAppend(JSON.stringify(AppSettings.config_obj), AppSettings.config_json_path, "UTF-8")
            return true
        } catch as e {
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
                if local_by_id[id]["desc"] == title {
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
        super.__New("-Resize -MaximizeBox", "UCLC 配置管理控制台 (CUI)")
        
        this.tabs := this.Add("Tab3", "x10 y10 w780 h580", ["命令映射", "通用设置", "工作台命令库"])

        ; =============== 第一页: 命令映射 ===============
        this.tabs.UseTab(1)
        this.Add("Text", "x30 y40 w200", "命令列表树 (工作台 -> 功能):")
        this.Add("Text", "x30 y65 w45", "工作台:")

        this.ddl_workbench := this.Add("DropDownList", "x75 y61 w205 Choose1", ["全部工作台"])
        
        this.Add("Text", "x30 y90 w40", "搜索:")
        this.edit_search := this.Add("Edit", "x70 y86 w210")
        
        this.tv_alias := this.Add("TreeView", "x30 y115 w250 h430")
        
        this.Btn_AddCmdFromOther := this.Add("Button", "x30 y550 w250 h24 Disabled", "从指定工作台添加命令")

        this.Add("GroupBox", "x300 y60 w460 h490", "详细属性与动态编辑")

        this.tabs.UseTab(1)
        this.Txt_Cat := this.Add("Text", "x320 y80 w80 Hidden", "所属工作台:")
        this.Txt_CatVal := this.Add("Text", "x400 y80 w340 cBlue Hidden", "")
        this.Txt_Desc := this.Add("Text", "x320 y110 w80 Hidden", "功能描述:")
        this.edit_desc := this.Add("Edit", "x400 y106 w340 Hidden ReadOnly", "")
        this.Txt_Cmd := this.Add("Text", "x320 y140 w80 Hidden", "执行命令:")
        this.Edit_Cmd := this.Add("Edit", "x400 y136 w340 Hidden ReadOnly", "")
        this.Txt_Alias := this.Add("Text", "x320 y180 w80 Hidden", "用户别名:")

        this.alias_pool := []
        loop 10 {
            e := this.Add("Edit", "x400 y0 w280 Hidden Uppercase", "")
            btn_add := this.Add("Button", "x685 y0 w25 h24 Hidden", "➕")
            btn_del := this.Add("Button", "x715 y0 w25 h24 Hidden", "➖")
            this.alias_pool.Push({ e: e, add: btn_add, del: btn_del })
        }

        this.Txt_Hotkey := this.Add("Text", "x320 y0 w80 Hidden", "快捷键:")
        this.hotkey_pool := []
        loop 10 {
            e := this.Add("Edit", "x400 y0 w280 Hidden", "")
            SendMessage(0x1501, 1, StrPtr("直接按键录入"), e.Hwnd)
            btn_add := this.Add("Button", "x685 y0 w25 h24 Hidden", "➕")
            btn_del := this.Add("Button", "x715 y0 w25 h24 Hidden", "➖")
            this.hotkey_pool.Push({ e: e, add: btn_add, del: btn_del })
        }

        this.Btn_Revert := this.Add("Button", "x400 y0 w120 h35 Hidden Disabled", "撤销当前修改")
        this.btn_save := this.Add("Button", "x620 y550 w140 h26 Disabled", "应用修改")
        this.SB := this.Add("StatusBar")

        ; =============== 第二页: 通用设置 ===============
        this.tabs.UseTab(2)
        this.Add("GroupBox", "x30 y50 w740 h150", "Everything 快速启动集成")
        this.Chk_Everything := this.Add("Checkbox", "x50 y80", "启用“双击右Ctrl”呼出 Everything")
        this.Add("Text", "x50 y120 w80", "主程序路径:")
        this.Edit_EverythingPath := this.Add("Edit", "x130 y116 w450", "")
        this.Btn_BrowseEverything := this.Add("Button", "x600 y115 w80", "浏览...")
        this.btn_saveGen := this.Add("Button", "x600 y160 w150 Default", "保存通用设置")

        ; =============== 第三页: 工作台命令库 ===============
        this.tabs.UseTab(3)
        this.Add("GroupBox", "x20 y40 w740 h65", "数据源获取")
        this.Add("Text", "x30 y68 w70", "目标工作台:")
        this.ddl_import_wb := this.Add("DropDownList", "x100 y64 w250 Choose1", ["通过导入文件确定"])
        this.Btn_AddWb := this.Add("Button", "x355 y64 w24 h22", "+")
        this.Btn_ImportCommands := this.Add("Button", "x500 y64 w120 h22", "导入命令")
        this.Btn_ReadTxt := this.Add("Button", "x630 y64 w120 h22", "从 TXT 导入")

        this.Add("GroupBox", "x20 y115 w740 h410", "同步状态视图")
        this.Add("Text", "x25 y130 w60 h32 +0x200", "视图筛选:")
        
        this.chk_filter_all := this.Add("CheckBox", "x85 y130 w60 h32 Checked", "全部`n(0)")
        this.SetFont("s9 bold c107C10")
        this.Add("Text", "x155 y130 w14 h32 +0x200", "+")
        this.SetFont("s9 norm cDefault")
        this.chk_filter_new := this.Add("CheckBox", "x169 y130 w60 h32 Checked", "新增`n(0)")
        
        this.SetFont("s9 bold c0078D7")
        this.Add("Text", "x239 y130 w14 h32 +0x200", "T")
        this.SetFont("s9 norm cDefault")
        this.chk_filter_update := this.Add("CheckBox", "x253 y130 w85 h32 Checked", "更新标题`n(0)")
        
        this.SetFont("s9 bold c0078D7")
        this.Add("Text", "x348 y130 w14 h32 +0x200", "C")
        this.SetFont("s9 norm cDefault")
        this.chk_filter_overwrite := this.Add("CheckBox", "x362 y130 w85 h32 Checked", "更新命令`n(0)")
        
        this.SetFont("s9 bold c107C10")
        this.Add("Text", "x457 y130 w14 h32 +0x200", "=")
        this.SetFont("s9 norm cDefault")
        this.chk_filter_same := this.Add("CheckBox", "x471 y130 w60 h32 Checked", "一致`n(0)")
        
        this.SetFont("s9 bold cE81123")
        this.Add("Text", "x541 y130 w14 h32 +0x200", "D")
        this.SetFont("s9 norm cDefault")
        this.chk_filter_delete := this.Add("CheckBox", "x555 y130 w75 h32 Checked", "待删除`n(0)")
        
        this.SetFont("s9 bold cE81123")
        this.Add("Text", "x640 y130 w14 h32 +0x200", "i")
        this.SetFont("s9 norm cDefault")
        this.chk_filter_ignore := this.Add("CheckBox", "x654 y130 w60 h32 Checked", "忽略`n(0)")

        this.lv_import := this.Add("ListView", "x30 y165 w720 h310 Grid", ["标题", "命令 ID", "导入的命令 ID", "操作"])
        this.lv_import.ModifyCol(1, 160)
        this.lv_import.ModifyCol(2, 240)
        this.lv_import.ModifyCol(3, 253)
        this.lv_import.ModifyCol(4, 50)
        this.lv_import.ModifyCol(4, "Center")

        this.txt_empty_lv := this.Add("Text", "x250 y305 w280 h30 Center c808080 BackgroundTrans", "请点击上方按钮获取数据")

        this.btn_mark_delete := this.Add("Button", "x30 y485 w80 h24 Disabled", "删除选中")
        this.btn_mark_ignore := this.Add("Button", "x120 y485 w80 h24 Disabled", "忽略选中")
        this.txt_sel_count := this.Add("Text", "x220 y489 w150 h20", "已选中: 0 项")

        this.btn_resetView := this.Add("Button", "x30 y550 w150", "重置视图")
        this.Btn_ApplyAll := this.Add("Button", "x600 y550 w150", "应用修改")
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

    show() {
        this.model.init()
        this.LoadGeneralSettings()
        this.load_command_tree()
        this.OnLButtonDownBound := ObjBindMethod(this, "on_lbutton_down")
        OnMessage(0x0201, this.OnLButtonDownBound)
        this.view.Show("w800 h600")
    }

    BindEvents() {
        this.view.OnEvent("Close", ObjBindMethod(this, "OnClose"))
        this.view.OnEvent("Escape", ObjBindMethod(this, "OnClose"))
        OnMessage(0x0200, ObjBindMethod(this, "on_mouse_move"))

        this.view.ddl_workbench.OnEvent("Change", ObjBindMethod(this, "OnWorkbenchFilter"))
        this.view.edit_search.OnEvent("Change", ObjBindMethod(this, "OnSearchFilter"))
        this.view.tv_alias.OnEvent("ItemSelect", ObjBindMethod(this, "on_command_tree_select"))
        this.view.Btn_AddCmdFromOther.OnEvent("Click", ObjBindMethod(this, "on_add_cmd_from_other"))

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
    }

    LoadGeneralSettings() {
        this.view.Chk_Everything.Value := AppSettings.Everything_Enabled
        this.view.Edit_EverythingPath.Value := AppSettings.Everything_Path
        
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
        
        this.view.ddl_import_wb.Delete()
        this.view.ddl_import_wb.Add(wb_list3)
        this.view.ddl_import_wb.Choose(1)
    }

    OnClose(*) {
        if (this.model.original_json_str != "") {
            this.save_inputs_to_current_cmd()
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
        if this.HasProp("OnLButtonDownBound") {
            OnMessage(0x0201, this.OnLButtonDownBound, 0)
        }
        this.view.Destroy()
    }

    ClearRightPane() {
        this.view.Txt_Cat.Opt("Hidden")
        this.view.Txt_CatVal.Opt("Hidden")
        this.view.Txt_Desc.Opt("Hidden")
        this.view.edit_desc.Opt("Hidden")
        this.view.Txt_Cmd.Opt("Hidden")
        this.view.Edit_Cmd.Opt("Hidden")
        this.view.Txt_Alias.Opt("Hidden")

        for p in this.view.alias_pool {
            p.e.Opt("Hidden")
            p.add.Opt("Hidden")
            p.del.Opt("Hidden")
        }

        this.view.Txt_Hotkey.Opt("Hidden")
        for p in this.view.hotkey_pool {
            p.e.Opt("Hidden")
            p.add.Opt("Hidden")
            p.del.Opt("Hidden")
        }

        this.view.Btn_Revert.Opt("Hidden")
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
        if (this.view.ddl_workbench.Text != "全部工作台") {
            this.view.Btn_AddCmdFromOther.Opt("-Disabled")
        } else {
            this.view.Btn_AddCmdFromOther.Opt("+Disabled")
        }
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

        cmd := info.cmd
        this.view.Txt_CatVal.Value := AppSettings.GetWbName(info.category)
        this.view.edit_desc.Value := cmd.Has("desc") ? cmd["desc"] : ""
        this.view.Edit_Cmd.Value := cmd.Has("command") ? cmd["command"] : ""

        this.view.Txt_Cat.Opt("-Hidden")
        this.view.Txt_CatVal.Opt("-Hidden")
        this.view.Txt_Desc.Opt("-Hidden")
        this.view.edit_desc.Opt("-Hidden")
        this.view.Txt_Cmd.Opt("-Hidden")
        this.view.Edit_Cmd.Opt("-Hidden")
        this.view.Txt_Alias.Opt("-Hidden")

        cur_y := 180
        aliases := cmd.Has("aliases") ? cmd["aliases"] : []
        if (aliases.Length == 0)
            aliases := [""]

        for idx, al in aliases {
            if (idx > 10) {
                break
            }
            p := this.view.alias_pool[idx]
            p.e.Value := al
            p.e.Move(, cur_y - 4)
            p.add.Move(, cur_y - 5)
            p.del.Move(, cur_y - 5)

            p.e.Opt("-Hidden")
            p.add.Opt("-Hidden")
            p.del.Opt("-Hidden")

            p.add.Opt((Trim(al) != "") ? "-Disabled" : "+Disabled")
            p.del.Opt((aliases.Length > 1) ? "-Disabled" : "+Disabled")
            this.alias_edits.Push(p.e)
            cur_y += 30
        }

        cur_y += 10
        this.view.Txt_Hotkey.Move(, cur_y)
        this.view.Txt_Hotkey.Opt("-Hidden")

        hotkeys := cmd.Has("hotkeys") ? cmd["hotkeys"] : []
        if (hotkeys.Length == 0)
            hotkeys := [""]

        for idx, hk in hotkeys {
            if (idx > 10) {
                break
            }
            p := this.view.hotkey_pool[idx]
            try p.e.Value := this.FormatHotkeyForDisplay(hk)
            catch
                p.e.Value := ""
            p.e.Move(, cur_y - 4)
            p.add.Move(, cur_y - 5)
            p.del.Move(, cur_y - 5)

            p.e.Opt("-Hidden")
            p.add.Opt("-Hidden")
            p.del.Opt("-Hidden")

            p.add.Opt((Trim(hk) != "") ? "-Disabled" : "+Disabled")
            p.del.Opt((hotkeys.Length > 1) ? "-Disabled" : "+Disabled")
            this.hotkey_edits.Push(p.e)
            cur_y += 30
        }

        cur_y += 30
        this.view.Btn_Revert.Move(, cur_y)
        this.view.Btn_Revert.Opt("-Hidden")

        this.CheckGlobalDirty()
        this.view.SB.SetText("")
    }

    save_inputs_to_current_cmd() {
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
                cmd["hotkeys"].Push(this.ParseHotkeyFromDisplay(v))
        }
    }

    on_add_alias(idx, *) {
        this.save_inputs_to_current_cmd()
        itemId := this.view.tv_alias.GetSelection()
        cmd := this.tv_map[itemId].cmd
        if (!cmd.Has("aliases")) {
            cmd["aliases"] := []
        }
        cmd["aliases"].InsertAt(idx + 1, "")
        this.on_command_tree_select(this.view.tv_alias, itemId)
    }

    on_del_alias(idx, *) {
        this.save_inputs_to_current_cmd()
        itemId := this.view.tv_alias.GetSelection()
        cmd := this.tv_map[itemId].cmd
        if (cmd.Has("aliases") && cmd["aliases"].Length >= idx)
            cmd["aliases"].RemoveAt(idx)
        this.on_command_tree_select(this.view.tv_alias, itemId)
    }

    on_add_hotkey(idx, *) {
        this.save_inputs_to_current_cmd()
        itemId := this.view.tv_alias.GetSelection()
        cmd := this.tv_map[itemId].cmd
        if (!cmd.Has("hotkeys")) {
            cmd["hotkeys"] := []
        }
        cmd["hotkeys"].InsertAt(idx + 1, "")
        this.on_command_tree_select(this.view.tv_alias, itemId)
    }

    on_del_hotkey(idx, *) {
        this.save_inputs_to_current_cmd()
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
            alias_bold := (JSON.stringify(info.cmd.Has("aliases") ? info.cmd["aliases"] : []) != JSON.stringify(orig_cmd.Has("aliases") ? orig_cmd["aliases"] : [])) ? "bold" : "norm"
            hk_bold := (JSON.stringify(info.cmd.Has("hotkeys") ? info.cmd["hotkeys"] : []) != JSON.stringify(orig_cmd.Has("hotkeys") ? orig_cmd["hotkeys"] : [])) ? "bold" : "norm"
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
                        || JSON.stringify(info.cmd.Has("aliases") ? info.cmd["aliases"] : []) != JSON.stringify(orig_cmd.Has("aliases") ? orig_cmd["aliases"] : [])
                        || JSON.stringify(info.cmd.Has("hotkeys") ? info.cmd["hotkeys"] : []) != JSON.stringify(orig_cmd.Has("hotkeys") ? orig_cmd["hotkeys"] : [])
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
        this.save_inputs_to_current_cmd()
        this.CheckGlobalDirty()
    }

    OnAliasChange(idx, GuiCtrlObj, *) {
        p := this.view.alias_pool[idx]
        p.add.Opt((Trim(GuiCtrlObj.Value) != "") ? "-Disabled" : "+Disabled")
        this.save_inputs_to_current_cmd()
        this.CheckGlobalDirty()
    }

    OnHotkeyChange(idx, GuiCtrlObj, *) {
        p := this.view.hotkey_pool[idx]
        p.add.Opt((Trim(GuiCtrlObj.Value) != "") ? "-Disabled" : "+Disabled")
        this.save_inputs_to_current_cmd()
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

    FormatHotkeyForDisplay(hk) {
        if (hk == "") {
                return ""
            }
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

    ParseHotkeyFromDisplay(display) {
        if (display == "") {
            return ""
        }
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
        this.save_inputs_to_current_cmd()
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
        this.view.Opt("+Disabled")
        path := FileSelect(, , "请选择 Everything.exe", "程序 (*.exe)")
        this.view.Opt("-Disabled")
        if path
            this.view.Edit_EverythingPath.Value := path
    }

    SaveGeneralSettings(*) {
        success := this.model.save_general_settings(this.view.Chk_Everything.Value, this.view.Edit_EverythingPath.Value)
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
        } catch as e {
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
                this.dlg_ddl_src.Move(, , Width - 120)
                this.dlg_edit_filter.Move(, , Width - 120)
                this.dlg_lv.Move(, , Width - 40, Height - 140)
                btn_w := (Width - 60) // 2
                this.dlg_btn_add.Move(20, Height - 45, btn_w)
                this.dlg_btn_cancel.Move(20 + btn_w + 20, Height - 45, btn_w)
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

        this.dlg_ddl_src := dlg.Add("DropDownList", "x100 y16 w330 Choose1", src_wbs)
        dlg.Add("Text", "x20 y52 w80 h20", "快速过滤:")
        this.dlg_edit_filter := dlg.Add("Edit", "x100 y48 w330 h22")
        this.dlg_lv := dlg.Add("ListView", "x20 y85 w410 h360", ["功能描述", "命令 ID"])
        this.dlg_lv.ModifyCol(1, 140)
        this.dlg_lv.ModifyCol(2, 200)
        this.dlg_btn_add := dlg.Add("Button", "x20 y455 w195 h30 Default", "添加")
        this.dlg_btn_cancel := dlg.Add("Button", "x235 y455 w195 h30", "取消")

        load_dlg_cmds(*) {
            this.dlg_lv.Delete()
            src_wb := this.dlg_ddl_src.Text
            if (src_wb == "")
                return

            filter := Trim(this.dlg_edit_filter.Value)
            target_cmds := Map()
            if AppSettings.commands_obj.Has(target_wb) {
                for cmd in AppSettings.commands_obj[target_wb] {
                    if cmd.Has("command")
                        target_cmds[cmd["command"]] := 1
                }
            }

            if AppSettings.commands_obj.Has(src_wb) {
                this.dlg_lv.Opt("-Redraw")
                for cmd in AppSettings.commands_obj[src_wb] {
                    desc := cmd.Has("desc") ? cmd["desc"] : ""
                    command := cmd.Has("command") ? cmd["command"] : ""
                    if (filter != "" && !InStr(desc, filter) && !InStr(command, filter)) {
                        continue
                    }
                    is_dup := target_cmds.Has(command)
                    this.dlg_lv.Add("", is_dup ? desc " (已存在)" : desc, command)
                }
                this.dlg_lv.Opt("+Redraw")
            }
        }

        this.dlg_ddl_src.OnEvent("Change", load_dlg_cmds)
        this.dlg_edit_filter.OnEvent("Change", load_dlg_cmds)

        do_add(*) {
            selected_indices := []
            row := 0
            while (row := this.dlg_lv.GetNext(row)) {
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

            src_wb := this.dlg_ddl_src.Text
            src_cmd_list := AppSettings.commands_obj[src_wb]
            added_count := 0
            skipped_count := 0

            for idx in selected_indices {
                cmd_id := this.dlg_lv.GetText(idx, 2)
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

        this.dlg_btn_add.OnEvent("Click", do_add)
        this.dlg_btn_cancel.OnEvent("Click", (*) => dlg.Destroy())
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

