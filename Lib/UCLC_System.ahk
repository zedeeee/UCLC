#Requires AutoHotkey v2.0

;-==== [ 原模块: stdio.ahk ] ====-
; ToolTip 的封装函数，简化函数调用
; - string: Message
; - int: Delay_ms
k_ToolTip(Message, Delay_ms)
{
  ToolTip Message
  SetTimer ToolTip, Delay_ms
}

;-==== [ 原模块: AHK_LOG.ahk ] ====-
; 打印日志（information）
AHK_LOGI(Message)
{
    if !AppSettings.DEBUG_I
        return
    k_ToolTip(Message, 3000)
}

; ; 开发功能启用提示
; ; 1. 检查标记值
; ; 2. 根据情况弹出提示框, 返回按键状态
; ; 3. 修改值
; ; 4. 重载
; init_dev_func_prompt(ini_path, key, describe) {
;     dev_func_section := "DevFunc"
;     dev_func_flag := IniRead(ini_path, dev_func_section, key)
; 
;     AHK_LOGI("开发功能（" . key . "）启用状态：" . dev_func_flag)
; 
;     if dev_func_flag == -1
;     {
;         user_chooise := MsgBox("是否需要启用开发功能 : `n" . describe, "UCLC 开发功能启用", 0x233)
;         switch user_chooise
;         {
;             case "Yes": IniWrite(1, ini_path, dev_func_section, key)
;             case "No": IniWrite(0, ini_path, dev_func_section, key)
;             default: MsgBox("未启用 " . describe . "`n下次启动脚本会再次询问", "UCLC 开发功能启用", 0x30)
;         }
;     }
; 
;     return IniRead(ini_path, dev_func_section, key)
; }

;-==== [ 原模块: string.ahk ] ====-
; /**
;  * **获取 ini 文件内指定 section 内所有 value, 将 value 以数组形式返回**
;  * @param file_path(string)  目标 ini 文件的路径
;  * @param section_name(string)   指定 section 的名称
;  * @return Array 
;  */
; INI_GET_ALL_VALUE_A(file_path, section_name)
; {
;     values := Array()
;     ; 这里需要添加判断，section_name 不存在的情况
;     try {
;         loop parse IniRead(file_path, section_name), "`n" ; 通过换行符获取数组
;         {
;             arr := StrSplit(A_LoopField, "=")
;             values.Push(arr[2])
;         }
;     }
;     catch as e {
;         k_ToolTip("没有找到与" section_name "对应的section", 1000)
;         Exit
;     }
; 
;     return values
; }
; 
; 
; ; 获取 config.ini 文件 [UserConf] 下的对应配置文件路径
; ;
; GET_USER_CONFIG_INI_PATH(key)
; {
;     try {
;         path := A_ScriptDir "\user-config\" IniRead(".\config.ini", "UserConf", key)
;         return path
;     }
;     catch as e {
;         MsgBox("获取 [" key "] 配置文件失败，请检查 config.ini 和 [" key "] 配置文件路径是否正确")
;     }
; 
; }

;-==== [ 原模块: windows.ahk ] ====-
; ; 获取最近找到窗口的所有控件名称 并返回数组
; WinGetTextFast_A(detect_hidden) {
;   controls := WinGetControlsHwnd()
; 
;   static WINDOW_TEXT_SIZE := 32767 ; Defined in AutoHotkey source.
; 
;   buf := Buffer(WINDOW_TEXT_SIZE * 2, 0)
; 
;   names := Array()
; 
;   Loop controls.Length {
;     hCtl := controls[A_Index]
;     if !detect_hidden && !DllCall("IsWindowVisible", "ptr", hCtl)
;       continue
;     if !DllCall("GetWindowText", "ptr", hCtl, "Ptr", buf.ptr, "int", WINDOW_TEXT_SIZE)
;       continue
; 
;     name := StrGet(buf)
;     ; names.Push(name)
;     names.InsertAt(1, name)
;   }
;   return names
; }

IMEmap := map(
"zh", 0x8040804,
"en", 0x4090409
)

getCurrentIMEID() {
  if WinWaitActive("A", , 3) {
    try {
      active_hwnd := WinGetID("A")
      thread_id := DllCall("GetWindowThreadProcessId", "UInt", active_hwnd, "UInt", 0)
      ime_locale_id := DllCall("GetKeyboardLayout", "Uint", thread_id, "Uint")
      return Format("{1:#x}", ime_locale_id)
    }
    catch Error as e
    {
      k_ToolTip("输入法获取失败：" . e.Message, 2000)
      return false
    }
  }
}

/**
 * 通过调用WinAPI切换输入法
 * https://github.com/mudssky/myAHKScripts
 *
 * @param IMEID
 */
switchIMEbyID(IMEID) {
  PostMessage(0x0050, 0, IMEID, , "A")
}

/**
 * 确认输入法已切换到en
 */
confirmIME(*) {
  IME_id := getCurrentIMEID()
  if !IME_id  ; 如果 getCurrentIMEID 返回 false，直接返回，不进行后续操作
    return

  if IME_id != IMEmap["en"]
    k_ToolTip("输入法自动切换失败，请检查系统设置", 2000)
}

download_file(url, save_path)
{
  temp := A_Temp . "\uclc-download.temp"
  try {
    Download(url, temp)
    FileMove(temp, save_path)
    ; MsgBox Format("临时文件：{1}`n 目标文件：{2}", temp, save_path)
    return true
  }
  catch Error as e
  {
    ; MsgBox(e.What)
    return false
  }
}

download_configurations(file_name, save_path)
{
  github_url := Format("https://github.com/zedeeee/UCLC-config/raw/master/{1}", file_name)
  gitee_url := Format("https://gitee.com/zedeeee/UCLC-config/raw/master/{1}", file_name)

  k_ToolTip(Format("尝试从Github下载{1}", file_name), 3000)
  Sleep(3000)
  if download_file(github_url, save_path)
  {
    return true
  }
  else
  {
    k_ToolTip(Format("从Github下载失败，尝试从Gitee获取{1}", file_name), 3000)
    Sleep(3000)
    return download_file(gitee_url, save_path)
  }

}

/**
 * 将匹配名称的进程添加到指定组
 *
 * @param group_name
 * @param section
 */
add_group_by_exe(group_name, section)
{
  if (AppSettings.config_obj.Has(section)) {
    for _, exe in AppSettings.config_obj[section] {
      GroupAdd group_name, "ahk_exe" . exe
    }
  }
}

; 音量控制类
class VolumeController {
  __New() {
    this.last_tick := A_TickCount
    this.base_increment := 1
    this.min_interval := 10
    this.max_interval := 20
    this.min_multiplier := 1
    this.max_multiplier := 7
    this.k := 1.5 ; 控制曲线的陡峭度
  }

  get_volume_increment() {
    current_tick := A_TickCount
    interval := current_tick - this.last_tick
    this.last_tick := current_tick

    ; 计算动态倍率
    if (interval > 0) {
      if (interval < this.min_interval) {
        multiplier := this.max_multiplier
      } else if (interval > this.max_interval) {
        multiplier := this.min_multiplier
      } else {
        scaled_interval := (interval - this.min_interval) / (this.max_interval - this.min_interval)
        sigmoid_input := (scaled_interval - 0.5) * this.k
        sigmoid_output := 1 / (1 + Exp(-sigmoid_input))
        multiplier := this.min_multiplier + (this.max_multiplier - this.min_multiplier) * sigmoid_output
      }
    } else {
      multiplier := this.min_multiplier
    }

    ; 根据倍率调整增量
    return Round(this.base_increment * multiplier, 2) ; 保留两位小数
  }

  show_volume_status() {
    current_volume := SoundGetVolume()
    mute_status := SoundGetMute() ? "(静音)" : ""
    k_ToolTip(Format("当前音量：{} {}", Integer(current_volume), mute_status), 1000)
  }
}

; forked from WindowSpy.ahk
; ===========================================================================================
; WinGetText ALWAYS uses the "slow" mode - TitleMatchMode only affects
; WinText/ExcludeText parameters. In "fast" mode, GetWindowText() is used
; to retrieve the text of each control.
; ===========================================================================================
WinGetTextFast(detect_hidden) {
    controls := WinGetControlsHwnd()

    static WINDOW_TEXT_SIZE := 32767 ; Defined in AutoHotkey source.

    buf := Buffer(WINDOW_TEXT_SIZE * 2, 0)

    text := ""

    Loop controls.Length {
        hCtl := controls[A_Index]
        if !detect_hidden && !DllCall("IsWindowVisible", "ptr", hCtl)
            continue
        if !DllCall("GetWindowText", "ptr", hCtl, "Ptr", buf.ptr, "int", WINDOW_TEXT_SIZE)
            continue

        text .= StrGet(buf) "`r`n" ; text .= buf "`r`n"
    }
    return text
}

;-==== [ 原模块: WinEventHook.ahk ] ====-
class WinEventHook {
    static hook_ptr := 0
    static cb_ptr := 0

    static Start() {
        if (this.hook_ptr)
            return

        ; Callback 参数：hHook, event, hwnd, idObject, idChild, dwEventThread, dwmsEventTime
        this.cb_ptr := CallbackCreate(ObjBindMethod(this, "OnWinEvent"), "F", 7)
        ; 0x0003 = EVENT_SYSTEM_FOREGROUND
        this.hook_ptr := DllCall("SetWinEventHook"
            , "UInt", 0x0003
            , "UInt", 0x0003
            , "Ptr", 0
            , "Ptr", this.cb_ptr
            , "UInt", 0
            , "UInt", 0
            , "UInt", 0
            , "Ptr")
    }

    static Stop() {
        if (this.hook_ptr) {
            DllCall("UnhookWinEvent", "Ptr", this.hook_ptr)
            this.hook_ptr := 0
        }
        if (this.cb_ptr) {
            CallbackFree(this.cb_ptr)
            this.cb_ptr := 0
        }
    }

    static OnWinEvent(hHook, event, hwnd, idObject, idChild, dwEventThread, dwmsEventTime) {
        if (event != 3) ; EVENT_SYSTEM_FOREGROUND
            return

        try {
            ; 检查 CATIA 窗口
            catia_window_hwnd := identify_catia_window(hwnd)

            if catia_window_hwnd {
                GroupAdd("GroupCATIA", "ahk_class " catia_window_hwnd)
            }

            ; 自动切换输入法逻辑
            if (WinActive("ahk_group group_autoime")) {
                switchIMEbyID(IMEmap["en"])
                SetTimer(confirmIME, -5000)
            }
        }
        catch Error as err {
            AHK_LOGI("WinEventHook: 处理前台切换事件失败")
        }
    }
}

