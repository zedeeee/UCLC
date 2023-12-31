﻿#Requires AutoHotKey v2.0
SetTitleMatchMode "RegEx"

#Include ./Lib/CATAlias.ahk
#Include ./Lib/stdio.ahk
#Include ./Lib/window.ahk
#Include ./Lib/string.ahk
#Include ./Lib/AHK_LOG.ahk
#Include ./Lib/IME.ahk

TraySetIcon("./icon/color-icon64.png")

global config_ini_path := A_ScriptDir "/config.ini"
global alias_ini_path := INI_GET_USERCONFIG_PATH("用户别名")
global iDelay := IniRead(config_ini_path, "通用", "扫描间隔")
global DEBUG_I := IniRead(config_ini_path, "通用", "DEBUG")
global WORKBENCH_LIST_A := Array()
global current_workbench := ""

; 检查 USER-CONFIG文件
user_config_exist_remind(alias_ini_path)

; 读取适配工作台列表，用于执行对应热键和快捷键？ 返回工作台名称的数组
WORKBENCH_LIST_A := INI_GET_ALL_VALUE_A(alias_ini_path, "工作台")

HotIfWinActive "ahk_group GroupCATIA"
{
  k_txt := IniRead(alias_ini_path, "HotKey")
  For each, line in StrSplit(k_txt, "`n")
  {
    k_part := StrSplit(line, "=")
    k_key := k_part[1]
    Hotkey k_key, SendAliasCommand
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

  #c::
  {
    Run "Calc"
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

  ; ^t::
  ; {
  ;   switchIMEbyID(IMEmap["en"])
  ; }
}


; 仅 CATIA 窗口生效的 热键/热字串
#HotIf WinActive("ahk_group GroupCATIA")
{

  ~Space::
  {
    global FocuseHwnd

    tempFocuseHwnd := ControlGetFocus("A")
    tempFocuseclassNN := ControlGetClassNN(tempFocuseHwnd)

    if !InStr(tempFocuseclassNN, "edit")
    {
      SendInput "^y"
      Exit
    }

    FocuseHwnd := tempFocuseHwnd
    CATIA_Command := CAT_POWERINPUT_ALIAS(ControlGetText(FocuseHwnd))
    ControlSetText "c:" CATIA_Command, FocuseHwnd
    ControlSend "{Enter}", FocuseHwnd

  }

  +Tab::
  {
    GroupActivate "GroupCATIA"
    k_ToolTip(WinGetTitle("A"), 1000)
  }

  ; ~Esc::
  ; {
  ;   tempFocuseHwnd := ControlGetFocus("A")
  ;   try {
  ;     if FocuseHwnd != tempFocuseHwnd
  ;     {
  ;       ControlFocus FocuseHwnd
  ;     }
  ;     else
  ;     {
  ;       ; MsgBox ("else " FocuseHwnd)
  ;       ControlSetText("", FocuseHwnd)
  ;     }
  ;   }
  ;   catch as e {
  ;     k_ToolTip("控件获取失败，请至少执行一次任意命令输入", 1000)
  ;     Exit
  ;   }
  ; }

  ; CapsLock::MButton
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
isCurrentWindowCATIA() {
  ; actWin := WinExist("A")

  curWin := Object()
  try {
    curWin.title := WinGetTitle()
    curWin.class := WinGetClass()
    curWin.exe := WinGetProcessName()
  }
  catch Error as err {
    AHK_LOGI("对象获取失败")
    return
  }

  if (StrUpper(curWin.exe) != "CNEXT.EXE" or SubStr(curWin.title, 1, 8) != "CATIA V5" or SubStr(curWin.class, 1, 4) != "Afx:")
  {
    AHK_LOGI("未获取到CATIA窗口")
    return
  }

  AHK_LOGI("CATIA窗口 获取成功")
  return curWin.class
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

; 根据输入的Alias值，在CATAlias.ini文件中查找对应工作台的别名，并返回字符串
CAT_POWERINPUT_ALIAS(input_str)
{
  current_workbench := CAT_CURRENT_WORKBENCH()

  key := StrUpper(input_str)
  catia_alias := readAlias(CURRENT_WORKBENCH, key)
  return catia_alias
}

user_config_exist_remind(file_path) {
  if (FileExist(file_path) = "")
  {
    MsgBox("未找到以下路径的文件：`n"
      file_path "`n"
      "`n"
      "user-config 文件下载地址`n"
      "https://github.com/zedeeee/UCLC-config`n"
      "`n"
      "现在退出脚本"
    , "user-config 配置错误")
    ExitApp
  }
}