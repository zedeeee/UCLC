#Requires AutoHotKey v2.0
SetTitleMatchMode 2

#Include ./Lib/CATAlias.ahk
#Include ./Lib/stdio.ahk
#Include ./Lib/windows.ahk
#Include ./Lib/string.ahk
#Include ./Lib/AHK_LOG.ahk
#Include ./Lib/CAT_Automatic.ahk
#Include ./Lib/tray_menu.ahk

add_coustom_tray_menu()

global config_ini_path := ".\config.ini"
global alias_ini_path := GET_USER_CONFIG_INI_PATH("用户别名")
global hotkey_ini_path := GET_USER_CONFIG_INI_PATH("快捷键")
global DEBUG_I := IniRead(config_ini_path, "通用", "DEBUG")
global workbench_list := Map()
global current_workbench := ""
; global ESC_CLEAN_FUNC_ENABLE_FLAG := ""

; 检查 USER-CONFIG文件
check_user_config()

; ESC_CLEAN_FUNC_ENABLE_FLAG := init_dev_func_prompt(config_ini_path, "ESC_CLEAN", "ESC 键清除 POWER-INPUT (CATIA 有崩溃风险)")

; 创建 计算器 组
GroupAdd "group_calc", "计算器"
GroupAdd "group_calc", "Calculator"

read_all_section_from_ini(alias_ini_path, workbench_list)
read_all_section_from_ini(hotkey_ini_path, workbench_list)

; 注册热键
HotIfWinActive "ahk_group GroupCATIA"
{
  available_workbench_list := StrSplit(IniRead(hotkey_ini_path), "`n")
  customize_hotkey_list_dict := Map()

  ; 将配置文件内所有热键写入字典
  for workbench in available_workbench_list
  {
    key_value_pair_array := StrSplit(IniRead(hotkey_ini_path, workbench), "`n")

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
  if (FileExist(alias_ini_path) = "" or FileExist(hotkey_ini_path) = "")
  {
    result := MsgBox(
      "未找到配置文件`n"
      "是否从 Github/Gitee 下载示例文件？`n"
      , "配置文件缺失"
      , 51
    )

    switch result {
      case "No":
        MsgBox "
        (
          示例配置文件下载地址：
          https://github.com/zedeeee/UCLC-config
        )"
        ExitApp

      case "Yes":
        config_and_path := [
          ["CAT_Alias.ini", alias_ini_path],
          ["CAT_Hotkey.ini", hotkey_ini_path]
        ]

        flag := 1
        for config_info in config_and_path
        {
          if not download_configurations(config_info[1], config_info[2])
            flag := 0
        }

        MsgBox("获取配置文件成功，请重新载入脚本")


      default: ExitApp
    }
  }
}


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
    if (WinActive("ahk_group GroupCATIA")) {
      switchIMEbyID(IMEmap["en"])
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
    if (A_PriorHotkey != "~RControl" or A_TimeSincePriorHotkey > 400)
    {
      KeyWait "Control"
      return
    }
    if (PID := ProcessExist("Everything.exe"))
    {
      AHK_LOGI("获取到Everything PID = " PID)
      Send "#]"
    }
    else
    {
      AHK_LOGI("未找到 Everything 进程，现在启动……")
      Run "Everything.exe", A_ProgramFiles "\Everything\"
    }
  }

  ; Win + 鼠标滚轮上下 切换虚拟桌面
  LWin & WheelDown::
  {
    try {
      if (A_TimeSincePriorHotkey > 100)
        Send "{Ctrl Down}{LWin Down}{Right}"
    }
  }

  LWin & WheelUp::
  {
    try {
      if (A_TimeSincePriorHotkey > 100)
        Send "^{Ctrl Down}{LWin Down}{Left}"
    }
  }


  ;右ALT+鼠标滚轮上，音量增大
  RAlt & WheelUp::
  {
    SoundSetVolume "+2"
  }

  ;右ALT+鼠标滚轮下，音量减小
  RAlt & WheelDown::
  {
    SoundSetVolume "-2"
  }

  ;右ALT+鼠标中键，静音
  RAlt & MButton::
  {
    SoundSetMute -1
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

    cat_command_execution(edit_text, alias_ini_path, power_input_edit_control_hwnd)
  }

  +Tab::
  {
    GroupActivate "GroupCATIA"
    k_ToolTip(WinGetTitle("A"), 1000)
  }


  ; 清除 CATIA power-input 输入框里的内容
  ~Esc::
  {
    if ESC_CLEAN_FUNC_ENABLE_FLAG == 1 {
      ControlSetText("", get_power_input_edit_hwnd())
    }
  }

}