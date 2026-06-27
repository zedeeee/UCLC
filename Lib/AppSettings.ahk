#Include "%A_LineFile%\..\Version.ahk"
#Include "%A_LineFile%\..\JSON.ahk"
#Include "%A_LineFile%\..\ConfigMigrator.ahk"

class AppSettings {
    static config_json_path := ""
    static alias_json_path := ""
    static hotkey_json_path := ""
    
    static config_obj := Map()
    static alias_obj := Map()
    static hotkey_obj := Map()

    static DEBUG_I := ""
    static workbench_list := Map()
    static current_workbench := ""
    static ESC_CLEAN_FUNC_ENABLE_FLAG := 0
    static Everything_Enabled := 0
    static Version := UCLC_VERSION
    static Everything_Path := ""

    static Init() {
        this.config_json_path := ".\config.json"
        
        ; 检查并迁移 config.ini
        if (!FileExist(this.config_json_path) && FileExist(".\config.ini")) {
            ConfigMigrator.MigrateIniToJson(".\config.ini", this.config_json_path)
        }
        
        ; 读取全局配置
        if (FileExist(this.config_json_path)) {
            text := FileRead(this.config_json_path, "UTF-8")
            this.config_obj := JSON.parse(text)
        } else {
            this.config_obj := Map(
                "通用", Map("DEBUG", "0"),
                "UserConf", Map("用户别名", "alias.json", "快捷键", "hotkey.json"),
                "Everything", Map("Enabled", "0", "Path", "")
            )
        }
        
        ; 获取用户配置路径，强制转换 .ini 为 .json (如果用户还在用老的路径配置)
        alias_file := "alias.json"
        hotkey_file := "hotkey.json"
        
        if (this.config_obj.Has("UserConf")) {
            if (this.config_obj["UserConf"].Has("用户别名"))
                alias_file := StrReplace(this.config_obj["UserConf"]["用户别名"], ".ini", ".json")
            if (this.config_obj["UserConf"].Has("快捷键"))
                hotkey_file := StrReplace(this.config_obj["UserConf"]["快捷键"], ".ini", ".json")
        }
        
        this.alias_json_path := A_ScriptDir "\user-config\" alias_file
        this.hotkey_json_path := A_ScriptDir "\user-config\" hotkey_file
        
        ; 检查并迁移 alias/hotkey
        alias_ini := StrReplace(this.alias_json_path, ".json", ".ini")
        if (!FileExist(this.alias_json_path) && FileExist(alias_ini)) {
            ConfigMigrator.MigrateIniToJson(alias_ini, this.alias_json_path)
        }
        
        hotkey_ini := StrReplace(this.hotkey_json_path, ".json", ".ini")
        if (!FileExist(this.hotkey_json_path) && FileExist(hotkey_ini)) {
            ConfigMigrator.MigrateIniToJson(hotkey_ini, this.hotkey_json_path)
        }
        
        ; 载入 JSON 到内存树
        if (FileExist(this.alias_json_path)) {
            this.alias_obj := JSON.parse(FileRead(this.alias_json_path, "UTF-8"))
        } else {
            this.alias_obj := Map()
        }
        
        if (FileExist(this.hotkey_json_path)) {
            this.hotkey_obj := JSON.parse(FileRead(this.hotkey_json_path, "UTF-8"))
        } else {
            this.hotkey_obj := Map()
        }

        ; 读取常规设置
        this.DEBUG_I := this.config_obj.Has("通用") && this.config_obj["通用"].Has("DEBUG") ? this.config_obj["通用"]["DEBUG"] : 0
        this.Everything_Enabled := this.config_obj.Has("Everything") && this.config_obj["Everything"].Has("Enabled") ? this.config_obj["Everything"]["Enabled"] : 0
        this.Everything_Path := this.config_obj.Has("Everything") && this.config_obj["Everything"].Has("Path") ? this.config_obj["Everything"]["Path"] : ""
        
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
