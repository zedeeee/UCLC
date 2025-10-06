class AppSettings {
    static config_ini_path := ""
    static alias_ini_path := ""
    static hotkey_ini_path := ""
    static DEBUG_I := ""
    static workbench_list := ""
    static current_workbench := ""
    static ESC_CLEAN_FUNC_ENABLE_FLAG := 0

    static Init() {
        this.config_ini_path := ".\config.ini"
        this.alias_ini_path := GET_USER_CONFIG_INI_PATH("用户别名")
        this.hotkey_ini_path := GET_USER_CONFIG_INI_PATH("快捷键")
        this.DEBUG_I := IniRead(this.config_ini_path, "通用", "DEBUG")
        this.workbench_list := Map()
        this.current_workbench := ""
    }
}
