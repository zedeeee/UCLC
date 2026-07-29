# ==============================================================================
# 【脚本作用】
# 本脚本为 CATIA 资源文件与文本编码的洗净与规范化工具。专门处理达索历史遗留的
# 混杂字符集 (UTF-8, UTF-16LE/BE, GBK, GB18030 及无 BOM 问题)，按从严到宽的顺序
# 尝试解码并过滤假成功乱码，将有效文本安全统一为无 BOM 的纯 UTF-8 (UTF-8-RAW) 格式。
#
# 【使用方法】
# 1. 交互式运行：直接执行 python convert_to_utf8.py，根据提示输入待转码的文件夹路径。
# 2. 命令行传参：python convert_to_utf8.py <源目录> [目标目录]
#    - 若不指定 [目标目录]，则默认在 <源目录> 进行原地转码覆盖。
#    - 若指定 [目标目录]，则将洗净后的 UTF-8 文件输出至目标路径，原文件不受影响。
# ==============================================================================

import os
import glob
import sys
import shutil

def convert_to_utf8(source_dir, dest_dir):
    # Ensure destination directory exists
    if not os.path.exists(dest_dir):
        os.makedirs(dest_dir)
        
    # Search for all files (CATNls, CATRsc, txt, etc.)
    files = []
    for ext in ["*.CATNls", "*.CATRsc", "*.txt"]:
        files.extend(glob.glob(os.path.join(source_dir, ext)))
        
    print(f"找到 {len(files)} 个待转换的文件...")
    print(f"转换后的文件将保存在: {dest_dir}")
    
    success_count = 0
    error_count = 0
    
    for filepath in files:
        content = None
        
        # 严格按照从严到宽的顺序尝试解码
        # 1. 优先尝试 utf-8
        # 2. 尝试 utf-16 (带 BOM 或小端)
        # 3. 最后尝试 gbk (CATIA 简体中文版的默认玄学编码)
        for enc in ['utf-8', 'utf-16', 'gbk', 'gb18030']:
            try:
                with open(filepath, "r", encoding=enc) as f:
                    content = f.read()
                
                # 如果用 utf-8 解码却读出了一堆 \x00，说明它大概率是个没 BOM 的 utf-16le
                if '\x00' in content and enc == 'utf-8':
                    continue
                break
            except Exception:
                continue
                
        filename = os.path.basename(filepath)
        dest_filepath = os.path.join(dest_dir, filename)
        
        if content is None:
            error_count += 1
            print(f"[!] 无法解码文件: {filename}")
            if source_dir != dest_dir:
                shutil.copy2(filepath, dest_filepath)
            continue
            
        # 以 UTF-8 无 BOM 格式写入新文件夹
        try:
            with open(dest_filepath, "w", encoding="utf-8") as f:
                f.write(content)
            success_count += 1
        except Exception as e:
            error_count += 1
            print(f"[!] 写入失败 {filename}: {e}")

    print("\n" + "="*40)
    print("转换完成！")
    print(f"成功导出 UTF-8 文件: {success_count} 个")
    print(f"失败/原样拷贝: {error_count} 个")
    print("="*40)

def print_banner():
    print("=" * 60)
    print("      CATIA 资源文件/导出的工作台文本转 UTF-8 编码工具")
    print("=" * 60)
    print(" 作用:")
    print("   全自动扫描指定目录下的 *.CATNls, *.CATRsc, *.txt 文件。")
    print("   自动识别其原有编码（UTF-8, UTF-16, GBK, GB18030），并安全地统一转码为无 BOM UTF-8。")
    print(" ")
    print(" 用法:")
    print("   1. 原地覆盖转码: 直接输入待转码目录。")
    print("   2. 异地转码备份: 在运行脚本时使用参数：python convert_to_utf8.py [源目录] [目标目录]")
    print("=" * 60 + "\n")

if __name__ == "__main__":
    try:
        print_banner()
        # 支持命令行参数传参，也支持交互式手动输入路径
        if len(sys.argv) > 1:
            src_dir = sys.argv[1]
        else:
            src_dir = input("请输入待转换的文件夹绝对路径: ").strip()
            
        if not src_dir:
            print("[!] 路径不能为空，脚本退出。")
            sys.exit(1)
            
        if not os.path.exists(src_dir):
            print(f"[!] 路径不存在: {src_dir}")
            sys.exit(1)
            
        dst_dir = sys.argv[2] if len(sys.argv) > 2 else src_dir
        convert_to_utf8(src_dir, dst_dir)
    except KeyboardInterrupt:
        print("\n[!] 用户已取消操作，脚本安全退出。")
        sys.exit(0)
