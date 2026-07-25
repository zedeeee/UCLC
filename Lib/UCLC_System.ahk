#Requires AutoHotkey v2.0

class Logger {
    static tooltip(message, delay_ms) {
        ToolTip(message)
        SetTimer(() => ToolTip(), delay_ms > 0 ? -delay_ms : delay_ms)
    }

    static info(message) {
        if !AppSettings.DEBUG_I
            return
        this.tooltip(message, 3000)
    }
}

class IMEController {
    static ime_map := Map("zh", 0x8040804, "en", 0x4090409)

    static get_current_ime_id() {
        if WinWaitActive("A", , 3) {
            try {
                active_hwnd := WinGetID("A")
                thread_id := DllCall("GetWindowThreadProcessId", "UInt", active_hwnd, "UInt", 0)
                ime_locale_id := DllCall("GetKeyboardLayout", "Uint", thread_id, "Uint")
                return Format("{1:#x}", ime_locale_id)
            }
            catch Error as e {
                Logger.tooltip("输入法获取失败：" . e.Message, 2000)
                return false
            }
        }
    }

    static switch_ime(ime_id) {
        PostMessage(0x0050, 0, ime_id, , "A")
    }

    static confirm_ime(*) {
        ime_id := this.get_current_ime_id()
        if !ime_id
            return

        if ime_id != this.ime_map["en"]
            Logger.tooltip("输入法自动切换失败，请检查系统设置", 2000)
    }
}

class Downloader {
    static download_file(url, save_path) {
        temp := A_Temp . "\uclc-download.temp"
        try {
            Download(url, temp)
            FileMove(temp, save_path, true)
            return true
        }
        catch Error as e {
            return false
        }
    }

    static download_configurations(file_name, save_path) {
        github_url := Format("https://github.com/zedeeee/UCLC-config/raw/master/{1}", file_name)
        gitee_url := Format("https://gitee.com/zedeeee/UCLC-config/raw/master/{1}", file_name)

        Logger.tooltip(Format("尝试从Github下载{1}", file_name), 3000)
        Sleep(3000)
        if this.download_file(github_url, save_path) {
            return true
        } else {
            Logger.tooltip(Format("从Github下载失败，尝试从Gitee获取{1}", file_name), 3000)
            Sleep(3000)
            return this.download_file(gitee_url, save_path)
        }
    }
}

class WindowManager {
    static add_group_by_exe(group_name, section) {
        if (AppSettings.config_obj.Has(section)) {
            for key, exe in AppSettings.config_obj[section] {
                if (key != "Enabled") {
                    GroupAdd(group_name, "ahk_exe " . exe)
                }
            }
        }
    }

    static get_window_text_fast(detect_hidden) {
        controls := WinGetControlsHwnd()
        static WINDOW_TEXT_SIZE := 32767

        buf := Buffer(WINDOW_TEXT_SIZE * 2, 0)
        text := ""

        for hCtl in controls {
            if !detect_hidden && !DllCall("IsWindowVisible", "ptr", hCtl)
                continue
            if !DllCall("GetWindowText", "ptr", hCtl, "Ptr", buf.ptr, "int", WINDOW_TEXT_SIZE)
                continue
            text .= StrGet(buf) "`r`n"
        }
        return text
    }
}

class VolumeController {
    __New() {
        this.last_tick := A_TickCount
        this.base_increment := 1
        this.min_interval := 10
        this.max_interval := 20
        this.min_multiplier := 1
        this.max_multiplier := 7
        this.k := 1.5
    }

    get_volume_increment() {
        current_tick := A_TickCount
        interval := current_tick - this.last_tick
        this.last_tick := current_tick

        if (interval > 0) {
            if (interval < this.min_interval) {
                multiplier := this.max_multiplier
            } else if (interval > this.max_interval) {
                multiplier := this.min_multiplier
            } else {
                scaled_interval := (interval - this.min_interval) / (this.max_interval - this.min_interval)
                sigmoid_input := (scaled_interval - 0.5) * this.k
                sigmoid_output := 1 / (1 + Exp(-sigmoid_input))
                multiplier := this.min_multiplier + (this.max_multiplier - this.min_multiplier) * sigmoid_output
            }
        } else {
            multiplier := this.min_multiplier
        }

        return Round(this.base_increment * multiplier, 2)
    }

    show_volume_status() {
        current_volume := SoundGetVolume()
        mute_status := SoundGetMute() ? "(静音)" : ""
        Logger.tooltip(Format("当前音量：{} {}", Integer(current_volume), mute_status), 1000)
    }
}

class ShortcutManager {
    static GetIconPath() {
        icon_file := A_ScriptDir "\icon\UCLC.ico"
        if !FileExist(icon_file)
            icon_file := A_IsCompiled ? A_ScriptFullPath : A_AhkPath
        return icon_file
    }

    static Create(dest_path, success_msg := "") {
        try {
            FileCreateShortcut(A_ScriptFullPath, dest_path, A_ScriptDir, "", "UCLC - 像 AutoCAD 一样使用 CATIA", this.GetIconPath())
            if (success_msg != "")
                Logger.tooltip(success_msg, 2000)
            return true
        } catch Error as e {
            Logger.tooltip("创建快捷方式失败：" . e.Message, 3000)
            return false
        }
    }

    static CreateDesktopShortcut() {
        return this.Create(A_Desktop "\UCLC.lnk", "桌面快捷方式创建成功！")
    }
}

class StartupManager {
    static lnkPath := A_Startup "\UCLC.lnk"

    static IsEnabled() {
        return FileExist(this.lnkPath) != "" ? 1 : 0
    }

    static SetStartup(enable := true) {
        if (enable) {
            return ShortcutManager.Create(this.lnkPath, "已开启开机自动启动")
        } else {
            if FileExist(this.lnkPath) {
                try {
                    FileDelete(this.lnkPath)
                    Logger.tooltip("已取消开机自动启动", 2000)
                    return true
                } catch Error as e {
                    Logger.tooltip("取消开机自启失败：" . e.Message, 3000)
                    return false
                }
            }
            return true
        }
    }
}