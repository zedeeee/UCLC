#Requires AutoHotKey v2.0
#include stdio.ahk
#Include AHK_LOG.ahk
#Include CAT_Automatic.ahk

/**
 * 获取用户别名配置文件中指定的key值，结果以数组形式返回
 * 
 * @param dict_type(string)  区分是 "alias" 还是 "hotkey"
 * @param section(string)    一般是工作台名称
 * @param key(string)        键值, 一般是输入的别名
 * @return Array             返回命令，[回调函数]，[参数]
 */
read_user_alias(dict_type, section, key) {
    command_id_and_cb_array := Array()
    
    target_obj := (dict_type == "alias") ? AppSettings.alias_obj : AppSettings.hotkey_obj

    try {
        AHK_LOGI("调用 " section)
        if (target_obj.Has(section) && target_obj[section].Has(key)) {
            config_str := target_obj[section][key]
            command_id_and_cb_array := process_config(config_str)
            return command_id_and_cb_array
        }
        
        AHK_LOGI("调用 通用")
        if (target_obj.Has("通用") && target_obj["通用"].Has(key)) {
            config_str := target_obj["通用"][key]
            command_id_and_cb_array := process_config(config_str)
            return command_id_and_cb_array
        }
        
        k_ToolTip(Format("没有找到与 {1} 对应的命令", key), 1000)
        return 0
    }
    catch as e {
        k_ToolTip(Format("查找 {1} 出错: {2}", key, e.Message), 1000)
        return 0
    }
}

process_config(config) {
    result := []

    ; 这里 JSON 里已经把整行注释分离出去了
    ; 但如果配置里还有带有 '&' 的旧格式（函数带参数），或者 ',' 格式
    config := StrReplace(Trim(config), "&", ",")
    params := StrSplit(config, ",")

    result.Push(Trim(params[1], " `t"))

    Loop params.length - 1
    {
        result.Push(Trim(params[A_Index + 1]))
    }

    return result
}

register_command(ThisHotkey) {
    edit_hwnd := get_power_input_edit_hwnd()
    cat_command_execution(ThisHotkey, "hotkey", edit_hwnd)
}