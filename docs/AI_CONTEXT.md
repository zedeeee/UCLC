# AI Context - UCLC 项目分支策略与现状

> 最后更新: 2026-03-11
> 本文件供 AI 助手快速恢复项目上下文，请保持同步更新。

## 分支策略

```
master (稳定发布) ← v2.5.0 (集成测试) ← feat/* (功能开发)
                 ← release/v2.4.2 (修复发布) ← fix/* (Bug 修复)
```

### 发布流程
- **功能开发**: `feat/*` → 合并到 `v2.5.0` → 测试通过后合并到 `master`
- **Bug 修复**: `fix/*` → 合并到 `release/v2.4.2` → 测试通过后发布为 `v2.4.2`

## 当前分支现状 (2026-04-11)

| 分支 | 用途 | 状态 |
|------|------|------|
| `master` | 稳定发布 (`v2.4.1`) | 🟢 稳定 |
| `v2.5.0` | 功能集成分支 | 🟡 从 master 新建，待合入功能 |
| `feat/v2.5-core-overhaul` | 核心重构功能分支 | 🟡 原 RC4 分支，含输入法增强/别名重构/配置GUI/热键引擎重写 |
| `release/v2.4.2` | 修复版发布候选 | 🟢 当前发布候选 `v2.4.2-RC5`。 |
| `feat/auto-version-stamp` | 版本号自动化 | ✅ 已合并到 `release/v2.4.2` |
| `fix/revert-hdr-instance-cache` | 撤销 Hdr 全局模式 | ✅ 已合并到 `release/v2.4.2` |
| `fix/alt-synchronous-core` | Alt 键同步修复 | ✅ 已合并到 `release/v2.4.2` |
| `fix/unhandled-workbench-return` | 工作台保护逻辑 | ✅ 已合并到 `release/v2.4.2` |
| `fix/alt-enter-blind-mode` | ControlSend 修饰键自适应修复 | ✅ 于 RC4 后提出，现已合并至发布分支。 |

## 版本演进历史

```
v2.4.1 (master)
  ├── v2.4.2-RC1 → RC2 → RC2-BUGFIX → RC3 → RC3.10081 → RC4 → RC5
  │     └── fix/alt-synchronous-core (已合入)
  │     └── fix/unhandled-workbench-return (已合入)
  │     └── fix/revert-hdr-instance-cache (已合入)
  │     └── feat/auto-version-stamp (已合入)
  │     └── fix/alt-enter-blind-mode (已合入)
  │     └── → release/v2.4.2 (当前修复发布候选 `v2.4.2-RC5`)
  │
  └── feat/v2.5-core-overhaul (大功能改动分支)
        └── → 待合入 v2.5.0
```

## feat/v2.5-core-overhaul 功能清单

1. **输入法自动切换增强** - 状态检测优化、确认算法优化
2. **别名函数系统重构** - 面向对象方式重写
3. **配置系统重建** - GUI 下载 + 模板化 (`config.template.ini`)
4. **核心热键引擎** - Alt 键修复、Hdr 缓存、safe_send_enter 统一收口
5. **架构变更** - AppSettings 静态类、版本号配置化、Everything GUI 配置

## 关键标签

`v2.4.0` → `v2.4.1` → `v2.4.2-RC1` → `v2.4.2-RC2` → `v2.4.2-RC2-BUGFIX` → `v2.4.2-RC3.10081` → `v2.4.2-RC3.10081.hotfix1` → `v2.4.2-RC4`

## 版本号自动化机制

- **唯一版本源**：Git tag（通过 `git describe --tags --always`）
- **自动注入**：`scripts/stamp_version.sh` 在每次 `git commit` 前通过 pre-commit hook 自动将版本号写入 `config.ini`
- **hook 安装**：新 clone 后需运行 `bash scripts/install_hooks.sh` 安装 hook
- **编码注意**：`config.ini` 为 UTF-16LE 编码，脚本通过 `iconv` 转码处理
- **计划中**：`.agent/workflows/release.md` 发布 workflow（待 `.agent` 独立为 submodule 后提交）
