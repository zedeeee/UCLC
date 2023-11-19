#Requires AutoHotkey v2.0

; 获取 ini 文件内指定 section 内所有 value, 将 value 以数组形式返回
; - string: file_path
; - string: section_name
INI_GET_ALL_VALUE_A(file_path, section_name)
{
    values := Array()
    ; 这里需要添加判断，section_name 不存在的情况
    try {
        loop parse IniRead(file_path, section_name), "`n" ; 通过换行符获取数组
        {
            arr := StrSplit(A_LoopField, "=")
            values.Push(arr[2])
        }
    }
    catch as e {
        k_ToolTip("没有找到与" section_name "对应的section", 1000)
        Exit
    }

    return values
}


; 通过config.ini文件读取分项配置文件路径
INI_GET_USERCONFIG_PATH(k_key) 
{
    try {
        ; sub_config_path := RTrim(config_ini_path, "config.ini") IniRead(config_ini_path, "SubConf", k_key)
        user_config_path := A_ScriptDir "/user-config/" IniRead(config_ini_path, "SubConf", k_key)
        return user_config_path
    }
    catch as e {
        MsgBox("获取" k_key "配置文件失败，请检查 config.ini 和" k_key "配置文件路径是否正确")
    }

}