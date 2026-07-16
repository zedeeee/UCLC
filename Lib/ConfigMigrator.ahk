#Requires AutoHotkey v2.0
#Include "%A_LineFile%\..\JSON.ahk"

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
                AHK_LOGI("ConfigMigrator 迁移失败: " . e.Message)
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
                AHK_LOGI("ConfigMigrator 迁移 commands 失败: " . e.Message)
            }
            return 0
        }
    }
}
