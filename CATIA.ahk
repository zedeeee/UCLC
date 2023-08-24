#Requires AutoHotKey v1.1
SetTitleMatchMode, RegEx

iClass :=
iDelay := 1000 ; ms

; GroupAdd, GroupCATIA, ahk_class ahk_class Afx:0000000140000000:8*

Loop {
  Gosub, addGroupCATIA
  Sleep iDelay
  ; ToolTip, A_Edit = %A_Edit% temp_ControlName = %temp_ControlName% stringPos = %stringPos%
  ; Sleep,2000
  ; ToolTip
}

#IfWinActive
{
  ^+r::
    ToolTip,Reloading Script ...
    Sleep,500
    ToolTip
    Reload		; 设定 Ctrl+Shift+R 重新载入脚本
  Return

  #c::
    Run Calc
  Return

  ^#t:: ; 测试键
    ControlGetFocus, OutputVar, A
    msgbox %OutputVar%
  Return

  ~RControl::
    Process, Exist, Everything.exe
    if(A_PriorHotkey != "~RControl" or A_TimeSincePriorHotkey > 400)
    {
      KeyWait, Control
      Return
    }
    if (%ErrorLevel% != 0)
    {
      Send #]
      ToolTip, Search Everything ...
      SetTimer, RemoveToolTip, -500
      Return
    }
    ;Run, Everything.exe %PROGRAMFILES%\Everything\
    Run, %PROGRAMFILES%\Everything\Everything.exe
  Return

  ;#+p::
  ;  if
  ;Return

}

#IfWinActive, 图标浏览器
  {
    $x::
      Loop
      {
        if not GetKeyState("x", "P")
          break
        Click
      }
    Return
  }

#IfWinActive, 编辑物料清单
  {
    $x::
      Loop
      {
        if not GetKeyState("x", "P")
          break
        Click
      }
    Return
  }

#IfWinActive ahk_group GroupCATIA
  {
    Space::
      ControlGetFocus, temp_ControlName, A
      if InStr(temp_ControlName,"edit" )
      {
        CommandControlName := temp_ControlName
        ControlGetText, CATIA_Command, %CommandControlName%
        StringLower, CATIA_Command, CATIA_Command
        ControlSetText, %CommandControlName%, c:%CATIA_Command%
        ControlSend, %CommandControlName%, {Enter}
      }
      Else
        SendInput, ^y
    Return

    Esc::
      SendInput, {Escape}
      ControlGetFocus tempEdit,A
      if CommandControlName != %tempEdit%
        ControlFocus, %CommandControlName%
      else
        ControlSetText, %CommandControlName%,
    Return

    ^!s::
      SendInput, c:dbvs{Enter}
    Return

    ^!d::
      SendInput, c:zdyst{Enter}
    Return

    ^!r::
      SendInput, c:clvs{Enter}
    Return

    ^!w::
      SendInput, c:nhr{Enter}
    Return

    !d::
      SendInput, c:definewo{Enter}
    Return

    ^+!s::
      SendInput, c:savem{Enter}
    Return

    F2::
      SendInput, !{Enter}
    Return

    ;LAlt::RButton
    ;Return
    CapsLock::MButton
  }

  ;-------------------------------

  RemoveToolTip:
    {
      ToolTip
      Return
    }

  addGroupCATIA:
    {
      if WinActive("ahk_exe CNEXT.exe") and WinActive("CATIA")
      {
        WinGetClass, iClass, A
        GroupAdd, GroupCATIA, ahk_class ahk_class %iClass%
      }
      Return
    }