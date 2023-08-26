#Requires AutoHotKey v2.0
SetTitleMatchMode "RegEx"

#Include <CATAlias>

iclass := ""
iDelay := 5000 ; ms

; GroupAdd("GroupCATIA", "ahk_class Afx:00007FF7E2A50000:8:00000000000100")

k_ini := A_ScriptDir "\Lib\CATAlias.ini"
k_txt := IniRead(k_ini, "HotKey_cn")

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
}


; 仅 CATIA 窗口生效的 热键/热字串
#HotIf WinActive("ahk_group GroupCATIA")
{

  ~Space::
  {
    ; FocuseHwnd := ""
    ; if FocuseHwnd == ""
    ; {
    ;   ; 测试是否因为重复声明造成的
    ;   ; BUG依旧
    global FocuseHwnd
    ; }

    tempFocuseHwnd := ControlGetFocus("A")
    tempFocuseclassNN := ControlGetClassNN(tempFocuseHwnd)
    
    ; 显示获取到的Hwnd
    ; k_ToolTip("tempFocuseHwnd: " tempFocuseHwnd "`n" "tempFocuseclassNN: " tempFocuseclassNN, 2000)

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

k_ToolTip(i_Message, i_delay)
{
  ToolTip i_Message
  SetTimer ToolTip, i_delay
}

addGroupCATIA()
{
  if WinActive("ahk_exe CNEXT.exe") and WinActive("CATIA")
  {
    k_ClassNN :=SubStr(WinGetClass("A"),1,40)

    ; 显示获取到的额ClassNN
    k_ToolTip(k_ClassNN,2000)

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