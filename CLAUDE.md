# CLAUDE.md

该文件为 Claude Code (claude.ai/code) 在此代码库中工作时提供指导。

## 项目概述

UCLC (Use CATIA Like AutoCAD) 是一个 AutoHotkey v2 脚本，旨在使 CATIA 的命令界面行为更像 AutoCAD。它允许用户使用字符组合加空格的方式执行命令，并支持自定义别名和热键。

## 快速入门

主脚本是 `UCLC.ahk`。要运行此项目：

1.  安装 AutoHotkey v2。
2.  确保 CATIA 配置为 P2 用户界面样式，并启用“Power-Input”输入框。
3.  运行 `UCLC.ahk`。

用户的别名和热键配置位于 `user-config/` 目录下的 `.ini` 文件中。如果缺少配置文件，脚本会提示下载默认配置。

## 开发

### 运行测试

`test/` 目录包含几个 `.ahk` 脚本，很可能是用于测试单个功能。要运行测试，请执行相应的 `.ahk` 文件。

### 重新加载脚本

可以使用热键 `Ctrl+Shift+R` 重新加载脚本。

## 代码架构

主脚本 `UCLC.ahk` 负责初始化、配置加载和热键注册。

-   **`Lib/`**: 包含各种辅助库，用于日志记录、字符串操作和窗口管理等功能。
-   **`user-config/`**: 存放用户自定义的配置，包括别名 (`alias.ini`) 和热键 (`hotkey.ini`)。
-   **`UCLC.ahk`**: 脚本的入口点。它会：
    -   包含必要的库文件。
    -   加载用户配置。
    -   设置全局变量和热键。
    -   进入一个循环来检测活动的 CATIA 窗口。
-   热键通过 `HotIfWinActive` 定义，仅在 CATIA 窗口激活时生效。
-   空格键被重新映射，用于执行 CATIA "Power-Input" 输入框中的命令。