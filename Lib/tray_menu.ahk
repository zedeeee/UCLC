#Requires AutoHotkey v2.0

#Include stdio.ahk


global ESC_CLEAN_FUNC_ENABLE_FLAG := 0

showProjectHomepage_cb(*) {
    Run "https://github.com/zedeeee/UCLC"
}

help_Homepage_cb(*) {
    Run "https://github.com/zedeeee/UCLC-config"
}

modify_alias_cb(*)
{
    Run "notepad " alias_ini_path
}

modify_shortcut_cb(*)
{
    Run "notepad " hotkey_ini_path
}

about_cb(*)
{
    arr := StrSplit(menu_items[1][1], "v")
    version := arr[arr.Length]
    MsgBox Format("一个CATIA快捷键脚本`n使CATIA的操作体验更接近AutoCAD`n版本：{1}", version), "UCLC", 0x40

}

update_check_cb(*)
{
}

esc_enhanced_cb(ItemName, ItemPos, MyMenu)
{
    global ESC_CLEAN_FUNC_ENABLE_FLAG := Mod(ESC_CLEAN_FUNC_ENABLE_FLAG + 1, 2)
    MyMenu.ToggleCheck(ItemName)
    if ESC_CLEAN_FUNC_ENABLE_FLAG
    {
        MsgBox("已开启 ESC 清除命令输入框功能`n开发阶段功能请酌情使用", "UCLC - ESC增强", 0x40)
    }
}

reload_cb(*) {
    Reload
}

disable_script_cb(ItemName, ItemPos, MyMenu)
{
    menu_toggleCheck_cb(ItemName, ItemPos, MyMenu)
    Suspend(-1)
}

exit_cb(*) {
    ExitApp
}

menu_toggleCheck_cb(ItemName, ItemPos, MyMenu)
{
    MyMenu.ToggleCheck(ItemName)
}


NoAction_cb(*) {
    ; Do Nothing
    k_ToolTip("功能未开放", 2000)
}

run_spy_cb(*)
{
    win_spy_path := RegRead("HKEY_LOCAL_MACHINE\SOFTWARE\AutoHotkey", "InstallDir") . "\UX\WindowSpy.ahk"
    Run(win_spy_path)
}

disable_botton_cb(ItemName, ItemPos, MyMenu) {
    MyMenu.Disable(ItemName)
}

add_sub_menu(ItemName, ItemPos, MyMenu) {

}

about_and_updates_menu := [
    ["关于", about_cb, ""],
    ["项目主页", showProjectHomepage_cb, ""],
    ["自定义帮助", help_Homepage_cb, ""],
    ; ["检查更新", NoAction_cb, ""]
]

dev_sub_menu := [
    ["ESC增强", esc_enhanced_cb, ""],
]

/**
 * ["按钮名称", 回调函数, 子菜单数组]
 */
menu_items := [
    ["UCLC v2.4.0", NoAction_cb, about_and_updates_menu],
    ["", NoAction_cb, ""],
    ["自定义别名", modify_alias_cb, ""],
    ["自定义快捷键", modify_shortcut_cb, ""],
    ["开发功能", NoAction_cb, dev_sub_menu],
    ["", NoAction_cb, ""],
    ; ["配置", disable_botton_cb, ""],
    ["Windows Spy", run_spy_cb, ""],
    ["重新载入", reload_cb, ""],
    ["禁用脚本", disable_script_cb, ""],
    ["退出", exit_cb, ""]
]


add_coustom_tray_menu()
{
    TraySetIcon("./icon/color-icon64.png")

    A_IconTip := "UCLC: 像AutoCAD一样使用CATIA"

    cus_tray_menu := Menu()

    A_TrayMenu.Delete()

    for menu_item in menu_items
    {
        button_name := menu_item[1]
        callback_function := menu_item[2]
        sub_menu_items := menu_item[3]

        if button_name == ""
        {
            A_TrayMenu.Add()
            continue
        }

        ; 如果子菜单不为空， 开始注册子菜单
        if sub_menu_items != ""
        {
            parent_button_name := button_name
            sub_menu_name := [button_name . "_sub_menu"]
            sub_menu_name[1] := Menu()

            for sub_menu_item in sub_menu_items
            {
                sub_button_name := sub_menu_item[1]
                sub_callback_function := sub_menu_item[2]
                sub_menu_name[1].Add(sub_button_name, sub_callback_function)
            }
            A_TrayMenu.Add(parent_button_name, sub_menu_name[1])
            continue
        }
        A_TrayMenu.Add(button_name, callback_function)

    }
    A_TrayMenu.Rename(menu_items[1][1], "UCLC")
}