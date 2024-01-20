#Requires AutoHotKey v2.0
#include stdio.ahk
#Include AHK_LOG.ahk

; 读取CATAlias.ini配置文件中的别名, 并返回别名字符串
; 返回的字符串会自动排除 “；” 以后的内容
READ_USER_ALIAS(ini_path, section, key) {
    try {
        ; 返回 CATAlias.ini 内 Key 的对应值
        AHK_LOGI("调用 " section)
        return StrSplit(IniRead(ini_path, section, key), ";")[1]
    }
    catch as e {
        if e
        {
            try {
                AHK_LOGI("调用 通用")
                return StrSplit(IniRead(ini_path, "通用", key), ";")[1]
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
SEND_HOTKEY_COMMAND(ThisHotkey) {
    try {
        SendInput(" ")
        ControlSetText("", ControlGetFocus("A"))
        SendInput("c:" READ_USER_ALIAS(alias_ini_path, "HotKey", ThisHotkey) "{Enter}")
    }
    catch as e {
        k_ToolTip("热键注册失败，请检查" alias_ini_path "目录是否正确", 3000)
    }
}