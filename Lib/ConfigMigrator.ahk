#Requires AutoHotkey v2.0
#Include "%A_LineFile%\..\JSON.ahk"

class ConfigMigrator {
    /**
     * 将指定的 INI 文件静默转换为 JSON 文件，并将旧文件备份
     * @param ini_path 原始 ini 路径
     * @param json_path 新的 json 路径
     * @returns {Integer} 1 表示成功迁移，0 表示未进行迁移或失败
     */
    static MigrateIniToJson(ini_path, json_path) {
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
                        
                        json_obj[section][key] := val
                        if (comment != "") {
                            json_obj[section]["_comment_" . key] := comment
                        }
                    }
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
            return 0
        }
    }
}
