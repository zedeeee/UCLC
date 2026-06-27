#Requires AutoHotkey v2.0
#Include %A_LineFile%\..\JSON.ahk
#Include %A_LineFile%\..\CAT_Automatic.ahk
#Include %A_LineFile%\..\stdio.ahk

class VBABridge {
    static GetTempFilePath() {
        return A_Temp "\uclc_vba_ipc.json"
    }

    /**
     * 调用 CATIA 的 VBA 宏并等待返回结果
     * @param macro_command_id 注册在 CATIA 中的 VBA 宏的 Command ID (如 "my_macro")
     * @param payload_obj      传递给 VBA 的参数 (AHK Map 或 Array)
     * @param timeout_ms       超时时间(毫秒)
     * @returns {Object}       VBA 返回的结果 (AHK Map 或 Array)
     */
    static CallMacro(macro_command_id, payload_obj := Map(), timeout_ms := 5000) {
        temp_file := this.GetTempFilePath()

        ; 准备请求数据
        request := Map(
            "status", "pending",
            "command", macro_command_id,
            "payload", payload_obj
        )

        ; 写入临时文件 (使用 UTF-8)
        if FileExist(temp_file) {
            FileDelete(temp_file)
        }
        FileAppend(JSON.stringify(request), temp_file, "UTF-8")

        ; 获取 CATIA 窗口句柄
        power_input_hwnd := get_power_input_edit_hwnd()
        if (!power_input_hwnd) {
            throw Error("找不到 CATIA 的 Power Input 输入框。")
        }

        ; 通过 Power Input 触发宏
        ControlSetText("c:" . macro_command_id, power_input_hwnd)
        safe_send_enter(power_input_hwnd)

        ; 轮询等待 VBA 处理完毕
        start_time := A_TickCount
        while (A_TickCount - start_time < timeout_ms) {
            Sleep 50
            if !FileExist(temp_file)
                continue

            try {
                file_content := FileRead(temp_file, "UTF-8")
                response := JSON.parse(file_content)

                if (response.Has("status")) {
                    if (response["status"] == "done") {
                        FileDelete(temp_file)
                        return response.Has("result") ? response["result"] : Map()
                    } else if (response["status"] == "error") {
                        err_msg := response.Has("error_message") ? response["error_message"] : "Unknown error in VBA"
                        FileDelete(temp_file)
                        throw Error("VBA Macro Error: " err_msg)
                    }
                }
            } catch Error as err {
                ; 可能是 VBA 正在写入 JSON 时导致文件被占用或 JSON 格式不完整，忽略并重试
                continue
            }
        }

        ; 超时处理
        throw Error("等待 VBA 宏超时 ( " timeout_ms " ms)。")
    }
}
