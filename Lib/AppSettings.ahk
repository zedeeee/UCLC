#Include "%A_LineFile%\..\Version.ahk"
#Include "%A_LineFile%\..\JSON.ahk"
#Include "%A_LineFile%\..\ConfigMigrator.ahk"

class AppSettings {
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
    static Version := UCLC_VERSION
    static Everything_Path := ""
    
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
        this.config_json_path := A_ScriptDir "\config.json"

        ; 只要发现 config.ini 就将其值合并更新到 config.json
        if (FileExist(A_ScriptDir "\config.ini")) {
            ConfigMigrator.MigrateIniToJson(A_ScriptDir "\config.ini", this.config_json_path)
        }

        ; 读取全局配置
        if (FileExist(this.config_json_path)) {
            text := FileRead(this.config_json_path, "UTF-8")
            this.config_obj := JSON.parse(text)
        } else {
            this.config_obj := Map(
                "通用", Map("DEBUG", "0"),
                "UserConf", Map("命令配置", "commands.json"),
                "Everything", Map("Enabled", "0", "Path", ""),
                "AutoIME", Map(
                    "AUTOCAD", "ACAD.exe",
                    "CATIA", "CNEXT.exe"
                )
            )
            FileAppend(JSON.stringify(this.config_obj), this.config_json_path, "UTF-8")
        }

        commands_file := "commands.json"

        if (this.config_obj.Has("UserConf") && this.config_obj["UserConf"].Has("命令配置")) {
            commands_file := this.config_obj["UserConf"]["命令配置"]
        }

        this.commands_json_path := A_ScriptDir "\user-config\" commands_file

        ; 检查并迁移 V2 INI
        alias_name := "alias.ini"
        hotkey_name := "hotkey.ini"
        
        if (this.config_obj.Has("UserConf")) {
            if (this.config_obj["UserConf"].Has("用户别名"))
                alias_name := this.config_obj["UserConf"]["用户别名"]
            if (this.config_obj["UserConf"].Has("快捷键"))
                hotkey_name := this.config_obj["UserConf"]["快捷键"]
        }

        if (alias_name = "alias.ini" && FileExist(A_ScriptDir "\config.ini")) {
            try alias_name := IniRead(A_ScriptDir "\config.ini", "UserConf", "用户别名", "alias.ini")
            try hotkey_name := IniRead(A_ScriptDir "\config.ini", "UserConf", "快捷键", "hotkey.ini")
        }
        
        ; 剥离可能带有的 .json 后缀，因为这里是为了找原始 ini
        alias_name := StrReplace(alias_name, ".json", ".ini")
        hotkey_name := StrReplace(hotkey_name, ".json", ".ini")

        this.alias_ini_path := A_ScriptDir "\user-config\" alias_name
        this.hotkey_ini_path := A_ScriptDir "\user-config\" hotkey_name
        
        this.LoadWorkbenchMapping()
        
        if (!FileExist(this.commands_json_path) && (FileExist(this.alias_ini_path) || FileExist(this.hotkey_ini_path))) {
            ConfigMigrator.MigrateV2IniToCommandsJson(this.alias_ini_path, this.hotkey_ini_path, this.commands_json_path)
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
                if FileExist(this.commands_json_path)
                    FileDelete(this.commands_json_path)
                FileAppend(JSON.stringify(this.commands_obj), this.commands_json_path, "UTF-8")
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
            this.config_obj["Everything"]["Enabled"] : 0
        this.Everything_Path := this.config_obj.Has("Everything") && this.config_obj["Everything"].Has("Path") ? this.config_obj[
            "Everything"]["Path"] : ""

        ; 初始化工作台列表
        this.workbench_list := Map()
        if (this.hotkey_obj != "") {
            for wb, _ in this.hotkey_obj {
                this.workbench_list[wb] := ""
            }
        }

        this.current_workbench := ""
    }
}
