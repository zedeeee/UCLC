#Requires AutoHotkey v2.0

#Include "string.ahk"
#Include "AHK_LOG.ahk"

; 获取最近找到窗口的所有控件名称 并返回数组
WinGetTextFast_A(detect_hidden) {
  controls := WinGetControlsHwnd()

  static WINDOW_TEXT_SIZE := 32767 ; Defined in AutoHotkey source.

  buf := Buffer(WINDOW_TEXT_SIZE * 2, 0)

  names := Array()

  Loop controls.Length {
    hCtl := controls[A_Index]
    if !detect_hidden && !DllCall("IsWindowVisible", "ptr", hCtl)
      continue
    if !DllCall("GetWindowText", "ptr", hCtl, "Ptr", buf.ptr, "int", WINDOW_TEXT_SIZE)
      continue

    name := StrGet(buf)
    ; names.Push(name)
    names.InsertAt(1, name)
  }
  return names
}

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
 * @param ini_path 配置文件路径
 */
add_group_by_exe(group_name, section, ini_path)
{
  exe_arr := INI_GET_ALL_VALUE_A(ini_path, section)
  for exe in exe_arr
  {
    GroupAdd group_name, "ahk_exe" . exe
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

/**
 * 查找当前 CATIA 实例的 #32770 弹窗并点击确认按钮
 * @returns {bool} 是否成功点击了确认按钮
 */
click_dialog_confirm_button() {
    ; 获取当前窗口的 PID（无论焦点在主窗口还是弹窗，PID 都指向同一 CATIA 实例）
    catia_pid := WinGetPID("A")

    ; 在同 PID 下精确查找 #32770 对话框
    dialog_hwnd := WinExist("ahk_class #32770 ahk_pid " . catia_pid)

    if !dialog_hwnd
        return false

    ; 遍历 Button 控件，按优先级匹配确认按钮文本
    try {
        for ctrl in WinGetControls(dialog_hwnd) {
            ; 忽略不可见的控件，防止误点击到隐藏的后台按钮
            if !ControlGetVisible(ctrl, dialog_hwnd)
                continue

            btn_text := ControlGetText(ctrl, dialog_hwnd)
            
            ; 净化按钮文本：去除快捷键标记 '&' (如 &OK) 和括号包围的字母 (如 确定(&O) -> 确定)
            clean_text := StrReplace(btn_text, "&", "")
            clean_text := RegExReplace(clean_text, "\([a-zA-Z]\)", "")
            clean_text := Trim(clean_text)

            if (clean_text == "确定" || clean_text == "OK"
                || clean_text == "是" || clean_text == "Yes") {
                
                ; 使用 SendMessage 发送 BM_CLICK (0xF5)，这比 ControlClick 稳定得多
                SendMessage(0xF5, 0, 0, ctrl, dialog_hwnd)
                return true
            }
        }
    }
    return false
}