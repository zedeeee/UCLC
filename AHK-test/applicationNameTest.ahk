#SingleInstance, Force
SendMode Input
SetWorkingDir, %A_ScriptDir%
SetTitleMatchMode, RegEx
#Hotstring, ("EndChars", ";") ; 定义终止符，仅 ";" 生效

#Include <testlib>

; iString := "CATIA V5 - [Product1]"
iClass := 
iDelay := 1000 ; ms

SetTimer, ChangeButtonNames, 50
MsgBox, 4, Add or Delete, Choose a button:
    IfMsgBox, Yes
    MsgBox, You choose Add.
    else
        msgbox , You choose Delete.
Return

ChangeButtonNames:
    IfWinNotExist, Add or Delete
        return
    settimer, ChangeButtonNames, off
    winactivate
    ControlSetText, Button1, &Add
    ControlSetText, Button2, &Delete
return

; GroupAdd, GroupCATIA, ahk_class ahk_class Afx:0000000140000000:8*

Loop
{
    Gosub, addGroupCATIA
    Sleep iDelay
    ; MsgBox % iClass
    ; GroupAdd, GroupCATIA, ahk_class ahk_class iClass
    ; MsgBox % Application_Ver
}

; #IfWinActive ahk_group GroupCATIA
#IfWinActive ahk_exe notepad.exe
    {
        ; #IfWinActive 
        ^+t::
            testa := func1(6)
            MsgBox, %testa%
            ; MsgBox % RegExMatch(iString, "R\d{2}") 
            ; MsgBox % SubStr(iString, RegExMatch(iString, "R\d{2}"), 3)
        Return
        ; WinGetClass, iClass, A
        ; if iClass is Space
        ;     MsgBox, empty
        ; Else
        ;      MsgBox, iClass = %iClass%
        ::btw::by the way
        :*:]d::
            FormatTime, CurrentDateTime,, MM/dd/yyyy H:mm tt
            SendInput, %CurrentDateTime%
        return

        ^+v::
            MsgBox, %A_AhkVersion%
        return

        j & k::
            MsgBox, hello
        return
    }

    addGroupCATIA:
        if WinActive("ahk_exe CNEXT.exe") and WinActive("CATIA")
        {
            ; WinGetTitle, iString
            ; Application_Ver := SubStr(iString, RegExMatch(iString, "R\d{2}"), 3)
            ; MsgBox, istring = %iString%, Ver = %Application_Ver%
            WinGetClass, iClass, A 
            GroupAdd, GroupCATIA, ahk_class ahk_class %iClass%
            ; MsgBox % iClass
            ; MsgBox, , Title, Text, Timeout]
        }
    Return
