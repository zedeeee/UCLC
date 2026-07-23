#Requires AutoHotkey v2.0

#Include "JSON.ahk"
#Include "Version.ahk"
#Include "UCLC_System.ahk"

;-==== [ 原模块: AppSettings.ahk ] ====-
class AppSettings {
    static config_json_path := ""
    static commands_json_path := ""

    static config_obj := Map()
    static commands_obj := Map()
    static alias_obj := Map()
    static hotkey_obj := Map()

    static alias_ini_path := ""
    static hotkey_ini_path := ""

    static DEBUG_I := ""
    static workbench_list := Map()
    static current_workbench := ""
    static Everything_Enabled := 0
    static AutoIME_Enabled := 1
    static Version := UCLC_VERSION
    static Everything_Path := ""
    
    static workbench_mapping := Map()

    static LoadWorkbenchMapping() {
        mapping_file := A_ScriptDir "\data\workbench_mapping.json"
        if FileExist(mapping_file) {
            try {
                text := FileRead(mapping_file, "UTF-8")
                parsed := JSON.parse(text)
                this.workbench_mapping := parsed.Has("mapping") ? parsed["mapping"] : parsed
            } catch {
                this.workbench_mapping := Map()
            }
        } else {
            this.workbench_mapping := Map()
        }
    }

    static GetWbName(id, lang := "Simplified_Chinese") {
        if this.workbench_mapping.Has(id) {
            if this.workbench_mapping[id].Has(lang) {
                return this.workbench_mapping[id][lang]
            }
            if this.workbench_mapping[id].Has("English") {
                return this.workbench_mapping[id]["English"]
            }
        }
        return id
    }

    static GetWbIdByUI(name) {
        ; 解决 CATIA 多工作台同名（如 Drafting 背景和主工作台都叫“工程制图”）导致反查 ID 不准的问题
        static canonical_map := Map(
            "工程制图", "CATDrwDrwWkb",
            "Drafting", "CATDrwDrwWkb",
            "零件设计", "CATPcfPartWkb",
            "Part Design", "CATPcfPartWkb"
        )
        if canonical_map.Has(name) {
            return canonical_map[name]
        }

        for id, langs in this.workbench_mapping {
            for lang, val in langs {
                if (val == name) {
                    return id
                }
            }
        }
        return name
    }

    static Init() {
        this.config_json_path := A_ScriptDir "\config.json"

        ; 只要发现 config.ini 就将其值合并更新到 config.json
        if (FileExist(A_ScriptDir "\config.ini")) {
            ConfigMigrator.MigrateIniToJson(A_ScriptDir "\config.ini", this.config_json_path)
        }

        ; 读取全局配置
        if (FileExist(this.config_json_path)) {
            text := FileRead(this.config_json_path, "UTF-8")
            this.config_obj := JSON.parse(text)
        } else {
            this.config_obj := Map(
                "通用", Map("DEBUG", "0"),
                "UserConf", Map("命令配置", "commands.json"),
                "Everything", Map("Enabled", "0", "Path", ""),
                "AutoIME", Map(
                    "AUTOCAD", "ACAD.exe",
                    "CATIA", "CNEXT.exe"
                )
            )
            FileAppend(JSON.stringify(this.config_obj), this.config_json_path, "UTF-8")
        }

        commands_file := "commands.json"

        if (this.config_obj.Has("UserConf") && this.config_obj["UserConf"].Has("命令配置")) {
            commands_file := this.config_obj["UserConf"]["命令配置"]
        }

        this.commands_json_path := A_ScriptDir "\user-config\" commands_file

        ; 检查并迁移 V2 INI
        alias_name := "alias.ini"
        hotkey_name := "hotkey.ini"
        
        if (this.config_obj.Has("UserConf")) {
            if (this.config_obj["UserConf"].Has("用户别名"))
                alias_name := this.config_obj["UserConf"]["用户别名"]
            if (this.config_obj["UserConf"].Has("快捷键"))
                hotkey_name := this.config_obj["UserConf"]["快捷键"]
        }

        if (alias_name = "alias.ini" && FileExist(A_ScriptDir "\config.ini")) {
            try alias_name := IniRead(A_ScriptDir "\config.ini", "UserConf", "用户别名", "alias.ini")
            try hotkey_name := IniRead(A_ScriptDir "\config.ini", "UserConf", "快捷键", "hotkey.ini")
        }
        
        ; 剥离可能带有的 .json 后缀，因为这里是为了找原始 ini
        alias_name := StrReplace(alias_name, ".json", ".ini")
        hotkey_name := StrReplace(hotkey_name, ".json", ".ini")

        this.alias_ini_path := A_ScriptDir "\user-config\" alias_name
        this.hotkey_ini_path := A_ScriptDir "\user-config\" hotkey_name
        
        this.LoadWorkbenchMapping()
        
        if (!FileExist(this.commands_json_path) && (FileExist(this.alias_ini_path) || FileExist(this.hotkey_ini_path))) {
            ConfigMigrator.MigrateV2IniToCommandsJson(this.alias_ini_path, this.hotkey_ini_path, this.commands_json_path)
        }

        ; 载入 JSON 到内存树
        if (FileExist(this.commands_json_path)) {
            this.commands_obj := JSON.parse(FileRead(this.commands_json_path, "UTF-8"))
        } else {
            this.commands_obj := Map()
        }
        
        ; 自动升维（迁移）：将旧版中文名的 Key 替换为 Internal ID
        migrated := false
        new_commands_obj := Map()
        for k, v in this.commands_obj {
            if (k == "_comment") {
                new_commands_obj[k] := v
                continue
            }
            id := this.GetWbIdByUI(k)
            if (id != k) {
                migrated := true
            }
            new_commands_obj[id] := v
        }

        if (migrated) {
            this.commands_obj := new_commands_obj
            try {
                if FileExist(this.commands_json_path)
                    FileDelete(this.commands_json_path)
                FileAppend(JSON.stringify(this.commands_obj), this.commands_json_path, "UTF-8")
            }
        }

        ; 内存反向映射，向下兼容核心执行引擎
        this.alias_obj := Map()
        this.hotkey_obj := Map()

        for wb, cmdArray in this.commands_obj {
            this.alias_obj[wb] := Map()
            this.hotkey_obj[wb] := Map()
            
            for cmd in cmdArray {
                if (cmd.Has("aliases")) {

                    for alias in cmd["aliases"] {
                        this.alias_obj[wb][alias] := cmd
                    }
                }
                if (cmd.Has("hotkeys")) {
                    for hotkey in cmd["hotkeys"] {
                        this.hotkey_obj[wb][hotkey] := cmd
                    }
                }
            }
        }

        ; 读取常规设置
        this.DEBUG_I := this.config_obj.Has("通用") && this.config_obj["通用"].Has("DEBUG") ? this.config_obj["通用"]["DEBUG"
            ] : 0
        this.Everything_Enabled := this.config_obj.Has("Everything") && this.config_obj["Everything"].Has("Enabled") ?
            this.config_obj["Everything"]["Enabled"] : 0
        this.Everything_Path := this.config_obj.Has("Everything") && this.config_obj["Everything"].Has("Path") ? this.config_obj[
            "Everything"]["Path"] : ""
        this.AutoIME_Enabled := this.config_obj.Has("AutoIME") && this.config_obj["AutoIME"].Has("Enabled") ?
            this.config_obj["AutoIME"]["Enabled"] : 1

        ; 初始化工作台列表
        this.workbench_list := Map()
        if (this.hotkey_obj != "") {
            for wb, _ in this.hotkey_obj {
                this.workbench_list[wb] := ""
            }
        }

        this.current_workbench := ""
    }
}

;-==== [ 原模块: ConfigMigrator.ahk ] ====-
class ConfigMigrator {
    /**
     * 将指定的 INI 文件静默转换为 JSON 文件，并将旧文件备份（用于 config.ini）
     * @param ini_path 原始 ini 路径
     * @param json_path 新的 json 路径
     * @returns {Integer} 1 表示成功迁移，0 表示未进行迁移或失败
     */
    static MigrateIniToJson(ini_path, json_path) {
        if (!FileExist(ini_path))
            return 0
        
        try {
            json_obj := Map()
            
            ; 如果已有 json，先读入内存
            if FileExist(json_path) {
                try {
                    text := FileRead(json_path, "UTF-8")
                    json_obj := JSON.parse(text)
                }
            }
            
            sections_str := IniRead(ini_path)
            if (sections_str == "")
                return 0
                
            loop parse sections_str, "`n", "`r" {
                section := A_LoopField
                if !json_obj.Has(section)
                    json_obj[section] := Map()
                
                keys_str := IniRead(ini_path, section)
                loop parse keys_str, "`n", "`r" {
                    eq_pos := InStr(A_LoopField, "=")
                    if (eq_pos > 0) {
                        key := Trim(SubStr(A_LoopField, 1, eq_pos - 1))
                        val := Trim(SubStr(A_LoopField, eq_pos + 1))
                        
                        comment := ""
                        semicolon_pos := InStr(val, ";")
                        if (semicolon_pos > 0) {
                            comment := Trim(SubStr(val, semicolon_pos + 1))
                            val := Trim(SubStr(val, 1, semicolon_pos - 1))
                        }
                        
                        json_obj[section][key] := val
                    }
                }
            }
            
            ; 针对 config.ini 转换出的 config.json，增加新的 commands.json 指向，但保留旧有参数
            if (json_obj.Has("UserConf")) {
                json_obj["UserConf"]["命令配置"] := "commands.json"
            }
            
            ; 格式化写入 JSON (UTF-8)
            json_str := JSON.stringify(json_obj)
            
            ; 写入前如果有旧的先删除
            if FileExist(json_path)
                FileDelete(json_path)
                
            FileAppend(json_str, json_path, "UTF-8")
            
            ; 迁移完毕后备份，防止未来启动时不断覆盖用户在 GUI 中的修改
            bak_path := ini_path . ".bak"
            if FileExist(bak_path) {
                index := 1
                while FileExist(bak_path . "." index)
                    index++
                bak_path := bak_path . "." index
            }
            FileMove(ini_path, bak_path, true)
            
            return 1
        }
        catch as e {
            try {
                Logger.info("ConfigMigrator 迁移失败: " . e.Message)
            }
            return 0
        }
    }

    /**
     * 从 V2 的 alias.ini 和 hotkey.ini 合并迁移到 commands.json (Array 结构)
     */
    static MigrateV2IniToCommandsJson(alias_ini, hotkey_ini, commands_json) {
        if (!FileExist(alias_ini) && !FileExist(hotkey_ini))
            return 0
            
        try {
            commands_obj := Map()

            ParseIniAndMerge(ini_path, is_hotkey) {
                if (!FileExist(ini_path))
                    return
                
                sections_str := IniRead(ini_path)
                if (sections_str == "")
                    return
                    
                loop parse sections_str, "`n", "`r" {
                    section := A_LoopField
                    section_id := AppSettings.GetWbIdByUI(section)
                    if !commands_obj.Has(section_id)
                        commands_obj[section_id] := []
                        
                    keys_str := IniRead(ini_path, section)
                    loop parse keys_str, "`n", "`r" {
                        eq_pos := InStr(A_LoopField, "=")
                        if (eq_pos > 0) {
                            trigger := Trim(SubStr(A_LoopField, 1, eq_pos - 1))
                            val := Trim(SubStr(A_LoopField, eq_pos + 1))
                            
                            comment := ""
                            semicolon_pos := InStr(val, ";")
                            if (semicolon_pos > 0) {
                                comment := Trim(SubStr(val, semicolon_pos + 1))
                                val := Trim(SubStr(val, 1, semicolon_pos - 1))
                            }
                            
                            clean_val := StrReplace(Trim(val), "&", ",")
                            params := StrSplit(clean_val, ",")
                            
                            cmd := Trim(params[1], " `t")
                            cb := params.Length > 1 ? Trim(params[2], " `t") : ""
                            args_arr := []
                            if (params.Length > 2) {
                                Loop params.Length - 2 {
                                    args_arr.Push(Trim(params[A_Index + 2], " `t"))
                                }
                            }
                            
                            ; 查找同类动作是否已存在
                            found_idx := 0
                            for idx, item in commands_obj[section_id] {
                                if (item.Has("command") && item["command"] == cmd) {
                                    item_cb := item.Has("callback") ? item["callback"] : ""
                                    if (item_cb != cb)
                                        continue
                                        
                                    item_args := item.Has("args") ? item["args"] : []
                                    if (item_args.Length != args_arr.Length)
                                        continue
                                    args_match := true
                                    Loop args_arr.Length {
                                        if (item_args[A_Index] != args_arr[A_Index]) {
                                            args_match := false
                                            break
                                        }
                                    }
                                    if (!args_match)
                                        continue
                                        
                                    found_idx := idx
                                    break
                                }
                            }
                            
                            if (found_idx > 0) {
                                target := commands_obj[section_id][found_idx]
                            } else {
                                target := Map("command", cmd, "aliases", [], "hotkeys", [])
                                if (cb != "")
                                    target["callback"] := cb
                                if (args_arr.Length > 0)
                                    target["args"] := args_arr
                                commands_obj[section_id].Push(target)
                            }
                            
                            if (comment != "" && !target.Has("desc"))
                                target["desc"] := comment
                                
                            if (is_hotkey) {
                                exists := false
                                for existing in target["hotkeys"] {
                                    if (existing == trigger) {
                                        exists := true
                                        break
                                    }
                                }
                                if (!exists)
                                    target["hotkeys"].Push(trigger)
                            } else {
                                exists := false
                                for existing in target["aliases"] {
                                    if (existing == trigger) {
                                        exists := true
                                        break
                                    }
                                }
                                if (!exists)
                                    target["aliases"].Push(trigger)
                            }
                        }
                    }
                }
            }

            ParseIniAndMerge(alias_ini, false)
            ParseIniAndMerge(hotkey_ini, true)
            
            json_str := JSON.stringify(commands_obj)
            if FileExist(commands_json)
                FileDelete(commands_json)
            FileAppend(json_str, commands_json, "UTF-8")
            ; 备份原文件
            if FileExist(alias_ini) {
                bak_path := alias_ini . ".bak"
                if FileExist(bak_path) {
                    index := 1
                    while FileExist(bak_path . "." index)
                        index++
                    bak_path := bak_path . "." index
                }
                FileMove(alias_ini, bak_path, true)
            }
            
            if FileExist(hotkey_ini) {
                bak_path := hotkey_ini . ".bak"
                if FileExist(bak_path) {
                    index := 1
                    while FileExist(bak_path . "." index)
                        index++
                    bak_path := bak_path . "." index
                }
                FileMove(hotkey_ini, bak_path, true)
            }
                
            return 1
        }
        catch as e {
            try {
                Logger.info("ConfigMigrator 迁移 commands 失败: " . e.Message)
            }
            return 0
        }
    }
}



class CATIAWindow {
    static catia_window_classnn_map := Map(
        "R21", "Afx:",
        "R27", "Afx:",
        "R30", "CATDlgDocument"
    )

    static is_catia_exe_and_title(obj) {
        if (StrLower(obj.exe) == "cnext.exe" and StrUpper(SubStr(obj.title, 1, 8)) == "CATIA V5") {
            return true
        }
        return false
    }

    static is_included_catia_class(obj) {
        test_class := obj.class
        for _, value in this.catia_window_classnn_map {
            if (SubStr(test_class, 1, StrLen(value)) == value) {
                return true
            }
        }
        return false
    }

    static identify_window(hwnd := "A") {
        current_window := Object()
        try {
            current_window.title := WinGetTitle(hwnd)
            current_window.class := WinGetClass(hwnd)
            current_window.exe := WinGetProcessName(hwnd)
        }
        catch Error as err {
            Logger.info("对象获取失败")
            return false
        }

        if (this.is_catia_exe_and_title(current_window) and this.is_included_catia_class(current_window)) {
            Logger.info("CATIA窗口 获取成功")
            return current_window.class
        }
        Logger.info("未获取到CATIA窗口")
        return false
    }

    static get_power_input_edit_hwnd() {
        status_bar_hwnd := ControlGetHwnd("msctls_statusbar321")
        for ctrl in WinGetControls(status_bar_hwnd) {
            if InStr(StrLower(ctrl), "edit") {
                edit_hwnd := ControlGetHwnd(ctrl, status_bar_hwnd)
                return edit_hwnd
            }
        }
        return false
    }
}

class CATIAInstance {
    static instances := Map()

    __New(pid) {
        this.pid := pid
        this.hdr_cache := Map()
    }

    static get_instance(hwnd) {
        pid := WinGetPID(hwnd)
        if !this.instances.Has(pid)
            this.instances[pid] := CATIAInstance(pid)
        return this.instances[pid]
    }

    safe_send_enter(hwnd) {
        SendInput "{Blind}{vk07}{Alt Up}{Ctrl Up}{Shift Up}"
        Sleep 10
        ControlSend "{Blind}{Enter}", , "ahk_id " . hwnd
        Sleep 30
        if GetKeyState("Ctrl", "P")
            SendInput "{Blind}{Ctrl Down}"
        if GetKeyState("Shift", "P")
            SendInput "{Blind}{Shift Down}"
        if GetKeyState("Alt", "P")
            SendInput "{Blind}{Alt Down}"
    }

    handle_hdr_error() {
        pop_hwnd := WinGetID()
        str := WindowManager.get_window_text_fast(false)

        WinClose(pop_hwnd)
        WinWaitClose(pop_hwnd, , 2)

        loop parse, str, "`n", "`r" {
            if InStr(A_LoopField, "未知命令") {
                command := Trim(SubStr(A_LoopField, InStr(A_LoopField, "：") + 1))
                corrected := (SubStr(command, -3) = "Hdr")
                    ? SubStr(command, 1, StrLen(command) - 3)
                    : command . "Hdr"
                Logger.info("Hdr 修正: " . command . " → " . corrected)
                return corrected
            }
        }
        return ""
    }
}

class CommandEngine {
    static match_current_workbench(workbench_map) {
        try {
            workbench_control_hwnd := ControlGetHwnd("WebBrowser", "A")
            for button in WinGetControls(workbench_control_hwnd) {
                button_name := ControlGetText(button, workbench_control_hwnd)
                id := AppSettings.GetWbIdByUI(button_name)
                if workbench_map.Has(id) {
                    return id
                }
            }
            return "通用"
        }
        catch {
            active_hwnd := WinExist("A")
            MsgBox("无法识别当前工作台，请确保【工作台】工具栏是吸附状态", "UCLC 警告", "Icon! Owner" . active_hwnd)
            return "ERROR_NOT_DOCKED"
        }
    }

    static get_map_value_case_insensitive(m, key, &val) {
        if (Type(m) != "Map")
            return false
        if m.Has(key) {
            val := m[key]
            return true
        }
        for k, v in m {
            if StrCompare(k, key, false) == 0 {
                val := v
                return true
            }
        }
        return false
    }

    static process_config(config) {
        if (Type(config) != "Map")
            return []
        cmd := config.Get("command", "")
        if (cmd == "")
            return []
        result := [ cmd ]
        if (cb := config.Get("callback", "")) {
            result.Push(cb)
            if (Type(args := config.Get("args", "")) == "Array") {
                result.Push(args*)
            }
        }
        return result
    }

    static read_user_alias(dict_type, section, key) {
        target_obj := (dict_type == "alias") ? AppSettings.alias_obj : AppSettings.hotkey_obj
        try {
            Logger.info("调用 " section)
            if this.get_map_value_case_insensitive(target_obj, section, &section_map) {
                if this.get_map_value_case_insensitive(section_map, key, &config_val) {
                    return this.process_config(config_val)
                }
            }
            Logger.info("调用 通用")
            if this.get_map_value_case_insensitive(target_obj, "通用", &general_map) {
                if this.get_map_value_case_insensitive(general_map, key, &config_val) {
                    return this.process_config(config_val)
                }
            }
            Logger.tooltip(Format("没有找到与 '{1}' 对应的命令", key), 1000)
            return 0
        }
        catch Error as e {
            Logger.tooltip(Format("查找 '{1}' 出错: {2}", key, e.Message), 1000)
            return 0
        }
    }

    static execute(input_string, dict_type, power_input_hwnd) {
        current_workbench := this.match_current_workbench(AppSettings.workbench_list)
        if !current_workbench {
            return
        }

        command_id_and_cb_array := this.read_user_alias(dict_type, current_workbench, StrUpper(input_string))
        if !command_id_and_cb_array {
            Logger.tooltip(Format("没有找到与 '{1}' 对应的命令", input_string), 1000)
            return
        }

        instance := CATIAInstance.get_instance(power_input_hwnd)
        original_id := command_id_and_cb_array[1]
        command_id := instance.hdr_cache.Has(original_id) ? instance.hdr_cache[original_id] : original_id

        ControlSetText("c:" . command_id, power_input_hwnd)
        instance.safe_send_enter(power_input_hwnd)

        if (current_workbench == "创成式外形设计" && !instance.hdr_cache.Has(original_id)) {
            loop 50 {
                if (ControlGetText(power_input_hwnd) == "") {
                    break
                }
                if WinExist("超级输入消息 ahk_pid " . instance.pid) {
                    corrected_id := instance.handle_hdr_error()
                    if corrected_id {
                        instance.hdr_cache[original_id] := corrected_id
                        Logger.info("GSD分支: Hdr 修正成功 -> " . corrected_id)
                        ControlSetText("c:" . corrected_id, power_input_hwnd)
                        instance.safe_send_enter(power_input_hwnd)
                    }
                    break
                }
                Sleep 10
            }
        }

        if command_id_and_cb_array.Length >= 2 {
            params := []
            loop command_id_and_cb_array.Length - 2 {
                params.Push(command_id_and_cb_array[A_Index + 2])
            }
            callback_func := command_id_and_cb_array[2]
            if HasMethod(Utilities, callback_func) {
                Utilities.%callback_func%(params*)
            } else if IsSet(%callback_func%) {
                %callback_func%(params*)
            }
        }
    }

    static register_command(ThisHotkey) {
        edit_hwnd := CATIAWindow.get_power_input_edit_hwnd()
        this.execute(ThisHotkey, "hotkey", edit_hwnd)
    }
}

class Utilities {
    static read_all_section_from_ini(ini_path, dict) {
        section_array := StrSplit(IniRead(ini_path), "`n")
        for section in section_array {
            if !dict.Has(section) {
                dict.Set(section, "")
            }
        }
    }

    static export_workshop_exposition() {
        hwnd := WinExist("A")
        catia_class := CATIAWindow.identify_window(hwnd)
        if !catia_class {
            MsgBox("未检测到活动的 CATIA 窗口，请先激活 CATIA", "UCLC 提示", "Icon!")
            return false
        }

        power_input_hwnd := CATIAWindow.get_power_input_edit_hwnd()
        if !power_input_hwnd {
            MsgBox("未找到 CATIA 超级输入框", "UCLC 错误", "Iconx")
            return false
        }

        ControlSetText("c:Workshop Exposition", power_input_hwnd)
        instance := CATIAInstance.get_instance(power_input_hwnd)
        instance.safe_send_enter(power_input_hwnd)
        return true
    }

    static cat_auto_graph_tree_reorder() {
        GroupAdd "ReorderTree", "Graph tree reordering"
        GroupAdd "ReorderTree", "图形树重新排序"
        raw_lists_string := ""

        dialogbox_hwnd := WinWait("ahk_group ReorderTree", , 5)
        if dialogbox_hwnd == 0 {
            Exit
        }

        Listbox_items := ControlGetItems("ListBox1", dialogbox_hwnd)
        for item in Listbox_items {
            raw_lists_string .= item ","
        }

        sorted_lists_string := Sort(raw_lists_string, "D,")
        refrence_lists_array := StrSplit(SubStr(sorted_lists_string, 1, StrLen(sorted_lists_string) - 1), ',')

        listbox_classnn := "ListBox1"
        free_move_button := ControlGetHwnd("自由移动", dialogbox_hwnd)

        listbox_items := ControlGetItems(listbox_classnn, dialogbox_hwnd)

        loop listbox_items.Length {
            if (listbox_items[A_Index] == refrence_lists_array[A_Index]) {
                if (A_Index == listbox_items.Length) {
                    Logger.tooltip("已排序完成, 不用继续排序", 3000)
                    Sleep 1000
                    PostMessage(0x10, 0, , , dialogbox_hwnd)
                    Exit
                }
                continue
            }
            else {
                break
            }
        }

        try {
            refrence_item_index := 0
            for item in refrence_lists_array {
                refrence_item_index += 1
                ControlChooseString(refrence_lists_array[A_Index], listbox_classnn, dialogbox_hwnd)
                if (ControlGetIndex(listbox_classnn, dialogbox_hwnd) == A_Index) {
                    continue
                }
                SendMessage(0xF5, 0, 0, free_move_button, dialogbox_hwnd)
                ControlChooseIndex(A_Index, listbox_classnn, dialogbox_hwnd)

                while ControlChooseString(item, listbox_classnn, dialogbox_hwnd) != refrence_item_index {
                    Sleep 1
                }
            }
        }
        catch Error as e {
            Logger.info(Format("函数: {1} 执行失败`n错误信息: {2} on Line {3} `n 文件: {4}", e.What, e.Message, e.Line, e.File))
            Exit
        }

        Logger.tooltip("结构树排序完成", 2000)
    }

    static quick_manipulation(diraction) {
        GroupAdd "Manipulation", "操作参数"
        manipulation_hwnd := WinWait("ahk_group Manipulation", , 5)
        if manipulation_hwnd == 0
            Exit
        diract_button := ControlGetHwnd(diraction, manipulation_hwnd)
        SendMessage(0xF5, 0, 0, diract_button, manipulation_hwnd)
    }
}


class WinEventHook {
    static hook_ptr := 0
    static cb_ptr := 0

    static Start() {
        if (this.hook_ptr)
            return

        this.cb_ptr := CallbackCreate(ObjBindMethod(this, "OnWinEvent"), "F", 7)
        this.hook_ptr := DllCall("SetWinEventHook"
            , "UInt", 0x0003
            , "UInt", 0x0003
            , "Ptr", 0
            , "Ptr", this.cb_ptr
            , "UInt", 0
            , "UInt", 0
            , "UInt", 0
            , "Ptr")
    }

    static Stop() {
        if (this.hook_ptr) {
            DllCall("UnhookWinEvent", "Ptr", this.hook_ptr)
            this.hook_ptr := 0
        }
        if (this.cb_ptr) {
            CallbackFree(this.cb_ptr)
            this.cb_ptr := 0
        }
    }

    static OnWinEvent(hHook, event, hwnd, idObject, idChild, dwEventThread, dwmsEventTime) {
        if (event != 3)
            return

        try {
            global CATIAWindow
            catia_window_hwnd := CATIAWindow.identify_window(hwnd)

            if catia_window_hwnd {
                GroupAdd("GroupCATIA", "ahk_class " catia_window_hwnd)
            }

            if (AppSettings.AutoIME_Enabled && WinActive("ahk_group group_autoime")) {
                IMEController.switch_ime(IMEController.ime_map["en"])
                SetTimer(ObjBindMethod(IMEController, "confirm_ime"), -5000)
            }
        }
        catch Error as err {
            Logger.info("WinEventHook: 处理前台切换事件失败")
        }
    }
}

