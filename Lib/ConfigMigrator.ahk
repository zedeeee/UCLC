#Requires AutoHotkey v2.0
#Include "%A_LineFile%\..\JSON.ahk"

class ConfigMigrator {
    /**
     * 将指定的 INI 文件静默转换为 JSON 文件，并将旧文件备份
     * @param ini_path 原始 ini 路径
     * @param json_path 新的 json 路径
     * @param is_alias_format 是否启用深度解构（针对 alias/hotkey）
     * @returns {Integer} 1 表示成功迁移，0 表示未进行迁移或失败
     */
    static MigrateIniToJson(ini_path, json_path, is_alias_format := false) {
        if (!FileExist(ini_path))
            return 0
        
        try {
            sections_str := IniRead(ini_path)
            if (sections_str == "")
                return 0
                
            json_obj := Map()
            
            loop parse sections_str, "`n", "`r" {
                section := A_LoopField
                json_obj[section] := Map()
                
                keys_str := IniRead(ini_path, section)
                loop parse keys_str, "`n", "`r" {
                    ; 仅分割第一个等号
                    eq_pos := InStr(A_LoopField, "=")
                    if (eq_pos > 0) {
                        key := Trim(SubStr(A_LoopField, 1, eq_pos - 1))
                        val := Trim(SubStr(A_LoopField, eq_pos + 1))
                        
                        ; 提取行内注释
                        comment := ""
                        semicolon_pos := InStr(val, ";")
                        if (semicolon_pos > 0) {
                            comment := Trim(SubStr(val, semicolon_pos + 1))
                            val := Trim(SubStr(val, 1, semicolon_pos - 1))
                        }
                        
                        if (is_alias_format) {
                            item_map := Map()
                            
                            ; 替换旧的 '&' 为 ',' 统一处理
                            clean_val := StrReplace(Trim(val), "&", ",")
                            params := StrSplit(clean_val, ",")
                            
                            item_map["command"] := Trim(params[1], " `t")
                            
                            if (params.Length > 1) {
                                item_map["callback"] := Trim(params[2], " `t")
                            }
                            
                            if (params.Length > 2) {
                                args_arr := []
                                Loop params.Length - 2 {
                                    args_arr.Push(Trim(params[A_Index + 2], " `t"))
                                }
                                item_map["args"] := args_arr
                            }
                            
                            if (comment != "") {
                                item_map["desc"] := comment
                            }
                            
                            json_obj[section][key] := item_map
                        } else {
                            json_obj[section][key] := val
                        }
                    }
                }
            }
            
            ; 针对 config.ini 转换出的 config.json，将其中的 UserConf 后缀修正为 .json
            if (!is_alias_format && json_obj.Has("UserConf")) {
                if (json_obj["UserConf"].Has("快捷键")) {
                    json_obj["UserConf"]["快捷键"] := StrReplace(json_obj["UserConf"]["快捷键"], ".ini", ".json")
                }
                if (json_obj["UserConf"].Has("用户别名")) {
                    json_obj["UserConf"]["用户别名"] := StrReplace(json_obj["UserConf"]["用户别名"], ".ini", ".json")
                }
            }
            
            ; 格式化写入 JSON (UTF-8)
            json_str := JSON.stringify(json_obj)
            
            ; 写入前如果有旧的先删除
            if FileExist(json_path)
                FileDelete(json_path)
                
            FileAppend(json_str, json_path, "UTF-8")
            
            ; 重命名老的 ini 为 bak
            FileMove(ini_path, ini_path . ".bak", true)
            
            return 1
        }
        catch as e {
            try {
                AHK_LOGI("ConfigMigrator 迁移失败: " . e.Message)
            }
            return 0
        }
    }
}
