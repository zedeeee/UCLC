#Requires AutoHotkey v2.0

#Include CATAlias.ahk
#Include AHK_LOG.ahk
#Include windows.ahk
#Include stdio.ahk
#Include CATIAInstance.ahk

/**
 * 安全发送回车键（统一收口）
 * 所有向 CATIA power-input 发送 Enter 的操作必须经过此函数
 * 三层防护：KeyWait(物理释放) → BlockInput(冻结输入) → SendInput(逻辑清理)
 * @param hwnd  目标控件句柄
 * 
 * NOTE: 三个 KeyWait 各 150ms 超时，极端情况叠加 ~450ms
 *       待用户实测跟手感受，如不可接受再调低超时或改用微轮询
 */
safe_send_enter(hwnd) {
    KeyWait("Alt", "T0.15")
    KeyWait("Ctrl", "T0.15")
    KeyWait("Shift", "T0.15")

    ; 记录进入 BlockInput 前的物理按键状态
    alt_held := GetKeyState("Alt", "P")
    ctrl_held := GetKeyState("Ctrl", "P")
    shift_held := GetKeyState("Shift", "P")

    BlockInput true
    ; 逻辑松开修饰键（加上 {Blind} 防止自身受意外干扰）
    SendInput "{Blind}{Alt Up}{Ctrl Up}{Shift Up}"
    
    ; 确保修饰键的 Up 事件已被系统处理，防止与 Enter 混叠
    Sleep 10

    ; ！！核心修复点：使用 {Blind} 强制阻止 ControlSend 自作聪明！！
    ; ControlSend 默认会根据物理实体按键的情况，自动补偿发出 Alt Up 和 Alt Down。
    ; 加上 {Blind} 让它绝对只发 Enter，不发任何多余的修饰键跳变。
    ControlSend "{Blind}{Enter}", hwnd
    
    ; 给 CATIA 留出一点消化 Enter 消息的时间，防止后续的 Alt Down 插队
    Sleep 30

    BlockInput false

    ; 回写：恢复仍被物理按住的修饰键的逻辑状态
    if ctrl_held
        SendInput "{Blind}{Ctrl Down}"
    if shift_held
        SendInput "{Blind}{Shift Down}"
    if alt_held
        SendInput "{Blind}{Alt Down}"
}


/**
 * 根据输入的用户别名, 执行配置文件中的 COMMAND_ID 以及 函数调用
 * @param alias_strings    用户别名字符串, 不区分大小写
 * @param command_ini      命令配置文件路径
 * @param power_input_hwnd    超级输入框的 hwnd 值
 * 
 */
cat_command_execution(input_string, command_ini, power_input_hwnd) {
    ; 获取当前工作台
    current_workbench := match_current_workbench(AppSettings.workbench_list)

    if !current_workbench {
        return  ; 如果没有识别到工作台，则终止后续操作
    }

    ; 获取对应的 Command-id 和 回调函数
    command_id_and_cb_array := read_user_alias(command_ini, current_workbench, StrUpper(input_string))

    if !command_id_and_cb_array {
        k_ToolTip(Format("没有找到与 '{1}' 对应的命令", input_string), 1000)
        return
    }

    ; 获取当前 CATIA 实例（按 PID 隔离）
    instance := get_catia_instance(power_input_hwnd)

    ; 查实例级 Hdr 缓存
    original_id := command_id_and_cb_array[1]
    command_id := instance.hdr_cache.Has(original_id)
        ? instance.hdr_cache[original_id] : original_id

    ; command-id 输出到 power-input
    ControlSetText("c:" . command_id, power_input_hwnd)

    ; 安全发送第一次回车
    safe_send_enter(power_input_hwnd)

    ; [仅 GSD 且未缓存] 同步侦测"超级输入消息"报错弹窗
    ; 通过 ahk_pid 限定到同一 CATIA 进程，避免误捕其他实例的弹窗
    if (current_workbench == "创成式外形设计" && !instance.hdr_cache.Has(original_id)) {
        if WinWait("超级输入消息 ahk_pid " . instance.pid, , 0.5) {
            corrected_id := handle_hdr_error()
            if corrected_id {
                instance.hdr_cache[original_id] := corrected_id
                ControlSetText("c:" . corrected_id, power_input_hwnd)
                safe_send_enter(power_input_hwnd)
            }
        }
    }

    ; 执行回调函数，如有
    if command_id_and_cb_array.Length >= 2 {
        params := []
        loop command_id_and_cb_array.Length - 2 {
            params.Push(command_id_and_cb_array[A_Index + 2])
        }

        %command_id_and_cb_array[2]%(params*)
    }
}

/**
 * 从"超级输入消息"报错弹窗中解析未知命令，修正 Hdr 后缀并返回
 * @returns {string} 修正后的命令ID，解析失败返回空字符串
 */
handle_hdr_error() {
    pop_hwnd := WinGetID()
    str := WinGetTextFast(false)

    WinClose(pop_hwnd)
    WinWaitClose(pop_hwnd, , 2)

    loop parse, str, "`n", "`r" {
        if InStr(A_LoopField, "未知命令") {
            command := Trim(SubStr(A_LoopField, InStr(A_LoopField, "：") + 1))
            ; 有 Hdr 后缀则删除，无则添加
            corrected := (SubStr(command, -3) = "Hdr")
                ? SubStr(command, 1, StrLen(command) - 3)
                : command . "Hdr"
            AHK_LOGI("Hdr 修正: " . command . " → " . corrected)
            return corrected
        }
    }
    return ""
}

/**
 * 获取装配设计下的 "图形树重新排序" 窗口, 自动执行排序操作
 * 
 */
cat_auto_graph_tree_reorder() {
    GroupAdd "ReorderTree", "Graph tree reordering"
    GroupAdd "ReorderTree", "图形树重新排序"

    dialogbox_hwnd := WinWait("ahk_group ReorderTree", , 5)
    if !dialogbox_hwnd {
        return
    }

    listbox_classnn := "ListBox1"
    raw_list_items := ControlGetItems(listbox_classnn, dialogbox_hwnd)
    
    ; 1. 数组转字符串，使用换行符代替逗号规避命名冲突Bug
    raw_lists_string := ""
    for item in raw_list_items {
        raw_lists_string .= item "`n"
    }
    raw_lists_string := Trim(raw_lists_string, "`n")

    ; 2. 排序并转为有序标准数组 (Sort 默认为 `n 分隔)
    sorted_lists_string := Sort(raw_lists_string)
    reference_lists_array := StrSplit(sorted_lists_string, "`n")

    free_move_button := ControlGetHwnd("自由移动", dialogbox_hwnd)

    ; 3. 拦截检查: 过滤是否已排序的状态
    is_sorted := true
    for idx, item in raw_list_items {
        if (item != reference_lists_array[idx]) {
            is_sorted := false
            break
        }
    }

    if is_sorted {
        k_ToolTip("已排序完成, 不用继续排序", 3000)
        Sleep 1000
        PostMessage(0x10, 0, , , dialogbox_hwnd)
        return
    }

    try {
        ; 4. 执行重组排序
        for idx, item in reference_lists_array {
            ; 选中该项，检查是否已在当前应该在的位置
            ControlChooseString(item, listbox_classnn, dialogbox_hwnd)
            if (ControlGetIndex(listbox_classnn, dialogbox_hwnd) == idx) {
                continue
            }
            
            ; 激活自由移动按钮并选择目标位置 (idx)
            SendMessage(0xF5, 0, 0, free_move_button, dialogbox_hwnd)
            ControlChooseIndex(idx, listbox_classnn, dialogbox_hwnd)

            ; 轮询验证是否已移动成功 (超时限制5s，防止死循环)
            loop 100 {
                try ControlChooseString(item, listbox_classnn, dialogbox_hwnd)
                if (ControlGetIndex(listbox_classnn, dialogbox_hwnd) == idx) {
                    break
                }
                Sleep 50
            }
        }
    }
    catch Error as e {
        AHK_LOGI(Format("函数: {1} 执行失败`n错误信息: {2} on Line {3} `n 文件: {4}", e.What, e.Message, e.Line, e.File))
        return
    }

    k_ToolTip("结构树排序完成", 2000)
}

quick_manipulation(diraction) {
    GroupAdd "Manipulation", "操作参数"

    manipulation_hwnd := WinWait("ahk_group Manipulation", , 5)
    if manipulation_hwnd == 0
        Exit

    diract_button := ControlGetHwnd(diraction, manipulation_hwnd)

    SendMessage(0xF5, 0, 0, diract_button, manipulation_hwnd)
}

/**
 * 通过比对工作台控件和工作台列表，返回当前生效工作台
 * 
 * @param workbench_map  工作台列表
 * @returns {string}  工作台名称
 */
match_current_workbench(workbench_map) {
    try {
        workbench_control_hwnd := ControlGetHwnd("WebBrowser", "A")
        ; workbench_buttons :=

        for button in WinGetControls(workbench_control_hwnd) {
            button_name := ControlGetText(button, workbench_control_hwnd)
            for key in workbench_map {
                if button_name == key
                    return button_name
            }
        }
    }
    catch {
        MsgBox "无法识别当前工作台，请确保【工作台】工具栏是吸附状态"
        return
    }
}

; CATIA 窗口 ClassNN 特征
catia_window_classnn_map := Map(
    "R21", "Afx:",
    "R27", "Afx:",
    "R30", "CATDlgDocument")

/**
 * 判断窗口的进程特征
 * 
 * @param obj 自定义封装
 * @returns {bool} 
 */
is_catia_exe_and_title(obj) {
    if (StrLower(obj.exe) == "cnext.exe" and StrUpper(SubStr(obj.title, 1, 8)) == "CATIA V5") {
        return true
    }

    return false
}

/**
 * 判断窗口的classnn特征
 * 
 * @param obj 自定义封装
 * @returns {bool} 
 */
is_included_catia_class(obj) {
    test_class := obj.class

    for , value in catia_window_classnn_map {
        if (SubStr(test_class, 1, StrLen(value)) == value) {
            return true
        }
    }

    return false
}

/**
 * 判断当前窗口是否为CATIA主界面
 * 执行此函数前需要先获取窗口
 * 
 * @returns {void|number} ahk_class
 */
identify_catia_window() {
    current_window := Object()

    try {
        current_window.title := WinGetTitle("A")
        current_window.class := WinGetClass("A")
        current_window.exe := WinGetProcessName("A")
    }
    catch Error as err {
        AHK_LOGI("对象获取失败")
        return
    }

    if (is_catia_exe_and_title(current_window) and is_included_catia_class(current_window)) {
        AHK_LOGI("CATIA窗口 获取成功")
        return current_window.class
    }

    AHK_LOGI("未获取到CATIA窗口")
    return
}

/**
 * 获取 power-input 输入框的HWND值
 * @returns {number} HWND
 */
get_power_input_edit_hwnd() {
    status_bar_hwnd := ControlGetHwnd("msctls_statusbar321")

    for ctrl in WinGetControls(status_bar_hwnd) {
        if InStr(StrLower(ctrl), "edit") {
            edit_hwnd := ControlGetHwnd(ctrl, status_bar_hwnd)
            break
        }
    }

    AHK_LOGI(ControlGetClassNN(edit_hwnd))
    return edit_hwnd
}

/**
 * 从ini文件获取所有section的名称，写入指定的Map对象（模仿字典）
 * @param ini_path    ini文件路径
 * @param dict        指定字典对象
 */
read_all_section_from_ini(ini_path, dict) {
    section_array := StrSplit(IniRead(ini_path), "`n")

    for section in section_array {
        if !dict.Has(section) {
            dict.Set(section, "")
        }
    }
}
