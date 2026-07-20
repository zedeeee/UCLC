#Requires AutoHotkey v2.0

class k_ToolTipManager {
    static logs := []
    static id_counter := 0
    static pending_render := false

    ; --- 配置区 ---
    ; 切换气泡渲染模式：true 为使用无边框透明 GUI 及物理缓动；false 为原生 ToolTip
    static UseSmoothGUI := true
    ; --------------

    ; GUI 专用状态
    static gui := ""
    static txt := ""
    static target_alpha := 0
    static current_alpha := 0
    static last_int_alpha := 0

    ; 通用状态
    static current_x := 0
    static current_y := 0
    static is_following := false
    static follow_timer_cb := () => k_ToolTipManager.UpdateFollow()
    static last_text := ""

    ; 原生模式专用
    static last_x := ""
    static last_y := ""

    static InitGUI() {
        if (this.gui != "")
            return

        ; +E0x20 (WS_EX_TRANSPARENT) 鼠标穿透
        ; +E0x80000 (WS_EX_LAYERED) 支持透明度
        this.gui := Gui("+ToolWindow -Caption +AlwaysOnTop +E0x20 +E0x80000", "")
        this.gui.BackColor := "2D2D2D" ; 深灰色背景
        this.gui.SetFont("s10 cFFFFFF", "Segoe UI") ; 白色字体

        ; 边距
        this.gui.MarginX := 12
        this.gui.MarginY := 8

        if (this.current_x == 0 && this.current_y == 0) {
            SavedCoordMode := A_CoordModeMouse
            CoordMode("Mouse", "Screen")
            MouseGetPos(&mX, &mY)
            CoordMode("Mouse", SavedCoordMode)
            
            this.current_x := mX + 24
            this.current_y := mY + 24
            this.current_alpha := 0
        }
    }
    
    static control_count := 0

    static UpdateTextGUI(text) {
        if (text == this.last_text)
            return
        
        old_gui := ""

        if (this.gui == "" || this.control_count > 30) {
            ; 如果窗体不存在，或累积控件超标（防极端刷屏导致句柄溢出）
            if (this.gui != "") {
                old_gui := this.gui
            }

            this.gui := Gui("+ToolWindow -Caption +AlwaysOnTop +E0x20 +E0x80000", "")
            this.gui.BackColor := "2D2D2D"
            this.gui.SetFont("s10 cFFFFFF", "Segoe UI")
            this.gui.MarginX := 12
            this.gui.MarginY := 8
            this.control_count := 0 ; 计数清零

            if (this.current_x == 0 && this.current_y == 0) {
                SavedCoordMode := A_CoordModeMouse
                CoordMode("Mouse", "Screen")
                MouseGetPos(&mX, &mY)
                CoordMode("Mouse", SavedCoordMode)
                this.current_x := mX + 24
                this.current_y := mY + 24
                this.current_alpha := 0
            }
        }

        if (this.txt != "") {
            this.txt.Visible := false  ; 隐藏旧文字控件避免重叠
        }

        this.txt := this.gui.Add("Text", "x12 y8 BackgroundTrans", text)
        this.control_count++
        WinSetTransparent(Integer(this.current_alpha), this.gui.Hwnd)
        this.gui.Show("AutoSize NA x" Integer(this.current_x) " y" Integer(this.current_y))

        ; 如果触发了垃圾回收（重建窗口），延迟 30 毫秒销毁旧窗口，让 DWM 平滑过渡
        if (old_gui != "") {
            SetTimer(ObjBindMethod(old_gui, "Destroy"), -30)
        }

        this.last_text := text
    }

    static Show(Message, Delay_ms, Category := "") {
        this.id_counter++
        current_id := this.id_counter

        if (Category != "") {
            for index, item in this.logs {
                if (item.HasOwnProp("category") && item.category == Category) {
                    this.logs.RemoveAt(index)
                    break
                }
            }
        }

        this.logs.Push({ id: current_id, text: Message, category: Category })
        this.RequestRender()

        ; 设定负数延时（单次触发），到期后移除该项
        SetTimer(() => this.Remove(current_id), -Abs(Delay_ms))
    }

    static Remove(id) {
        for index, item in this.logs {
            if (item.id == id) {
                this.logs.RemoveAt(index)
                break
            }
        }
        this.RequestRender()
    }

    static RequestRender() {
        if (!this.pending_render) {
            this.pending_render := true
            SetTimer(() => this.DoRender(), -10)
        }
    }

    static DoRender() {
        this.pending_render := false

        text := ""
        for item in this.logs {
            text .= item.text . "`n"
        }
        text := Trim(text, "`n")

        if (this.UseSmoothGUI) {
            if (text == "") {
                this.target_alpha := 0
            } else {
                this.target_alpha := 220 ; 最高透明度 220 带有略微玻璃感
                this.UpdateTextGUI(text)
            }
            if (!this.is_following) {
                ; 开启 1ms 系统底层高精度定时器，突破 AHK 的 15.6ms 刷新率上限
                DllCall("Winmm\timeBeginPeriod", "UInt", 1)
                SetTimer(this.follow_timer_cb, 2) ; 极致刷新率：2ms (约 500FPS)
                this.is_following := true
            }
        } else {
            ; =======================
            ; 原生 ToolTip 模式
            ; =======================
            if (text == "") {
                ToolTip(, , , 20) ; 列表为空时清除 20 号气泡
                this.last_text := "" ; 清除缓存
                if (this.is_following) {
                    SetTimer(this.follow_timer_cb, 0) ; 关闭跟随定时器
                    DllCall("Winmm\timeEndPeriod", "UInt", 1) ; 恢复系统定时器分辨率
                    this.is_following := false
                }
                return
            }

            if (!this.is_following) {
                DllCall("Winmm\timeBeginPeriod", "UInt", 1)
                SetTimer(this.follow_timer_cb, 10) ; 每 10ms 刷新一次位置
                this.is_following := true
            }
            this.UpdateFollow()
        }
    }

    static UpdateFollow() {
        if (!this.UseSmoothGUI) {
            ; 原生跟随模式
            if (this.logs.Length == 0)
                return

            text := ""
            for item in this.logs {
                text .= item.text . "`n"
            }
            text := Trim(text, "`n")

            SavedCoordMode := A_CoordModeMouse
            CoordMode("Mouse", "Screen")
            MouseGetPos(&mX, &mY)
            CoordMode("Mouse", SavedCoordMode)

            if (text == this.last_text && mX == this.last_x && mY == this.last_y)
                return

            this.last_text := text
            this.last_x := mX
            this.last_y := mY
            ToolTip(text, mX + 16, mY + 16, 20)
            return
        }

        ; GUI 跟随模式
        if (this.target_alpha == 0 && this.current_alpha <= 1) {
            this.current_alpha := 0
            if (this.gui != "") {
                this.gui.Destroy()
                this.gui := ""
                this.txt := ""
            }
            SetTimer(this.follow_timer_cb, 0)
            DllCall("Winmm\timeEndPeriod", "UInt", 1) ; 释放系统高精度定时器
            this.is_following := false
            this.last_text := "" ; 清除缓存，以便下次强制重绘
            return
        }

        ; Alpha 渐变 (Lerp) — 仅在整数值变化时才调用 WinSetTransparent
        if (this.current_alpha != this.target_alpha) {
            this.current_alpha += (this.target_alpha - this.current_alpha) * 0.15
            if (Abs(this.target_alpha - this.current_alpha) < 2)
                this.current_alpha := this.target_alpha
            new_int_alpha := Integer(this.current_alpha)
            if (this.gui != "" && new_int_alpha != this.last_int_alpha) {
                DllCall("SetLayeredWindowAttributes"
                    , "Ptr", this.gui.Hwnd
                    , "UInt", 0
                    , "UChar", new_int_alpha
                    , "UInt", 2)  ; LWA_ALPHA = 2
                this.last_int_alpha := new_int_alpha
            }
        }

        ; 位置移动 (Lerp)
        SavedCoordMode := A_CoordModeMouse
        CoordMode("Mouse", "Screen")
        MouseGetPos(&mX, &mY)
        CoordMode("Mouse", SavedCoordMode)

        target_x := mX + 24
        target_y := mY + 24

        dist := Sqrt((target_x - this.current_x) ** 2 + (target_y - this.current_y) ** 2)
        if (dist > 800 || (this.current_alpha < 5 && this.target_alpha > 0)) {
            this.current_x := target_x
            this.current_y := target_y
        } else {
            this.current_x += (target_x - this.current_x) * 0.70
            this.current_y += (target_y - this.current_y) * 0.70
        }

        ; 用 Win32 底层 SetWindowPos 替代 WinMove，附加轻量标志跳过重绘和消息派发
        ; SWP_NOSIZE(0x1) | SWP_NOZORDER(0x4) | SWP_NOACTIVATE(0x10) | SWP_NOREDRAW(0x8) | SWP_NOSENDCHANGING(0x400) = 0x41D
        new_ix := Integer(this.current_x)
        new_iy := Integer(this.current_y)
        if (this.gui != "") {
            try DllCall("SetWindowPos"
                , "Ptr", this.gui.Hwnd
                , "Ptr", 0
                , "Int", new_ix
                , "Int", new_iy
                , "Int", 0
                , "Int", 0
                , "UInt", 0x041D)
        }
    }
}

; ToolTip 的封装函数，简化函数调用
; - string: Message
; - int: Delay_ms
; - string: Category (可选分类，相同分类的气泡互相覆盖)
k_ToolTip(Message, Delay_ms := 1000, Category := "") {
    k_ToolTipManager.Show(Message, Delay_ms, Category)
}
