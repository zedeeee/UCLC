#Requires AutoHotkey v2.0

#Include "JSON.ahk"
#Include "Version.ahk"
#Include "UCLC_System.ahk"

;-==== [ 原模块: AppSettings.ahk ] ====-
class AppSettings {
    static DefaultConfigDir := A_AppData "\UCLC"
    static ConfigDir := ""
    static config_json_path := ""
    static commands_json_path := ""

    static config_obj := Map()
    static commands_obj := Map()
    static alias_obj := Map()
    static hotkey_obj := Map()

    static alias_ini_path := ""
    static hotkey_ini_path := ""

    static DEBUG_I := ""
    static workbench_list := Map()
    static current_workbench := ""
    static Everything_Enabled := 0
    static AutoIME_Enabled := 1
    static Version := UCLC_VERSION
    static Everything_Path := ""
    static Everything_Hotkey := ""

    static Volume_Enabled := 0
    static Calc_Enabled := 0
    static Calc_Hotkey := ""

    static Updater_Enabled := 1
    static Updater_Channel := "Preview"
    static Updater_LastCheckTime := ""
    static Updater_SkippedVersion := ""

    static workbench_mapping := Map()

    static LoadWorkbenchMapping() {
        mapping_file := A_ScriptDir "\data\workbench_mapping.json"
        if FileExist(mapping_file) {
            try {
                text := FileRead(mapping_file, "UTF-8")
                parsed := JSON.parse(text)
                this.workbench_mapping := parsed.Has("mapping") ? parsed["mapping"] : parsed
            } catch {
                this.workbench_mapping := Map()
            }
        } else {
            this.workbench_mapping := Map()
        }
    }

    static GetWbName(id, lang := "Simplified_Chinese") {
        if this.workbench_mapping.Has(id) {
            if this.workbench_mapping[id].Has(lang) {
                return this.workbench_mapping[id][lang]
            }
            if this.workbench_mapping[id].Has("English") {
                return this.workbench_mapping[id]["English"]
            }
        }
        return id
    }

    static GetWbIdByUI(name) {
        ; 解决 CATIA 多工作台同名（如 Drafting 背景和主工作台都叫“工程制图”）导致反查 ID 不准的问题
        static canonical_map := Map(
            "工程制图", "CATDrwDrwWkb",
            "Drafting", "CATDrwDrwWkb",
            "零件设计", "CATPcfPartWkb",
            "Part Design", "CATPcfPartWkb"
        )
        if canonical_map.Has(name) {
            return canonical_map[name]
        }

        for id, langs in this.workbench_mapping {
            for lang, val in langs {
                if (val == name) {
                    return id
                }
            }
        }
        return name
    }

    static Init() {
        if !DirExist(this.DefaultConfigDir)
            try DirCreate(this.DefaultConfigDir)

        this.ConfigDir := this.DefaultConfigDir
        default_config_path := this.DefaultConfigDir "\config.json"

        ; 只要在根目录下发现 config.ini 就将其迁移到 AppData 目录下的 config.json
        if (FileExist(A_ScriptDir "\config.ini")) {
            ConfigMigrator.MigrateIniToJson(A_ScriptDir "\config.ini", default_config_path)
        }

        ; 场景 3：旧版 v3 JSON 继承（从项目根目录迁移到 AppData 目录，完成无感继承）
        old_config_path := A_ScriptDir "\config.json"
        if (FileExist(old_config_path) && old_config_path != default_config_path) {
            try {
                if (!FileExist(default_config_path))
                    FileCopy(old_config_path, default_config_path, true)
                FileMove(old_config_path, old_config_path ".bak", true)
            }
        }

        ; 读取默认目录的全局配置
        if (FileExist(default_config_path)) {
            text := FileRead(default_config_path, "UTF-8")
            this.config_obj := JSON.parse(text)
        } else {
            this.config_obj := Map(
                "通用", Map("DEBUG", "0"),
                "UserConf", Map("命令配置", "commands.json", "配置目录", ""),
                "Everything", Map("Enabled", "0", "Path", "", "Hotkey", ""),
                "AutoIME", Map(
                    "AUTOCAD", "ACAD.exe",
                    "CATIA", "CNEXT.exe"
                )
            )
            FileAppend(JSON.stringify(this.config_obj), default_config_path, "UTF-8")
        }

        ; 检查用户是否自定义了配置存储/网盘同步目录
        custom_dir := ""
        if (this.config_obj.Has("UserConf") && this.config_obj["UserConf"].Has("配置目录")) {
            custom_dir := Trim(this.config_obj["UserConf"]["配置目录"])
        }
        if (custom_dir != "" && DirExist(custom_dir)) {
            this.ConfigDir := custom_dir
        } else if (custom_dir != "") {
            try {
                DirCreate(custom_dir)
                this.ConfigDir := custom_dir
            } catch {
                this.ConfigDir := this.DefaultConfigDir
            }
        } else {
            this.ConfigDir := this.DefaultConfigDir
        }
        this.config_json_path := this.ConfigDir "\config.json"

        ; 若启用外部自定义目录且存在独立 config.json，载入该同步配置
        if (this.ConfigDir != this.DefaultConfigDir && FileExist(this.config_json_path)) {
            try {
                text := FileRead(this.config_json_path, "UTF-8")
                this.config_obj := JSON.parse(text)
            }
        }

        commands_file := "commands.json"
        if (this.config_obj.Has("UserConf") && this.config_obj["UserConf"].Has("命令配置")) {
            commands_file := this.config_obj["UserConf"]["命令配置"]
        }
        this.commands_json_path := this.ConfigDir "\" commands_file

        ; 场景 3：旧版 v3 user-config/commands.json 或旧根目录下文件继承到新目录
        old_cmd_path1 := A_ScriptDir "\user-config\" commands_file
        old_cmd_path2 := A_ScriptDir "\" commands_file
        if (!FileExist(this.commands_json_path)) {
            if (FileExist(old_cmd_path1)) {
                try {
                    FileCopy(old_cmd_path1, this.commands_json_path, true)
                    FileMove(old_cmd_path1, old_cmd_path1 ".bak", true)
                }
            } else if (FileExist(old_cmd_path2)) {
                try {
                    FileCopy(old_cmd_path2, this.commands_json_path, true)
                    FileMove(old_cmd_path2, old_cmd_path2 ".bak", true)
                }
            }
        }

        ; 场景 2：参照 v2.4.2 逻辑，根据字段动态解析旧 INI 并转译至 commands.json（保留原文件追加 .bak）
        alias_name := "alias.ini"
        hotkey_name := "hotkey.ini"
        if (this.config_obj.Has("UserConf")) {
            if (this.config_obj["UserConf"].Has("用户别名"))
                alias_name := this.config_obj["UserConf"]["用户别名"]
            if (this.config_obj["UserConf"].Has("快捷键"))
                hotkey_name := this.config_obj["UserConf"]["快捷键"]
        }
        if (alias_name = "alias.ini" && FileExist(A_ScriptDir "\config.ini.bak")) {
            try alias_name := IniRead(A_ScriptDir "\config.ini.bak", "UserConf", "用户别名", "alias.ini")
            try hotkey_name := IniRead(A_ScriptDir "\config.ini.bak", "UserConf", "快捷键", "hotkey.ini")
        }
        alias_name := StrReplace(alias_name, ".json", ".ini")
        hotkey_name := StrReplace(hotkey_name, ".json", ".ini")

        alias_ini_path := ""
        hotkey_ini_path := ""
        if FileExist(A_ScriptDir "\user-config\" alias_name)
            alias_ini_path := A_ScriptDir "\user-config\" alias_name
        else if FileExist(A_ScriptDir "\" alias_name)
            alias_ini_path := A_ScriptDir "\" alias_name

        if FileExist(A_ScriptDir "\user-config\" hotkey_name)
            hotkey_ini_path := A_ScriptDir "\user-config\" hotkey_name
        else if FileExist(A_ScriptDir "\" hotkey_name)
            hotkey_ini_path := A_ScriptDir "\" hotkey_name

        this.alias_ini_path := alias_ini_path
        this.hotkey_ini_path := hotkey_ini_path

        this.LoadWorkbenchMapping()

        if (!FileExist(this.commands_json_path) && (alias_ini_path != "" || hotkey_ini_path != "")) {
            if (ConfigMigrator.MigrateV2IniToCommandsJson(alias_ini_path, hotkey_ini_path, this.commands_json_path)) {
                if (alias_ini_path != "" && FileExist(alias_ini_path))
                    try FileMove(alias_ini_path, alias_ini_path ".bak", true)
                if (hotkey_ini_path != "" && FileExist(hotkey_ini_path))
                    try FileMove(hotkey_ini_path, hotkey_ini_path ".bak", true)
            }
        }

        ; 载入 JSON 到内存树
        if (FileExist(this.commands_json_path)) {
            this.commands_obj := JSON.parse(FileRead(this.commands_json_path, "UTF-8"))
        } else {
            this.commands_obj := Map()
        }

        ; 自动升维（迁移）：将旧版中文名的 Key 替换为 Internal ID
        migrated := false
        new_commands_obj := Map()
        for k, v in this.commands_obj {
            if (k == "_comment") {
                new_commands_obj[k] := v
                continue
            }
            id := this.GetWbIdByUI(k)
            if (id != k) {
                migrated := true
            }
            new_commands_obj[id] := v
        }

        if (migrated) {
            this.commands_obj := new_commands_obj
            try {
                this.FlushCommands()
            }
        }

        ; 内存反向映射，向下兼容核心执行引擎
        this.alias_obj := Map()
        this.hotkey_obj := Map()

        for wb, cmdArray in this.commands_obj {
            this.alias_obj[wb] := Map()
            this.hotkey_obj[wb] := Map()

            for cmd in cmdArray {
                if (cmd.Has("aliases")) {

                    for alias in cmd["aliases"] {
                        this.alias_obj[wb][alias] := cmd
                    }
                }
                if (cmd.Has("hotkeys")) {
                    for hotkey in cmd["hotkeys"] {
                        this.hotkey_obj[wb][hotkey] := cmd
                    }
                }
            }
        }

        ; 读取常规设置
        this.DEBUG_I := this.config_obj.Has("通用") && this.config_obj["通用"].Has("DEBUG") ? this.config_obj["通用"]["DEBUG"
            ] : 0
        this.Everything_Enabled := this.config_obj.Has("Everything") && this.config_obj["Everything"].Has("Enabled") ?
            Integer(this.config_obj["Everything"]["Enabled"]) : 0
        this.Everything_Path := this.config_obj.Has("Everything") && this.config_obj["Everything"].Has("Path") ? this.config_obj[
            "Everything"]["Path"] : ""
        this.Everything_Hotkey := this.config_obj.Has("Everything") && this.config_obj["Everything"].Has("Hotkey") ? this.config_obj[
            "Everything"]["Hotkey"] : ""
        if (this.Everything_Path == "" || !FileExist(this.Everything_Path)) {
            auto_p := this.FindEverythingPath()
            if (auto_p != "")
                this.Everything_Path := auto_p
        }
        if (this.Everything_Hotkey == "") {
            ini_hk := this.ReadEverythingHotkeyFromIni(this.Everything_Path)
            if (ini_hk != "") {
                this.Everything_Hotkey := ini_hk
            }
        }
        this.AutoIME_Enabled := this.config_obj.Has("AutoIME") && this.config_obj["AutoIME"].Has("Enabled") ?
            this.config_obj["AutoIME"]["Enabled"] : 1

        this.Volume_Enabled := this.config_obj.Has("Volume") && this.config_obj["Volume"].Has("Enabled") ?
            Integer(this.config_obj["Volume"]["Enabled"]) : 0
        this.Calc_Enabled := this.config_obj.Has("Calculator") && this.config_obj["Calculator"].Has("Enabled") ?
            Integer(this.config_obj["Calculator"]["Enabled"]) : 0
        this.Calc_Hotkey := this.config_obj.Has("Calculator") && this.config_obj["Calculator"].Has("Hotkey") ?
            this.config_obj["Calculator"]["Hotkey"] : ""

        this.Updater_Enabled := this.config_obj.Has("Updater") && this.config_obj["Updater"].Has("Enabled") ?
            Integer(this.config_obj["Updater"]["Enabled"]) : 1
        this.Updater_Channel := this.config_obj.Has("Updater") && this.config_obj["Updater"].Has("Channel") ?
            this.config_obj["Updater"]["Channel"] : "Preview"
        this.Updater_LastCheckTime := this.config_obj.Has("Updater") && this.config_obj["Updater"].Has("LastCheckTime") ?
            this.config_obj["Updater"]["LastCheckTime"] : ""
        this.Updater_SkippedVersion := this.config_obj.Has("Updater") && this.config_obj["Updater"].Has("SkippedVersion") ?
            this.config_obj["Updater"]["SkippedVersion"] : ""

        ; 初始化工作台列表
        this.workbench_list := Map()
        if (this.hotkey_obj != "") {
            for wb, _ in this.hotkey_obj {
                this.workbench_list[wb] := ""
            }
        }

        this.current_workbench := ""
    }

    static SaveUpdaterConfig(key, value) {
        if (!this.config_obj.Has("Updater")) {
            this.config_obj["Updater"] := Map()
        }
        this.config_obj["Updater"][key] := value

        if (key == "Enabled")
            this.Updater_Enabled := Integer(value)
        else if (key == "Channel")
            this.Updater_Channel := value
        else if (key == "LastCheckTime")
            this.Updater_LastCheckTime := value
        else if (key == "SkippedVersion")
            this.Updater_SkippedVersion := value

        try {
            this.FlushConfig()
        } catch Error as e {
            Logger.info("保存 Updater 配置失败: " . e.Message)
        }
    }

    static _atomic_write(filepath, content) {
        tmp_path := filepath . ".tmp"
        bak_path := filepath . ".bak"
        if FileExist(tmp_path)
            FileDelete(tmp_path)
        f := FileOpen(tmp_path, "w", "UTF-8")
        f.Write(content)
        f.Close()
        has_orig := FileExist(filepath)
        if (has_orig)
            FileCopy(filepath, bak_path, 1)
        try {
            FileMove(tmp_path, filepath, 1)
            return true
        } catch Error as err {
            if (has_orig && FileExist(bak_path))
                FileCopy(bak_path, filepath, 1)
            throw Error("文件原子写入失败: " err.Message)
        }
    }

    static FlushConfig() {
        this._atomic_write(this.config_json_path, JSON.stringify(this.config_obj))
        if (this.ConfigDir != "" && this.ConfigDir != this.DefaultConfigDir && DirExist(this.DefaultConfigDir)) {
            try this._atomic_write(this.DefaultConfigDir "\config.json", JSON.stringify(this.config_obj))
        }
    }

    static FlushCommands() {
        this._atomic_write(this.commands_json_path, JSON.stringify(this.commands_obj))
    }

    static SaveConfigDir(new_dir) {
        new_dir := Trim(new_dir)
        if (new_dir == "")
            new_dir := this.DefaultConfigDir
        if !DirExist(new_dir) {
            try DirCreate(new_dir)
        }
        if !DirExist(new_dir)
            throw Error("无法创建自定义目标目录: " new_dir)

        if (!FileExist(new_dir "\config.json") && FileExist(this.config_json_path))
            try FileCopy(this.config_json_path, new_dir "\config.json", false)
        if (!FileExist(new_dir "\commands.json") && FileExist(this.commands_json_path))
            try FileCopy(this.commands_json_path, new_dir "\commands.json", false)

        this.ConfigDir := new_dir
        this.config_json_path := new_dir "\config.json"
        this.commands_json_path := new_dir "\commands.json"

        if !this.config_obj.Has("UserConf")
            this.config_obj["UserConf"] := Map()
        this.config_obj["UserConf"]["配置目录"] := (new_dir == this.DefaultConfigDir) ? "" : new_dir

        this._atomic_write(this.DefaultConfigDir "\config.json", JSON.stringify(this.config_obj))
        if (new_dir != this.DefaultConfigDir)
            this._atomic_write(this.config_json_path, JSON.stringify(this.config_obj))
    }

    static ExportConfig(target_dir) {
        target_dir := Trim(target_dir)
        if (target_dir == "")
            return false
        if !DirExist(target_dir) {
            try DirCreate(target_dir)
        }
        if !DirExist(target_dir)
            throw Error("无法创建或访问目标备份目录: " target_dir)

        this.FlushConfig()
        this.FlushCommands()

        if FileExist(this.config_json_path)
            FileCopy(this.config_json_path, target_dir "\config.json", true)
        if FileExist(this.commands_json_path)
            FileCopy(this.commands_json_path, target_dir "\commands.json", true)
        return true
    }

    static ImportConfig(source_dir) {
        source_dir := Trim(source_dir)
        if (source_dir == "" || !DirExist(source_dir))
            throw Error("指定的备份目录不存在！")

        has_config := FileExist(source_dir "\config.json")
        has_commands := FileExist(source_dir "\commands.json")
        if (!has_config && !has_commands)
            throw Error("在目录 [" source_dir "] 中未发现 config.json 或 commands.json！")

        if (has_config)
            FileCopy(source_dir "\config.json", this.config_json_path, true)
        if (has_commands)
            FileCopy(source_dir "\commands.json", this.commands_json_path, true)

        this.Init()
        return true
    }

    static FindEverythingPath() {
        reg_paths := [
            "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\Everything.exe",
            "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\Everything.exe",
            "HKLM\SOFTWARE\voidtools\Everything",
            "HKLM\SOFTWARE\WOW6432Node\voidtools\Everything"
        ]
        for reg in reg_paths {
            try {
                path := RegRead(reg, "")
                if (path != "" && FileExist(path))
                    return path
            }
            try {
                path := RegRead(reg, "InstallLocation")
                if (path != "") {
                    path := RTrim(path, "\/") "\Everything.exe"
                    if FileExist(path)
                        return path
                }
            }
        }
        file_paths := [
            A_ProgramFiles "\Everything\Everything.exe",
            "C:\Program Files (x86)\Everything\Everything.exe",
            A_ProgramFiles "\Everything 1.5a\Everything64.exe",
            A_AppData "\Local\Programs\Everything\Everything.exe",
            "D:\Program Files\Everything\Everything.exe"
        ]
        for fp in file_paths {
            if FileExist(fp)
                return fp
        }
        return ""
    }

    static ReadEverythingHotkeyFromIni(everythingPath := "") {
        ini_paths := [
            A_AppData "\Everything\Everything.ini",
            A_AppData "\Everything\Everything-1.5a.ini"
        ]
        if (everythingPath != "") {
            SplitPath(everythingPath, , &exeDir)
            ini_paths.Push(exeDir "\Everything.ini", exeDir "\Everything-1.5a.ini")
        }
        val := 0
        for path in ini_paths {
            if FileExist(path) {
                try val := Integer(IniRead(path, "Everything", "show_window_key", 0))
                if (val > 0)
                    break
            }
        }
        if (val <= 0)
            return ""

        vk := val & 0x00FF
        mods := val & 0xFF00
        if (vk == 0)
            return ""

        key_name := ""
        try key_name := GetKeyName(Format("vk{:x}", vk))
        if (key_name == "")
            return ""
        if (StrLen(key_name) == 1)
            key_name := StrUpper(key_name)

        prefix := ""
        if (mods & 0x0100) ; Ctrl = 0x01
            prefix .= "Ctrl + "
        if (mods & 0x0200) ; Alt = 0x02
            prefix .= "Alt + "
        if (mods & 0x0400) ; Shift = 0x04
            prefix .= "Shift + "
        if (mods & 0x0800) ; Win = 0x08
            prefix .= "Win + "

        return prefix . key_name
    }
}

;-==== [ 原模块: ConfigMigrator.ahk ] ====-
class ConfigMigrator {
    /**
     * 将指定的 INI 文件静默转换为 JSON 文件，并将旧文件备份（用于 config.ini）
     * @param ini_path 原始 ini 路径
     * @param json_path 新的 json 路径
     * @returns {Integer} 1 表示成功迁移，0 表示未进行迁移或失败
     */
    static MigrateIniToJson(ini_path, json_path) {
        if (!FileExist(ini_path))
            return 0

        try {
            json_obj := Map()

            ; 如果已有 json，先读入内存
            if FileExist(json_path) {
                try {
                    text := FileRead(json_path, "UTF-8")
                    json_obj := JSON.parse(text)
                }
            }

            sections_str := IniRead(ini_path)
            if (sections_str == "")
                return 0

            loop parse sections_str, "`n", "`r" {
                section := A_LoopField
                if !json_obj.Has(section)
                    json_obj[section] := Map()

                keys_str := IniRead(ini_path, section)
                loop parse keys_str, "`n", "`r" {
                    eq_pos := InStr(A_LoopField, "=")
                    if (eq_pos > 0) {
                        key := Trim(SubStr(A_LoopField, 1, eq_pos - 1))
                        val := Trim(SubStr(A_LoopField, eq_pos + 1))

                        comment := ""
                        semicolon_pos := InStr(val, ";")
                        if (semicolon_pos > 0) {
                            comment := Trim(SubStr(val, semicolon_pos + 1))
                            val := Trim(SubStr(val, 1, semicolon_pos - 1))
                        }

                        json_obj[section][key] := val
                    }
                }
            }

            ; 针对 config.ini 转换出的 config.json，增加新的 commands.json 指向，但保留旧有参数
            if (json_obj.Has("UserConf")) {
                json_obj["UserConf"]["命令配置"] := "commands.json"
            }

            ; 格式化写入 JSON (UTF-8)
            json_str := JSON.stringify(json_obj)

            ; 写入前如果有旧的先删除
            if FileExist(json_path)
                FileDelete(json_path)

            FileAppend(json_str, json_path, "UTF-8")

            ; 迁移完毕后备份，防止未来启动时不断覆盖用户在 GUI 中的修改
            bak_path := ini_path . ".bak"
            if FileExist(bak_path) {
                index := 1
                while FileExist(bak_path . "." index)
                    index++
                bak_path := bak_path . "." index
            }
            FileMove(ini_path, bak_path, true)

            return 1
        }
        catch as e {
            try {
                Logger.info("ConfigMigrator 迁移失败: " . e.Message)
            }
            return 0
        }
    }

    /**
     * 从 V2 的 alias.ini 和 hotkey.ini 合并迁移到 commands.json (Array 结构)
     */
    static MigrateV2IniToCommandsJson(alias_ini, hotkey_ini, commands_json) {
        if (!FileExist(alias_ini) && !FileExist(hotkey_ini))
            return 0

        try {
            commands_obj := Map()

            ParseIniAndMerge(ini_path, is_hotkey) {
                if (!FileExist(ini_path))
                    return

                sections_str := IniRead(ini_path)
                if (sections_str == "")
                    return

                loop parse sections_str, "`n", "`r" {
                    section := A_LoopField
                    section_id := AppSettings.GetWbIdByUI(section)
                    if !commands_obj.Has(section_id)
                        commands_obj[section_id] := []

                    keys_str := IniRead(ini_path, section)
                    loop parse keys_str, "`n", "`r" {
                        eq_pos := InStr(A_LoopField, "=")
                        if (eq_pos > 0) {
                            trigger := Trim(SubStr(A_LoopField, 1, eq_pos - 1))
                            val := Trim(SubStr(A_LoopField, eq_pos + 1))

                            comment := ""
                            semicolon_pos := InStr(val, ";")
                            if (semicolon_pos > 0) {
                                comment := Trim(SubStr(val, semicolon_pos + 1))
                                val := Trim(SubStr(val, 1, semicolon_pos - 1))
                            }

                            clean_val := StrReplace(Trim(val), "&", ",")
                            params := StrSplit(clean_val, ",")

                            cmd := Trim(params[1], " `t")
                            cb := params.Length > 1 ? Trim(params[2], " `t") : ""
                            args_arr := []
                            if (params.Length > 2) {
                                Loop params.Length - 2 {
                                    args_arr.Push(Trim(params[A_Index + 2], " `t"))
                                }
                            }

                            ; 查找同类动作是否已存在
                            found_idx := 0
                            for idx, item in commands_obj[section_id] {
                                if (item.Has("command") && item["command"] == cmd) {
                                    item_cb := item.Has("callback") ? item["callback"] : ""
                                    if (item_cb != cb)
                                        continue

                                    item_args := item.Has("args") ? item["args"] : []
                                    if (item_args.Length != args_arr.Length)
                                        continue
                                    args_match := true
                                    Loop args_arr.Length {
                                        if (item_args[A_Index] != args_arr[A_Index]) {
                                            args_match := false
                                            break
                                        }
                                    }
                                    if (!args_match)
                                        continue

                                    found_idx := idx
                                    break
                                }
                            }

                            if (found_idx > 0) {
                                target := commands_obj[section_id][found_idx]
                            } else {
                                target := Map("command", cmd, "aliases", [], "hotkeys", [])
                                if (cb != "")
                                    target["callback"] := cb
                                if (args_arr.Length > 0)
                                    target["args"] := args_arr
                                commands_obj[section_id].Push(target)
                            }

                            if (comment != "" && !target.Has("desc"))
                                target["desc"] := comment

                            if (is_hotkey) {
                                exists := false
                                for existing in target["hotkeys"] {
                                    if (existing == trigger) {
                                        exists := true
                                        break
                                    }
                                }
                                if (!exists)
                                    target["hotkeys"].Push(trigger)
                            } else {
                                exists := false
                                for existing in target["aliases"] {
                                    if (existing == trigger) {
                                        exists := true
                                        break
                                    }
                                }
                                if (!exists)
                                    target["aliases"].Push(trigger)
                            }
                        }
                    }
                }
            }

            ParseIniAndMerge(alias_ini, false)
            ParseIniAndMerge(hotkey_ini, true)

            json_str := JSON.stringify(commands_obj)
            if FileExist(commands_json)
                FileDelete(commands_json)
            FileAppend(json_str, commands_json, "UTF-8")
            ; 备份原文件
            if FileExist(alias_ini) {
                bak_path := alias_ini . ".bak"
                if FileExist(bak_path) {
                    index := 1
                    while FileExist(bak_path . "." index)
                        index++
                    bak_path := bak_path . "." index
                }
                FileMove(alias_ini, bak_path, true)
            }

            if FileExist(hotkey_ini) {
                bak_path := hotkey_ini . ".bak"
                if FileExist(bak_path) {
                    index := 1
                    while FileExist(bak_path . "." index)
                        index++
                    bak_path := bak_path . "." index
                }
                FileMove(hotkey_ini, bak_path, true)
            }

            return 1
        }
        catch as e {
            try {
                Logger.info("ConfigMigrator 迁移 commands 失败: " . e.Message)
            }
            return 0
        }
    }
}


class CATIAWindow {
    static catia_window_classnn_map := Map(
        "R21", "Afx:",
        "R27", "Afx:",
        "R30", "CATDlgDocument"
    )

    static is_catia_exe_and_title(obj) {
        if (StrLower(obj.exe) == "cnext.exe" and StrUpper(SubStr(obj.title, 1, 8)) == "CATIA V5") {
            return true
        }
        return false
    }

    static is_included_catia_class(obj) {
        test_class := obj.class
        for _, value in this.catia_window_classnn_map {
            if (SubStr(test_class, 1, StrLen(value)) == value) {
                return true
            }
        }
        return false
    }

    static identify_window(hwnd := "A") {
        current_window := Object()
        try {
            current_window.title := WinGetTitle(hwnd)
            current_window.class := WinGetClass(hwnd)
            current_window.exe := WinGetProcessName(hwnd)
        }
        catch Error as err {
            Logger.info("对象获取失败")
            return false
        }

        if (this.is_catia_exe_and_title(current_window) and this.is_included_catia_class(current_window)) {
            Logger.info("CATIA窗口 获取成功")
            return current_window.class
        }
        Logger.info("未获取到CATIA窗口")
        return false
    }

    static get_power_input_edit_hwnd() {
        status_bar_hwnd := ControlGetHwnd("msctls_statusbar321")
        for ctrl in WinGetControls(status_bar_hwnd) {
            if InStr(StrLower(ctrl), "edit") {
                edit_hwnd := ControlGetHwnd(ctrl, status_bar_hwnd)
                return edit_hwnd
            }
        }
        return false
    }
}

class KeyboardController {
    static modifiers := ["LAlt", "RAlt", "LCtrl", "RCtrl", "LShift", "RShift"]

    /**
     * 强制释放所有修饰键，并注入 {vk07} 阻止系统菜单激活
     */
    static force_release_all() {
        SendInput "{Blind}{vk07}{LAlt Up}{RAlt Up}{LCtrl Up}{RCtrl Up}{LShift Up}{RShift Up}"
    }

    /**
     * 探针检测物理按压状态，精准恢复仍被按下的修饰键逻辑状态
     */
    static restore_physical_state() {
        restore_str := ""
        for key in this.modifiers {
            if GetKeyState(key, "P") {
                restore_str .= "{" . key . " Down}"
            }
        }
        if (restore_str != "") {
            SendInput "{Blind}" . restore_str
        }
    }

    /**
     * 统一注册全局防粘滞与透传热键
     */
    static register_anti_sticky_hotkeys() {
        try {
            ; 修复 RAlt & RButton 未注册组合导致的 RAlt 粘滞问题（>! 代表 Right Alt）
            Hotkey(">!RButton", (*) => SendInput("{RButton}"))

            ; 兜底清场：物理抬起时注入逻辑 Up，打断粘滞
            Hotkey("~>!Up", (*) => SendInput("{Blind}{vk07}{RAlt Up}"))
            Hotkey("~<!Up", (*) => SendInput("{Blind}{vk07}{LAlt Up}"))
        } catch Error as e {
            Logger.info("注册防粘滞热键失败：" . e.Message)
        }
    }

    /**
     * 高阶执行器：在一个安全的物理按键隔离环境内执行动作。
     * @param actionCallback 实际要执行的逻辑
     * @param preSleep 执行前强制隔离缓冲（单位：毫秒）
     * @param postSleep 恢复前执行缓冲（单位：毫秒）
     */
    static RunWithModifiersIsolated(actionCallback, preSleep := 10, postSleep := 30) {
        try {
            if (AppSettings.config_obj.Has("通用") && AppSettings.config_obj["通用"].Has("AntiStickyDelay")) {
                preSleep := Integer(AppSettings.config_obj["通用"]["AntiStickyDelay"])
                postSleep := preSleep * 3
            }
        }

        this.force_release_all()
        if (preSleep > 0)
            Sleep preSleep

        try {
            actionCallback()
        } finally {
            if (postSleep > 0)
                Sleep postSleep
            this.restore_physical_state()
        }
    }
}

class CATIAInstance {
    static instances := Map()
    pid := 0
    hdr_cache := Map()

    __New(pid) {
        this.pid := pid
        this.hdr_cache := Map()
    }

    static get_instance(hwnd) {
        pid := WinGetPID(hwnd)
        if !this.instances.Has(pid)
            this.instances[pid] := CATIAInstance(pid)
        return this.instances[pid]
    }

    safe_send_enter(hwnd) {
        KeyboardController.RunWithModifiersIsolated(() => ControlSend("{Blind}{Enter}", , "ahk_id " . hwnd))
    }

    static safe_send_enter_static(hwnd) {
        KeyboardController.RunWithModifiersIsolated(() => ControlSend("{Blind}{Enter}", , "ahk_id " . hwnd))
    }

    static is_catia_bindable_context() {
        if WinActive("ahk_group GroupCATIA")
            return true
        if WinActive("ahk_class #32770 ahk_exe CNEXT.exe")
            return true
        return false
    }

    static is_catia_dialog_context() {
        if !this.is_catia_bindable_context()
            return false
        try {
            catia_pid := WinGetPID("A")
            return WinExist("ahk_class #32770 ahk_pid " . catia_pid)
        }
        return false
    }

    static mbutton_suppressed := false

    static handle_suppressed_aux(btn) {
        this.mbutton_suppressed := false
        SendInput "{Blind}{MButton Down}{" . btn . " Down}"
        KeyWait btn
        SendInput "{Blind}{" . btn . " Up}"
    }

    static handle_mbutton_smart() {
        MouseGetPos(&startX, &startY)
        startTime := A_TickCount
        is_native := false
        this.mbutton_suppressed := true

        try {
            while GetKeyState("MButton", "P") {
                Sleep 10
                if !this.mbutton_suppressed
                    break
                MouseGetPos(&currX, &currY)
                if (abs(currX - startX) > 5 || abs(currY - startY) > 5 || (A_TickCount - startTime) >= 200 || GetKeyState("Ctrl", "P") || GetKeyState("Shift", "P") || GetKeyState("Alt", "P") || GetKeyState("RButton", "P") || GetKeyState("LButton", "P")) {
                    is_native := true
                    break
                }
            }

            if !this.mbutton_suppressed {
                KeyWait "MButton"
                SendInput "{Blind}{MButton Up}"
                return
            }

            this.mbutton_suppressed := false

            if is_native {
                SendInput "{Blind}{MButton Down}"
                KeyWait "MButton"
                SendInput "{Blind}{MButton Up}"
            } else {
                this.click_dialog_confirm_button()
            }
        } finally {
            this.mbutton_suppressed := false
        }
    }

    static click_dialog_button(keywords, target_hwnd := 0) {
        if !target_hwnd {
            try {
                catia_pid := WinGetPID("A")
                target_hwnd := WinExist("ahk_class #32770 ahk_pid " . catia_pid)
            }
        }
        if !target_hwnd
            return false
        try {
            for ctrl in WinGetControls(target_hwnd) {
                if !ControlGetVisible(ctrl, target_hwnd)
                    continue
                clean_text := Trim(RegExReplace(StrReplace(ControlGetText(ctrl, target_hwnd), "&", ""), "\([a-zA-Z]\)", ""))
                for kw in keywords {
                    if (clean_text == kw) {
                        SendMessage(0xF5, 0, 0, ctrl, target_hwnd)
                        return true
                    }
                }
            }
        }
        return false
    }

    static click_dialog_confirm_button(hwnd := 0) => this.click_dialog_button(["确定", "OK", "是", "Yes"], hwnd)
    static click_dialog_preview_button(hwnd := 0) => this.click_dialog_button(["预览", "Preview"], hwnd)
    static click_dialog_apply_button(hwnd := 0) => this.click_dialog_button(["应用", "Apply"], hwnd)

    handle_hdr_error() {
        pop_hwnd := WinGetID()
        str := WindowManager.get_window_text_fast(false)

        WinClose(pop_hwnd)
        WinWaitClose(pop_hwnd, , 2)

        loop parse, str, "`n", "`r" {
            if InStr(A_LoopField, "未知命令") {
                command := Trim(SubStr(A_LoopField, InStr(A_LoopField, "：") + 1))
                corrected := (SubStr(command, -3) = "Hdr")
                    ? SubStr(command, 1, StrLen(command) - 3)
                    : command . "Hdr"
                Logger.info("Hdr 修正: " . command . " → " . corrected)
                return corrected
            }
        }
        return ""
    }
}

class CommandEngine {
    static match_current_workbench(workbench_map) {
        try {
            workbench_control_hwnd := ControlGetHwnd("WebBrowser", "A")
            for button in WinGetControls(workbench_control_hwnd) {
                button_name := ControlGetText(button, workbench_control_hwnd)
                id := AppSettings.GetWbIdByUI(button_name)
                if workbench_map.Has(id) {
                    return id
                }
            }
            return "通用"
        }
        catch {
            active_hwnd := WinExist("A")
            MsgBox("无法识别当前工作台，请确保【工作台】工具栏为吸附状态。", "UCLC - CATIA 增强", "Icon! Owner" . active_hwnd)
            return "ERROR_NOT_DOCKED"
        }
    }

    static get_map_value_case_insensitive(m, key, &val) {
        if (Type(m) != "Map")
            return false
        if m.Has(key) {
            val := m[key]
            return true
        }
        for k, v in m {
            if StrCompare(k, key, false) == 0 {
                val := v
                return true
            }
        }
        return false
    }

    static process_config(config) {
        if (Type(config) != "Map")
            return []
        cmd := config.Get("command", "")
        if (cmd == "")
            return []
        result := [cmd]
        if (cb := config.Get("callback", "")) {
            result.Push(cb)
            if (Type(args := config.Get("args", "")) == "Array") {
                result.Push(args*)
            }
        }
        return result
    }

    static read_user_alias(dict_type, section, key) {
        target_obj := (dict_type == "alias") ? AppSettings.alias_obj : AppSettings.hotkey_obj
        try {
            Logger.info("调用 " section)
            if this.get_map_value_case_insensitive(target_obj, section, &section_map) {
                if this.get_map_value_case_insensitive(section_map, key, &config_val) {
                    return this.process_config(config_val)
                }
            }
            Logger.info("调用 通用")
            if this.get_map_value_case_insensitive(target_obj, "通用", &general_map) {
                if this.get_map_value_case_insensitive(general_map, key, &config_val) {
                    return this.process_config(config_val)
                }
            }
            Logger.tooltip(Format("没有找到与 '{1}' 对应的命令", key), 1000)
            return 0
        }
        catch Error as e {
            Logger.tooltip(Format("查找 '{1}' 出错: {2}", key, e.Message), 1000)
            return 0
        }
    }

    static execute(input_string, dict_type, power_input_hwnd) {
        current_workbench := this.match_current_workbench(AppSettings.workbench_list)
        if !current_workbench {
            return
        }

        command_id_and_cb_array := this.read_user_alias(dict_type, current_workbench, StrUpper(input_string))
        if !command_id_and_cb_array {
            Logger.tooltip(Format("没有找到与 '{1}' 对应的命令", input_string), 1000)
            return
        }

        original_id := command_id_and_cb_array[1]

        if (current_workbench == "创成式外形设计") {
            instance := CATIAInstance.get_instance(power_input_hwnd)
            command_id := instance.hdr_cache.Has(original_id) ? instance.hdr_cache[original_id] : original_id

            ControlSetText("c:" . command_id, power_input_hwnd)
            instance.safe_send_enter(power_input_hwnd)

            if !instance.hdr_cache.Has(original_id) {
                if WinWait("超级输入消息 ahk_pid " . instance.pid, , 0.5) {
                    corrected_id := instance.handle_hdr_error()
                    if corrected_id {
                        instance.hdr_cache[original_id] := corrected_id
                        Logger.info("GSD分支: Hdr 修正成功 -> " . corrected_id)
                        ControlSetText("c:" . corrected_id, power_input_hwnd)
                        instance.safe_send_enter(power_input_hwnd)
                    }
                }
            }
        } else {
            ControlSetText("c:" . original_id, power_input_hwnd)
            CATIAInstance.safe_send_enter_static(power_input_hwnd)
        }

        if command_id_and_cb_array.Length >= 2 {
            params := []
            loop command_id_and_cb_array.Length - 2 {
                params.Push(command_id_and_cb_array[A_Index + 2])
            }
            callback_func := command_id_and_cb_array[2]
            if HasMethod(Utilities, callback_func) {
                Utilities.%callback_func%(params*)
            } else if IsSet(%callback_func%) {
                %callback_func%(params*)
            }
        }
    }

    static register_command(ThisHotkey) {
        edit_hwnd := CATIAWindow.get_power_input_edit_hwnd()
        this.execute(ThisHotkey, "hotkey", edit_hwnd)
    }
}

class Utilities {
    static read_all_section_from_ini(ini_path, dict) {
        section_array := StrSplit(IniRead(ini_path), "`n")
        for section in section_array {
            if !dict.Has(section) {
                dict.Set(section, "")
            }
        }
    }

    static export_workshop_exposition() {
        hwnd := WinExist("A")
        catia_class := CATIAWindow.identify_window(hwnd)
        if !catia_class {
            MsgBox("未检测到活动的 CATIA 窗口，请先激活 CATIA。", "UCLC - CATIA 增强", "Icon!")
            return false
        }

        power_input_hwnd := CATIAWindow.get_power_input_edit_hwnd()
        if !power_input_hwnd {
            MsgBox("未找到 CATIA 超级输入框。", "UCLC - CATIA 增强", "Iconx")
            return false
        }

        ControlSetText("c:Workshop Exposition", power_input_hwnd)
        instance := CATIAInstance.get_instance(power_input_hwnd)
        instance.safe_send_enter(power_input_hwnd)
        return true
    }

    static cat_auto_graph_tree_reorder() {
        GroupAdd "ReorderTree", "Graph tree reordering"
        GroupAdd "ReorderTree", "图形树重新排序"
        raw_lists_string := ""

        dialogbox_hwnd := WinWait("ahk_group ReorderTree", , 5)
        if dialogbox_hwnd == 0 {
            Exit
        }

        Listbox_items := ControlGetItems("ListBox1", dialogbox_hwnd)
        for item in Listbox_items {
            raw_lists_string .= item ","
        }

        sorted_lists_string := Sort(raw_lists_string, "D,")
        refrence_lists_array := StrSplit(SubStr(sorted_lists_string, 1, StrLen(sorted_lists_string) - 1), ',')

        listbox_classnn := "ListBox1"
        free_move_button := ControlGetHwnd("自由移动", dialogbox_hwnd)

        listbox_items := ControlGetItems(listbox_classnn, dialogbox_hwnd)

        loop listbox_items.Length {
            if (listbox_items[A_Index] == refrence_lists_array[A_Index]) {
                if (A_Index == listbox_items.Length) {
                    Logger.tooltip("已排序完成, 不用继续排序", 3000)
                    Sleep 1000
                    PostMessage(0x10, 0, , , dialogbox_hwnd)
                    Exit
                }
                continue
            }
            else {
                break
            }
        }

        try {
            refrence_item_index := 0
            for item in refrence_lists_array {
                refrence_item_index += 1
                ControlChooseString(refrence_lists_array[A_Index], listbox_classnn, dialogbox_hwnd)
                if (ControlGetIndex(listbox_classnn, dialogbox_hwnd) == A_Index) {
                    continue
                }
                SendMessage(0xF5, 0, 0, free_move_button, dialogbox_hwnd)
                ControlChooseIndex(A_Index, listbox_classnn, dialogbox_hwnd)

                while ControlChooseString(item, listbox_classnn, dialogbox_hwnd) != refrence_item_index {
                    Sleep 1
                }
            }
        }
        catch Error as e {
            Logger.info(Format("函数: {1} 执行失败`n错误信息: {2} on Line {3} `n 文件: {4}", e.What, e.Message, e.Line, e.File))
            Exit
        }

        Logger.tooltip("结构树排序完成", 2000)
    }

    static quick_manipulation(diraction) {
        GroupAdd "Manipulation", "操作参数"
        manipulation_hwnd := WinWait("ahk_group Manipulation", , 5)
        if manipulation_hwnd == 0
            Exit
        diract_button := ControlGetHwnd(diraction, manipulation_hwnd)
        SendMessage(0xF5, 0, 0, diract_button, manipulation_hwnd)
    }
}


class WinEventHook {
    static hook_ptr := 0
    static cb_ptr := 0

    static Start() {
        if (this.hook_ptr)
            return

        this.cb_ptr := CallbackCreate(ObjBindMethod(this, "OnWinEvent"), "F", 7)
        this.hook_ptr := DllCall("SetWinEventHook"
            , "UInt", 0x0003
            , "UInt", 0x0003
            , "Ptr", 0
            , "Ptr", this.cb_ptr
            , "UInt", 0
            , "UInt", 0
            , "UInt", 0
            , "Ptr")

        ; 脚本重载时如果已经在 CATIA 内部，系统不会触发焦点切换事件
        ; 因此挂载后主动检查一次当前的前台窗口，并模拟一次事件推送
        active_hwnd := WinExist("A")
        if (active_hwnd) {
            this.OnWinEvent(0, 3, active_hwnd, 0, 0, 0, 0)
        }
    }

    static Stop() {
        if (this.hook_ptr) {
            DllCall("UnhookWinEvent", "Ptr", this.hook_ptr)
            this.hook_ptr := 0
        }
        if (this.cb_ptr) {
            CallbackFree(this.cb_ptr)
            this.cb_ptr := 0
        }
    }

    static OnWinEvent(hHook, event, hwnd, idObject, idChild, dwEventThread, dwmsEventTime) {
        if (event != 3)
            return

        try {
            global CATIAWindow
            catia_window_hwnd := CATIAWindow.identify_window(hwnd)

            if catia_window_hwnd {
                GroupAdd("GroupCATIA", "ahk_class " catia_window_hwnd)
            }

            if (AppSettings.AutoIME_Enabled && WinActive("ahk_group group_autoime")) {
                IMEController.switch_ime(IMEController.ime_map["en"])
                SetTimer(ObjBindMethod(IMEController, "confirm_ime"), -5000)
            }
        }
        catch Error as err {
            Logger.info("WinEventHook: 处理前台切换事件失败")
        }
    }
}