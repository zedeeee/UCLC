#!/bin/bash
# stamp_version.sh - 从 Git tag 自动注入版本号到 config.ini
#
# 使用 `git describe --tags --always` 获取版本描述，写入 config.ini 的 [Version] 段。
# 在 tag 上时输出精确版本号（如 v2.4.2），否则输出带提交距离的描述（如 v2.4.2-3-g1a2b3c4）。
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

# 将 UTF-16LE 转为 UTF-8 后读取当前版本号
current_version=$(iconv -f UTF-16 -t UTF-8 "${CONFIG_FILE}" | grep -E "^Version\s*=" | sed 's/^Version\s*=\s*//' | tr -d '\r')

# 如果版本号没有变化，跳过写入
if [[ "${current_version}" == "${version}" ]]; then
    echo "[stamp_version] 版本号未变化: ${version}"
    exit 0
fi

# UTF-16LE → UTF-8 → sed 替换 → UTF-8 → UTF-16LE 写回
iconv -f UTF-16 -t UTF-8 "${CONFIG_FILE}" \
    | sed "s/^Version = .*/Version = ${version}/" \
    | iconv -f UTF-8 -t UTF-16 \
    > "${CONFIG_FILE}.tmp"

mv "${CONFIG_FILE}.tmp" "${CONFIG_FILE}"

echo "[stamp_version] 版本号已更新: ${current_version} → ${version}"
