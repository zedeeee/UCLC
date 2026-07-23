#Requires AutoHotkey v2.0
#SingleInstance Force
#Include "%A_ScriptDir%\..\Lib\JSON.ahk"

; ==============================================================================
; 【脚本作用】
; 本脚本用于全自动从 CATIA 中导出各个工作台 (Workbench) 的配置数据，并自动在
; `data\custom_mapping.json` 中建立和维护“工作台英文 ID” -> “工作台中文名称”的字典表。
; 导出的原始文本文件保存在 `data\command-id_raw` 文件夹中。
;
; 【使用方法】
; 1. 确保已运行 CATIA。
; 2. 运行本脚本，会弹出“全自动导出与 JSON 记录”对话框。
; 3. 在 CATIA 中正常切换到你要录入的某个“目标工作台”（确保工作台工具栏处于吸附显示状态）。
; 4. 返回脚本弹窗并点击【确定】。
; 5. 脚本将全程自动完成以下操作：
;    - 自动获取当前活动工作台的中文名称（若浮动或隐藏会执行双重容错检测）。
;    - 发送命令调起 CATIA “工作间呈示” (Workshop Exposition) 对话框。
;    - 自动提取并选中列表里类型为 `Workbench`（或非通用的 `Workshop`）的目标行。
;    - 自动检测并填入目标导出目录，并利用 `BM_CLICK` 底层消息直接触发「打印」按钮。
;    - 开启 30 秒轮询，等待文件生成并检测字节大小停止增长以确认异步写入完毕。
;    - 自动发送确认消息关闭对话框（让 CATIA 记住路径下次默认打开）。
;    - 解析生成的 txt 文件名提取英文 ID，实时合并写入 `data\custom_mapping.json`。
; 6. 切换下一个工作台，继续点【确定】，以此循环。
; 7. 录入完成后，在脚本弹框上点击【取消】安全退出。
; ==============================================================================

; 强制设置鼠标坐标模式为 Client 模式
CoordMode("Mouse", "Client")

DirCreate(A_ScriptDir "\..\data\command-id_raw")
loop files, A_ScriptDir "\..\data\command-id_raw", "D"
    out_dir := A_LoopFileFullPath "\"

json_file := A_ScriptDir "\..\data\custom_mapping.json"
mapping_obj := Map()
if FileExist(json_file) {
    try {
        mapping_obj := JSON.parse(FileRead(json_file, "UTF-8"))
    }
}

GetWorkbenchName() {
    wb_name := ""
    ; 优先直接抓取“工作台”/“Workbench”工具栏窗口 of Button1
    for title in ["工作台", "Workbench"] {
        hwnd := WinExist(title " ahk_class Afx:000077000C0000:808:0000000000010003 ahk_exe CNEXT.exe")
        if !hwnd
            hwnd := WinExist(title " ahk_exe CNEXT.exe")
        if hwnd {
            try {
                name := ControlGetText("Button1", hwnd)
                if (name != "") {
                    wb_name := name
                    break
                }
            }
        }
    }

    ; 备选：如果工具栏被吸附隐藏，用 WebBrowser 遍历逻辑
    if (wb_name == "") {
        try {
            for hwnd in WinGetList("ahk_exe CNEXT.exe") {
                try {
                    workbench_control_hwnd := ControlGetHwnd("WebBrowser", hwnd)
                    for button in WinGetControls(workbench_control_hwnd) {
                        name := ControlGetText(button, workbench_control_hwnd)
                        if (name != "") {
                            wb_name := name
                            break 2
                        }
                    }
                }
            }
        }
    }
    return wb_name
}

DoExport(out_dir) {
    ; 记录导出前的所有文件及其最后修改时间
    before_files := Map()
    loop files, out_dir "*.txt" {
        before_files[A_LoopFileName] := FileGetTime(A_LoopFilePath, "M")
    }

    ; 发送命令打开“工作间呈示”窗口
    try {
        CATIA := ComObjActive("CATIA.Application")
        try {
            CATIA.StartCommand("工作间呈示")
        } catch {
            CATIA.StartCommand("Workshop Exposition")
        }
    } catch {
        Send("{Text}c:工作间呈示")
        Send("{Enter}")
    }

    if WinWait("工作间呈示", , 5) {
        Sleep(500) ; 等待列表内容加载

        ; 自动寻找 Workbench 或 Workshop 行
        target_row := 0
        try {
            content := ListViewGetContent("Col2", "SysListView321", "工作间呈示")
            loop parse, content, "`n", "`r" {
                if (A_LoopField = "Workbench") {
                    target_row := A_Index
                    break
                }
            }
            if (target_row == 0) {
                names := ListViewGetContent("Col1", "SysListView321", "工作间呈示")
                name_list := StrSplit(names, "`n", "`r")
                loop parse, content, "`n", "`r" {
                    if (A_LoopField = "Workshop" && A_Index <= name_list.Length && name_list[A_Index] !=
                        "CATAfrGeneralWks") {
                        target_row := A_Index
                        break
                    }
                }
            }
        } catch {
            target_row := 1
        }

        ; 焦点并选择目标行
        ControlFocus("SysListView321", "工作间呈示")
        Sleep(100)
        Send("{Home}") ; 回到第一行
        Sleep(100)

        if (target_row > 1) {
            loop (target_row - 1) {
                Send("{Down}")
                Sleep(50)
            }
            Sleep(200)
        }

        ; 填写导出目录（先判断是否已经是目标路径，减少多余填写）
        try {
            current_dir := ControlGetText("Edit1", "工作间呈示")
        } catch {
            current_dir := ""
        }

        if (Trim(current_dir, " \") != Trim(out_dir, " \")) {
            ControlSetText(out_dir, "Edit1", "工作间呈示")
            Sleep(50)
            ControlFocus("Edit1", "工作间呈示")
            Sleep(50)
            ControlSend("{End}{Space}{BackSpace}", "Edit1", "工作间呈示")
            Sleep(100)
        }

        Sleep(300)

        ; 使用本项目 CAT_Automatic.ahk:L203 规范：发送 BM_CLICK (0xF5) 消息进行最底层的无感物理按键模拟
        try {
            print_hwnd := ControlGetHwnd("Button2", "工作间呈示")
            SendMessage(0xF5, 0, 0, print_hwnd, "工作间呈示")
        } catch {
            try ControlClick("Button2", "工作间呈示")
        }

        ; 统一的 30 秒文件检索与大小稳定检测循环
        new_file := ""
        start_wait := A_TickCount
        last_size := -1
        loop {
            ; 检索新增/修改的文件
            loop files, out_dir "*.txt" {
                time := FileGetTime(A_LoopFilePath, "M")
                if (!before_files.Has(A_LoopFileName) || before_files[A_LoopFileName] != time) {
                    new_file := A_LoopFilePath
                    break
                }
            }

            ; 如果文件出现了，且文件大小已经大于 0 并停止增长，代表写入完成
            if (new_file != "") {
                try {
                    current_size := FileGetSize(new_file)
                    if (current_size > 0 && current_size == last_size) {
                        Sleep(500)
                        if (FileGetSize(new_file) == current_size) {
                            break
                        }
                    }
                    last_size := current_size
                }
            }

            ; 整体 30 秒超时控制
            if (A_TickCount - start_wait > 30000) {
                break
            }

            Sleep(500)
        }

        ; 确定关闭（同样发送 BM_CLICK 0xF5 消息以安全关闭窗口并保留路径）
        try {
            ok_hwnd := ControlGetHwnd("Button1", "工作间呈示")
            SendMessage(0xF5, 0, 0, ok_hwnd, "工作间呈示")
        } catch {
            try ControlClick("Button1", "工作间呈示")
        }
        WinWaitClose("工作间呈示", , 2)

        return new_file
    }
    return ""
}

success_count := 0

loop {
    res := MsgBox(
        "【全自动导出与 JSON 记录】`n`n"
        "请在 CATIA 中切换好你要导出的工作台，然后点击 [确定]。`n`n"
        "如果某个工作台没有对应 txt，脚本会忽略导出但依然帮你把 ID 记录到 JSON。`n"
        "点击 [取消] 退出脚本。",
        "全自动导出 (已成功: " success_count ")",
        "OKCancel Iconi"
    )

    if (res == "Cancel")
        break

    ; 激活 CATIA 窗口
    if WinExist("ahk_exe cnext.exe") {
        WinActivate("ahk_exe cnext.exe")
        WinWaitActive("ahk_exe cnext.exe", , 2)
        Sleep(500) ; 等待 UI 彻底刷新
    } else {
        MsgBox("找不到 CATIA 窗口！脚本中止。", "致命错误", "Iconx")
        ExitApp
    }

    ; 自动抓取工作台名称
    wb_name := GetWorkbenchName()
    if (wb_name == "") {
        res_name := InputBox("自动抓取工作台名称失败 (工具栏可能未吸附)！`n请手动输入当前工作台的中文名称：", "手动输入")
        if (res_name.Result == "Cancel" || res_name.Value == "")
            continue
        wb_name := Trim(res_name.Value)
    }

    ; 尝试导出
    new_file := DoExport(out_dir)
    wb_id := ""

    if (new_file != "") {
        SplitPath(new_file, , , , &wb_id)

        ; 如果导出了通用工作台 CATAfrGeneralWks，但中文名又不是它，说明不支持导出，回退到了默认项
        if (wb_id == "CATAfrGeneralWks" && !InStr(wb_name, "通用") && !InStr(wb_name, "General")) {
            try FileDelete(new_file)
            wb_id := ""
        }
    }

    ; 如果没有成功导出，或者被判定为不支持导出
    if (wb_id == "") {
        unknown_count := 1
        loop {
            if !mapping_obj.Has("UNKNOWN_NO_EXPORT_" unknown_count)
                break
            unknown_count++
        }
        wb_id := "UNKNOWN_NO_EXPORT_" unknown_count
    }

    ; 重新读取 JSON 以兼顾并保留运行期间外部手动的修改（例如删除或改名占位符）
    if FileExist(json_file) {
        try {
            mapping_obj := JSON.parse(FileRead(json_file, "UTF-8"))
        }
    }

    ; 写入 JSON
    mapping_obj[wb_id] := wb_name
    FileOpen(json_file, "w", "UTF-8-RAW").Write(JSON.stringify(mapping_obj, 4))

    success_count++
    ToolTip("成功记录: " wb_id " -> " wb_name)
    SetTimer(() => ToolTip(), -3000)
}

ExitApp