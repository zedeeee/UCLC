import os
import glob
import re
import json

def is_chinese_system():
    try:
        import ctypes
        lang_id = ctypes.windll.kernel32.GetUserDefaultUILanguage()
        return (lang_id & 0x3FF) == 0x04
    except Exception:
        return False

def T(zh_str, en_str):
    return zh_str if is_chinese_system() else en_str

def detect_catia_path():
    default_paths = glob.glob(r"C:\Program Files\Dassault Systemes\B*\win_b64\resources\msgcatalog")
    if default_paths and os.path.exists(default_paths[0]):
        return default_paths[0]
    
    try:
        import subprocess
        output = subprocess.check_output('wmic process where "name=\'CNEXT.exe\'" get ExecutablePath', shell=True).decode(errors='ignore')
        paths = [p.strip() for p in output.split('\n') if 'CNEXT.exe' in p]
        if paths:
            bin_dir = os.path.dirname(paths[0])
            win_b64_dir = os.path.dirname(os.path.dirname(bin_dir))
            msg_dir = os.path.join(win_b64_dir, 'resources', 'msgcatalog')
            if os.path.exists(msg_dir):
                return msg_dir
    except Exception:
        pass
        
    return None

def generate_mapping(msgcatalog_path):
    languages = [
        'English', 'French', 'German', 'Italian', 
        'Japanese', 'Korean', 'Russian', 'Simplified_Chinese'
    ]
    
    access_pattern = re.compile(r'^\s*([A-Za-z0-9_]+)\.Access\s*=\s*"([^"]+)";', re.IGNORECASE)
    id_to_prefix = {}
    
    print(T("\n[*] 正在解析根目录的 .CATRsc 资源文件...", "\n[*] Parsing .CATRsc resource files in the root directory..."))
    rsc_files = glob.glob(os.path.join(msgcatalog_path, "*.CATRsc"))
    for filepath in rsc_files:
        try:
            with open(filepath, "r", encoding="utf-8", errors="ignore") as f:
                for line in f:
                    match = access_pattern.search(line)
                    if match:
                        id_to_prefix[match.group(2)] = match.group(1)
        except Exception:
            pass

    nls_files = glob.glob(os.path.join(msgcatalog_path, "*.CATNls"))
    for filepath in nls_files:
        basename = os.path.basename(filepath)[:-7]
        if "Wkb" in basename or "Wks" in basename or "Workshop" in basename or "Workbench" in basename:
            if basename not in id_to_prefix:
                id_to_prefix[basename] = basename

    print(T(f"[*] 提取到 {len(id_to_prefix)} 个内部映射，开始抓取多语言名称...", f"[*] Extracted {len(id_to_prefix)} internal mappings, fetching multi-language names..."))

    title_pattern = re.compile(r'^\s*([A-Za-z0-9_]+)\.Title\s*=\s*"([^"]+)";', re.IGNORECASE)
    
    def extract_title(nls_filepath, expected_prefix, lang):
        if not os.path.exists(nls_filepath):
            return None
            
        enc_map = {
            'Japanese': ['shift_jis', 'utf-8'],
            'Korean': ['euc_kr', 'utf-8'],
            'Russian': ['windows-1251', 'utf-8'],
            'Simplified_Chinese': ['gbk', 'utf-8'],
            'French': ['windows-1252', 'utf-8'],
            'German': ['windows-1252', 'utf-8'],
            'Italian': ['windows-1252', 'utf-8'],
            'English': ['windows-1252', 'utf-8']
        }
        
        for enc in enc_map.get(lang, ['utf-8', 'latin1']):
            try:
                with open(nls_filepath, "r", encoding=enc) as f:
                    content = f.read()
                for line in content.splitlines():
                    match = title_pattern.search(line)
                    if match and match.group(1).lower() == expected_prefix.lower():
                        return match.group(2)
            except Exception:
                pass
        return None

    mapping_result = {}
    
    for internal_id, prefix in id_to_prefix.items():
        translations = {}
        for lang in languages:
            if lang == 'English':
                nls_path = os.path.join(msgcatalog_path, f"{prefix}.CATNls")
            else:
                nls_path = os.path.join(msgcatalog_path, lang, f"{prefix}.CATNls")
                
            title = extract_title(nls_path, prefix, lang)
            if title:
                translations[lang] = title
                
        if translations:
            mapping_result[internal_id] = translations

    return mapping_result

if __name__ == "__main__":
    print("=" * 60)
    print(T(" CATIA 工作台多语言映射提取工具 (UCLC)", " CATIA Workbench Multi-Language Mapping Tool (UCLC)"))
    print("=" * 60)
    
    auto_path = detect_catia_path()
    
    if auto_path:
        print(T(f"\n[+] 自动侦测到 CATIA msgcatalog 目录:\n    {auto_path}", f"\n[+] Auto-detected CATIA msgcatalog directory:\n    {auto_path}"))
        prompt = T("\n确认使用此路径？(按回车确认，或直接输入新的路径): ", "\nConfirm to use this path? (Press Enter to confirm, or input a new path): ")
        user_input = input(prompt).strip()
        msg_path = user_input if user_input else auto_path
    else:
        print(T("\n[-] 未能自动侦测到 CATIA 目录。", "\n[-] Failed to auto-detect CATIA directory."))
        prompt = T("请输入你的 msgcatalog 绝对路径: ", "Please input your msgcatalog absolute path: ")
        msg_path = input(prompt).strip()

    if not os.path.exists(msg_path):
        print(T(f"\n[!] 错误: 路径不存在或无效 -> {msg_path}", f"\n[!] Error: Path does not exist or is invalid -> {msg_path}"))
        exit(1)
        
    mapping = generate_mapping(msg_path)
    
    script_dir = os.path.dirname(os.path.abspath(__file__))
    
    # 尝试寻找 UCLC 根目录 (特征：包含 UCLC.ahk)
    def find_uclc_root(start_path):
        current = start_path
        for _ in range(3):  # 最多往上找3层
            if os.path.exists(os.path.join(current, "UCLC.ahk")):
                return current
            parent = os.path.dirname(current)
            if parent == current:
                break
            current = parent
        return None

    uclc_root = find_uclc_root(script_dir)
    
    if uclc_root:
        # 如果在 UCLC 项目内运行，规范输出到 data 文件夹
        target_dir = os.path.join(uclc_root, "data")
    else:
        # 如果被单独拎出去运行（绿色版模式），直接存在同级目录
        target_dir = script_dir
        
    if not os.path.exists(target_dir):
        os.makedirs(target_dir)
        
    out_file = os.path.join(target_dir, "workbench_mapping.json")
    with open(out_file, "w", encoding="utf-8") as f:
        json.dump(mapping, f, ensure_ascii=False, indent=4)
        
    print(T(f"\n[+] 成功生成了 {len(mapping)} 个工作台的全语种映射字典。", f"\n[+] Successfully generated multi-language mapping dictionary for {len(mapping)} workbenches."))
    print(T(f"[+] 字典已保存至:\n    {out_file}", f"[+] Dictionary saved to:\n    {out_file}"))

