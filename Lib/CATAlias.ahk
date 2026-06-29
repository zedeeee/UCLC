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
        if get_map_value_case_insensitive(target_obj, section, &section_map) {
            if get_map_value_case_insensitive(section_map, key, &config_val) {
                return process_config(config_val)
            }
        }
        
        AHK_LOGI("调用 通用")
        if get_map_value_case_insensitive(target_obj, "通用", &general_map) {
            if get_map_value_case_insensitive(general_map, key, &config_val) {
                return process_config(config_val)
            }
        }
        
        k_ToolTip(Format("没有找到与 '{1}' 对应的命令", key), 1000)
        return 0
    }
    catch as e {
        k_ToolTip(Format("查找 '{1}' 出错: {2}", key, e.Message), 1000)
        return 0
    }
}

get_map_value_case_insensitive(m, key, &val) {
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

process_config(config) {
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

register_command(ThisHotkey) {
    edit_hwnd := get_power_input_edit_hwnd()
    cat_command_execution(ThisHotkey, "hotkey", edit_hwnd)
}