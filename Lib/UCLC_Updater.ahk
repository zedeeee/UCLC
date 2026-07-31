#Requires AutoHotkey v2.0
#Include "UCLC_Core.ahk"
#Include "UCLC_UI.ahk"

class UCLCUpdater {
    static isChecking := false

    static CheckForUpdate(isManual := false, parentGui := "") {
        if (this.isChecking)
            return
        if (!AppSettings.Updater_Enabled && !isManual)
            return

        ; 判断是否满足24小时检查间隔
        if (!isManual) {
            last_time := StateManager.Get("LastCheckTime", "")
            if (last_time == "" && AppSettings.Updater_LastCheckTime != "")
                last_time := AppSettings.Updater_LastCheckTime
            if (last_time != "") {
                try {
                    diff := DateDiff(A_Now, last_time, "Hours")
                    if (diff < 24)
                        return
                }
            }
        }

        ; 如果静默检查满足条件，更新 LastCheckTime
        if (!isManual) {
            AppSettings.SaveUpdaterConfig("LastCheckTime", FormatTime(A_Now, "yyyyMMddHHmmss"))
        }

        this.SendAsyncRequest(isManual, parentGui)
    }

    static SendAsyncRequest(isManual, parentGui) {
        this.isChecking := true
        if (isManual) {
            try Logger.tooltip("正在检查新版本...", 1500)
        }
        try {
            req := ComObject("Msxml2.XMLHTTP")
            ; 根据 Channel 决定 API 接口
            if (AppSettings.Updater_Channel != "Preview") {
                url := "https://api.github.com/repos/zedeeee/UCLC/releases/latest"
            } else {
                url := "https://api.github.com/repos/zedeeee/UCLC/releases"
            }
            
            req.open("GET", url, true) 
            req.setRequestHeader("User-Agent", "UCLC-Updater/" . UCLC_VERSION)
            req.setRequestHeader("Cache-Control", "no-cache")
            req.onreadystatechange := ObjBindMethod(this, "OnResponse", req, isManual, parentGui)
            req.send()
        } catch Error as e {
            this.isChecking := false
            if (isManual) {
                if (parentGui)
                    try parentGui.Opt("+OwnDialogs")
                MsgBox("创建网络请求失败: " . e.Message, "检查更新", "IconX")
            }
        }
    }

    static OnResponse(req, isManual, parentGui) {
        if (req.readyState != 4)
            return

        this.isChecking := false

        ; 清理 COM 对象回调引用，防止内存泄漏
        try req.onreadystatechange := ""

        if (req.status == 200) {
            try {
                response := JSON.parse(req.responseText)
                
                latestVersion := ""
                releaseNotes := ""
                downloadUrl := ""
                is_preview := false

                if (AppSettings.Updater_Channel == "Preview") {
                    ; 取返回数组的第一个元素
                    if (Type(response) == "Array" && response.Length > 0) {
                        target := response[1]
                        latestVersion := target.Has("tag_name") ? target["tag_name"] : ""
                        releaseNotes := (target.Has("body") && target["body"] != "") ? target["body"] : "暂无更新说明。"
                        downloadUrl := target.Has("html_url") ? target["html_url"] : ""
                        is_preview := target.Has("prerelease") ? target["prerelease"] : false
                    } else {
                        throw(Error("无法解析 Releases 数组"))
                    }
                } else {
                    ; Stable 直接返回的是单一 Object
                    latestVersion := response.Has("tag_name") ? response["tag_name"] : ""
                    releaseNotes := (response.Has("body") && response["body"] != "") ? response["body"] : "暂无更新说明。"
                    downloadUrl := response.Has("html_url") ? response["html_url"] : ""
                    is_preview := response.Has("prerelease") ? response["prerelease"] : false
                }
                
                ; 判断是否跳过该版本
                if (!isManual && latestVersion == AppSettings.Updater_SkippedVersion) 
                    return

                if (this.CompareVersion(latestVersion, UCLC_VERSION) > 0) {
                    StateManager.Set("AvailableUpdateVersion", latestVersion)
                    StateManager.Set("LatestReleaseNotes", releaseNotes)
                    StateManager.Set("LatestDownloadUrl", downloadUrl)
                    StateManager.Set("LatestIsPreview", is_preview ? "1" : "0")
                    if IsSet(add_coustom_tray_menu)
                        try add_coustom_tray_menu()
                    if IsSet(SettingsController)
                        try SettingsController.RefreshUpdateNotice()
                    
                    if (!isManual) {
                        lastVer := StateManager.Get("LastPromptVersion", "")
                        lastDate := StateManager.Get("LastPromptDate", "")
                        today := FormatTime(A_Now, "yyyyMMdd")
                        if (latestVersion == lastVer && today == lastDate)
                            return
                        StateManager.Set("LastPromptVersion", latestVersion)
                        StateManager.Set("LastPromptDate", today)
                        ver_tag := is_preview ? " [预览版]" : " [稳定版]"
                        try TrayTip("✨ 发现新版本 " latestVersion ver_tag, "【UCLC】更新提醒", "Iconi")
                    } else {
                        if IsSet(ShowUpdateGUI)
                            try ShowUpdateGUI(latestVersion, UCLC_VERSION, releaseNotes, downloadUrl, parentGui)
                    }
                } else {
                    StateManager.Set("AvailableUpdateVersion", "")
                    if IsSet(add_coustom_tray_menu)
                        try add_coustom_tray_menu()
                    if IsSet(SettingsController)
                        try SettingsController.RefreshUpdateNotice()
                    if (isManual) {
                        if (parentGui)
                            try parentGui.Opt("+OwnDialogs")
                        MsgBox("当前已经是最新版本。", "检查更新", "Iconi")
                    }
                }
            } catch Error as e {
                if (isManual) {
                    if (parentGui)
                        try parentGui.Opt("+OwnDialogs")
                    MsgBox("解析更新数据失败: " . e.Message, "检查更新", "IconX")
                }
            }
        } else if (isManual) {
            if (parentGui)
                try parentGui.Opt("+OwnDialogs")
            MsgBox("网络请求失败，无法连接到 GitHub。状态码: " . req.status, "检查更新", "IconX")
        }
    }

    static CompareVersion(v1, v2) {
        ; 将 v1 (remote) 和 v2 (local) 的前缀 v 剔除
        v1 := RegExReplace(v1, "^v", "")
        v2 := RegExReplace(v2, "^v", "")
        
        ; 匹配主、次、修订号，并可选提取 -[数字]-g[hash] 形式的 commit count
        RegExMatch(v1, "^(\d+)\.(\d+)\.(\d+)(?:-(\d+)-g[a-f0-9]+)?", &m1)
        RegExMatch(v2, "^(\d+)\.(\d+)\.(\d+)(?:-(\d+)-g[a-f0-9]+)?", &m2)
        
        if (!m1 || !m2) {
            ; 格式不符合则直接比对字符串
            return StrCompare(v1, v2, true)
        }

        ; 1. 比较主、次、修订号
        loop 3 {
            val1 := Integer(m1[A_Index])
            val2 := Integer(m2[A_Index])
            if (val1 > val2)
                return 1
            if (val1 < val2)
                return -1
        }
        
        ; 2. 比较 commit_count (m[4])
        count1 := m1[4] == "" ? 0 : Integer(m1[4])
        count2 := m2[4] == "" ? 0 : Integer(m2[4])
        
        if (count1 > count2)
            return 1
        if (count1 < count2)
            return -1
            
        return 0
    }
}
