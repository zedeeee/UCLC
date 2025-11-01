#Requires AutoHotKey v2.0
#SingleInstance Force
#MaxThreads 20
SetTitleMatchMode 2

#Include ./Lib/AppSettings.ahk
#Include ./Lib/CATAlias.ahk
#Include ./Lib/stdio.ahk
#Include ./Lib/windows.ahk
#Include ./Lib/string.ahk
#Include ./Lib/AHK_LOG.ahk
#Include ./Lib/CAT_Automatic.ahk
#Include ./Lib/tray_menu.ahk
#Include ./Lib/SettingsGUI.ahk
#Include ./Lib/ConfigDownloaderGUI.ahk

ensure_main_config_exists()
AppSettings.Init()
add_coustom_tray_menu()

; 检查 USER-CONFIG文件
check_user_config()

; 创建 计算器 组
GroupAdd "group_calc", "计算器"
GroupAdd "group_calc", "Calculator"

read_all_section_from_ini(AppSettings.alias_ini_path, AppSettings.workbench_list)
read_all_section_from_ini(AppSettings.hotkey_ini_path, AppSettings.workbench_list)

; 注册热键
HotIfWinActive "ahk_group GroupCATIA"
{
  available_workbench_list := StrSplit(IniRead(AppSettings.hotkey_ini_path), "`n")
  customize_hotkey_list_dict := Map()

  ; 将配置文件内所有热键写入字典
  for workbench in available_workbench_list
  {
    key_value_pair_array := StrSplit(IniRead(AppSettings.hotkey_ini_path, workbench), "`n")

    for each_pair in key_value_pair_array
    {
      key := StrSplit(each_pair, "=")[1]
      if !customize_hotkey_list_dict.Has(key)
      {
        customize_hotkey_list_dict.Set(key, "")
      }
    }
  }

  for each_hotkey in customize_hotkey_list_dict
  {
    Hotkey each_hotkey, register_command
  }
}

check_user_config() {
  if (FileExist(AppSettings.alias_ini_path) = "" or FileExist(AppSettings.hotkey_ini_path) = "")
  {
    downloaderGUI := ConfigDownloaderGUI()
    downloaderGUI.Show()
  }
}

ensure_main_config_exists() {
  config_path := A_ScriptDir . "\config.ini"
  template_path := A_ScriptDir . "\config.template.ini"

  if FileExist(config_path)
    return

  if !FileExist(template_path)
  {
    MsgBox "致命错误：配置文件模板 config.template.ini 丢失，无法创建 config.ini。请重新下载程序。", "错误", 16
    ExitApp
  }

  try
  {
    ; FileRecycle(config_path)
    FileCopy template_path, config_path, 0
  }
  catch
  {
    MsgBox("
    ( LTrim
      创建配置文件失败！

      这通常是因为 UCLC 程序被放置在了需要管理员权限的系统目录中（例如 "Program Files"）。

      建议解决方案：
      1. 将整个 UCLC 文件夹移动到您的个人文件夹（例如“文档”或“桌面”）。
      2. 然后重新启动程序。

      如果您确实需要在此位置运行，请手动右键点击 `UCLC.ahk` 文件，并选择“以管理员身份运行”。
    )", "错误", 16)
    ExitApp
  }
}

add_group_by_exe("group_autoime", "AutoIME", AppSettings.config_ini_path)

volume_control := VolumeController.Call()

; 启动脚本后 循环检测 CATIA 脚本程序
loop {
  try {
    last_found_window_hwnd := WinExist("A")
    catia_window_hwnd := identify_catia_window()

    if catia_window_hwnd
    {
      GroupAdd "GroupCATIA", "ahk_class " catia_window_hwnd
    }

    ; 检测到匹配窗口后，自动切换为英文输入法
    if (WinActive("ahk_group group_autoime")) {
      switchIMEbyID(IMEmap["en"])
      SetTimer(confirmIME,-5000)
    }

    WinWaitNotActive(last_found_window_hwnd)
  }
  catch Error as err {
    AHK_LOGI("循环获取当前窗口失败")
    Sleep 100
  }
}

#HotIf WinActive
{
  ^+r::
  {
    ToolTip "Reloading Script ..."
    Sleep 500
    ToolTip
    Reload		; 设定 Ctrl-Shift-R 热键来重启脚本.
  }

  ; win + c 启动系统自带的计算器
  ; 如果计算器已经打开，则激活它
  #c::
  {
    try
    {
      WinActivate("ahk_group group_calc")
    }
    catch as e
    {
      Run "Calc"
      WinWait("ahk_group group_calc")
      WinActivate("ahk_group group_calc")
    }
  }

  ~RControl::
  {
    ; 检查功能是否启用
    if !AppSettings.Everything_Enabled
    {
        return
    }

    ; 双击判断逻辑不变
    if (A_PriorHotkey != "~RControl" or A_TimeSincePriorHotkey > 400)
    {
        KeyWait "Control"
        return
    }

    ; 如果 Everything 正在运行，直接激活
    if ProcessExist("Everything.exe")
    {
        Send "#]" ; 仍然依赖用户在 Everything 中设置的快捷键
        return
    }

    ; 如果未运行，检查路径是否有效
    if (AppSettings.Everything_Path and FileExist(AppSettings.Everything_Path))
    {
        Run AppSettings.Everything_Path
    }
    else
    {
        ; --- 核心改进：弹出交互式对话框 ---
        result := MsgBox(
            "“Everything 快速启动”功能已启用，但未找到 Everything.exe。`n`n"
            "请检查 config.ini 中的路径配置是否正确。`n`n"
            "要现在打开设置窗口进行配置吗？"
            , "配置缺失"
            , 36 ; Yes/No buttons + Question icon
        )

        if (result == "Yes")
        {
            ShowSettingsGUI() ; 直接调用显示设置窗口的函数
        }
    }
  }

  ; Win + 鼠标滚轮上下 切换虚拟桌面
  LWin & WheelDown::
  {
    try {
      if (A_TimeSincePriorHotkey > 200)
        Send "{Ctrl Down}{LWin Down}{Right}{Ctrl Up}{LWin Up}"
    }
  }

  LWin & WheelUp::
  {
    try {
      if (A_TimeSincePriorHotkey > 200)
        Send "{Ctrl Down}{LWin Down}{Left}{Ctrl Up}{LWin Up}"
    }
  }

  ; 右ALT+鼠标滚轮上，音量增大
  RAlt & WheelUp::
  {
    increment := volume_control.get_volume_increment()
    SoundSetVolume "+" . increment
    volume_control.show_volume_status()
    Sleep 5
  }

  ; 右ALT+鼠标滚轮下，音量减小
  RAlt & WheelDown::
  {
    increment := volume_control.get_volume_increment()
    SoundSetVolume "-" . increment
    volume_control.show_volume_status()
    Sleep 5
  }

  ; 右ALT+鼠标中键，静音
  RAlt & MButton::
  {
    SoundSetMute -1
    muteStatus := SoundGetMute() ? "静音" : "解除静音：" . Integer(SoundGetVolume())
    k_ToolTip(muteStatus, 1000)
  }

  ; ^+t::
  ; {

  ; }
}

; 仅 CATIA 窗口生效的 热键/热字串
#HotIf WinActive("ahk_group GroupCATIA")
{

  Space::
  {
    power_input_edit_control_hwnd := get_power_input_edit_hwnd()
    edit_text := ControlGetText(power_input_edit_control_hwnd)

    if (edit_text == "")
    {
      SendInput "^y"
      Exit
    }

    cat_command_execution(edit_text, AppSettings.alias_ini_path, power_input_edit_control_hwnd)
  }

  +Tab::
  {
    GroupActivate "GroupCATIA"
    k_ToolTip(WinGetTitle("A"), 1000)
  }

  ; 清除 CATIA power-input 输入框里的内容
  ~Esc::
  {
      ControlSetText("", get_power_input_edit_hwnd())
  }

}