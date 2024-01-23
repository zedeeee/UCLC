#Requires AutoHotkey v2.0

#Include CATAlias.ahk
#Include AHK_LOG.ahk


/**
 * 根据输入的用户别名, 执行配置文件中的 COMMAND_ID 以及 函数调用
 * @param alias_strings    用户别名字符串, 不区分大小写
 * @param power_input_hwnd    超级输入框的 hwnd 值
 * 
 */
cat_alias_exexcution(alias_string, power_input_hwnd)
{
    current_workbench := CAT_CURRENT_WORKBENCH()

    command_id_and_cb_array := read_user_alias(alias_ini_path, current_workbench, StrUpper(alias_string))

    if command_id_and_cb_array.Length == 0
    {
        k_ToolTip(Format("没有找到与 '{1}' 对应的命令", alias_string), 1000)
        return
    }

    ; hwnd_current := ControlGetHwnd("A")
    ControlSetText("c:" . command_id_and_cb_array[1], power_input_hwnd)
    ; ControlSetText("c:" . "ViewAlignment", power_input_hwnd)
    SendInput "{Enter}"

    if command_id_and_cb_array.Length == 2
    {
        %command_id_and_cb_array[2]%()
    }

}

; 获取装配设计下的 "图形树重新排序" 窗口, 自动执行排序操作
cat_auto_graph_tree_reorder()
{
    GroupAdd "ReorderTree", "Graph tree reordering"
    GroupAdd "ReorderTree", "图形树重新排序"
    raw_lists_string := ""

    dialogbox_hwnd := WinWait("ahk_group ReorderTree", , 5)
    if dialogbox_hwnd == 0
    {
        Exit
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
    loop listbox_items.Length
    {
        if (listbox_items[A_Index] == refrence_lists_array[A_Index]) {
            if (A_Index == listbox_items.Length)
            {
                k_ToolTip("已排序完成, 不用继续排序", 3000)
                Sleep 1000
                PostMessage(0x10, 0, , , dialogbox_hwnd)
                Exit
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

        for item in refrence_lists_array
        {
            refrence_item_index += 1
            ControlChooseString(refrence_lists_array[A_Index], listbox_classnn, dialogbox_hwnd)
            if (ControlGetIndex(listbox_classnn, dialogbox_hwnd) == A_Index)
            {
                continue
            }
            SendMessage(0xF5, 0, 0, free_move_button, dialogbox_hwnd)
            ControlChooseIndex(A_Index, listbox_classnn, dialogbox_hwnd)

            while ControlChooseString(item, listbox_classnn, dialogbox_hwnd) != refrence_item_index
            {
                Sleep 1
            }
        }
    }
    catch Error as e
    {
        AHK_LOGI(Format("函数: {1} 执行失败`n错误信息: {2} on Line {3} `n 文件: {4}", e.What, e.Message, e.Line, e.File))
        Exit
    }

    k_ToolTip("结构树排序完成", 2000)
}

; 检测当前 CATIA 工作台，并返回字符串
CAT_CURRENT_WORKBENCH()
{
    WinExist("A")

    workbench_name := "NULL"
    visible_text := WinGetTextFast_A(false)

    ; 获取工作台列表
    if WORKBENCH_LIST_A.Length = 0
    {
        INI_GET_ALL_VALUE_A(config_ini_path, "workbench")
    }

    for value1 in visible_text {
        for value2 in WORKBENCH_LIST_A {
            ; FileAppend "WORKBENCH_LIST_A: " value1 "    " "visible_text: " value2 "`n", ".\log.txt"
            if (value1 != value2)
            {
                continue
            }
            AHK_LOGI("value1: " value1 "`n" "value2: " value2 "`n" "A_index: " A_Index)
            workbench_name := value1
            return workbench_name
        }
    }

}