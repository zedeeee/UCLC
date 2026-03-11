#!/bin/bash
# stamp_version.sh - pre-commit 自动处理 config.ini
#
# 功能：
#   1. 从 Git tag 注入版本号到 [Version] 段
#   2. 强制将 DEBUG 设为 0，防止调试配置被提交
#
# 注意：config.ini 为 UTF-16LE 编码（Windows INI 默认），脚本通过 iconv 转码处理。
#
# 用法：
#   直接运行：bash scripts/stamp_version.sh
#   由 pre-commit hook 自动调用

set -euo pipefail

# 定位项目根目录（脚本可能从任意目录被调用）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONFIG_FILE="${PROJECT_ROOT}/config.ini"

# 获取 Git 版本描述
version=$(git -C "${PROJECT_ROOT}" describe --tags --always 2>/dev/null || echo "Unknown")

# 检查 config.ini 是否存在
if [[ ! -f "${CONFIG_FILE}" ]]; then
    echo "[stamp_version] 错误: 未找到 ${CONFIG_FILE}"
    exit 1
fi

# 将 UTF-16LE 转为 UTF-8 后读取当前值
config_utf8=$(iconv -f UTF-16 -t UTF-8 "${CONFIG_FILE}")
current_version=$(echo "${config_utf8}" | grep -E "^Version\s*=" | sed 's/^Version\s*=\s*//' | tr -d '\r')
current_debug=$(echo "${config_utf8}" | grep -E "^DEBUG\s*=" | sed 's/^DEBUG\s*=\s*//' | tr -d '\r')

changed=false

# 检查是否需要更新版本号
if [[ "${current_version}" != "${version}" ]]; then
    config_utf8=$(echo "${config_utf8}" | sed "s/^Version = .*/Version = ${version}/")
    echo "[stamp_version] 版本号已更新: ${current_version} → ${version}"
    changed=true
fi

# 强制 DEBUG = 0，防止调试配置被提交
if [[ "${current_debug}" != "0" ]]; then
    config_utf8=$(echo "${config_utf8}" | sed "s/^DEBUG = .*/DEBUG = 0/")
    echo "[stamp_version] DEBUG 已重置: ${current_debug} → 0"
    changed=true
fi

# 如果没有任何变化，跳过写入
if [[ "${changed}" != "true" ]]; then
    echo "[stamp_version] config.ini 无需更新"
    exit 0
fi

# UTF-8 → UTF-16LE (带 BOM) 写回
# 注意：iconv -t UTF-16 可能输出 BE，必须显式指定 UTF-16LE 并手动补 BOM (FF FE)
(printf '\xff\xfe' && echo "${config_utf8}" | iconv -f UTF-8 -t UTF-16LE) \
    > "${CONFIG_FILE}.tmp"

mv "${CONFIG_FILE}.tmp" "${CONFIG_FILE}"
