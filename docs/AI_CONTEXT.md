# AI Context - UCLC 项目分支策略与开发历程

> 最后更新: 2026-06-22
> 本文件记录 AI 协同开发的历程与项目现状，供 AI 助手快速恢复上下文。

## 分支策略

```
master (稳定发布) ← v2.5.0-dev (长期开发) ← feat/* (功能分支)
```

### 发布流程
- **功能开发**: `feat/*` → 合并到 `v2.5.0-dev` → 稳定后合并到 `master`
- **Bug 修复**: `fix/*` → 合并到 `v2.5.0-dev` 或 `release/*` → 测试通过后发布

## 当前分支现状 (2026-06-22)

| 分支 | 用途 | 状态 |
|------|------|------|
| `master` | 稳定发布 (`v2.4.2`) | 🟢 稳定，已发布 GitHub Release |
| `v2.5.0-dev` | 长期开发分支 | 🟡 基于 v2.4.2 创建，开发中 |
| `release/v2.4.2` | v2.4.2 修复版发布 | ✅ 已完成使命，已合入 master |
| `feat/auto-version-stamp` | 版本号自动化 | ✅ 已合并到 `release/v2.4.2` |
| `fix/revert-hdr-instance-cache` | 撤销 Hdr 全局模式 | ✅ 已合并到 `release/v2.4.2` |
| `fix/alt-synchronous-core` | Alt 键同步修复 | ✅ 已合并到 `release/v2.4.2` |
| `fix/unhandled-workbench-return` | 工作台保护逻辑 | ✅ 已合并到 `release/v2.4.2` |
| `fix/alt-enter-blind-mode` | ControlSend 修饰键修复 | ✅ 已合并到 `release/v2.4.2` |

## 版本演进历史

```
v2.4.1 (master, 旧版)
  ├── v2.4.2-RC1 → RC2 → RC2-BUGFIX → RC3 → RC3.10081 → RC4 → RC5 → RC6
  │     └── fix/alt-synchronous-core (已合入)
  │     └── fix/unhandled-workbench-return (已合入)
  │     └── fix/revert-hdr-instance-cache (已合入)
  │     └── feat/auto-version-stamp (已合入)
  │     └── fix/alt-enter-blind-mode (已合入)
  │     └── → release/v2.4.2 → 合入 master → 正式发布 v2.4.2 ✅
  │
  └── v2.4.2 (master, 当前稳定版)
        └── v2.5.0-dev (长期开发分支，开发中)
```

## 关键标签

`v2.4.0` → `v2.4.1` → `v2.4.2-RC1` → `v2.4.2-RC2` → `v2.4.2-RC2-BUGFIX` → `v2.4.2-RC3.10081` → `v2.4.2-RC3.10081.hotfix1` → `v2.4.2-RC4` → `v2.4.2-RC5` → `v2.4.2` (正式版)

## 版本号自动化机制

- **唯一版本源**：Git tag（通过 `git describe --tags --always`）
- **自动注入**：`scripts/stamp_version.sh` 在每次 `git commit` 前通过 pre-commit hook 自动将版本号写入 `Lib/Version.ahk`
- **hook 安装**：新 clone 后需运行 `bash scripts/install_hooks.sh` 安装 hook
- **编码注意**：`config.ini` 为 UTF-16LE 编码，脚本通过 `iconv` 转码处理
- **重要修复记录**：v2.4.2 发布过程中发现 `stamp_version.sh` 因 CRLF 换行符导致 Bash 执行失败（`$'\r': command not found`），已修复为 LF 换行符

## v2.4.2 发布过程记录

1. 将 `release/v2.4.2` 以 `--no-ff` 合入 `master`
2. 发现 `stamp_version.sh` 因 CRLF 换行符在 Windows Bash 中执行失败
3. 使用 Python 脚本修复换行符为 LF
4. 重新执行 `stamp_version.sh`，版本号 `v2.4.2` 成功注入 `Lib/Version.ahk`
5. `git commit --amend --no-edit` 将修复纳入合并提交
6. `git tag -f -a v2.4.2` 重新打标签
7. Push `master` 和 `v2.4.2` tag 到 GitHub
8. 通过 `gh release create v2.4.2` 创建 GitHub Release
