#!/bin/bash
# install_hooks.sh - 安装 Git hooks
#
# .git/hooks/ 不受版本控制，新 clone 仓库后需运行一次此脚本来安装 hooks。
#
# 用法：
#   bash scripts/install_hooks.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
HOOKS_DIR="${PROJECT_ROOT}/.git/hooks"

# 确保 hooks 目录存在
mkdir -p "${HOOKS_DIR}"

# 创建 pre-commit hook
cat > "${HOOKS_DIR}/pre-commit" << 'HOOK_EOF'
#!/bin/bash
# pre-commit hook - 自动更新 Lib/Version.ahk
#
# 由 scripts/install_hooks.sh 安装，请勿手动编辑。
# 如需修改逻辑，请编辑 scripts/stamp_version.sh 后重新运行安装脚本。

REPO_ROOT="$(git rev-parse --show-toplevel)"

# 运行版本号注入脚本
bash "${REPO_ROOT}/scripts/stamp_version.sh"

# 如果 Lib/Version.ahk 被修改，将其加入暂存区
if git diff --name-only -- Lib/Version.ahk | grep -q "Lib/Version.ahk"; then
    git add Lib/Version.ahk
    echo "[pre-commit] Lib/Version.ahk 版本号已自动暂存"
fi
HOOK_EOF

# 设置可执行权限
chmod +x "${HOOKS_DIR}/pre-commit"

echo "[install_hooks] pre-commit hook 安装成功"
echo "[install_hooks] 位置: ${HOOKS_DIR}/pre-commit"
