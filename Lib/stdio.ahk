#Requires AutoHotkey v2.0

class k_ToolTipManager {
    static logs := []
    static id_counter := 0
    static pending_render := false
    static follow_timer_cb := () => k_ToolTipManager.UpdateFollow()
    static is_following := false
    static last_text := ""
    static last_x := ""
    static last_y := ""

    static Show(Message, Delay_ms) {
        this.id_counter++
        current_id := this.id_counter
        
        this.logs.Push({id: current_id, text: Message})
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
        
        if (this.logs.Length == 0) {
            ToolTip( , , , 20) ; 列表为空时清除 20 号气泡
            this.last_text := "" ; 清除缓存
            if (this.is_following) {
                SetTimer(this.follow_timer_cb, 0) ; 关闭跟随定时器
                this.is_following := false
            }
            return
        }
        
        if (!this.is_following) {
            SetTimer(this.follow_timer_cb, 10) ; 每 10ms 刷新一次位置
            this.is_following := true
        }
        
        this.UpdateFollow()
    }

    static UpdateFollow() {
        if (this.logs.Length == 0) {
            return
        }
        
        text := ""
        for item in this.logs {
            text .= item.text . "`n"
        }
        text := Trim(text, "`n")
        
        ; 获取鼠标坐标
        MouseGetPos(&mX, &mY)
        
        ; 如果文本和坐标都没变，拒绝冗余渲染以防闪烁
        if (text == this.last_text && mX == this.last_x && mY == this.last_y) {
            return
        }
        
        this.last_text := text
        this.last_x := mX
        this.last_y := mY
        
        ToolTip(text, mX + 16, mY + 16, 20)
    }
}

; ToolTip 的封装函数，简化函数调用
; - string: Message
; - int: Delay_ms
k_ToolTip(Message, Delay_ms := 1000)
{
    k_ToolTipManager.Show(Message, Delay_ms)
}