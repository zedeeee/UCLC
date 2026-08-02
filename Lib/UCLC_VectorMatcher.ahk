#Requires AutoHotkey v2.0

class VectorSpaceMatcher {
    learned_vectors := []
    json_path := ""

    __New(storage_path) {
        this.json_path := storage_path
        this.load_knowledge()
    }

    load_knowledge() {
        if !FileExist(this.json_path) {
            this.learned_vectors := []
            return
        }
        try {
            json_str := FileRead(this.json_path, "UTF-8")
            if (json_str != "") {
                raw_list := JSON.parse(json_str)
                this.learned_vectors := []
                ; 启动时直接预计算向量空间 (Pre-compute vectors at load time)
                for item in raw_list {
                    item["class_vec"] := this.get_ngrams(item["class_raw"])
                    item["title_vec"] := this.get_ngrams(item["title_raw"])
                    
                    ; 预计算分母 (Magnitude squared sum) 避免每次 predict 重复计算
                    sum_c := 0.0
                    for k, v in item["class_vec"]
                        sum_c += v ** 2
                    item["class_mag"] := Sqrt(sum_c)
                    
                    sum_t := 0.0
                    for k, v in item["title_vec"]
                        sum_t += v ** 2
                    item["title_mag"] := Sqrt(sum_t)
                    
                    this.learned_vectors.Push(item)
                }
            }
        } catch Error as e {
            Logger.info("解析向量知识库失败：" . e.Message)
            this.learned_vectors := []
        }
    }

    save_knowledge() {
        try {
            ; 剔除预计算的复杂对象以保证 JSON 纯净
            export_list := []
            for item in this.learned_vectors {
                clean_item := Map(
                    "id", item["id"],
                    "label", item["label"],
                    "exe", item["exe"],
                    "class_raw", item["class_raw"],
                    "title_raw", item["title_raw"]
                )
                export_list.Push(clean_item)
            }
            json_str := JSON.stringify(export_list)
            
            SplitPath this.json_path, &name, &dir
            if !DirExist(dir) {
                DirCreate dir
            }

            file_obj := FileOpen(this.json_path, "w", "UTF-8")
            file_obj.Write(json_str)
            file_obj.Close()
        } catch Error as e {
            Logger.info("保存向量知识库失败：" . e.Message)
        }
    }

    learn_sample(window_info, label) {
        new_record := Map(
            "id", A_Now,
            "label", label,
            "exe", StrLower(window_info.exe),
            "class_raw", window_info.class,
            "title_raw", window_info.title
        )
        ; 手动预计算放入内存
        new_record["class_vec"] := this.get_ngrams(new_record["class_raw"])
        new_record["title_vec"] := this.get_ngrams(new_record["title_raw"])
        
        sum_c := 0.0
        for k, v in new_record["class_vec"]
            sum_c += v ** 2
        new_record["class_mag"] := Sqrt(sum_c)
        
        sum_t := 0.0
        for k, v in new_record["title_vec"]
            sum_t += v ** 2
        new_record["title_mag"] := Sqrt(sum_t)

        this.learned_vectors.Push(new_record)
        this.save_knowledge()
        return new_record["id"]
    }

    predict(window_info) {
        if (this.learned_vectors.Length == 0) {
            return {label: "Not_CATIA", score: 0}
        }

        exe := StrLower(window_info.exe)
        
        ; 目标窗口只计算一次向量
        target_class_vec := this.get_ngrams(window_info.class)
        target_title_vec := this.get_ngrams(window_info.title)
        
        target_class_mag := 0.0
        for k, v in target_class_vec
            target_class_mag += v ** 2
        target_class_mag := Sqrt(target_class_mag)
        
        target_title_mag := 0.0
        for k, v in target_title_vec
            target_title_mag += v ** 2
        target_title_mag := Sqrt(target_title_mag)

        best_score := 0.0
        best_label := "Not_CATIA"

        for base in this.learned_vectors {
            if (exe != base["exe"]) {
                continue
            }

            score_class := this.fast_cosine(base["class_vec"], base["class_mag"], target_class_vec, target_class_mag)
            score_title := this.fast_cosine(base["title_vec"], base["title_mag"], target_title_vec, target_title_mag)

            total_score := (score_class * 0.5) + (score_title * 0.5)

            if (total_score > best_score) {
                best_score := total_score
                best_label := base["label"]
            }
        }

        if (best_score > 0.60) {
            return {label: best_label, score: best_score}
        }
        
        return {label: "Not_CATIA", score: best_score}
    }

    get_ngrams(text, n:=3) {
        grams := Map()
        len := StrLen(text)
        if (len < n) {
            grams[text] := 1
            return grams
        }
        
        Loop (len - n + 1) {
            frag := SubStr(text, A_Index, n)
            if (grams.Has(frag)) {
                grams[frag] += 1
            } else {
                grams[frag] := 1
            }
        }
        return grams
    }

    fast_cosine(vec1, mag1, vec2, mag2) {
        if (mag1 == 0 or mag2 == 0) {
            return 0.0
        }
        
        numerator := 0.0
        for k, v1 in vec1 {
            if (vec2.Has(k)) {
                numerator += v1 * vec2[k]
            }
        }
        return numerator / (mag1 * mag2)
    }
}

class ImageCapture {
    static CaptureWindow(hwnd, filepath) {
        try {
            hGdiplus := DllCall("LoadLibrary", "Str", "gdiplus.dll", "Ptr")
            
            si := Buffer(16, 0)
            NumPut("UInt", 1, si, 0)
            DllCall("gdiplus\GdiplusStartup", "UPtr*", &pToken:=0, "Ptr", si, "Ptr", 0)
            
            rect := Buffer(16, 0)
            DllCall("GetWindowRect", "Ptr", hwnd, "Ptr", rect)
            w := NumGet(rect, 8, "Int") - NumGet(rect, 0, "Int")
            h := NumGet(rect, 12, "Int") - NumGet(rect, 4, "Int")
            
            if (w <= 0 or h <= 0) {
                return false
            }

            hDC := DllCall("GetDC", "Ptr", 0, "Ptr")
            mDC := DllCall("CreateCompatibleDC", "Ptr", hDC, "Ptr")
            hBM := DllCall("CreateCompatibleBitmap", "Ptr", hDC, "Int", w, "Int", h, "Ptr")
            oBM := DllCall("SelectObject", "Ptr", mDC, "Ptr", hBM, "Ptr")
            
            DllCall("PrintWindow", "Ptr", hwnd, "Ptr", mDC, "UInt", 3)
            
            DllCall("gdiplus\GdipCreateBitmapFromHBITMAP", "Ptr", hBM, "Ptr", 0, "UPtr*", &pBitmap:=0)
            
            clsid := Buffer(16, 0)
            DllCall("ole32\CLSIDFromString", "WStr", "{557CF406-1A04-11D3-9A73-0000F81EF32E}", "Ptr", clsid)
            
            DllCall("gdiplus\GdipSaveImageToFile", "Ptr", pBitmap, "WStr", filepath, "Ptr", clsid, "Ptr", 0)
            
            DllCall("gdiplus\GdipDisposeImage", "Ptr", pBitmap)
            DllCall("SelectObject", "Ptr", mDC, "Ptr", oBM)
            DllCall("DeleteObject", "Ptr", hBM)
            DllCall("DeleteDC", "Ptr", mDC)
            DllCall("ReleaseDC", "Ptr", 0, "Ptr", hDC)
            DllCall("gdiplus\GdiplusShutdown", "UPtr", pToken)
            DllCall("FreeLibrary", "Ptr", hGdiplus)

            return true
        } catch Error as e {
            Logger.info("截图失败: " e.Message)
            return false
        }
    }
}
