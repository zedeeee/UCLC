#Requires AutoHotKey v2.0
SetTitleMatchMode "RegEx"

#Include <CATAlias>
#Include "./Lib/stdio.ahk"
#Include "./Lib/window.ahk"
#Include "./Lib/string.ahk"
#Include "./Lib/AHK_LOG.ahk"

iclass := ""
iDelay := 5000 ; ms
WORKBENCH_LIST_A := Array()
CURRENT_WORKBENCH := ""
DEBUG_I := true

; GroupAdd("GroupCATIA", "ahk_class Afx:00007FF7E2A50000:8:00000000000100")

k_ini := A_ScriptDir "\Lib\CATAlias.ini"
k_txt := IniRead(k_ini, "HotKey_cn")

; 读取适配工作台列表，用于执行对应热键和快捷键？ 返回工作台名称的数组
WORKBENCH_LIST_A := INI_GET_ALL_VALUE_A("./config/config.ini", "workbench")

HotIfWinActive "ahk_group GroupCATIA"
{
  For each, line in StrSplit(k_txt, "`n")
  {
    k_part := StrSplit(line, "=")
    k_key := k_part[1]
    Hotkey k_key, SendAliasCommand
  }
}

; 启动脚本后 循环检测 CATIA 脚本程序
loop {
  addGroupCATIA()
  Sleep iDelay
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
    if (PID := ProcessExist("Everything.exe"))
    {
      if (A_PriorHotkey != "~RControl" or A_TimeSincePriorHotkey > 400)
      {
        KeyWait "Control"
      }
      ; if (%ErrorLevel% != 0)
      else
      {
        Send "#]"
      }
    }
    else
    {
      Run "%PROGRAMFILES%\Everything\Everything.exe"
      ; Run, %PROGRAMFILES%\
      ; Everything\
      ; Everything.exe
    }

    ;#+p::
    ;  if
    ;Return

  }
  RWin::RButton

  ^+t::
  {
    CAT_CURRENT_WORKBENCH()
  }
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
    CATIA_Command := StrUpper(ControlGetText(FocuseHwnd))
    ControlSetText "c:" readAlias("Alias_cn", CATIA_Command), FocuseHwnd
    ControlSend "{Enter}", FocuseHwnd

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

; ;-------------------------------


addGroupCATIA()
{
  if WinActive("ahk_exe CNEXT.exe") and WinActive("CATIA")
  {
    k_ClassNN := SubStr(WinGetClass("A"), 1, 40)

    ; 显示获取到的额ClassNN
    ; k_ToolTip(k_ClassNN,2000)

    GroupAdd "GroupCATIA", "ahk_class " k_ClassNN
  }
  Return
}

detCATIA() {
  i := 20
  while i < 0 {
    Sleep iDelay
    i -= 1
  }
}

; 检测当前 CATIA 工作台，并返回工作台对应名称
CAT_CURRENT_WORKBENCH()
{
  WinExist("A")

  workbench_name := ""
  visible_text := WinGetTextFast_A(false)

  ; 获取工作台列表
  if WORKBENCH_LIST_A.Length = 0
  {
    INI_GET_ALL_VALUE_A("./config/config.ini", "workbench")
  }

  for value1 in WORKBENCH_LIST_A {
    for value2 in visible_text {
      if (value1 != value2)
      {
        continue
      }
      AHK_LOGI("value1: " value1 "`n" "value2: " value2 "`n" "A_index: " A_Index, DEBUG_I)
      return
    }
  }
  if workbench_name == ""
  {
    workbench_name := "NULL"
  }

  return workbench_name
}