#Requires AutoHotkey v2.0

#Include "string.ahk"

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
    winID := WinGetID("A")
    ThreadID := DllCall("GetWindowThreadProcessId", "UInt", WinID, "UInt", 0)
    InputLocaleID := DllCall("GetKeyboardLayout", "Uint", ThreadID, "Uint")
    return InputLocaleID
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