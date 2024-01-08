#Requires AutoHotKey v2.0
#include stdio.ahk
#Include AHK_LOG.ahk

; 读取CATAlias.ini配置文件中的别名, 并返回别名字符串
; 返回的字符串会自动排除 “；” 以后的内容
readAlias(k_Section, k_Key) {
    try {
        ; 返回 CATAlias.ini 内 Key 的对应值
        AHK_LOGI("调用 " k_Section)
        return StrSplit(IniRead(alias_ini_path, k_Section, k_Key), ";")[1]
    }
    catch as e {
        if e
        {
            try {
                AHK_LOGI("调用 通用")
                return StrSplit(IniRead(alias_ini_path, "通用", k_Key), ";")[1]
            }
            catch as e {
                k_ToolTip("没有找到与" k_Key "对应的命令", 1000)
                return ""
                ; Exit
            }
        }
    }
}

; 查找 ini 文件，匹配 [Hotkey] 的对应快捷键
SendAliasCommand(ThisHotkey) {
    try {
        SendInput(" ")
        ControlSetText("", ControlGetFocus("A"))
        SendInput("c:" readAlias("HotKey", ThisHotkey) "{Enter}")
    }
    catch as e {
        k_ToolTip("热键注册失败，请检查" alias_ini_path "目录是否正确", 3000)
    }
}