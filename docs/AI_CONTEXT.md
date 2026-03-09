# AI Context - UCLC 项目分支策略与现状

> 最后更新: 2026-03-10
> 本文件供 AI 助手快速恢复项目上下文，请保持同步更新。

## 分支策略

```
master (稳定发布) ← v2.5.0 (集成测试) ← feat/* (功能开发)
                 ← v2.4.2-RC4 (修复发布) ← fix/* (Bug 修复)
```

### 发布流程
- **功能开发**: `feat/*` → 合并到 `v2.5.0` → 测试通过后合并到 `master`
- **Bug 修复**: `fix/*` → 合并到 `v2.4.2-RC4` → 测试通过后发布为 `v2.4.2`

## 当前分支现状 (2026-03-10)

| 分支 | 用途 | 状态 |
|------|------|------|
| `master` | 稳定发布 (`v2.4.1`) | 🟢 稳定 |
| `v2.5.0` | 功能集成分支 | 🟡 从 master 新建，待合入功能 |
| `feat/v2.5-core-overhaul` | 核心重构功能分支 | 🟡 原 `v2.4.2-RC4`，含输入法增强/别名重构/配置GUI/热键引擎重写 |
| `v2.4.2-RC4` | 修复版发布候选 | 🟢 已合并 `fix/alt-synchronous-core` + `fix/unhandled-workbench-return` |
| `fix/alt-synchronous-core` | Alt 键同步修复 | ✅ 已合并到 `v2.4.2-RC4` |
| `fix/unhandled-workbench-return` | 工作台保护逻辑 | ✅ 已合并到 `v2.4.2-RC4` |
| `hotfix/v2.4.2-RC3.10081` | RC3 热修复 | 📦 `fix/alt-synchronous-core` 的前身/base |

## 版本演进历史

```
v2.4.1 (master)
  ├── v2.4.2-RC1 → RC2 → RC2-BUGFIX → RC3 → RC3.10081
  │     └── fix/alt-synchronous-core (已合入 RC4)
  │     └── fix/unhandled-workbench-return (已合入 RC4)
  │     └── → v2.4.2-RC4 (当前修复发布候选)
  │
  └── feat/v2.5-core-overhaul (原 v2.4.2-RC4，大功能改动)
        └── → 待合入 v2.5.0
```

## feat/v2.5-core-overhaul 功能清单

1. **输入法自动切换增强** - 状态检测优化、确认算法优化
2. **别名函数系统重构** - 面向对象方式重写
3. **配置系统重建** - GUI 下载 + 模板化 (`config.template.ini`)
4. **核心热键引擎** - Alt 键修复、Hdr 缓存、safe_send_enter 统一收口
5. **架构变更** - AppSettings 静态类、版本号配置化、Everything GUI 配置

## 关键标签

`v2.4.0` → `v2.4.1` → `v2.4.2-RC1` → `v2.4.2-RC2` → `v2.4.2-RC2-BUGFIX` → `v2.4.2-RC3.10081` → `v2.4.2-RC3.10081.hotfix1`
