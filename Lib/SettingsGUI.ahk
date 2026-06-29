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
    
    static right_controls := []
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

        this.GuiObj := Gui("+Resize", "UCLC 配置管理控制台 (CUI)")
        this.GuiObj.OnEvent("Close", ObjBindMethod(this, "OnClose"))

        this.Tabs := this.GuiObj.Add("Tab3", "x10 y10 w780 h580", ["命令映射 (Commands)", "通用设置 (General)"])

        ; =============== 第一页: 命令映射 ===============
        this.Tabs.UseTab(1)
        this.GuiObj.Add("Text", "x30 y50 w200", "命令列表树 (类别 -> 功能):")
        
        ; 增加一个搜索框
        this.GuiObj.Add("Text", "x30 y70 w40", "搜索:")
        search_edit := this.GuiObj.Add("Edit", "x70 y66 w210")
        search_edit.OnEvent("Change", ObjBindMethod(this, "OnSearchFilter"))
        this.Edit_Search := search_edit

        this.TV_Alias := this.GuiObj.Add("TreeView", "x30 y95 w250 h455")
        this.TV_Alias.OnEvent("ItemSelect", ObjBindMethod(this, "OnCommandTreeSelect"))

        ; 右侧详情编辑区框
        this.GuiObj.Add("GroupBox", "x300 y60 w460 h490", "详细属性与动态编辑")
        
        ; 新增命令按钮放在树下面
        btn_add := this.GuiObj.Add("Button", "x30 y555 w250 h30", "➕ 在所选分类下新增命令")
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
        
        for category, cmdArray in AppSettings.commands_obj {
            if (category == "_comment")
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
    
    static OnSearchFilter(CtrlObj, *) {
        val := CtrlObj.Value
        this.LoadCommandTree(val)
    }

    static OnClose(*) {
        this.right_controls := []
        this.alias_edits := []
        this.hotkey_edits := []
        this.GuiObj := ""
    }

    static ClearRightPane() {
        for ctrl in this.right_controls {
            if IsObject(ctrl) {
                try {
                    DllCall("DestroyWindow", "Ptr", ctrl.Hwnd)
                }
            }
        }
        this.right_controls := []
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
            
        this.Tabs.UseTab(1)
        cmd := info.cmd
        
        c := this.GuiObj.Add("Text", "x320 y80 w80", "所属类别:")
        this.right_controls.Push(c)
        c := this.GuiObj.Add("Text", "x400 y80 w340 cBlue", info.category)
        this.right_controls.Push(c)
        
        c := this.GuiObj.Add("Text", "x320 y110 w80", "功能描述:")
        this.right_controls.Push(c)
        this.Edit_Desc := this.GuiObj.Add("Edit", "x400 y106 w340", cmd.Has("desc") ? cmd["desc"] : "")
        this.right_controls.Push(this.Edit_Desc)
        
        c := this.GuiObj.Add("Text", "x320 y140 w80", "执行命令:")
        this.right_controls.Push(c)
        this.Edit_Cmd := this.GuiObj.Add("Edit", "x400 y136 w340", cmd.Has("command") ? cmd["command"] : "")
        this.right_controls.Push(this.Edit_Cmd)
        
        cur_y := 180
        
        ; 别名区
        c := this.GuiObj.Add("Text", "x320 y" cur_y " w80", "触发别名:")
        this.right_controls.Push(c)
        
        aliases := cmd.Has("aliases") ? cmd["aliases"] : []
        if (aliases.Length == 0)
            aliases := [""]
            
        for idx, al in aliases {
            e := this.GuiObj.Add("Edit", "x400 y" (cur_y - 4) " w120", al)
            this.right_controls.Push(e)
            this.alias_edits.Push(e)
            
            btn_add := this.GuiObj.Add("Button", "x530 y" (cur_y - 5) " w30 h24", "➕")
            btn_add.OnEvent("Click", ObjBindMethod(this, "OnAddAlias", idx))
            this.right_controls.Push(btn_add)
            
            btn_del := this.GuiObj.Add("Button", "x565 y" (cur_y - 5) " w30 h24", "➖")
            btn_del.OnEvent("Click", ObjBindMethod(this, "OnDelAlias", idx))
            this.right_controls.Push(btn_del)
            
            cur_y += 30
        }
        
        cur_y += 10
        
        ; 快捷键区
        c := this.GuiObj.Add("Text", "x320 y" cur_y " w80", "触发快捷键:")
        this.right_controls.Push(c)
        
        hotkeys := cmd.Has("hotkeys") ? cmd["hotkeys"] : []
        if (hotkeys.Length == 0)
            hotkeys := [""]
            
        for idx, hk in hotkeys {
            e := this.GuiObj.Add("Edit", "x400 y" (cur_y - 4) " w120", hk)
            this.right_controls.Push(e)
            this.hotkey_edits.Push(e)
            
            btn_add := this.GuiObj.Add("Button", "x530 y" (cur_y - 5) " w30 h24", "➕")
            btn_add.OnEvent("Click", ObjBindMethod(this, "OnAddHotkey", idx))
            this.right_controls.Push(btn_add)
            
            btn_del := this.GuiObj.Add("Button", "x565 y" (cur_y - 5) " w30 h24", "➖")
            btn_del.OnEvent("Click", ObjBindMethod(this, "OnDelHotkey", idx))
            this.right_controls.Push(btn_del)
            
            cur_y += 30
        }
        
        cur_y += 30
        btn_save := this.GuiObj.Add("Button", "x400 y" cur_y " w120 h35", "✔ 保存映射修改")
        btn_save.OnEvent("Click", ObjBindMethod(this, "SaveCurrentItem"))
        this.right_controls.Push(btn_save)
        
        btn_del_item := this.GuiObj.Add("Button", "x530 y" cur_y " w120 h35", "✖ 删除此命令")
        btn_del_item.OnEvent("Click", ObjBindMethod(this, "DeleteCurrentItem"))
        this.right_controls.Push(btn_del_item)
        
        this.Tabs.UseTab()
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

    static SaveCurrentItem(*) {
        this.SaveInputsToCurrentCmd()
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
