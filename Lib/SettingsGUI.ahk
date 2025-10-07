#Include AppSettings.ahk

ShowSettingsGUI(*) {
    ; 如果设置窗口已存在，则激活它，避免多开
    if WinExist("UCLC 设置") {
        WinActivate("UCLC 设置")
        return
    }

    ; 创建 GUI 窗口
    SettingsGui := Gui("+AlwaysOnTop", "UCLC 设置")

    ; --- Everything 功能区 ---
    SettingsGui.Add("GroupBox", "x10 y10 w380 h100", "Everything 快速启动")

    ; 1. 添加复选框
    ; 直接使用 AppSettings 中已加载的运行时变量，并使用测试有效的 .Value 属性
    SettingsGui.Add("Checkbox", "x20 y30 vEverythingEnabled", "启用“双击右Ctrl”呼出 Everything").Value := AppSettings.Everything_Enabled

    ; 2. 添加路径输入框和浏览按钮
    current_path := IniRead(AppSettings.config_ini_path, "Everything", "Path", "")
    SettingsGui.Add("Text", "x20 y60", "路径:")
    SettingsGui.Add("Edit", "x60 y58 w240 vEverythingPath", current_path)
    SettingsGui.Add("Button", "x310 y58 w70", "浏览...").OnEvent("Click", BrowseForEverything)

    ; --- 保存和取消按钮 ---
    SettingsGui.Add("Button", "x180 y120 w100 Default", "保存").OnEvent("Click", SaveSettings)
    SettingsGui.Add("Button", "x290 y120 w100", "取消").OnEvent("Click", CancelSettings)

    SettingsGui.Show("w400")

    ; --- GUI 事件处理 ---
    BrowseForEverything(*) {
        SettingsGui.Opt("+Disabled -AlwaysOnTop")
        path := FileSelect(,, "请选择 Everything.exe", "程序 (*.exe)")
        SettingsGui.Opt("-Disabled +AlwaysOnTop")
        if path {
            SettingsGui["EverythingPath"].Value := path
        }
    }

    SaveSettings(*) {
        try
        {
            config_path := AppSettings.config_ini_path

            ; 检查 [Everything] section 是否存在
            all_sections := IniRead(config_path)
            if !InStr(all_sections, "Everything")
            {
                ; 如果不存在，在写入前先在文件末尾追加一个换行符
                FileAppend("`r`n", config_path)
            }

            ; 将 GUI 上的值写入 config.ini
            IniWrite(SettingsGui["EverythingEnabled"].Value, config_path, "Everything", "Enabled")
            IniWrite(SettingsGui["EverythingPath"].Value, config_path, "Everything", "Path")

            ; 同步更新 AppSettings 中的静态变量，使其立即生效
            AppSettings.Everything_Enabled := SettingsGui["EverythingEnabled"].Value
            AppSettings.Everything_Path := SettingsGui["EverythingPath"].Value

            ; 保存成功后，直接销毁窗口
            SettingsGui.Destroy()
        }
        catch as e
        {
            MsgBox "保存设置失败！`n`n错误信息: " e.Message, "错误", 16
        }
    }

    CancelSettings(*) {
        SettingsGui.Destroy()
    }
}
