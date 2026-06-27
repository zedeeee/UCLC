#Requires AutoHotkey v2.0
#Include AppSettings.ahk

ShowSettingsGUI(*) {
    UCLC_CUI.Show()
}

class UCLC_CUI {
    static GuiObj := ""
    static TV_Alias := ""
    static TV_Map := Map()
    static Edit_AliasKey := ""
    static Edit_AliasVal := ""
    static Text_Category := ""

    static Show() {
        if (this.GuiObj) {
            WinActivate(this.GuiObj.Hwnd)
            return
        }

        this.GuiObj := Gui("+Resize", "UCLC 配置管理控制台 (CUI)")
        this.GuiObj.OnEvent("Close", (*) => this.GuiObj := "")

        Tabs := this.GuiObj.Add("Tab3", "x10 y10 w780 h580", ["别名与快捷键 (Aliases & Hotkeys)", "通用设置 (General)"])

        ; =============== 第一页: 别名与快捷键 ===============
        Tabs.UseTab(1)
        this.GuiObj.Add("Text", "x30 y50 w200", "命令列表树 (类别 -> 别名):")
        this.TV_Alias := this.GuiObj.Add("TreeView", "x30 y70 w250 h480")
        this.TV_Alias.OnEvent("ItemSelect", ObjBindMethod(this, "OnAliasTreeSelect"))

        ; 右侧详情编辑区
        this.GuiObj.Add("GroupBox", "x300 y60 w460 h490", "详细属性与编辑")

        this.GuiObj.Add("Text", "x320 y90 w80", "所属类别:")
        this.Text_Category := this.GuiObj.Add("Text", "x400 y90 w340 cBlue", "-")

        this.GuiObj.Add("Text", "x320 y140 w80", "触发别名:")
        this.Edit_AliasKey := this.GuiObj.Add("Edit", "x400 y136 w340")

        this.GuiObj.Add("Text", "x320 y190 w80", "映射命令:")
        this.Edit_AliasVal := this.GuiObj.Add("Edit", "x400 y186 w340", "")
        this.GuiObj.Add("Text", "x400 y215 w340 cGray", "例如: c:Center graph (原生命令) 或 a:Action_Rotate (外部动作)")

        ; 保存当前项按钮
        btn_save := this.GuiObj.Add("Button", "x400 y260 w100", "✔ 保存修改")
        btn_save.OnEvent("Click", ObjBindMethod(this, "SaveCurrentItem"))

        ; 删除当前项按钮
        btn_del := this.GuiObj.Add("Button", "x520 y260 w100", "✖ 删除选定项")
        btn_del.OnEvent("Click", ObjBindMethod(this, "DeleteCurrentItem"))

        ; 新增按钮 (可以在当前选中的分类下新增)
        btn_add := this.GuiObj.Add("Button", "x640 y260 w100", "➕ 新增别名")
        btn_add.OnEvent("Click", ObjBindMethod(this, "AddNewItem"))


        ; =============== 第二页: 通用设置 ===============
        Tabs.UseTab(2)
        this.GuiObj.Add("GroupBox", "x30 y50 w740 h150", "Everything 快速启动集成")
        
        this.Chk_Everything := this.GuiObj.Add("Checkbox", "x50 y80", "启用“双击右Ctrl”呼出 Everything")
        this.Chk_Everything.Value := AppSettings.Everything_Enabled

        this.GuiObj.Add("Text", "x50 y120 w80", "主程序路径:")
        this.Edit_EverythingPath := this.GuiObj.Add("Edit", "x130 y116 w450", AppSettings.Everything_Path)
        
        btn_browse := this.GuiObj.Add("Button", "x600 y115 w80", "浏览...")
        btn_browse.OnEvent("Click", ObjBindMethod(this, "BrowseEverything"))

        btn_saveGen := this.GuiObj.Add("Button", "x600 y160 w150 Default", "保存通用设置")
        btn_saveGen.OnEvent("Click", ObjBindMethod(this, "SaveGeneralSettings"))

        ; =============== 初始化数据加载 ===============
        Tabs.UseTab()
        this.LoadAliasTree()
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
            ; 检查 JSON 对象中是否有 Everything
            if !AppSettings.config_obj.Has("Everything") {
                AppSettings.config_obj["Everything"] := Map("Enabled", "0", "Path", "")
            }
            AppSettings.config_obj["Everything"]["Enabled"] := String(this.Chk_Everything.Value)
            AppSettings.config_obj["Everything"]["Path"] := this.Edit_EverythingPath.Value

            ; 更新 AppSettings 内存并保存到文件
            AppSettings.Everything_Enabled := this.Chk_Everything.Value
            AppSettings.Everything_Path := this.Edit_EverythingPath.Value
            
            FileDelete(AppSettings.config_json_path)
            FileAppend(JSON.stringify(AppSettings.config_obj), AppSettings.config_json_path, "UTF-8")
            
            MsgBox("通用设置保存成功！", "UCLC", "Iconi T2")
        } catch as e {
            MsgBox("保存失败: " e.Message, "错误", 16)
        }
    }

    static LoadAliasTree() {
        this.TV_Alias.Delete()
        this.TV_Map.Clear()
        
        for category, items in AppSettings.alias_obj {
            if (category == "_comment")
                continue

            catId := this.TV_Alias.Add(category)
            this.TV_Map[catId] := {type: "Category", name: category}
            
            if (items is Map) {
                for key, val in items {
                    if (key == "_comment")
                        continue
                    itemId := this.TV_Alias.Add(key, catId)
                    this.TV_Map[itemId] := {type: "Item", category: category, key: key, val: val}
                }
            }
        }
    }

    static OnAliasTreeSelect(GuiCtrlObj, Item) {
        if (!this.TV_Map.Has(Item))
            return
            
        info := this.TV_Map[Item]
        if (info.type == "Item") {
            this.Text_Category.Text := info.category
            this.Edit_AliasKey.Value := info.key
            this.Edit_AliasVal.Value := info.val
        } else {
            this.Text_Category.Text := info.name
            this.Edit_AliasKey.Value := ""
            this.Edit_AliasVal.Value := ""
        }
    }

    static SaveCurrentItem(*) {
        itemId := this.TV_Alias.GetSelection()
        if (!itemId || !this.TV_Map.Has(itemId)) {
            MsgBox("请先在左侧选择要保存的项。", "提示", "Icon!")
            return
        }

        info := this.TV_Map[itemId]
        newKey := Trim(this.Edit_AliasKey.Value)
        newVal := Trim(this.Edit_AliasVal.Value)

        if (info.type == "Item") {
            if (newKey == "" || newVal == "") {
                MsgBox("别名和命令映射均不能为空！", "提示", "Iconx")
                return
            }
            
            category := info.category
            oldKey := info.key

            ; 更新 AppSettings 内存树
            if (oldKey != newKey) {
                AppSettings.alias_obj[category].Delete(oldKey)
            }
            AppSettings.alias_obj[category][newKey] := newVal

            this.FlushAliasJson()

            ; 刷新界面
            this.LoadAliasTree()
            MsgBox("保存并热重载成功！", "UCLC", "Iconi T2")
        } else {
            MsgBox("请选择一个具体的别名子项进行修改。", "提示", "Icon!")
        }
    }

    static AddNewItem(*) {
        itemId := this.TV_Alias.GetSelection()
        category := ""

        if (itemId && this.TV_Map.Has(itemId)) {
            info := this.TV_Map[itemId]
            category := (info.type == "Category") ? info.name : info.category
        } else {
            ; 默认加到第一个分类下
            for k, v in AppSettings.alias_obj {
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

        newKey := "新别名"
        newVal := "c:命令名"

        if (!AppSettings.alias_obj.Has(category))
            AppSettings.alias_obj[category] := Map()
            
        AppSettings.alias_obj[category][newKey] := newVal
        this.FlushAliasJson()
        this.LoadAliasTree()
    }

    static DeleteCurrentItem(*) {
        itemId := this.TV_Alias.GetSelection()
        if (!itemId || !this.TV_Map.Has(itemId))
            return

        info := this.TV_Map[itemId]
        if (info.type == "Item") {
            if (MsgBox("确定要删除别名 [" info.key "] 吗？", "确认删除", "YesNo Icon?") == "Yes") {
                AppSettings.alias_obj[info.category].Delete(info.key)
                this.FlushAliasJson()
                this.LoadAliasTree()
            }
        }
    }

    static FlushAliasJson() {
        try {
            FileDelete(AppSettings.alias_json_path)
            FileAppend(JSON.stringify(AppSettings.alias_obj), AppSettings.alias_json_path, "UTF-8")
        } catch as e {
            MsgBox("写入 JSON 文件失败: " e.Message, "错误", 16)
        }
    }
}
