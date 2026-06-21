# CLAUDE.md

> 该文件是 UCLC 项目专属的 AI 开发约束文件。
> 任何 AI 编码助手在本项目中工作时，必须遵循以下规范。

## 项目概述

UCLC (Use CATIA Like AutoCAD) 是一个 AutoHotkey v2 脚本，让 CATIA V5 的命令交互更接近 AutoCAD 的操作习惯。核心能力：在 CATIA 的 Power-Input 输入框中输入用户自定义的短别名，按空格即可执行对应的 CATIA 命令。同时提供自定义热键、输入法自动切换、音量控制、虚拟桌面切换等辅助功能。

## 技术栈与运行环境

- **语言**: AutoHotkey v2.0+
- **操作系统**: Windows 10 / 11
- **目标软件**: CATIA V5-6 R27 (进程名 `CNEXT.exe`)
- **配置文件编码**: `config.ini` 当前为 UTF-16LE (BOM) 编码。此编码方案**计划迁移**，不应围绕 UTF-16LE 做任何新的投入或适配。

## 项目结构

```
UCLC/
├── UCLC.ahk                 # 主入口：初始化、热键注册、主循环
├── config.ini                # 全局配置（调试开关、功能开关、路径等）
├── Lib/                      # 核心库
│   ├── AppSettings.ahk       # 全局状态管理（静态类，Single Source of Truth）
│   ├── Version.ahk           # 版本号（由 Git hook 自动生成，严禁手动编辑）
│   ├── CAT_Automatic.ahk     # CATIA 自动化核心（命令执行、工作台识别、弹窗处理）
│   ├── CATAlias.ahk          # 别名解析与命令注册
│   ├── CATIAInstance.ahk     # CATIA 多实例管理（PID 隔离的 Hdr 缓存）
│   ├── windows.ahk           # 窗口工具函数（输入法、下载、音量控制）
│   ├── SettingsGUI.ahk       # 设置界面
│   ├── tray_menu.ahk         # 托盘菜单
│   ├── AHK_LOG.ahk           # 日志
│   ├── stdio.ahk             # INI 读写工具
│   └── string.ahk            # 字符串工具
├── scripts/
│   ├── stamp_version.sh      # 版本号自动注入脚本（pre-commit hook 调用）
│   └── install_hooks.sh      # Git hook 安装脚本
├── user-config/              # 用户配置文件（submodule，.ini 格式）
├── docs/                     # 文档
├── test/                     # 测试脚本（.gitignore 中已排除）
├── icon/                     # 图标资源
└── pic/                      # 图片资源
```

## 核心设计模式

### AppSettings 静态类

`AppSettings` 是全局状态和配置的唯一来源。所有功能开关、文件路径、运行时状态均通过此类访问。新增功能时**必须**在此类中添加对应的配置属性和 `Init()` 读取逻辑，默认值应为关闭状态。

### #HotIf 上下文分层

脚本通过 `#HotIf` 指令实现热键的上下文隔离：

- **全局热键** (`#HotIf WinActive`): `Ctrl+Shift+R` 重载、`Win+C` 计算器、音量控制等
- **CATIA 专属热键** (`#HotIf WinActive("ahk_group GroupCATIA")`): `Space` 别名执行、`Shift+Tab` 窗口切换、`Esc` 清除输入
- **扩展上下文**: 如需覆盖 CATIA 主窗口和弹窗，应定义独立的 `#HotIf` 判定函数

`GroupCATIA` 是动态构建的窗口组，仅包含 `Afx:...` 类名的 CATIA 主窗口，**不包含** `#32770` 等弹窗。

### 别名执行流

```
用户在 Power-Input 输入 "PA" → 按 Space 触发
→ 读取输入框文本 → StrUpper 统一为大写
→ read_user_alias() 查询 INI: 先查当前工作台 Section，未命中则回退到"通用"Section
→ 获得 command_id + 可选回调函数
→ ControlSetText("c:" . command_id) 写入 Power-Input
→ safe_send_enter() 安全发送回车
→ [可选] 处理 Hdr 报错弹窗并缓存修正结果
→ [可选] 执行回调函数
```

### INI 配置约定

- **Section 名** = CATIA 工作台名（如 `创成式外形设计`、`零件设计`、`通用`）
- **Key** = 用户别名（大写，如 `PA`、`GR`）
- **Value** = CATIA 命令 ID + 可选回调（如 `CATSpdPadHdr`、`CATPstReorderHdr&cat_auto_graph_tree_reorder`）

## 项目开发规范

### 代码风格 (Coding Style)

以下规范从现有代码库中提取，AI 生成的代码**必须严格遵循**：

| 元素 | 风格 | 示例 |
|------|------|------|
| 函数名 | `snake_case` | `safe_send_enter()`, `match_current_workbench()` |
| 普通变量 | `snake_case` | `catia_pid`, `dialog_hwnd`, `edit_text` |
| 循环/临时变量 | `snake_case` | `each_pair`, `btn_text` |
| 类名 | `PascalCase` | `AppSettings`, `CATIAInstance`, `VolumeController` |
| 类属性/配置开关 | `PascalCase` 或 `PascalCase_PascalCase` | `MButton_Confirm`, `Everything_Enabled` |
| 常量/Map 键 | 按上下文，字符串键小写 | `IMEmap["en"]`, `catia_window_classnn_map` |
| 缩进 | 4 个空格 | — |
| 大括号 | 不换行，跟在语句末尾 | `if (condition) {` |
| 文档注释 | JSDoc `/** ... */` 风格 | 标注 `@param`、`@returns` |
| 行内注释 | `;` 注释符，与代码间隔一个空格 | `catia_pid := WinGetPID("A") ; 获取当前 PID` |
| `#Include` | 集中在文件头部 | — |
| `#Requires` | 所有 `.ahk` 文件首行 | `#Requires AutoHotkey v2.0` |

### 分支策略

```
master (稳定发布) ← v2.5.0-dev (长期开发) ← feat/* (功能分支)
```

- **严禁**直接在 `master` 上提交代码
- 功能开发在 `feat/*` 分支上进行，完成后合入 `v2.5.0-dev`
- `v2.5.0-dev` 稳定后合入 `master` 并打 Tag 发布

### 版本号管理

- 唯一版本源：Git Tag（通过 `git describe --tags --always` 获取）
- 自动注入：`scripts/stamp_version.sh` 在每次 `git commit` 前通过 pre-commit hook 自动将版本号写入 `Lib/Version.ahk`
- **严禁手动修改** `Lib/Version.ahk`
- 新 clone 后需运行 `bash scripts/install_hooks.sh` 安装 hook

### Commit 规范

使用 Conventional Commits 格式，英文 commit message：

```
feat(core): add MButton dialog confirm shortcut
fix(core): resolve Alt key sticky issue
chore: remove tracked log files
docs: update AI_CONTEXT.md
```

### Shell 脚本

- 必须使用 **LF** 换行符（非 CRLF），否则 Bash 会因 `\r` 报错
- 使用 `#!/usr/bin/env bash` shebang

## 测试

- `test/` 目录包含功能测试脚本，直接执行对应 `.ahk` 文件即可
- 开发时使用 `Ctrl+Shift+R` 热重载脚本，无需重启

## 常见陷阱 (Gotchas)

### ControlSend 修饰键幽灵事件

`ControlSend` 会**自作主张**根据物理按键状态补偿发出 `Alt Up/Down` 等修饰键事件，导致 CATIA 触发"属性"窗口或 `Alt+Enter` 等意外行为。**必须**使用 `{Blind}` 前缀阻止补偿：

```autohotkey
ControlSend "{Blind}{Enter}", hwnd  ; ✅ 正确
ControlSend "{Enter}", hwnd          ; ❌ 会产生幽灵修饰键事件
```

### 物理按键状态与 KeyWait

`SendInput` 无法覆盖物理按键状态。如果用户在按住 Alt 时触发了命令，必须使用 `KeyWait` 等待物理释放，而非尝试用 `SendInput "{Alt Up}"` 强制松开。

### Hdr 后缀随机变化

CATIA 的命令 ID 尾部的 `Hdr` 后缀在不同版本/实例中可能随机存在或缺失（如 `CATSpdPadHdr` vs `CATSpdPad`）。项目通过 `CATIAInstance.hdr_cache` 按 PID 缓存修正结果，避免重复试错。

### 跨工作台同名命令

不同工作台可能存在同名的用户别名但对应不同的命令 ID。INI 的 Section 机制自然隔离了这一问题：优先查当前工作台 Section，未命中才回退到"通用"Section。
