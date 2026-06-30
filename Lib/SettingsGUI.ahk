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

    static Show() {
        if (this.GuiObj) {
            WinActivate(this.GuiObj.Hwnd)
            return
        }

        ; 每次打开设置面板前强制从硬盘重载，丢弃一切未保存的内存脏数据
        AppSettings.Init()

        this.GuiObj := Gui("-Resize -MaximizeBox", "UCLC 配置管理控制台 (CUI)")
        this.GuiObj.OnEvent("Close", ObjBindMethod(this, "OnClose"))

        this.Tabs := this.GuiObj.Add("Tab3", "x10 y10 w780 h580", ["命令映射 (Commands)", "通用设置 (General)"])

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
            
            this.alias_pool.Push({e: e, add: btn_add, del: btn_del})
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
            
            this.hotkey_pool.Push({e: e, add: btn_add, del: btn_del})
        }
        
        this.Btn_Save := this.GuiObj.Add("Button", "x400 y0 w120 h35 Hidden", "✔ 保存映射修改")
        this.Btn_Save.OnEvent("Click", ObjBindMethod(this, "SaveCurrentItem"))
        
        this.Btn_DelItem := this.GuiObj.Add("Button", "x530 y0 w120 h35 Hidden", "✖ 删除此命令")
        this.Btn_DelItem.OnEvent("Click", ObjBindMethod(this, "DeleteCurrentItem"))
        this.Tabs.UseTab()
        
        ; 新增命令按钮放在树下面
        btn_add := this.GuiObj.Add("Button", "x30 y550 w250 h30", "➕ 在所选工作台下新增命令")
        btn_add.OnEvent("Click", ObjBindMethod(this, "AddNewItem"))

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
        btn_reload.OnEvent("Click", (*) => Reload())

        ; =============== 初始化数据加载 ===============
        this.Tabs.UseTab()
        this.LoadCommandTree()
        this.GuiObj.Show("w800 h600")
    }

    static BrowseEverything(*) {
        this.GuiObj.Opt("+Disabled")
        path := FileSelect(,, "请选择 Everything.exe", "程序 (*.exe)")
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
                display_name := (cmd.Has("desc") && cmd["desc"] != "") ? cmd["desc"] : (cmd.Has("command") ? cmd["command"] : "未知")
                
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
                    this.TV_Map[catId] := {type: "Category", name: category}
                }
                
                itemId := this.TV_Alias.Add(display_name, catId)
                this.TV_Map[itemId] := {type: "Item", category: category, index: index, cmd: cmd}
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
        this.Btn_DelItem.Opt("Hidden")
        
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
        
        this.Btn_DelItem.Move(, cur_y)
        this.Btn_DelItem.Opt("-Hidden")
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

    static AddNewItem(*) {
        itemId := this.TV_Alias.GetSelection()
        category := ""

        if (itemId && this.TV_Map.Has(itemId)) {
            info := this.TV_Map[itemId]
            category := (info.type == "Category") ? info.name : info.category
        } else {
            for k, v in AppSettings.commands_obj {
                if k != "_comment" {
                    category := k
                    break
                }
            }
        }

        if (category == "") {
            MsgBox("找不到可用的分类类别。", "错误", 16)
            return
        }

        newCmd := Map("command", "NEW_COMMAND_HDR", "desc", "新功能", "aliases", [], "hotkeys", [])

        if (!AppSettings.commands_obj.Has(category))
            AppSettings.commands_obj[category] := []
            
        AppSettings.commands_obj[category].Push(newCmd)
        this.FlushCommandsJson()
        this.LoadCommandTree(this.Edit_Search.Value)
    }

    static DeleteCurrentItem(*) {
        itemId := this.TV_Alias.GetSelection()
        if (!itemId || !this.TV_Map.Has(itemId))
            return

        info := this.TV_Map[itemId]
        if (info.type == "Item") {
            if (MsgBox("确定要删除整个命令动作（包含所有绑定的别名与快捷键）吗？", "确认删除", "YesNo Icon?") == "Yes") {
                AppSettings.commands_obj[info.category].RemoveAt(info.index)
                this.FlushCommandsJson()
                this.LoadCommandTree(this.Edit_Search.Value)
                this.ClearRightPane()
            }
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
}
