#Requires AutoHotkey v2.0
#Include AppSettings.ahk

ShowSettingsGUI(*) {
    UCLC_CUI.Show()
}

class UCLC_CUI {
    static GuiObj := ""
    static Tabs := ""
    static TV_Alias := ""
    static TV_Map := Map()

    static alias_pool := []
    static hotkey_pool := []

    static Txt_Cat := ""
    static Txt_CatVal := ""
    static Txt_Desc := ""
    static Txt_Cmd := ""
    static Txt_Alias := ""
    static Txt_Hotkey := ""
    static Btn_Revert := ""
    static Btn_Save := ""
    static Btn_DelItem := ""
    static Btn_AddCmdFromOther := ""
    static dlg_ddl_src := ""
    static dlg_edit_filter := ""
    static dlg_lv := ""
    static dlg_btn_add := ""
    static dlg_btn_cancel := ""
    static dlg_target_wb := ""
    static btn_markDelete := ""
    static btn_markIgnore := ""
    static Txt_SelCount := ""

    static alias_edits := []
    static hotkey_edits := []

    static Edit_Cmd := ""
    static Edit_Desc := ""
    static Edit_Search := ""

    static Chk_Everything := ""
    static Edit_EverythingPath := ""
    static Txt_EmptyLV := ""
    static DDL_ImportWb := ""
    static original_json_str := ""

    static Show() {
        if (this.GuiObj) {
            WinActivate(this.GuiObj.Hwnd)
            return
        }

        ; 每次打开设置面板前强制从硬盘重载，丢弃一切未保存的内存脏数据
        AppSettings.Init()
        this.original_json_str := JSON.stringify(AppSettings.commands_obj)

        this.GuiObj := Gui("-Resize -MaximizeBox", "UCLC 配置管理控制台 (CUI)")
        this.GuiObj.OnEvent("Close", ObjBindMethod(this, "OnClose"))
        this.GuiObj.OnEvent("Escape", ObjBindMethod(this, "OnClose"))
        OnMessage(0x0200, ObjBindMethod(this, "OnMouseMove"))
        this.Tabs := this.GuiObj.Add("Tab3", "x10 y10 w780 h580", ["命令映射", "通用设置", "工作台命令库"])

        ; =============== 第一页: 命令映射 ===============
        this.Tabs.UseTab(1)
        this.GuiObj.Add("Text", "x30 y40 w200", "命令列表树 (工作台 -> 功能):")

        this.GuiObj.Add("Text", "x30 y65 w45", "工作台:")

        sort_str := ""
        for k, v in AppSettings.commands_obj {
            if (k != "_comment") {
                sort_str .= AppSettings.GetWbName(k) "|||" k "`n"
            }
        }
        sort_str := Sort(Trim(sort_str, "`n"))

        wb_list := ["全部工作台"]
        this.workbench_ids := [""] ; 第一个为空，代表全选
        loop parse sort_str, "`n", "`r" {
            if (A_LoopField == "")
                continue
            parts := StrSplit(A_LoopField, "|||")
            wb_list.Push(parts[1])
            this.workbench_ids.Push(parts[2])
        }
        this.DDL_Workbench := this.GuiObj.Add("DropDownList", "x75 y61 w205 Choose1", wb_list)
        this.DDL_Workbench.OnEvent("Change", ObjBindMethod(this, "OnWorkbenchFilter"))

        ; 增加一个搜索框
        this.GuiObj.Add("Text", "x30 y90 w40", "搜索:")
        search_edit := this.GuiObj.Add("Edit", "x70 y86 w210")
        search_edit.OnEvent("Change", ObjBindMethod(this, "OnSearchFilter"))
        this.Edit_Search := search_edit

        this.TV_Alias := this.GuiObj.Add("TreeView", "x30 y115 w250 h430")
        this.TV_Alias.OnEvent("ItemSelect", ObjBindMethod(this, "OnCommandTreeSelect"))

        this.Btn_AddCmdFromOther := this.GuiObj.Add("Button", "x30 y550 w250 h24 Disabled", "从指定工作台添加命令")
        this.Btn_AddCmdFromOther.OnEvent("Click", ObjBindMethod(this, "OnAddCmdFromOther"))

        ; 右侧详情编辑区框
        this.GuiObj.Add("GroupBox", "x300 y60 w460 h490", "详细属性与动态编辑")

        ; 预分配右侧控件（池化技术防泄露，解决 Tab3 渲染覆盖问题）
        this.Tabs.UseTab(1)
        this.Txt_Cat := this.GuiObj.Add("Text", "x320 y80 w80 Hidden", "所属工作台:")
        this.Txt_CatVal := this.GuiObj.Add("Text", "x400 y80 w340 cBlue Hidden", "")

        this.Txt_Desc := this.GuiObj.Add("Text", "x320 y110 w80 Hidden", "功能描述:")
        this.Edit_Desc := this.GuiObj.Add("Edit", "x400 y106 w340 Hidden ReadOnly", "")

        this.Txt_Cmd := this.GuiObj.Add("Text", "x320 y140 w80 Hidden", "执行命令:")
        this.Edit_Cmd := this.GuiObj.Add("Edit", "x400 y136 w340 Hidden ReadOnly", "")

        this.Txt_Alias := this.GuiObj.Add("Text", "x320 y180 w80 Hidden", "用户别名:")

        this.alias_pool := []
        loop 10 {
            e := this.GuiObj.Add("Edit", "x400 y0 w280 Hidden Uppercase", "")
            btn_add := this.GuiObj.Add("Button", "x685 y0 w25 h24 Hidden", "➕")
            btn_del := this.GuiObj.Add("Button", "x715 y0 w25 h24 Hidden", "➖")

            btn_add.OnEvent("Click", ObjBindMethod(this, "OnAddAlias", A_Index))
            btn_del.OnEvent("Click", ObjBindMethod(this, "OnDelAlias", A_Index))
            e.OnEvent("Change", ObjBindMethod(this, "OnAliasChange", A_Index))

            this.alias_pool.Push({ e: e, add: btn_add, del: btn_del })
        }

        this.Txt_Hotkey := this.GuiObj.Add("Text", "x320 y0 w80 Hidden", "快捷键:")

        this.hotkey_pool := []
        loop 10 {
            e := this.GuiObj.Add("Edit", "x400 y0 w280 Hidden", "")
            SendMessage(0x1501, 1, StrPtr("直接按键录入"), e)
            btn_add := this.GuiObj.Add("Button", "x685 y0 w25 h24 Hidden", "➕")
            btn_del := this.GuiObj.Add("Button", "x715 y0 w25 h24 Hidden", "➖")

            btn_add.OnEvent("Click", ObjBindMethod(this, "OnAddHotkey", A_Index))
            btn_del.OnEvent("Click", ObjBindMethod(this, "OnDelHotkey", A_Index))
            e.OnEvent("Change", ObjBindMethod(this, "OnHotkeyChange", A_Index))
            e.OnEvent("Focus", ObjBindMethod(this, "OnHotkeyFocus", A_Index))
            e.OnEvent("LoseFocus", ObjBindMethod(this, "OnHotkeyLoseFocus", A_Index))

            this.hotkey_pool.Push({ e: e, add: btn_add, del: btn_del })
        }

        this.Btn_Revert := this.GuiObj.Add("Button", "x400 y0 w120 h35 Hidden Disabled", "撤销当前修改")
        this.Btn_Revert.OnEvent("Click", ObjBindMethod(this, "OnRevertChanges"))

        this.Btn_Save := this.GuiObj.Add("Button", "x620 y550 w140 h26 Disabled", "应用修改")
        this.Btn_Save.OnEvent("Click", ObjBindMethod(this, "SaveCurrentItem"))

        this.SB := this.GuiObj.Add("StatusBar")

        ; 新增与删除功能移至第三页工作台命令库管理，此处仅保留右侧详情面板
        ; =============== 第二页: 通用设置 ===============
        this.Tabs.UseTab(2)
        this.GuiObj.Add("GroupBox", "x30 y50 w740 h150", "Everything 快速启动集成")

        this.Chk_Everything := this.GuiObj.Add("Checkbox", "x50 y80", "启用“双击右Ctrl”呼出 Everything")
        this.Chk_Everything.Value := AppSettings.Everything_Enabled

        this.GuiObj.Add("Text", "x50 y120 w80", "主程序路径:")
        this.Edit_EverythingPath := this.GuiObj.Add("Edit", "x130 y116 w450", AppSettings.Everything_Path)

        btn_browse := this.GuiObj.Add("Button", "x600 y115 w80", "浏览...")
        btn_browse.OnEvent("Click", ObjBindMethod(this, "BrowseEverything"))

        btn_saveGen := this.GuiObj.Add("Button", "x600 y160 w150 Default", "保存通用设置")
        btn_saveGen.OnEvent("Click", ObjBindMethod(this, "SaveGeneralSettings"))

        ; =============== 第三页: 工作台命令库 ===============
        this.Tabs.UseTab(3)

        ; --- 顶部区块：数据源与获取 ---
        this.GuiObj.Add("GroupBox", "x20 y40 w740 h65", "数据源获取")

        this.GuiObj.Add("Text", "x30 y68 w70", "目标工作台:")
        wb_list3 := ["通过导入文件确定"]
        this.import_wb_ids := [""]
        loop parse sort_str, "`n", "`r" {
            if (A_LoopField == "")
                continue
            parts := StrSplit(A_LoopField, "|||")
            wb_list3.Push(parts[1])
            this.import_wb_ids.Push(parts[2])
        }
        this.DDL_ImportWb := this.GuiObj.Add("DropDownList", "x100 y64 w250 Choose1", wb_list3)
        this.DDL_ImportWb.ToolTip := "选择要将命令导入到的目标工作台"
        this.DDL_ImportWb.OnEvent("Change", ObjBindMethod(this, "OnTargetWorkbenchChanged"))

        btn_addWb := this.GuiObj.Add("Button", "x355 y64 w24 h22", "+")
        btn_addWb.ToolTip := "新增自定义目标工作台名称"
        btn_addWb.OnEvent("Click", ObjBindMethod(this, "OnAddTargetWorkbench"))

        btn_getCatia := this.GuiObj.Add("Button", "x500 y64 w120 h22", "导入命令")
        btn_getCatia.ToolTip := "从已导出的工作台命令库中选择并导入"
        btn_getCatia.OnEvent("Click", ObjBindMethod(this, "OnImportCommands"))

        btn_readTxt := this.GuiObj.Add("Button", "x630 y64 w120 h22", "从 TXT 导入")
        btn_readTxt.ToolTip := "从本地读取导出的 TXT 命令文件"
        btn_readTxt.OnEvent("Click", ObjBindMethod(this, "OnReadExportedTxt"))

        ; --- 中部区块：同步状态视图 ---
        this.GuiObj.Add("GroupBox", "x20 y115 w740 h410", "同步状态视图")

        this.GuiObj.Add("Text", "x25 y130 w60 h32 +0x200", "视图筛选:")

        ; 全部 (无符号)
        this.chk_filterAll := this.GuiObj.Add("CheckBox", "x85 y130 w60 h32 Checked", "全部`n(0)")
        this.chk_filterAll.ToolTip := "显示/隐藏全部数据"

        ; 新增
        this.GuiObj.SetFont("s9 bold c107C10")
        this.GuiObj.Add("Text", "x155 y130 w14 h32 +0x200", "+")
        this.GuiObj.SetFont("s9 norm cDefault")
        this.chk_filterNew := this.GuiObj.Add("CheckBox", "x169 y130 w60 h32 Checked", "新增`n(0)")
        this.chk_filterNew.ToolTip := "导入文件中包含，但本地配置中缺失的命令"

        ; 更新标题
        this.GuiObj.SetFont("s9 bold c0078D7")
        this.GuiObj.Add("Text", "x239 y130 w14 h32 +0x200", "T")
        this.GuiObj.SetFont("s9 norm cDefault")
        this.chk_filterUpdate := this.GuiObj.Add("CheckBox", "x253 y130 w85 h32 Checked", "更新标题`n(0)")
        this.chk_filterUpdate.ToolTip := "命令 ID 相同，但导入文件中的标题与本地不一致"

        ; 更新命令 (覆盖)
        this.GuiObj.SetFont("s9 bold c0078D7")
        this.GuiObj.Add("Text", "x348 y130 w14 h32 +0x200", "C")
        this.GuiObj.SetFont("s9 norm cDefault")
        this.chk_filterOverwrite := this.GuiObj.Add("CheckBox", "x362 y130 w85 h32 Checked", "更新命令`n(0)")
        this.chk_filterOverwrite.ToolTip := "标题相同，但导入文件中的命令 ID 与本地不一致"

        ; 一致
        this.GuiObj.SetFont("s9 bold c107C10")
        this.GuiObj.Add("Text", "x457 y130 w14 h32 +0x200", "=")
        this.GuiObj.SetFont("s9 norm cDefault")
        this.chk_filterSame := this.GuiObj.Add("CheckBox", "x471 y130 w60 h32 Checked", "一致`n(0)")
        this.chk_filterSame.ToolTip := "导入文件与本地配置完全相同的命令"

        ; 待删除
        this.GuiObj.SetFont("s9 bold cE81123")
        this.GuiObj.Add("Text", "x541 y130 w14 h32 +0x200", "D")
        this.GuiObj.SetFont("s9 norm cDefault")
        this.chk_filterDelete := this.GuiObj.Add("CheckBox", "x555 y130 w75 h32 Checked", "待删除`n(0)")
        this.chk_filterDelete.ToolTip := "仅存在于本地配置，准备删除的命令"

        ; 忽略
        this.GuiObj.SetFont("s9 bold cE81123")
        this.GuiObj.Add("Text", "x640 y130 w14 h32 +0x200", "i")
        this.GuiObj.SetFont("s9 norm cDefault")
        this.chk_filterIgnore := this.GuiObj.Add("CheckBox", "x654 y130 w60 h32 Checked", "忽略`n(0)")
        this.chk_filterIgnore.ToolTip := "用户标记为忽略的更改"

        this.chk_filterAll.OnEvent("Click", ObjBindMethod(this, "OnFilterAll"))
        this.chk_filterNew.OnEvent("Click", ObjBindMethod(this, "OnFilterNew"))
        this.chk_filterUpdate.OnEvent("Click", ObjBindMethod(this, "OnFilterUpdate"))
        this.chk_filterOverwrite.OnEvent("Click", ObjBindMethod(this, "OnFilterOverwrite"))
        this.chk_filterSame.OnEvent("Click", ObjBindMethod(this, "OnFilterSame"))
        this.chk_filterDelete.OnEvent("Click", ObjBindMethod(this, "OnFilterDelete"))
        this.chk_filterIgnore.OnEvent("Click", ObjBindMethod(this, "OnFilterIgnore"))

        this.LV_Import := this.GuiObj.Add("ListView", "x30 y165 w720 h310 Grid", ["标题", "命令 ID", "导入的命令 ID", "操作"])
        this.LV_Import.OnEvent("Click", ObjBindMethod(this, "OnImportListViewClick"))
        this.LV_Import.OnEvent("ItemSelect", ObjBindMethod(this, "OnImportListViewItemSelect"))
        this.LV_Import.OnEvent("DoubleClick", ObjBindMethod(this, "OnImportListViewDoubleClick"))
        this.LV_Import.OnEvent("ContextMenu", ObjBindMethod(this, "OnImportListViewContextMenu"))

        this.LV_Import.ModifyCol(1, 160)
        this.LV_Import.ModifyCol(2, 240)
        this.LV_Import.ModifyCol(3, 253)
        this.LV_Import.ModifyCol(4, 50)
        this.LV_Import.ModifyCol(4, "Center")

        ; 空状态占位符
        this.Txt_EmptyLV := this.GuiObj.Add("Text", "x250 y305 w280 h30 Center c808080 BackgroundTrans", "请点击上方按钮获取数据")

        ; --- 列表底部操作按钮 (分组在同步状态视图内) ---
        this.btn_markDelete := this.GuiObj.Add("Button", "x30 y485 w80 h24 Disabled", "删除选中")
        this.btn_markDelete.ToolTip := "将选中的命令标记为待删除"
        this.btn_markDelete.OnEvent("Click", ObjBindMethod(this, "OnMarkItemsToDelete"))

        this.btn_markIgnore := this.GuiObj.Add("Button", "x120 y485 w80 h24 Disabled", "忽略选中")
        this.btn_markIgnore.ToolTip := "将选中的命令标记为忽略"
        this.btn_markIgnore.OnEvent("Click", ObjBindMethod(this, "OnMarkItemsToIgnore"))

        this.Txt_SelCount := this.GuiObj.Add("Text", "x220 y489 w150 h20", "已选中: 0 项")

        ; --- 底部区块：执行操作 ---

        btn_resetView := this.GuiObj.Add("Button", "x30 y550 w150", "重置视图")
        btn_resetView.ToolTip := "撤销所有未保存的操作并重置视图"
        btn_resetView.OnEvent("Click", ObjBindMethod(this, "OnResetImportView"))

        btn_applyAll := this.GuiObj.Add("Button", "x600 y550 w150", "应用修改")
        btn_applyAll.ToolTip := "将列表中高亮选中的新增/更新/删除操作保存到配置"
        btn_applyAll.OnEvent("Click", ObjBindMethod(this, "OnApplyImportAll"))

        ; =============== 初始化数据加载 ===============
        this.LoadCommandTree()
        this.OnLButtonDownBound := ObjBindMethod(this, "OnLButtonDown")
        OnMessage(0x0201, this.OnLButtonDownBound)
        this.GuiObj.Show("w800 h600")
    }

    static BrowseEverything(*) {
        this.GuiObj.Opt("+Disabled")
        path := FileSelect(, , "请选择 Everything.exe", "程序 (*.exe)")
        this.GuiObj.Opt("-Disabled")
        if path {
            this.Edit_EverythingPath.Value := path
        }
    }

    static SaveGeneralSettings(*) {
        try {
            if !AppSettings.config_obj.Has("Everything") {
                AppSettings.config_obj["Everything"] := Map("Enabled", "0", "Path", "")
            }
            AppSettings.config_obj["Everything"]["Enabled"] := String(this.Chk_Everything.Value)
            AppSettings.config_obj["Everything"]["Path"] := this.Edit_EverythingPath.Value

            AppSettings.Everything_Enabled := this.Chk_Everything.Value
            AppSettings.Everything_Path := this.Edit_EverythingPath.Value

            FileDelete(AppSettings.config_json_path)
            FileAppend(JSON.stringify(AppSettings.config_obj), AppSettings.config_json_path, "UTF-8")

            this.SB.SetText("通用设置保存成功！请手动重新载入 UCLC 脚本以使其生效。")
        } catch as e {
            MsgBox("保存失败: " e.Message, "错误", 16)
        }
    }

    static LoadCommandTree(filter := "") {
        this.ClearRightPane()
        this.TV_Alias.Delete()
        this.TV_Map.Clear()

        wb_filter_id := ""
        if (this.HasProp("DDL_Workbench") && IsObject(this.DDL_Workbench) && this.DDL_Workbench.Value > 1) {
            wb_filter_id := this.workbench_ids[this.DDL_Workbench.Value]
        }

        for category, cmdArray in AppSettings.commands_obj {
            if (category == "_comment")
                continue

            if (wb_filter_id != "" && category != wb_filter_id)
                continue

            catId := 0

            for index, cmd in cmdArray {
                display_name := (cmd.Has("desc") && cmd["desc"] != "") ? cmd["desc"] : (cmd.Has("command") ? cmd[
                    "command"] : "未知")

                if (filter != "") {
                    ; 搜索匹配
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
                    if (!matched)
                        continue
                }

                if (catId == 0) {
                    catId := this.TV_Alias.Add(AppSettings.GetWbName(category))
                    this.TV_Map[catId] := { type: "Category", name: category }
                }

                itemId := this.TV_Alias.Add(display_name, catId)
                this.TV_Map[itemId] := { type: "Item", category: category, index: index, cmd: cmd }
            }

            if (catId != 0)
                this.TV_Alias.Modify(catId, "Expand")
        }
    }

    static OnWorkbenchFilter(CtrlObj, *) {
        if (this.DDL_Workbench.Text != "全部工作台") {
            this.Btn_AddCmdFromOther.Opt("-Disabled")
        } else {
            this.Btn_AddCmdFromOther.Opt("+Disabled")
        }
        this.LoadCommandTree(this.Edit_Search.Value)
    }

    static OnSearchFilter(CtrlObj, *) {
        val := CtrlObj.Value
        this.LoadCommandTree(val)
    }

    static GetUnsavedChangesSummary(orig_str, curr_obj) {
        try {
            orig_obj := JSON.parse(orig_str)
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

    static OnClose(*) {
        if (this.HasProp("original_json_str") && this.original_json_str != "") {
            this.SaveInputsToCurrentCmd()
            current_json := JSON.stringify(AppSettings.commands_obj)
            if (current_json !== this.original_json_str) {
                summary := this.GetUnsavedChangesSummary(this.original_json_str, AppSettings.commands_obj)
                this.GuiObj.Opt("+OwnDialogs")
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
        this.alias_edits := []
        this.hotkey_edits := []
        this.alias_pool := []
        this.hotkey_pool := []

        this.TV_Map.Clear()

        if (this.GuiObj) {
            this.GuiObj.Destroy()
        }

        this.GuiObj := ""
        this.Tabs := ""
        this.TV_Alias := ""
        this.DDL_Workbench := ""
        this.Edit_Search := ""
        this.Chk_Everything := ""
        this.Edit_EverythingPath := ""
        this.Edit_Cmd := ""
        this.Edit_Desc := ""

        this.Txt_Cat := ""
        this.Txt_CatVal := ""
        this.Txt_Desc := ""
        this.Txt_Cmd := ""
        this.Txt_Alias := ""
        this.Txt_Hotkey := ""
        this.Btn_Save := ""
        this.Btn_DelItem := ""
        this.Btn_AddCmdFromOther := ""
        this.dlg_ddl_src := ""
        this.dlg_edit_filter := ""
        this.dlg_lv := ""
        this.dlg_btn_add := ""
        this.dlg_btn_cancel := ""
        this.dlg_target_wb := ""
        this.btn_markDelete := ""
        this.btn_markIgnore := ""
        this.Txt_SelCount := ""
    }

    static ClearRightPane() {
        if (!this.GuiObj || !this.HasProp("Txt_Cat"))
            return

        this.Txt_Cat.Opt("Hidden")
        this.Txt_CatVal.Opt("Hidden")
        this.Txt_Desc.Opt("Hidden")
        this.Edit_Desc.Opt("Hidden")
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

        this.alias_edits := []
        this.hotkey_edits := []
    }

    static OnCommandTreeSelect(GuiCtrlObj, Item) {
        this.ClearRightPane()
        if (!this.TV_Map.Has(Item))
            return

        info := this.TV_Map[Item]
        if (info.type != "Item")
            return

        cmd := info.cmd

        this.Txt_CatVal.Value := AppSettings.GetWbName(info.category)
        this.Edit_Desc.Value := cmd.Has("desc") ? cmd["desc"] : ""
        this.Edit_Cmd.Value := cmd.Has("command") ? cmd["command"] : ""

        this.Txt_Cat.Opt("-Hidden")
        this.Txt_CatVal.Opt("-Hidden")
        this.Txt_Desc.Opt("-Hidden")
        this.Edit_Desc.Opt("-Hidden")
        this.Txt_Cmd.Opt("-Hidden")
        this.Edit_Cmd.Opt("-Hidden")
        this.Txt_Alias.Opt("-Hidden")

        cur_y := 180

        ; 别名区
        aliases := cmd.Has("aliases") ? cmd["aliases"] : []
        if (aliases.Length == 0)
            aliases := [""]

        for idx, al in aliases {
            if (idx > 10)
                break
            p := this.alias_pool[idx]
            p.e.Value := al
            p.e.Move(, cur_y - 4)
            p.add.Move(, cur_y - 5)
            p.del.Move(, cur_y - 5)

            p.e.Opt("-Hidden")
            p.add.Opt("-Hidden")
            p.del.Opt("-Hidden")

            if (Trim(al) != "")
                p.add.Opt("-Disabled")
            else
                p.add.Opt("+Disabled")

            if (aliases.Length > 1)
                p.del.Opt("-Disabled")
            else
                p.del.Opt("+Disabled")

            this.alias_edits.Push(p.e)
            cur_y += 30
        }

        cur_y += 10

        ; 快捷键区
        this.Txt_Hotkey.Move(, cur_y)
        this.Txt_Hotkey.Opt("-Hidden")

        hotkeys := cmd.Has("hotkeys") ? cmd["hotkeys"] : []
        if (hotkeys.Length == 0)
            hotkeys := [""]

        for idx, hk in hotkeys {
            if (idx > 10)
                break
            p := this.hotkey_pool[idx]
            try {
                p.e.Value := this.FormatHotkeyForDisplay(hk)
            } catch {
                p.e.Value := ""
            }
            p.e.Move(, cur_y - 4)
            p.add.Move(, cur_y - 5)
            p.del.Move(, cur_y - 5)

            p.e.Opt("-Hidden")
            p.add.Opt("-Hidden")
            p.del.Opt("-Hidden")

            if (Trim(hk) != "")
                p.add.Opt("-Disabled")
            else
                p.add.Opt("+Disabled")

            if (hotkeys.Length > 1)
                p.del.Opt("-Disabled")
            else
                p.del.Opt("+Disabled")

            this.hotkey_edits.Push(p.e)
            cur_y += 30
        }

        cur_y += 30
        this.Btn_Revert.Move(, cur_y)
        this.Btn_Revert.Opt("-Hidden")

        this.CheckGlobalDirty()
        this.SB.SetText("")
    }

    static SaveInputsToCurrentCmd() {
        itemId := this.TV_Alias.GetSelection()
        if (!itemId || !this.TV_Map.Has(itemId) || this.TV_Map[itemId].type != "Item")
            return

        cmd := this.TV_Map[itemId].cmd
        cmd["command"] := Trim(this.Edit_Cmd.Value)
        cmd["desc"] := Trim(this.Edit_Desc.Value)

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

    static OnAddAlias(idx, *) {
        this.SaveInputsToCurrentCmd()
        itemId := this.TV_Alias.GetSelection()
        cmd := this.TV_Map[itemId].cmd
        if (!cmd.Has("aliases"))
            cmd["aliases"] := []
        cmd["aliases"].InsertAt(idx + 1, "")
        this.OnCommandTreeSelect(this.TV_Alias, itemId)
    }

    static OnDelAlias(idx, *) {
        this.SaveInputsToCurrentCmd()
        itemId := this.TV_Alias.GetSelection()
        cmd := this.TV_Map[itemId].cmd
        if (cmd.Has("aliases") && cmd["aliases"].Length >= idx)
            cmd["aliases"].RemoveAt(idx)
        this.OnCommandTreeSelect(this.TV_Alias, itemId)
    }

    static OnAddHotkey(idx, *) {
        this.SaveInputsToCurrentCmd()
        itemId := this.TV_Alias.GetSelection()
        cmd := this.TV_Map[itemId].cmd
        if (!cmd.Has("hotkeys"))
            cmd["hotkeys"] := []
        cmd["hotkeys"].InsertAt(idx + 1, "")
        this.OnCommandTreeSelect(this.TV_Alias, itemId)
    }

    static OnDelHotkey(idx, *) {
        this.SaveInputsToCurrentCmd()
        itemId := this.TV_Alias.GetSelection()
        cmd := this.TV_Map[itemId].cmd
        if (cmd.Has("hotkeys") && cmd["hotkeys"].Length >= idx)
            cmd["hotkeys"].RemoveAt(idx)
        this.OnCommandTreeSelect(this.TV_Alias, itemId)
    }

    static CheckGlobalDirty() {
        if (!this.HasOwnProp("original_json_str") || this.original_json_str == "")
            return

        current_json := JSON.stringify(AppSettings.commands_obj)
        if (current_json !== this.original_json_str) {
            this.Btn_Save.Opt("-Disabled")
        } else {
            this.Btn_Save.Opt("+Disabled")
        }

        if !this.HasOwnProp("original_commands_obj") {
            this.original_commands_obj := JSON.parse(this.original_json_str)
        }

        for id, info in this.TV_Map {
            if (info.type == "Item") {
                orig_cmd := ""
                wb := info.category
                if (this.original_commands_obj.Has(wb) && this.original_commands_obj[wb].Length >= info.index) {
                    orig_cmd := this.original_commands_obj[wb][info.index]
                }

                is_dirty := false
                if (orig_cmd == "") {
                    is_dirty := true
                } else {
                    is_dirty := (info.cmd["command"] != orig_cmd["command"])
                    || (info.cmd.Has("desc") ? info.cmd["desc"] : "") != (orig_cmd.Has("desc") ? orig_cmd["desc"] : "")
                    || JSON.stringify(info.cmd.Has("aliases") ? info.cmd["aliases"] : []) != JSON.stringify(orig_cmd.Has(
                        "aliases") ? orig_cmd["aliases"] : [])
                    || JSON.stringify(info.cmd.Has("hotkeys") ? info.cmd["hotkeys"] : []) != JSON.stringify(orig_cmd.Has(
                        "hotkeys") ? orig_cmd["hotkeys"] : [])
                }

                if (is_dirty) {
                    this.TV_Alias.Modify(id, "Bold")
                    if (id == this.TV_Alias.GetSelection())
                        this.Btn_Revert.Opt("-Disabled")
                } else {
                    this.TV_Alias.Modify(id, "-Bold")
                    if (id == this.TV_Alias.GetSelection())
                        this.Btn_Revert.Opt("+Disabled")
                }
            }
        }
    }

    static OnDetailChange(*) {
        this.SaveInputsToCurrentCmd()
        this.CheckGlobalDirty()
    }

    static OnAliasChange(idx, GuiCtrlObj, *) {
        p := this.alias_pool[idx]
        if (Trim(GuiCtrlObj.Value) != "")
            p.add.Opt("-Disabled")
        else
            p.add.Opt("+Disabled")
        this.SaveInputsToCurrentCmd()
        this.CheckGlobalDirty()
    }

    static OnHotkeyChange(idx, GuiCtrlObj, *) {
        p := this.hotkey_pool[idx]
        if (Trim(GuiCtrlObj.Value) != "")
            p.add.Opt("-Disabled")
        else
            p.add.Opt("+Disabled")
        this.SaveInputsToCurrentCmd()
        this.CheckGlobalDirty()
    }

    static OnHotkeyFocus(idx, GuiCtrlObj, *) {
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

    static OnHotkeyLoseFocus(idx, GuiCtrlObj, *) {
        if this.HasProp("ih") && this.ih {
            this.ih.Stop()
            this.ih := ""
        }
    }

    static OnInputHookEnd(idx, GuiCtrlObj, ih) {
        if (ih.EndReason = "EndKey") {
            key := ih.EndKey

            if (key = "Backspace" || key = "Delete") {
                GuiCtrlObj.Value := ""
            } else if (key = "Escape" || key = "Tab" || key = "Enter" || key = "NumpadEnter") {
                ; Do nothing for focus navigation keys
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

        ; Restart hook if still focused
        try {
            if (this.GuiObj.FocusedCtrl == GuiCtrlObj) {
                this.OnHotkeyFocus(idx, GuiCtrlObj)
            }
        }
    }

    static FormatHotkeyForDisplay(hk) {
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

    static ParseHotkeyFromDisplay(display) {
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

    static OnLButtonDown(wParam, lParam, msg, hwnd) {
        if (this.HasProp("GuiObj") && this.GuiObj) {
            try {
                ctrl := this.GuiObj.FocusedCtrl
                if (!ctrl || Type(ctrl) != "Gui.Edit")
                    return

                class := WinGetClass(hwnd)
                if (class == "Edit" || class == "SysTreeView32" || class == "ComboBox")
                    return

                if (class == "Button") {
                    style := WinGetStyle(hwnd)
                    if ((style & 0xF) != 0x7) ; Not a GroupBox
                        return
                }

                SetTimer(ObjBindMethod(this, "DoBlur"), -10)
            }
        }
    }

    static DoBlur() {
        if (this.HasProp("Tabs") && this.Tabs)
            try this.Tabs.Focus()
    }

    static OnRevertChanges(*) {
        if (!this.HasOwnProp("original_commands_obj"))
            return

        itemId := this.TV_Alias.GetSelection()
        if (!itemId || !this.TV_Map.Has(itemId) || this.TV_Map[itemId].type != "Item")
            return

        wb := this.TV_Map[itemId].category
        index := this.TV_Map[itemId].index

        orig_cmd := ""
        if (this.original_commands_obj.Has(wb) && this.original_commands_obj[wb].Length >= index) {
            orig_cmd := this.original_commands_obj[wb][index]
        }

        if (orig_cmd != "") {
            restored_cmd := JSON.parse(JSON.stringify(orig_cmd))
            this.TV_Map[itemId].cmd := restored_cmd

            if (AppSettings.commands_obj.Has(wb) && AppSettings.commands_obj[wb].Length >= index) {
                AppSettings.commands_obj[wb][index] := restored_cmd
            }

            this.OnCommandTreeSelect(this.TV_Alias, itemId)
            this.CheckGlobalDirty()
            this.SB.SetText("当前命令已恢复到初始状态。")
        }
    }

    static SaveCurrentItem(*) {
        this.SaveInputsToCurrentCmd()

        itemId := this.TV_Alias.GetSelection()
        saved_cmd_id := ""
        saved_cat := ""
        if (itemId && this.TV_Map.Has(itemId) && this.TV_Map[itemId].type == "Item") {
            cmd := this.TV_Map[itemId].cmd
            saved_cmd_id := cmd["command"]
            saved_cat := this.TV_Map[itemId].category
        }

        hotkey_changed := false
        if (this.HasOwnProp("original_commands_obj")) {
            for id, info in this.TV_Map {
                if (info.type == "Item") {
                    orig_cmd := ""
                    wb := info.category
                    if (this.original_commands_obj.Has(wb) && this.original_commands_obj[wb].Length >= info.index) {
                        orig_cmd := this.original_commands_obj[wb][info.index]
                    }
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
        }

        this.FlushCommandsJson()

        ; 触发内存重建
        AppSettings.Init()
        this.original_json_str := JSON.stringify(AppSettings.commands_obj)
        if this.HasOwnProp("original_commands_obj") {
            this.DeleteProp("original_commands_obj")
        }

        ; 刷新界面
        this.LoadCommandTree(this.Edit_Search.Value)

        if (saved_cmd_id != "") {
            for id, info in this.TV_Map {
                if (info.type == "Item" && info.cmd["command"] == saved_cmd_id && info.category == saved_cat) {
                    this.TV_Alias.Modify(id, "Select Vis")
                    this.OnCommandTreeSelect(this.TV_Alias, id)
                    break
                }
            }
        }

        this.CheckGlobalDirty()
        if (hotkey_changed) {
            this.SB.SetText("修改成功！请手动重新载入 UCLC 以应用最新配置。")
        } else {
            this.SB.SetText("修改成功。")
        }
    }
    static FlushCommandsJson() {
        try {
            FileDelete(AppSettings.commands_json_path)
            FileAppend(JSON.stringify(AppSettings.commands_obj), AppSettings.commands_json_path, "UTF-8")
        } catch as e {
            MsgBox("写入 JSON 文件失败: " e.Message, "错误", 16)
        }
    }

    ; --- 第三页 (工作台命令库) 回调预留 ---
    static RefreshIfDataExists() {
        if (this.HasOwnProp("parsed_import_data") && this.parsed_import_data.Count > 0)
            this.RenderImportLV()
    }

    static OnFilterAll(ctrl, *) {
        state := ctrl.Value
        this.chk_filterNew.Value := state
        this.chk_filterUpdate.Value := state
        this.chk_filterOverwrite.Value := state
        this.chk_filterSame.Value := state
        this.chk_filterDelete.Value := state
        this.chk_filterIgnore.Value := state
        this.RefreshIfDataExists()
    }

    static UpdateFilterAllState() {
        if (this.chk_filterNew.Value && this.chk_filterUpdate.Value && this.chk_filterOverwrite.Value && this.chk_filterSame
            .Value && this.chk_filterDelete.Value && this.chk_filterIgnore.Value)
            this.chk_filterAll.Value := 1
        else
            this.chk_filterAll.Value := 0
    }

    static HandleFilterClick(ctrl) {
        if GetKeyState("Alt", "P") {
            this.chk_filterNew.Value := (ctrl == this.chk_filterNew)
            this.chk_filterUpdate.Value := (ctrl == this.chk_filterUpdate)
            this.chk_filterOverwrite.Value := (ctrl == this.chk_filterOverwrite)
            this.chk_filterSame.Value := (ctrl == this.chk_filterSame)
            this.chk_filterDelete.Value := (ctrl == this.chk_filterDelete)
            this.chk_filterIgnore.Value := (ctrl == this.chk_filterIgnore)
        }
        this.UpdateFilterAllState()
        this.RefreshIfDataExists()
    }

    static OnFilterNew(ctrl, *) {
        this.HandleFilterClick(ctrl)
    }
    static OnFilterUpdate(ctrl, *) {
        this.HandleFilterClick(ctrl)
    }
    static OnFilterOverwrite(ctrl, *) {
        this.HandleFilterClick(ctrl)
    }
    static OnFilterSame(ctrl, *) {
        this.HandleFilterClick(ctrl)
    }
    static OnFilterDelete(ctrl, *) {
        this.HandleFilterClick(ctrl)
    }
    static OnFilterIgnore(ctrl, *) {
        this.HandleFilterClick(ctrl)
    }

    static OnImportCommands(ctrl, *) {
        this.ShowImportSelector()
    }

    static ShowImportSelector() {
        cmd_id_dir := A_ScriptDir "\data\command-id"
        if !DirExist(cmd_id_dir) {
            MsgBox("未找到工作台命令库目录：" cmd_id_dir, "错误", "Iconx")
            return
        }

        dlg := Gui("+Owner" this.GuiObj.Hwnd " -MinimizeBox -MaximizeBox", "导入内置工作台命令")
        this.GuiObj.Opt("+Disabled")

        dlg.Add("Text", "x15 y15 w80 h20", "搜索工作台:")
        edit_search := dlg.Add("Edit", "x100 y11 w325 h24")

        lv := dlg.Add("ListView", "x15 y45 w410 h340 +Grid -Multi", ["工作台名称", "ID"])
        lv.ModifyCol(1, 260)
        lv.ModifyCol(2, 120)

        all_items := []
        loop files, cmd_id_dir "\*.txt" {
            id := StrReplace(A_LoopFileName, ".txt", "")
            name := AppSettings.GetWbName(id)
            all_items.Push({ name: name, id: id })
        }

        default_wb := ""
        if (this.DDL_ImportWb.Value > 1) {
            default_wb := this.import_wb_ids[this.DDL_ImportWb.Value]
        }

        fill_lv(filter_str := "") {
            lv.Opt("-Redraw")
            lv.Delete()
            default_row := 0
            for item in all_items {
                if (filter_str != "" && !InStr(item.name, filter_str) && !InStr(item.id, filter_str)) {
                    continue
                }
                row := lv.Add("", item.name, item.id)
                if (default_wb != "" && item.id == default_wb) {
                    default_row := row
                }
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

        btn_confirm := dlg.Add("Button", "x110 y405 w100 h30 Default", "确认导入")
        btn_cancel := dlg.Add("Button", "x230 y405 w100 h30", "取消")

        do_confirm(*) {
            row := lv.GetNext(0)
            if (row == 0) {
                MsgBox("请先选择一个工作台！", "提示", "Iconi")
                return
            }
            sel_id := lv.GetText(row, 2)
            filepath := cmd_id_dir "\" sel_id ".txt"
            this.GuiObj.Opt("-Disabled")
            dlg.Destroy()
            this.ImportFile(filepath)
        }

        close_dlg(*) {
            this.GuiObj.Opt("-Disabled")
            dlg.Destroy()
        }

        btn_confirm.OnEvent("Click", do_confirm)
        lv.OnEvent("DoubleClick", do_confirm)
        btn_cancel.OnEvent("Click", close_dlg)
        dlg.OnEvent("Close", close_dlg)
        dlg.OnEvent("Escape", close_dlg)

        dlg.Show("w440 h450")
    }

    static OnReadExportedTxt(ctrl, *) {
        selectedFile := FileSelect(3, , "选择 CATIA 导出的 Workshop Exposition 文件", "Text Documents (*.txt)")
        if (selectedFile = "")
            return
        this.ImportFile(selectedFile)
    }

    static ImportFile(selectedFile) {
        this.DDL_ImportWb.Choose(1)
        target_wb := "通过导入文件确定"

        content := FileRead(selectedFile, "UTF-8")
        if (!InStr(content, "Workshop Exposition") || InStr(content, Chr(0xFFFD))) {
            content := FileRead(selectedFile, "CP0")
            if !InStr(content, "Workshop Exposition") {
                MsgBox("所选文件非有效的 Workshop Exposition 导出文件！", "解析错误", "Iconx")
                return
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

        if (target_wb != "通过导入文件确定" && wb_id != "" && target_wb != wb_id) {
            result := MsgBox("文件中解析的工作台 ID (" wb_id ") 与当前选择的目标工作台 (" AppSettings.GetWbName(target_wb) ") 不一致。是否继续导入到 " AppSettings
            .GetWbName(target_wb) "？", "警告", "YesNo Icon!")
            if (result == "No") {
                return
            }
        }

        this.parsed_import_data := parsed_commands
        this.parsed_import_wb_id := wb_id

        this.RefreshImportDiff(target_wb)
    }

    static OnTargetWorkbenchChanged(ctrl, *) {
        if (!this.HasOwnProp("parsed_import_data") || this.parsed_import_data.Count == 0)
            return
        target_wb := ""
        if (ctrl.Value > 1) {
            target_wb := this.import_wb_ids[ctrl.Value]
        } else {
            target_wb := ctrl.Text
        }
        this.RefreshImportDiff(target_wb)
    }

    static RefreshImportDiff(target_wb) {
        parsed_commands := this.parsed_import_data
        wb_id := this.parsed_import_wb_id

        if (target_wb == "通过导入文件确定") {
            if (wb_id != "") {
                target_wb := wb_id
                found_idx := 0
                for i, id in this.import_wb_ids {
                    if (id == target_wb) {
                        found_idx := i
                        break
                    }
                }
                if (found_idx > 0) {
                    this.DDL_ImportWb.Choose(found_idx)
                } else {
                    wb_name := AppSettings.GetWbName(target_wb)
                    this.DDL_ImportWb.Add([wb_name])
                    this.import_wb_ids.Push(target_wb)
                    this.DDL_ImportWb.Choose(this.import_wb_ids.Length)
                }
            } else {
                this.Txt_EmptyLV.Value := "无法从文件中解析出工作台 ID，请手动选择目标工作台"
                return
            }
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

        this.import_items := []
        matched_local_ids := Map()

        for id, title in parsed_commands {
            if local_by_id.Has(id) {
                if local_by_id[id]["desc"] == title {
                    this.import_items.Push({ title: title, local_id: id, action: "=", imported_id: id })
                } else {
                    this.import_items.Push({ title: title, local_id: local_by_id[id]["command"], action: "T",
                        imported_id: id })
                }
                matched_local_ids[id] := true
            } else if local_by_title.Has(title) {
                old_id := local_by_title[title]["command"]
                this.import_items.Push({ title: title, local_id: old_id, action: "C", imported_id: id })
                matched_local_ids[old_id] := true
            } else {
                this.import_items.Push({ title: title, local_id: "", action: "+", imported_id: id })
            }
        }

        for cmd in local_array {
            id := cmd["command"]
            if !matched_local_ids.Has(id) {
                desc := (cmd.Has("desc") && cmd["desc"] != "") ? cmd["desc"] : cmd["command"]
                this.import_items.Push({ title: desc, local_id: id, action: "D", imported_id: "" })
            }
        }

        this.RenderImportLV()
    }

    static UpdateCounts() {
        if !this.HasOwnProp("import_items")
            return

        cNew := 0, cUpd := 0, cOvr := 0, cSam := 0, cDel := 0, cIgn := 0
        for item in this.import_items {
            a := item.action
            if (a == "+")
                cNew++
            else if (a == "T")
                cUpd++
            else if (a == "C")
                cOvr++
            else if (a == "=")
                cSam++
            else if (a == "D")
                cDel++
            else if (a == "i")
                cIgn++
        }
        cAll := cNew + cUpd + cOvr + cSam + cDel + cIgn
        this.chk_filterAll.Text := "全部`n(" cAll ")"
        this.chk_filterNew.Text := "新增`n(" cNew ")"
        this.chk_filterUpdate.Text := "更新标题`n(" cUpd ")"
        this.chk_filterOverwrite.Text := "更新命令`n(" cOvr ")"
        this.chk_filterSame.Text := "一致`n(" cSam ")"
        this.chk_filterDelete.Text := "待删除`n(" cDel ")"
        this.chk_filterIgnore.Text := "忽略`n(" cIgn ")"
    }

    static RenderImportLV() {
        if !this.HasOwnProp("import_items")
            return

        this.UpdateCounts()

        showNew := this.chk_filterNew.Value
        showUpdate := this.chk_filterUpdate.Value
        showOverwrite := this.chk_filterOverwrite.Value
        showSame := this.chk_filterSame.Value
        showDelete := this.chk_filterDelete.Value
        showIgnore := this.chk_filterIgnore.Value

        this.LV_Import.Opt("-Redraw")
        this.LV_Import.Delete()
        this.Txt_EmptyLV.Visible := false

        for item in this.import_items {
            a := item.action
            if ((a == "+" && showNew) || (a == "T" && showUpdate) || (a == "C" && showOverwrite)
            || (a == "=" && showSame) || (a == "D" && showDelete) || (a == "i" && showIgnore)) {
                this.LV_Import.Add("", item.title, item.local_id, item.imported_id, a)
            }
        }

        this.LV_Import.Opt("+Redraw")
        this.LV_Import.ModifyCol(1, "Sort")
        this.Txt_SelCount.Value := "已选中: 0 项"
    }

    static OnImportListViewClick(ctrl, item, *) {
    }
    static OnImportListViewItemSelect(ctrl, item, selected) {
        sel_count := this.LV_Import.GetCount("S")
        this.btn_markDelete.Opt(sel_count > 0 ? "-Disabled" : "+Disabled")
        this.btn_markIgnore.Opt(sel_count > 0 ? "-Disabled" : "+Disabled")
        this.Txt_SelCount.Value := "已选中: " sel_count " 项"
    }
    static OnImportListViewDoubleClick(ctrl, item, *) {
    }
    static OnImportListViewContextMenu(ctrl, item, isRightClick, X, Y) {
    }

    static OnResetImportView(*) {
        if this.HasOwnProp("parsed_import_data") {
            target_wb := ""
            if (this.DDL_ImportWb.Value > 1) {
                target_wb := this.import_wb_ids[this.DDL_ImportWb.Value]
            } else {
                target_wb := this.DDL_ImportWb.Text
            }
            this.RefreshImportDiff(target_wb)
        }
    }

    static OnAddTargetWorkbench(ctrl, *) {
    }

    static OnMarkItemsToDelete(*) {
        selected := []
        row := 0
        while (row := this.LV_Import.GetNext(row)) {
            selected.Push(row)
        }
        if (selected.Length == 0)
            return

        for r in selected {
            this.LV_Import.Modify(r, "Col4", "D")
            title := this.LV_Import.GetText(r, 1)
            old_id := this.LV_Import.GetText(r, 2)
            new_id := this.LV_Import.GetText(r, 3)
            for item in this.import_items {
                if (item.title == title && item.local_id == old_id && item.imported_id == new_id) {
                    item.action := "D"
                    break
                }
            }
        }
        this.UpdateCounts()
    }

    static OnMarkItemsToIgnore(*) {
        selected := []
        row := 0
        while (row := this.LV_Import.GetNext(row)) {
            selected.Push(row)
        }
        if (selected.Length == 0)
            return

        for r in selected {
            this.LV_Import.Modify(r, "Col4", "i")
            title := this.LV_Import.GetText(r, 1)
            old_id := this.LV_Import.GetText(r, 2)
            new_id := this.LV_Import.GetText(r, 3)
            for item in this.import_items {
                if (item.title == title && item.local_id == old_id && item.imported_id == new_id) {
                    item.action := "i"
                    break
                }
            }
        }
        this.UpdateCounts()
    }

    static OnApplyImportAll(*) {
        if (this.DDL_ImportWb.Value > 1) {
            target_wb := this.import_wb_ids[this.DDL_ImportWb.Value]
        } else {
            target_wb := this.DDL_ImportWb.Text
        }
        if (target_wb == "通过导入文件确定" || target_wb == "") {
            MsgBox("请先选择目标工作台或导入文件", "提示", "Iconi")
            return
        }

        if !AppSettings.commands_obj.Has(target_wb) {
            AppSettings.commands_obj[target_wb] := []
        }
        local_array := AppSettings.commands_obj[target_wb]

        local_by_id := Map()
        for cmd in local_array {
            local_by_id[cmd["command"]] := cmd
        }

        if (!this.HasOwnProp("import_items")) {
            MsgBox("没有可应用的数据", "提示", "Iconi")
            return
        }

        selected_keys := Map()
        row := 0
        while (row := this.LV_Import.GetNext(row)) {
            title := this.LV_Import.GetText(row, 1)
            old_id := this.LV_Import.GetText(row, 2)
            new_id := this.LV_Import.GetText(row, 3)
            selected_keys[title "_" old_id "_" new_id] := true
        }

        cNew := 0, cUpd := 0, cOvr := 0, cDel := 0
        strNew := "", strUpd := "", strOvr := "", strDel := ""

        for item in this.import_items {
            if !selected_keys.Has(item.title "_" item.local_id "_" item.imported_id)
                continue

            a := item.action
            if (a == "+") {
                cNew++
                strNew .= "- " item.title " (" item.imported_id ")`r`n"
            } else if (a == "T") {
                cUpd++
                strUpd .= "- " item.title " (" item.imported_id ")`r`n"
            } else if (a == "C") {
                cOvr++
                strOvr .= "- " item.title " (" item.imported_id ")`r`n"
            } else if (a == "D") {
                cDel++
                strDel .= "- " item.title " (" item.local_id ")`r`n"
            }
        }

        if (cNew == 0 && cUpd == 0 && cOvr == 0 && cDel == 0) {
            MsgBox("没有实质性的修改需要应用。", "提示", "Iconi")
            return
        }

        full_msg := ""

        if cNew > 0
            full_msg .= "【新增】(数量: " cNew ")`r`n" strNew "`r`n"
        if cUpd > 0
            full_msg .= "【更新标题】(数量: " cUpd ")`r`n" strUpd "`r`n"
        if cOvr > 0
            full_msg .= "【更新命令】(数量: " cOvr ")`r`n" strOvr "`r`n"
        if cDel > 0
            full_msg .= "【待删除】(数量: " cDel ")`r`n" strDel "`r`n"

        confirm_gui := Gui("+Owner" this.GuiObj.Hwnd " +ToolWindow -MinimizeBox -MaximizeBox", "确认执行以下操作")
        confirm_gui.Add("Text", "x15 y15 w450 h20", "应用到 [" AppSettings.GetWbName(target_wb) "] 工作台:")
        confirm_gui.Add("Edit", "x15 y40 w450 h300 ReadOnly Multi VScroll", full_msg)

        user_confirmed := false

        close_dialog := (confirmed, *) => (
            user_confirmed := confirmed,
            this.GuiObj.Opt("-Disabled"),
            confirm_gui.Destroy()
        )

        btn_ok := confirm_gui.Add("Button", "x250 y350 w100 h30 Default", "确认")
        btn_ok.OnEvent("Click", close_dialog.Bind(true))

        btn_cancel := confirm_gui.Add("Button", "x365 y350 w100 h30", "取消")
        btn_cancel.OnEvent("Click", close_dialog.Bind(false))

        confirm_gui.OnEvent("Close", close_dialog.Bind(false))
        confirm_gui.OnEvent("Escape", close_dialog.Bind(false))

        this.GuiObj.Opt("+Disabled")
        confirm_gui.Show("AutoSize Center")
        btn_cancel.Focus()

        WinWaitClose(confirm_gui.Hwnd)

        if (!user_confirmed)
            return

        new_array := []
        for item in this.import_items {
            title := item.title
            old_id := item.local_id
            action := item.action
            new_id := item.imported_id

            if !selected_keys.Has(title "_" old_id "_" new_id) {
                action := "i"
            }

            if (action == "i" || action == "=") {
                if (old_id != "" && local_by_id.Has(old_id)) {
                    new_array.Push(local_by_id[old_id])
                }
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
                ; Do nothing to delete
            }
        }

        AppSettings.commands_obj[target_wb] := new_array
        this.FlushCommandsJson()

        MsgBox("成功！请重新载入UCLC使修改生效。", "成功", "Iconi")
        this.OnResetImportView()
    }

    static OnAddCmdFromOther(*) {
        target_wb := this.DDL_Workbench.Text
        if (target_wb == "全部工作台" || target_wb == "")
            return

        ; 创建模态自适应弹窗
        dlg := Gui("+Resize +Owner" this.GuiObj.Hwnd " +MinSize350x300", "从指定工作台添加命令 - 目标: " target_wb)
        dlg.OnEvent("Size", ObjBindMethod(this, "OnDlgSize"))
        dlg.OnEvent("Close", (*) => dlg.Destroy())
        dlg.OnEvent("Escape", (*) => dlg.Destroy())

        dlg.Add("Text", "x20 y20 w80 h20", "源工作台:")

        ; 搜集除目标工作台之外的所有工作台
        src_wbs := []
        for k, v in AppSettings.commands_obj {
            if (k != "_comment" && k != target_wb)
                src_wbs.Push(k)
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

        ; 事件绑定
        this.dlg_ddl_src.OnEvent("Change", ObjBindMethod(this, "OnDlgWbChange"))
        this.dlg_edit_filter.OnEvent("Change", ObjBindMethod(this, "OnDlgFilterChange"))
        this.dlg_btn_add.OnEvent("Click", ObjBindMethod(this, "OnDlgAdd", target_wb, dlg))
        this.dlg_btn_cancel.OnEvent("Click", (*) => dlg.Destroy())

        ; 记录当前选中工作台的命令池，方便搜索过滤
        this.dlg_target_wb := target_wb
        this.LoadDlgCommands()

        dlg.Show("w450 h500")
    }

    static OnDlgSize(GuiObj, MinMax, Width, Height) {
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

    static LoadDlgCommands() {
        this.dlg_lv.Delete()
        src_wb := this.dlg_ddl_src.Text
        if (src_wb == "")
            return

        filter := Trim(this.dlg_edit_filter.Value)

        target_cmds := Map()
        if AppSettings.commands_obj.Has(this.dlg_target_wb) {
            for cmd in AppSettings.commands_obj[this.dlg_target_wb] {
                if cmd.Has("command")
                    target_cmds[cmd["command"]] := 1
            }
        }

        if AppSettings.commands_obj.Has(src_wb) {
            this.dlg_lv.Opt("-Redraw")
            for cmd in AppSettings.commands_obj[src_wb] {
                desc := cmd.Has("desc") ? cmd["desc"] : ""
                command := cmd.Has("command") ? cmd["command"] : ""

                if (filter != "") {
                    if (!InStr(desc, filter) && !InStr(command, filter))
                        continue
                }

                is_dup := target_cmds.Has(command)
                display_desc := is_dup ? desc " (已存在)" : desc

                this.dlg_lv.Add("", display_desc, command)
            }
            this.dlg_lv.Opt("+Redraw")
        }
    }

    static OnDlgWbChange(*) {
        this.LoadDlgCommands()
    }

    static OnDlgFilterChange(*) {
        this.LoadDlgCommands()
    }

    static OnDlgAdd(target_wb, dlg, *) {
        row_count := this.dlg_lv.GetCount()
        selected_indices := []
        row := 0
        loop {
            row := this.dlg_lv.GetNext(row)
            if (!row)
                break
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
                    for item in v
                        arr_copy.Push(item)
                    new_cmd[k] := arr_copy
                } else {
                    new_cmd[k] := v
                }
            }

            target_cmd_list.Push(new_cmd)
            added_count++
        }

        if (added_count > 0) {
            this.FlushCommandsJson()
            AppSettings.Init()
            this.LoadCommandTree(this.Edit_Search.Value)

            msg := "成功添加 " added_count " 个命令到 [" target_wb "]"
            if (skipped_count > 0)
                msg .= "`n已自动忽略 " skipped_count " 个重复命令"
            MsgBox(msg, "成功", "Iconi T2")
            dlg.Destroy()
        } else {
            MsgBox("未添加任何命令（所选命令在目标工作台均已存在）。", "提示", "Iconi")
        }
    }

    static OnMouseMove(wParam, lParam, msg, hwnd) {
        static prev_hwnd := 0
        static hover_timer := 0

        if (hwnd == prev_hwnd)
            return
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
}
