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
    current_path := AppSettings.Everything_Path
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
            config_path := AppSettings.config_json_path

            ; 更新内存中的配置对象
            if !AppSettings.config_obj.Has("Everything")
                AppSettings.config_obj["Everything"] := Map()
                
            AppSettings.config_obj["Everything"]["Enabled"] := String(SettingsGui["EverythingEnabled"].Value)
            AppSettings.config_obj["Everything"]["Path"] := SettingsGui["EverythingPath"].Value

            ; 将配置对象序列化为 JSON
            json_str := JSON.stringify(AppSettings.config_obj)

            if FileExist(config_path)
                FileDelete(config_path)

            FileAppend(json_str, config_path, "UTF-8")

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
