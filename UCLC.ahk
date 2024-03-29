﻿#Requires AutoHotKey v2.0
SetTitleMatchMode 2

#Include ./Lib/CATAlias.ahk
#Include ./Lib/stdio.ahk
#Include ./Lib/windows.ahk
#Include ./Lib/string.ahk
#Include ./Lib/AHK_LOG.ahk
#Include ./Lib/CAT_Automatic.ahk

TraySetIcon("./icon/color-icon64.png")

global config_ini_path := ".\config.ini"
global alias_ini_path := GET_USER_CONFIG_INI_PATH("用户别名")
global DEBUG_I := IniRead(config_ini_path, "通用", "DEBUG")
global WORKBENCH_LIST_A := Array()
global current_workbench := ""
global ESC_CLEAN_FUNC_FLAG := ""

; 检查 USER-CONFIG文件
user_config_exist_remind(alias_ini_path)

ESC_CLEAN_FUNC_FLAG := init_dev_func_prompt(config_ini_path, "ESC_CLEAN", "ESC 键清除 POWER-INPUT (CATIA 有崩溃风险)")

; 创建 计算器 组
GroupAdd "group_calc", "计算器"
GroupAdd "group_calc", "Calculator"

; 读取适配工作台列表，用于执行对应热键和快捷键？ 返回工作台名称的数组
WORKBENCH_LIST_A := INI_GET_ALL_VALUE_A(alias_ini_path, "工作台")

; 注册热键
HotIfWinActive "ahk_group GroupCATIA"
{
  HotKeys_List := StrSplit(IniRead(alias_ini_path, "HotKey"), "`n")
  For each, line in HotKeys_List
  {
    HotKey_Map := StrSplit(line, "=")
    KeyName := HotKey_Map[1]
    Hotkey KeyName, register_command
  }
}

; 启动脚本后 循环检测 CATIA 脚本程序
loop {
  try {
    ; getCurrentWindow
    activeID := WinExist("A")

    ; isCurrentWindowCATIA
    if (isCurrentWindowCATIA() != "")
    {
      ADD_AHK_GROUP_CATIA()
    }

    ; 检测到匹配窗口后，自动切换为英文输入法
    if (WinActive("ahk_group GroupCATIA")) {
      switchIMEbyID(IMEmap["en"])
    }

    WinWaitNotActive(activeID)
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

  ; ^+t::
  ; {
  ;   cat_auto_graph_tree_reorder()
  ; }

  ^+t::
  {
    arr := ["aaa", "test_func"]
    MsgBox arr[1]
    Sleep 2000

    if arr.Length == 2
    {
      %arr[2]%()
    }
  }

}

test_func()
{
  k_ToolTip("call back function test", 1000)
}


; 仅 CATIA 窗口生效的 热键/热字串
#HotIf WinActive("ahk_group GroupCATIA")
{

  Space::
  {
    power_input_edit_control_hwnd := GET_POWER_INPUT_EDIT_HWND()
    edit_text := ControlGetText(power_input_edit_control_hwnd)

    if (edit_text == "")
    {
      SendInput "^y"
      Exit
    }

    cat_alias_exexcution(edit_text, power_input_edit_control_hwnd)
    ; ControlSetText "c:" . cat_alias_exexcution(edit_text), power_input_edit_control_hwnd
    ; SendInput "{Enter}"
  }

  +Tab::
  {
    GroupActivate "GroupCATIA"
    k_ToolTip(WinGetTitle("A"), 1000)
  }


  ; 清除 CATIA power-input 输入框里的内容
  ~Esc::
  {
    if ESC_CLEAN_FUNC_FLAG == 1 {
      ControlSetText("", GET_POWER_INPUT_EDIT_HWND())
    }
  }

}

; -------------------------------
; 将CATIA窗口对应的 ahk_class 值添加到 “GroupCATIA”
; 以便 #Hotif WinActive 规则生效
ADD_AHK_GROUP_CATIA()
{
  k_ClassNN := isCurrentWindowCATIA()

  if (k_ClassNN = "") {
    return
  }
  GroupAdd "GroupCATIA", "ahk_class " k_ClassNN
  k_ClassNN := ""
}

; ADD_AHK_GROUP()

; 获取最新找到的窗口，判断是否为CATIA主界面
; True 返回 CATIA 窗口的 ahk_class 值
; 执行此函数前需要先获取窗口
;
isCurrentWindowCATIA() {

  curWin := Object()
  try {
    curWin.title := WinGetTitle("A")
    curWin.class := WinGetClass("A")
    curWin.exe := WinGetProcessName("A")
  }
  catch Error as err {
    AHK_LOGI("对象获取失败")
    return
  }

  if (StrUpper(curWin.exe) == "CNEXT.EXE" and SubStr(curWin.title, 1, 8) == "CATIA V5") and (SubStr(curWin.class, 1, 4) != "Afx:" or SubStr(curWin.class, 1, 14) != "CATDlgDocument")
  {
    AHK_LOGI("CATIA窗口 获取成功")
    return curWin.class
  }
  AHK_LOGI("未获取到CATIA窗口")
  return

}

user_config_exist_remind(file_path) {
  if (FileExist(file_path) = "")
  {
    MsgBox("未找到配置文件, 请检查以下路径和文件：`n"
      file_path "`n"
      "`n"
      "示例配置文件下载地址:`n"
      "https://github.com/zedeeee/UCLC-config`n"
      "`n"
      "点击确认按钮退出脚本"
      , "配置文件错误")
    ExitApp
  }
}

; 获取 power-input 输入框的HWND值
GET_POWER_INPUT_EDIT_HWND() {
  SendInput "U"
  SendInput "{BackSpace}"
  Sleep 50
  control_edit_hwnd := ControlGetFocus("A")
  AHK_LOGI(ControlGetClassNN(control_edit_hwnd))
  return control_edit_hwnd
}