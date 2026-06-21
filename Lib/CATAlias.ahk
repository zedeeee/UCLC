#Requires AutoHotKey v2.0
#include stdio.ahk
#Include AHK_LOG.ahk
#Include CAT_Automatic.ahk

/**
 * 获取用户别名配置文件中指定的key值，结果以数组形式返回
 * 
 * @param alias_list_ini_path(string)    配置文件的路径
 * @param section(string)    ini 文件的section, 一般是工作台名称
 * @param key(string)    键值, 一般是输入的别名
 * @return Array         返回命令，[回调函数]，[参数]
 * 
 * @example:
 * - GR = CATPstReorderHdr               ; 图形树重新排序
 * @return arr[]
 * - arr[1] == "CATPstReorderHdr"
 *   
 * @example:
 * - AGR = CATPstReorderHdr &cat_auto_graph_tree_reorder    ; 图形树自动排序
 * @return arr[]
 * - arr[1] == "CATPstReorderHdr"
 * - arr[2] == "cat_auto_graph_tree_reorder"
 */
read_user_alias(alias_list_ini_path, section, key) {
    command_id_and_cb_array := Array()

    try {
        AHK_LOGI("调用 " section)
        config_str := IniRead(alias_list_ini_path, section, key)
        command_id_and_cb_array := process_config(config_str)
    }
    catch as e {
        if e
        {
            try {
                AHK_LOGI("调用 通用")
                config_str := IniRead(alias_list_ini_path, "通用", key)
                command_id_and_cb_array := process_config(config_str)
            }
            catch as e {
                k_ToolTip(Format("没有找到与 {1} 对应的命令", key), 1000)
                return 0
            }
        }
    }

    return command_id_and_cb_array
}

process_config(config) {
    result := []

    ; 去除注释部分
    config := StrReplace(Trim(StrSplit(config, ";")[1]), "&", ",")
    params := StrSplit(config, ",")

    result.Push(Trim(params[1], " `t"))

    ; 去除后面所有项的空格
    Loop params.length - 1
    {
        result.Push(Trim(params[A_Index + 1]))
    }

    return result
}

; 查找 CAT_Hotkey.ini 文件，注册对应快捷键/*  */
register_command(ThisHotkey) {
    edit_hwnd := get_power_input_edit_hwnd()
    cat_command_execution(ThisHotkey, AppSettings.hotkey_ini_path, edit_hwnd)
}