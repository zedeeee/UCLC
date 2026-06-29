#!/bin/bash
# stamp_version.sh - pre-commit 自动注入版本号到 Lib/Version.ahk
#
# 功能：
#   从 Git tag 提取描述性版本号并精确更新 Lib/Version.ahk 中的常量值。
#   - 精确命中 tag 时输出短格式（如 v2.4.2-RC5）
#   - 偏离 tag 时输出长格式（如 v2.4.2-RC5-3-04430a5）
#
# 用法：
#   直接运行：bash scripts/stamp_version.sh
#   由 pre-commit hook 自动调用

set -euo pipefail

# 环境变量跳过检查
if [[ "${SKIP_STAMP_VERSION:-0}" == "1" ]]; then
    exit 0
fi

# Rebase 检测跳过逻辑 (防止 rebase 期间的自动 amend 失败)
if [ -d "$(git rev-parse --git-dir 2>/dev/null)/rebase-merge" ] || [ -d "$(git rev-parse --git-dir 2>/dev/null)/rebase-apply" ]; then
    echo "[stamp_version] 当前处于 rebase 状态，跳过版本号注入"
    exit 0
fi

# 定位项目根目录（脚本可能从任意目录被调用）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
VERSION_FILE="${PROJECT_ROOT}/Lib/Version.ahk"

# 获取 Git 版本描述并根据 tag 命中情况智能裁剪
raw_version=$(git -C "${PROJECT_ROOT}" describe --tags --always --long 2>/dev/null || echo "Unknown")
if [[ "${raw_version}" == *-0-g* ]]; then
    # 精确处于 tag，仅截取 tag 名称
    version=$(echo "${raw_version}" | sed -E 's/-0-g[0-9a-f]+$//')
else
    # 偏离 tag，去除 g 标识
    version=$(echo "${raw_version}" | sed -E 's/-g([0-9a-f]{7,})$/-\1/')
fi

# 精确修改 Lib/Version.ahk 中的版本号
if [[ -f "${VERSION_FILE}" ]]; then
    sed -E "s/^(global UCLC_VERSION := \").*(\")/\1${version}\2/" "${VERSION_FILE}" > "${VERSION_FILE}.tmp"
    mv "${VERSION_FILE}.tmp" "${VERSION_FILE}"
    echo "[stamp_version] Version.ahk 版本号已更新: ${version}"
else
    echo "[stamp_version] 警告: 未找到 ${VERSION_FILE}"
fi
