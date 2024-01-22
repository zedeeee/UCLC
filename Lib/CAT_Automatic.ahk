#Requires AutoHotkey v2.0

cat_auto_graph_tree_reorder()
{
    GroupAdd "SortTree", "Graph tree reordering"
    GroupAdd "SortTree", "图形树重新排序"

    raw_lists_string := ""

    dialogbox_hwnd := WinWait("ahk_group SortTree")
    Listbox_items := ControlGetItems("ListBox1", dialogbox_hwnd)

    for item in Listbox_items {
        raw_lists_string .= item ","
    }

    sorted_lists_string := Sort(raw_lists_string, "D,")
    refrence_lists_array := StrSplit(SubStr(sorted_lists_string, 1, StrLen(sorted_lists_string) - 1), ',')

    ; autoGR3(refrence_lists_array, dialogbox_hwnd)
    listbox_classnn := "ListBox1"
    free_move_button := ControlGetHwnd("自由移动", dialogbox_hwnd)

    listbox_items := ControlGetItems(listbox_classnn, dialogbox_hwnd)

    ; 检查当前的排序状态
    loop listbox_items.Length
    {
        if (listbox_items[A_Index] == refrence_lists_array[A_Index]) {
            if (A_Index == listbox_items.Length)
            {
                MsgBox "结构树已完成排序"
                Exit
            }
            continue
        }
        else {
            break
        }
    }

    ; 执行排序
    loop refrence_lists_array.Length {
        ControlChooseString(refrence_lists_array[A_Index], listbox_classnn, dialogbox_hwnd)
        if (ControlGetIndex(listbox_classnn, dialogbox_hwnd) == A_Index)
        {
            continue
        }
        SendMessage(0xF5, 0, 0, free_move_button, dialogbox_hwnd)
        ControlChooseIndex(A_Index, listbox_classnn, dialogbox_hwnd)
        while ControlGetIndex(listbox_classnn, dialogbox_hwnd) != A_Index
        {
            Sleep 10
        }
        Sleep 100
    }
    MsgBox "结构树整理完毕"
}