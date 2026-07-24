#Requires AutoHotkey v2.0
#Include "UCLC_Core.ahk"
#Include "UCLC_UI.ahk"

class UCLCUpdater {
    static CheckForUpdate(isManual := false) {
        if (!AppSettings.Updater_Enabled && !isManual)
            return

        ; 判断是否满足24小时检查间隔
        if (!isManual) {
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

        this.SendAsyncRequest(isManual)
    }

    static SendAsyncRequest(isManual) {
        if (isManual) {
            try Logger.tooltip("正在检查新版本...", 1500)
        }
        try {
            req := ComObject("Msxml2.XMLHTTP")
            ; 根据 Channel 决定 API 接口
            if (AppSettings.Updater_Channel == "Stable") {
                url := "https://api.github.com/repos/zedeeee/UCLC/releases/latest"
            } else {
                url := "https://api.github.com/repos/zedeeee/UCLC/releases"
            }
            
            req.open("GET", url, true) 
            req.setRequestHeader("User-Agent", "UCLC-Updater/" . UCLC_VERSION)
            req.setRequestHeader("Cache-Control", "no-cache")
            req.onreadystatechange := ObjBindMethod(this, "OnResponse", req, isManual)
            req.send()
        } catch Error as e {
            if (isManual)
                MsgBox("创建网络请求失败: " . e.Message, "检查更新", "IconX")
        }
    }

    static OnResponse(req, isManual) {
        if (req.readyState != 4)
            return

        ; 清理 COM 对象回调引用，防止内存泄漏
        try req.onreadystatechange := ""

        if (req.status == 200) {
            try {
                response := JSON.parse(req.responseText)
                
                latestVersion := ""
                releaseNotes := ""
                downloadUrl := ""

                if (AppSettings.Updater_Channel == "Preview") {
                    ; 取返回数组的第一个元素
                    if (Type(response) == "Array" && response.Length > 0) {
                        target := response[1]
                        latestVersion := target.Has("tag_name") ? target["tag_name"] : ""
                        releaseNotes := (target.Has("body") && target["body"] != "") ? target["body"] : "暂无更新说明。"
                        downloadUrl := target.Has("html_url") ? target["html_url"] : ""
                    } else {
                        throw(Error("无法解析 Releases 数组"))
                    }
                } else {
                    ; Stable 直接返回的是单一 Object
                    latestVersion := response.Has("tag_name") ? response["tag_name"] : ""
                    releaseNotes := (response.Has("body") && response["body"] != "") ? response["body"] : "暂无更新说明。"
                    downloadUrl := response.Has("html_url") ? response["html_url"] : ""
                }
                
                ; 判断是否跳过该版本
                if (!isManual && latestVersion == AppSettings.Updater_SkippedVersion) 
                    return

                if (this.CompareVersion(latestVersion, UCLC_VERSION) > 0) {
                    ; 调用 UI
                    ShowUpdateGUI(latestVersion, UCLC_VERSION, releaseNotes, downloadUrl)
                } else if (isManual) {
                    MsgBox("当前已经是最新版本。", "检查更新", "Iconi")
                }
            } catch Error as e {
                if (isManual)
                    MsgBox("解析更新数据失败: " . e.Message, "检查更新", "IconX")
            }
        } else if (isManual) {
             MsgBox("网络请求失败，无法连接到 GitHub。状态码: " . req.status, "检查更新", "IconX")
        }
    }

    static CompareVersion(v1, v2) {
        ; 将 v1 (remote) 和 v2 (local) 的前缀 v 剔除
        v1 := RegExReplace(v1, "^v", "")
        v2 := RegExReplace(v2, "^v", "")
        
        ; 使用正则分割: 提取 major.minor.patch 和 后缀 pre-release
        RegExMatch(v1, "^(\d+)\.(\d+)\.(\d+)(?:-(.+))?$", &m1)
        RegExMatch(v2, "^(\d+)\.(\d+)\.(\d+)(?:-(.+))?$", &m2)
        
        if (!m1 || !m2) {
            ; 格式不符合则直接比对字符串
            return StrCompare(v1, v2, true)
        }

        ; 比较主、次、修订号
        loop 3 {
            val1 := Integer(m1[A_Index])
            val2 := Integer(m2[A_Index])
            if (val1 > val2)
                return 1
            if (val1 < val2)
                return -1
        }
        
        ; 数字部分相同，比较 pre-release
        pre1 := m1[4]
        pre2 := m2[4]
        
        ; 正式版 (无pre-release) 永远比 预览版 大
        if (pre1 == "" && pre2 != "")
            return 1
        if (pre1 != "" && pre2 == "")
            return -1
        if (pre1 == pre2)
            return 0
            
        ; 都带预发布后缀，提取后缀中的数字部分进行比对
        ; 为了简化，直接按照 ASCII 排序进行比对
        return StrCompare(pre1, pre2, true) > 0 ? 1 : -1
    }
}
