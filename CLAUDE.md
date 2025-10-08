# CLAUDE.md

该文件为 Claude Code (claude.ai/code) 在此代码库中工作时提供指导。

## 项目概述

UCLC (Use CATIA Like AutoCAD) 是一个 AutoHotkey v2 脚本，旨在使 CATIA 的命令界面行为更像 AutoCAD。它允许用户使用字符组合加空格的方式执行命令，并支持自定义别名和热键。

## 快速入门

主脚本是 `UCLC.ahk`。要运行此项目：

1.  安装 AutoHotkey v2。
2.  确保 CATIA 配置为 P2 用户界面样式，并启用“Power-Input”输入框。
3.  运行 `UCLC.ahk`。

用户的别名和热键配置位于 `user-config/` 目录下的 `.ini` 文件中。如果缺少配置文件，脚本会提示从网上下载默认配置。

## 开发

### 运行测试

`test/` 目录包含多个 `.ahk` 脚本，用于测试单个功能。要运行测试，请直接执行相应的 `.ahk` 文件。

### 重新加载脚本

在脚本运行时，可以使用热键 `Ctrl+Shift+R` 快速重新加载。

## 代码架构

-   **`UCLC.ahk`**: 脚本的主入口点。它负责：
    -   通过 `#Include` 引入所有必要的库文件。
    -   初始化设置，加载用户配置。
    -   注册全局和特定于 CATIA 窗口的热键。
    -   启动一个主循环来持续检测活动的 CATIA 窗口。

-   **`Lib/`**: 包含所有辅助库和模块。
    -   **`AppSettings.ahk`**: 定义一个静态类 `AppSettings`，作为全局状态和配置（如文件路径、功能开关）的单一来源。这是脚本架构的核心，用于管理所有设置。
    -   其他库文件提供了日志记录、字符串处理、窗口管理、GUI 等功能。

-   **`user-config/`**: 存放用户自定义的配置文件。
    -   `CAT_Alias.ini`: 定义用户命令别名。
    -   `CAT_Hotkey.ini`: 定义用户快捷键。

-   **`config.ini`**: 存放脚本的全局配置，例如调试模式开关和 Everything 功能的路径。

-   **核心逻辑**:
    -   脚本通过 `HotIfWinActive` 指令定义仅在 CATIA 窗口激活时生效的热键。
    -   核心功能是重新映射空格键 (`Space`)，当在 CATIA 的 Power-Input 输入框中按下时，它会读取输入框中的文本，查找匹配的别名并执行相应的 CATIA 命令。
