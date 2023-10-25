#Requires AutoHotkey v2.0

; 获取 ini 文件内指定 section 内所有 value, 将 value 以数组形式并返回
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