#Requires AutoHotKey v2.0
#include stdio.ahk
#Include AHK_LOG.ahk
#Include CAT_Automatic.ahk

/**
 * 获取用户别名配置文件中指定的key值
 * 
 * @param alias_list_ini_path(string)    配置文件的路径
 * @param section(string)    ini 文件的section, 一般是工作台名称
 * @param key(string)    键值, 一般是输入的别名
 * 
 * @example:
 * - GR = CATPstReorderHdr               ; 图形树重新排序
 * @return arr[1]
 * - arr[1] == "CATPstReorderHdr"
 *   
 * @example:
 * - AGR = CATPstReorderHdr &cat_auto_graph_tree_reorder    ; 图形树自动排序
 * @return arr[2]
 * - arr[1] == "CATPstReorderHdr"
 * - arr[2] == "cat_auto_graph_tree_reorder"
 */
read_user_alias(alias_list_ini_path, section, key) {
    command_id_and_cb_array := Array()

    try {
        AHK_LOGI("调用 " section)
        command_id_and_cb_str := StrSplit(StrReplace(IniRead(alias_list_ini_path, section, key), A_Space, ''), ";")[1]
        command_id_and_cb_array := StrSplit(command_id_and_cb_str, "&")
        return command_id_and_cb_array
    }
    catch as e {
        if e
        {
            command_id_and_cb_array := ""
            try {
                AHK_LOGI("调用 通用")
                command_id_and_cb_str := StrSplit(StrReplace(IniRead(alias_list_ini_path, "通用", key), A_Space, ''), ";")[1]
                command_id_and_cb_array := StrSplit(command_id_and_cb_str, "&")
                return command_id_and_cb_array
            }
            catch as e {
                k_ToolTip("没有找到与" key "对应的命令", 1000)
                return ""
                ; Exit
            }
        }
    }
}

; 查找 ini 文件，匹配 [Hotkey] 的对应快捷键
register_command(ThisHotkey) {
    try {
        SendInput(" ")
        ControlSetText("", ControlGetFocus("A"))
        SendInput("c:" read_user_alias(alias_ini_path, "HotKey", ThisHotkey)[1] "{Enter}")
    }
    catch as e {
        k_ToolTip("热键注册失败，请检查" alias_ini_path "目录是否正确", 3000)
    }
}