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

# 清理旧的 pre-commit hook（版本注入已迁移至 post-commit）
if [ -f "${HOOKS_DIR}/pre-commit" ]; then
    rm -f "${HOOKS_DIR}/pre-commit"
    echo "[install_hooks] 已移除旧的 pre-commit hook"
fi

# 创建 post-commit hook
cat > "${HOOKS_DIR}/post-commit" << 'HOOK_EOF'
#!/bin/bash
# post-commit hook - 自动更新 Lib/Version.ahk
#
# 由 scripts/install_hooks.sh 安装，请勿手动编辑。
# 如需修改逻辑，请编辑 scripts/stamp_version.sh 后重新运行安装脚本。

# ── 递归保护 ──
# git commit --amend 也会触发 post-commit，
# 通过环境变量防止无限递归。
if [ "${UCLC_VERSION_STAMPING:-}" = "1" ]; then
    exit 0
fi
export UCLC_VERSION_STAMPING=1

REPO_ROOT="$(git rev-parse --show-toplevel)"

# 运行版本号注入脚本
bash "${REPO_ROOT}/scripts/stamp_version.sh"

# 如果 Lib/Version.ahk 被修改，追补进当前 commit
if git diff --name-only -- Lib/Version.ahk | grep -q "Lib/Version.ahk"; then
    git add Lib/Version.ahk
    git commit --amend --no-edit --no-verify
    echo "[post-commit] Lib/Version.ahk 版本号已自动追补"
fi
HOOK_EOF

# 设置可执行权限
chmod +x "${HOOKS_DIR}/post-commit"

echo "[install_hooks] post-commit hook 安装成功"
echo "[install_hooks] 位置: ${HOOKS_DIR}/post-commit"
