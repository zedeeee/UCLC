#Requires AutoHotkey v2.0

/**
 * **获取 ini 文件内指定 section 内所有 value, 将 value 以数组形式返回**
 * @param file_path(string)  目标 ini 文件的路径
 * @param section_name(string)   指定 section 的名称
 * @return Array 
 */
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


; 获取 config.ini 文件 [UserConf] 下的对应配置文件路径
;
GET_USER_CONFIG_INI_PATH(key)
{
    try {
        path := A_ScriptDir "\user-config\" IniRead(".\config.ini", "UserConf", key)
        return path
    }
    catch as e {
        MsgBox("获取 [" key "] 配置文件失败，请检查 config.ini 和 [" key "] 配置文件路径是否正确")
    }

}