#Requires AutoHotkey v2.0

; 获取ini文件内指定section内所有value, 并返回数组
; - string: file_path
; - string: section_name
INI_GET_ALL_VALUE_A(file_path, section_name)
{
    values := Array()
    loop parse IniRead(file_path, section_name), "`n" ; 通过换行符获取数组
    {
        arr := StrSplit(A_LoopField, "=")
        values.Push(arr[2])
    }
    return values
}