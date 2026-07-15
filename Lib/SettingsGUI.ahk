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
    static Btn_Save := ""
    static Btn_DelItem := ""

    static alias_edits := []
    static hotkey_edits := []

    static Edit_Cmd := ""
    static Edit_Desc := ""
    static Edit_Search := ""

    static Chk_Everything := ""
    static Edit_EverythingPath := ""
    static Txt_EmptyLV := ""
    static DDL_ImportWb := ""

    static Show() {
        if (this.GuiObj) {
            WinActivate(this.GuiObj.Hwnd)
            return
        }

        ; 每次打开设置面板前强制从硬盘重载，丢弃一切未保存的内存脏数据
        AppSettings.Init()

        this.GuiObj := Gui("-Resize -MaximizeBox", "UCLC 配置管理控制台 (CUI)")
        this.GuiObj.OnEvent("Close", ObjBindMethod(this, "OnClose"))
        OnMessage(0x0200, ObjBindMethod(this, "OnMouseMove"))
        this.Tabs := this.GuiObj.Add("Tab3", "x10 y10 w780 h580", ["命令映射", "通用设置", "工作台命令库"])

        ; =============== 第一页: 命令映射 ===============
        this.Tabs.UseTab(1)
        this.GuiObj.Add("Text", "x30 y40 w200", "命令列表树 (工作台 -> 功能):")

        this.GuiObj.Add("Text", "x30 y65 w45", "工作台:")
        wb_list := ["全部工作台"]
        for k, v in AppSettings.commands_obj {
            if (k != "_comment")
                wb_list.Push(k)
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

        ; 右侧详情编辑区框
        this.GuiObj.Add("GroupBox", "x300 y60 w460 h490", "详细属性与动态编辑")

        ; 预分配右侧控件（池化技术防泄露，解决 Tab3 渲染覆盖问题）
        this.Tabs.UseTab(1)
        this.Txt_Cat := this.GuiObj.Add("Text", "x320 y80 w80 Hidden", "所属工作台:")
        this.Txt_CatVal := this.GuiObj.Add("Text", "x400 y80 w340 cBlue Hidden", "")

        this.Txt_Desc := this.GuiObj.Add("Text", "x320 y110 w80 Hidden", "功能描述:")
        this.Edit_Desc := this.GuiObj.Add("Edit", "x400 y106 w340 Hidden", "")

        this.Txt_Cmd := this.GuiObj.Add("Text", "x320 y140 w80 Hidden", "执行命令:")
        this.Edit_Cmd := this.GuiObj.Add("Edit", "x400 y136 w340 Hidden", "")

        this.Txt_Alias := this.GuiObj.Add("Text", "x320 y180 w80 Hidden", "触发别名:")

        this.alias_pool := []
        loop 10 {
            e := this.GuiObj.Add("Edit", "x400 y0 w120 Hidden", "")
            btn_add := this.GuiObj.Add("Button", "x530 y0 w30 h24 Hidden", "➕")
            btn_del := this.GuiObj.Add("Button", "x565 y0 w30 h24 Hidden", "➖")

            btn_add.OnEvent("Click", ObjBindMethod(this, "OnAddAlias", A_Index))
            btn_del.OnEvent("Click", ObjBindMethod(this, "OnDelAlias", A_Index))
            e.OnEvent("Change", ObjBindMethod(this, "OnAliasChange", A_Index))

            this.alias_pool.Push({ e: e, add: btn_add, del: btn_del })
        }

        this.Txt_Hotkey := this.GuiObj.Add("Text", "x320 y0 w80 Hidden", "触发快捷键:")

        this.hotkey_pool := []
        loop 10 {
            e := this.GuiObj.Add("Edit", "x400 y0 w120 Hidden", "")
            btn_add := this.GuiObj.Add("Button", "x530 y0 w30 h24 Hidden", "➕")
            btn_del := this.GuiObj.Add("Button", "x565 y0 w30 h24 Hidden", "➖")

            btn_add.OnEvent("Click", ObjBindMethod(this, "OnAddHotkey", A_Index))
            btn_del.OnEvent("Click", ObjBindMethod(this, "OnDelHotkey", A_Index))
            e.OnEvent("Change", ObjBindMethod(this, "OnHotkeyChange", A_Index))

            this.hotkey_pool.Push({ e: e, add: btn_add, del: btn_del })
        }

        this.Btn_Save := this.GuiObj.Add("Button", "x400 y0 w120 h35 Hidden", "✔ 保存映射修改")
        this.Btn_Save.OnEvent("Click", ObjBindMethod(this, "SaveCurrentItem"))

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

        btn_reload := this.GuiObj.Add("Button", "x30 y550 w150", "🔄 保存并热重载脚本")
        btn_reload.ToolTip := "保存当前设置并重新加载 UCLC 脚本"
        btn_reload.OnEvent("Click", (*) => Reload())

        ; =============== 第三页: 工作台命令库 ===============
        this.Tabs.UseTab(3)

        ; --- 顶部区块：数据源与获取 ---
        this.GuiObj.Add("GroupBox", "x20 y40 w740 h65", "数据源获取")

        this.GuiObj.Add("Text", "x30 y68 w70", "目标工作台:")
        wb_list3 := ["通过导入文件确定"]
        for k, v in AppSettings.commands_obj {
            if (k != "_comment")
                wb_list3.Push(k)
        }
        this.DDL_ImportWb := this.GuiObj.Add("DropDownList", "x100 y64 w250 Choose1", wb_list3)
        this.DDL_ImportWb.ToolTip := "选择要将命令导入到的目标工作台"

        btn_addWb := this.GuiObj.Add("Button", "x355 y64 w24 h22", "+")
        btn_addWb.ToolTip := "新增自定义目标工作台名称"
        btn_addWb.OnEvent("Click", ObjBindMethod(this, "OnAddTargetWorkbench"))

        btn_getCatia := this.GuiObj.Add("Button", "x500 y64 w120 h22 Disabled", "从 CATIA 提取")
        btn_getCatia.ToolTip := "暂不可用：未来版本将支持直接与活动 CATIA 通信"
        btn_getCatia.OnEvent("Click", ObjBindMethod(this, "OnGetCommandsFromCatia"))

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

        this.LV_Import := this.GuiObj.Add("ListView", "x30 y165 w720 h310 Grid Checked", ["标题", "命令 ID", "操作",
            "导入的命令 ID"])
        this.LV_Import.OnEvent("Click", ObjBindMethod(this, "OnImportListViewClick"))
        this.LV_Import.OnEvent("DoubleClick", ObjBindMethod(this, "OnImportListViewDoubleClick"))
        this.LV_Import.OnEvent("ContextMenu", ObjBindMethod(this, "OnImportListViewContextMenu"))

        this.LV_Import.ModifyCol(1, 160)
        this.LV_Import.ModifyCol(2, 255)
        this.LV_Import.ModifyCol(3, 50)
        this.LV_Import.ModifyCol(3, "Center")
        this.LV_Import.ModifyCol(4, 255)

        ; 空状态占位符
        this.Txt_EmptyLV := this.GuiObj.Add("Text", "x250 y305 w280 h30 Center c808080 BackgroundTrans", "请点击上方按钮获取数据")

        ; --- 列表底部操作按钮 (分组在同步状态视图内) ---
        btn_markDelete := this.GuiObj.Add("Button", "x30 y485 w80 h24 Disabled", "删除选中")
        btn_markDelete.ToolTip := "将选中的命令标记为待删除"
        btn_markDelete.OnEvent("Click", ObjBindMethod(this, "OnMarkItemsToDelete"))

        btn_markIgnore := this.GuiObj.Add("Button", "x120 y485 w80 h24 Disabled", "忽略选中")
        btn_markIgnore.ToolTip := "将选中的命令标记为忽略"
        btn_markIgnore.OnEvent("Click", ObjBindMethod(this, "OnMarkItemsToIgnore"))

        ; --- 底部区块：执行操作 ---

        btn_resetView := this.GuiObj.Add("Button", "x30 y550 w150", "重置视图")
        btn_resetView.ToolTip := "撤销所有未保存的操作并重置视图"
        btn_resetView.OnEvent("Click", ObjBindMethod(this, "OnResetImportView"))

        btn_applyAll := this.GuiObj.Add("Button", "x600 y550 w150", "应用修改")
        btn_applyAll.ToolTip := "将所有勾选的新增/更新/删除操作保存到配置"
        btn_applyAll.OnEvent("Click", ObjBindMethod(this, "OnApplyImportAll"))

        ; =============== 初始化数据加载 ===============
        this.Tabs.UseTab()
        this.LoadCommandTree()
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

            MsgBox("通用设置保存成功！", "UCLC", "Iconi T2")
        } catch as e {
            MsgBox("保存失败: " e.Message, "错误", 16)
        }
    }

    static LoadCommandTree(filter := "") {
        this.ClearRightPane()
        this.TV_Alias.Delete()
        this.TV_Map.Clear()

        wb_filter := ""
        if (this.HasProp("DDL_Workbench") && IsObject(this.DDL_Workbench)) {
            wb_filter := this.DDL_Workbench.Text
        }

        for category, cmdArray in AppSettings.commands_obj {
            if (category == "_comment")
                continue

            if (wb_filter != "" && wb_filter != "全部工作台" && category != wb_filter)
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
                    catId := this.TV_Alias.Add(category)
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
        this.LoadCommandTree(this.Edit_Search.Value)
    }

    static OnSearchFilter(CtrlObj, *) {
        val := CtrlObj.Value
        this.LoadCommandTree(val)
    }

    static OnClose(*) {
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

        this.Btn_Save.Opt("Hidden")

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

        this.Txt_CatVal.Value := info.category
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
            p.e.Value := hk
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
        this.Btn_Save.Move(, cur_y)
        this.Btn_Save.Opt("-Hidden")
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
            cmd["aliases"].Push(v)
        }

        cmd["hotkeys"] := []
        for e in this.hotkey_edits {
            v := Trim(e.Value)
            cmd["hotkeys"].Push(v)
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

    static OnAliasChange(idx, GuiCtrlObj, *) {
        p := this.alias_pool[idx]
        if (Trim(GuiCtrlObj.Value) != "")
            p.add.Opt("-Disabled")
        else
            p.add.Opt("+Disabled")
    }

    static OnHotkeyChange(idx, GuiCtrlObj, *) {
        p := this.hotkey_pool[idx]
        if (Trim(GuiCtrlObj.Value) != "")
            p.add.Opt("-Disabled")
        else
            p.add.Opt("+Disabled")
    }

    static SaveCurrentItem(*) {
        this.SaveInputsToCurrentCmd()

        ; 仅在最终保存时过滤掉空字符串，防止写入 JSON
        itemId := this.TV_Alias.GetSelection()
        if (itemId && this.TV_Map.Has(itemId) && this.TV_Map[itemId].type == "Item") {
            cmd := this.TV_Map[itemId].cmd

            clean_aliases := []
            for v in cmd["aliases"]
                if (v != "")
                    clean_aliases.Push(v)
            cmd["aliases"] := clean_aliases

            clean_hotkeys := []
            for v in cmd["hotkeys"]
                if (v != "")
                    clean_hotkeys.Push(v)
            cmd["hotkeys"] := clean_hotkeys
        }

        this.FlushCommandsJson()

        ; 触发内存重建
        AppSettings.Init()

        ; 刷新界面
        this.LoadCommandTree(this.Edit_Search.Value)
        MsgBox("保存成功！别名与快捷键已热更新生效。", "UCLC", "Iconi T2")
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

    static OnGetCommandsFromCatia(*) {
        MsgBox("Stage 3 功能预留: 将向 CATIA 发送 c:Workshop Exposition 命令", "UCLC", "Iconi")
    }

    static OnReadExportedTxt(*) {
        MsgBox("Stage 3 功能预留: 将弹出 FileSelect 并解析文件", "UCLC", "Iconi")
    }

    static OnFilterAll(ctrl, *) {
        state := ctrl.Value
        this.chk_filterNew.Value := state
        this.chk_filterUpdate.Value := state
        this.chk_filterOverwrite.Value := state
        this.chk_filterSame.Value := state
        this.chk_filterDelete.Value := state
        this.chk_filterIgnore.Value := state
    }

    static UpdateFilterAllState() {
        if (this.chk_filterNew.Value && this.chk_filterUpdate.Value && this.chk_filterOverwrite.Value && this.chk_filterSame
            .Value && this.chk_filterDelete.Value && this.chk_filterIgnore.Value)
            this.chk_filterAll.Value := 1
        else
            this.chk_filterAll.Value := 0
    }

    static OnFilterNew(*) {
        this.UpdateFilterAllState()
    }
    static OnFilterUpdate(*) {
        this.UpdateFilterAllState()
    }
    static OnFilterOverwrite(*) {
        this.UpdateFilterAllState()
    }
    static OnFilterSame(*) {
        this.UpdateFilterAllState()
    }
    static OnFilterDelete(*) {
        this.UpdateFilterAllState()
    }
    static OnFilterIgnore(*) {
        this.UpdateFilterAllState()
    }

    static OnImportListViewClick(ctrl, item, *) {
    }
    static OnImportListViewDoubleClick(ctrl, item, *) {
    }
    static OnImportListViewContextMenu(ctrl, item, isRightClick, X, Y) {
    }

    static OnResetImportView(*) {
    }

    static OnAddTargetWorkbench(ctrl, *) {
    }

    static OnMarkItemsToDelete(*) {
    }

    static OnMarkItemsToIgnore(*) {
    }

    static OnApplyImportAll(*) {
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
