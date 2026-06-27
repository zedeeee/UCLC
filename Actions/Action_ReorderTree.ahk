#Requires AutoHotkey v2.0
#Include %A_LineFile%\..\..\Lib\stdio.ahk

GroupAdd "ReorderTree", "Graph tree reordering"
GroupAdd "ReorderTree", "图形树重新排序"
raw_lists_string := ""

dialogbox_hwnd := WinWait("ahk_group ReorderTree", , 5)
if dialogbox_hwnd == 0 {
    ExitApp
}

Listbox_items := ControlGetItems("ListBox1", dialogbox_hwnd)

for item in Listbox_items {
    raw_lists_string .= item ","
}

sorted_lists_string := Sort(raw_lists_string, "D,")
refrence_lists_array := StrSplit(SubStr(sorted_lists_string, 1, StrLen(sorted_lists_string) - 1), ',')

listbox_classnn := "ListBox1"
free_move_button := ControlGetHwnd("自由移动", dialogbox_hwnd)

listbox_items := ControlGetItems(listbox_classnn, dialogbox_hwnd)

; 检查当前的排序状态
loop listbox_items.Length {
    if (listbox_items[A_Index] == refrence_lists_array[A_Index]) {
        if (A_Index == listbox_items.Length) {
            k_ToolTip("已排序完成, 不用继续排序", 3000)
            Sleep 1000
            PostMessage(0x10, 0, , , dialogbox_hwnd)
            ExitApp
        }
        continue
    }
    else {
        break
    }
}

try {
    ; 执行排序
    refrence_item_index := 0

    for item in refrence_lists_array {
        refrence_item_index += 1
        ControlChooseString(refrence_lists_array[A_Index], listbox_classnn, dialogbox_hwnd)
        if (ControlGetIndex(listbox_classnn, dialogbox_hwnd) == A_Index) {
            continue
        }
        SendMessage(0xF5, 0, 0, free_move_button, dialogbox_hwnd)
        ControlChooseIndex(A_Index, listbox_classnn, dialogbox_hwnd)

        while ControlChooseString(item, listbox_classnn, dialogbox_hwnd) != refrence_item_index {
            Sleep 1
        }
    }
}
catch Error as e {
    MsgBox(Format("函数执行失败`n错误信息: {1} on Line {2} `n 文件: {3}", e.Message, e.Line, e.File))
    ExitApp
}

k_ToolTip("结构树排序完成", 2000)
ExitApp
