#Requires AutoHotkey v2.0

/**
 * 管理单个 CATIA 实例的状态
 * 不同 CATIA 进程的 GSD 命令可能需要不同的 Hdr 后缀，
 * 因此以 PID 为 key 隔离每个实例的缓存
 */
class CATIAInstance {
    __New(pid) {
        this.pid := pid
        this.hdr_cache := Map()  ; key=原始命令ID, value=修正后的正确命令ID
    }
}

; 全局实例注册表（PID → CATIAInstance）
global catia_instances := Map()

/**
 * 获取或创建与 hwnd 对应的 CATIA 实例
 * @param hwnd  CATIA 窗口内的任意控件句柄
 * @returns {CATIAInstance}
 */
get_catia_instance(hwnd) {
    pid := WinGetPID(hwnd)
    if !catia_instances.Has(pid)
        catia_instances[pid] := CATIAInstance(pid)
    return catia_instances[pid]
}
