#Requires AutoHotkey v2.0

/**
 * ConfigDownloaderGUI 类
 *
 * 创建并管理一个 GUI 窗口，用于在主配置文件缺失时引导用户下载它们。
 * 特性:
 * - 可选择从 Gitee 或 Github 下载。
 * - 分别下载别名和热键配置文件。
 * - 提供打开用户配置文件夹的快捷方式。
 * - 显示下载状态和进度。
 */
class ConfigDownloaderGUI {
    ; 仓库基础 URL
    static base_urls := Map(
        "Gitee", "https://gitee.com/zedeeee/UCLC-config/raw/master/",
        "Github", "https://raw.githubusercontent.com/zedeeee/UCLC-config/master/"
    )

    /**
     * 构造函数 - 初始化 GUI 界面
     */
    __New() {
        this.gui := Gui(, "UCLC 配置文件下载器")
        this.gui.OnEvent("Close", this.ExitGUI.Bind(this))
        this.gui.MarginX := 10
        this.gui.MarginY := 10
        this.gui.SetFont("s10", "Microsoft YaHei UI")

        ; --- GUI 控件定义 (使用布局管理器) ---
        this.gui.Add("GroupBox", "w400 Section", "1. 选择下载源")
        this.gui.Add("Radio", "vSource Checked xp+10 yp+25", "Gitee (国内用户推荐)")
        this.gui.Add("Radio", "x+20", "Github")

        this.gui.Add("GroupBox", "w400 xs y+15", "2. 下载配置文件")
        this.gui.Add("Button", "w185 h30 vAliasBtn xp+10 yp+25", "下载别名配置").OnEvent("Click", this.download_alias.Bind(this))
        this.gui.Add("Button", "x+10 yp w185 h30 vHotkeyBtn", "下载热键配置").OnEvent("Click", this.download_hotkey.Bind(this))

        this.gui.Add("Text", "xs y+15", "下载进度:")
        this.gui.Add("Progress", "w400 h20 vProgressBar", 0)
        this.gui.Add("Text", "w400 h20 vStatusText", "准备就绪...")

        this.gui.Add("GroupBox", "w400 xs y+15", "3. 其他操作")
        this.gui.Add("Button", "w185 h30 xp+10 yp+25", "打开配置文件夹").OnEvent("Click", this.OpenConfigFolder.Bind(this))
        this.gui.Add("Button", "x+10 yp w185 h30", "完成并退出").OnEvent("Click", this.ExitGUI.Bind(this))

        local_dir := ""
        SplitPath(AppSettings.alias_ini_path, , &local_dir) ; 提取目录路径
        this.user_config_dir := local_dir
        this.check_existing_files()
    }

    /**
     * 显示 GUI 窗口 (模式)
     */
    Show() {
        ; this.gui.Show("Modal")
        this.gui.Show("AutoSize Center")
    WinWaitClose(this.gui.Hwnd)
    }

    /**
     * 检查现有文件并禁用相应的下载按钮
     */
    check_existing_files() {
        if FileExist(AppSettings.alias_ini_path) {
            this.gui["AliasBtn"].Text := "重新下载别名配置"
        } else {
            this.gui["AliasBtn"].Text := "下载别名配置"
        }
        if FileExist(AppSettings.hotkey_ini_path) {
            this.gui["HotkeyBtn"].Text := "重新下载热键配置"
        } else {
            this.gui["HotkeyBtn"].Text := "下载热键配置"
        }
    }

    /**
     * 事件处理器: 关闭窗口或点击退出
     */
    ExitGUI(*) {
        ; 检查是否所有文件都已存在
        if (FileExist(AppSettings.alias_ini_path) and FileExist(AppSettings.hotkey_ini_path)) {
            MsgBox "配置完成！脚本将重新加载以应用更改。", "提示", 4096
            Reload
        } else {
            if (MsgBox("仍有配置文件缺失，确定要退出吗？", "确认", 36) = "Yes") {
                ExitApp
            }
        }
    }

    /**
     * 事件处理器: 打开配置文件夹
     */
    OpenConfigFolder(*) {
        try {
            if DirExist(this.user_config_dir) {
                Run(this.user_config_dir)
            } else {
                if (MsgBox("配置文件夹不存在，是否立即创建？", "确认", 36) = "Yes") {
                    try {
                        DirCreate(this.user_config_dir)
                        Run(this.user_config_dir)
                    } catch {
                        MsgBox "错误：无法创建配置文件夹，请检查权限。", "错误", 16
                    }
                }
            }
        } catch {
            MsgBox "错误：无法打开或创建配置文件夹。", "错误", 16
        }
    }

    /**
     * 事件处理器: 下载别名配置
     */
    download_alias(*) {
        this.download_file("alias.ini", AppSettings.alias_ini_path)
    }

    /**
     * 事件处理器: 下载热键配置
     */
    download_hotkey(*) {
        this.download_file("hotkey.ini", AppSettings.hotkey_ini_path)
    }

    /**
     * 核心下载逻辑
     * @param file_name 要下载的文件名 (e.g., "CAT_Alias.ini")
     * @param dest_path 文件的本地保存路径
     */
    download_file(file_name, dest_path) {
        ; 如果文件已存在，则警告并备份
        if FileExist(dest_path) {
            timestamp := FormatTime(, "yyyyMMddHHmmss")
            backup_path := dest_path . "." . timestamp . ".bak"

            confirm_msg := "配置文件 '" . file_name . "' 已存在。"
                        . "`n`n重新下载将覆盖您当前的设置。"
                        . "`n`n现有文件将被备份为:`n" . backup_path
                        . "`n`n是否继续？"

            if (MsgBox(confirm_msg, "确认覆盖", 36) = "No") {
                this.gui["StatusText"].Text := "重新下载已取消。"
                return
            }

            try {
                FileMove(dest_path, backup_path)
            } catch {
                MsgBox "错误：无法创建备份文件，下载已中止。", "错误", 16
                return
            }
        }

        ; 获取用户选择的下载源
        source_name := (this.gui["Source"].Value == 1) ? "Gitee" : "Github"
        url := ConfigDownloaderGUI.base_urls[source_name] . file_name

        ; 检查并创建目录
        if !DirExist(this.user_config_dir) {
            if (MsgBox("配置文件夹不存在，需要创建它才能继续下载。`n`n是否立即创建？", "确认", 36) = "No") {
                this.gui["StatusText"].Text := "下载已取消（用户拒绝创建文件夹）。"
                return
            }
            try {
                DirCreate(this.user_config_dir)
            } catch {
                MsgBox "错误：无法创建配置文件夹，请检查权限。下载已中止。", "错误", 16
                return
            }
        }

        ; 更新 UI 状态
        this.gui["StatusText"].Text := "正在从 " . source_name . " 下载 " . file_name . "..."
        this.gui["ProgressBar"].Value := 0
        this.set_buttons_enabled(false)

        try {
            req := ComObject("WinHttp.WinHttpRequest.5.1")

            ; --- 最终代理解决方案: 直接读取IE/WinINET代理设置 ---
            proxy_enable := 0
            proxy_server := ""
            try {
                proxy_enable := RegRead("HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings", "ProxyEnable")
                if (proxy_enable = 1) {
                    proxy_server := RegRead("HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings", "ProxyServer")
                }
            } catch {
                ; 无法读取注册表，忽略错误并继续
            }

            if (proxy_enable = 1 && proxy_server != "") {
                req.SetProxy(2, proxy_server) ; 2 = HTTPREQUEST_PROXYSETTING_PROXY
            } else {
                req.SetProxy(0) ; 作为备用方案，尝试自动检测
            }
            ; --- 代理解决方案结束 ---

            req.Open("GET", url, false) ; 同步
            req.Send()

            if (req.Status == 200) {
                ; 使用 ADODB.Stream 保存二进制数据以确保编码正确
                stream := ComObject("ADODB.Stream")
                stream.Type := 1 ; adTypeBinary
                stream.Open()
                stream.Write(req.ResponseBody)
                stream.SaveToFile(dest_path, 2) ; 2 = adSaveCreateOverWrite
                stream.Close()

                this.gui["StatusText"].Text := file_name . " 下载成功！"
                this.gui["ProgressBar"].Value := 100
                this.check_existing_files() ; 再次检查，更新按钮状态
            } else {
                this.gui["StatusText"].Text := "下载失败，服务器返回状态码: " . req.Status
                MsgBox "下载失败，请检查网络连接或尝试更换下载源。", "错误", 16
            }
        } catch as e {
            this.gui["StatusText"].Text := "下载出错，请检查网络或防火墙设置。"
            MsgBox "下载过程中发生错误: `n" . e.Message, "错误", 16
        } finally {
            this.set_buttons_enabled(true)
        }
    }

    /**
     * 统一设置按钮的可用状态
     * @param is_enabled true 为启用, false 为禁用
     */
    set_buttons_enabled(is_enabled) {
        this.gui["AliasBtn"].Enabled := is_enabled
        this.gui["HotkeyBtn"].Enabled := is_enabled
    }
}
