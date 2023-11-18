# UCLC(Use CAITA like AutoCAD)
像 AutoCAD 一样使用 CATIA  
---
CATIA 自带的快捷键修改不便，使用效率不高，这个 AutoHotKey 脚本就是为了大家~~愉快~~画图而编写的。

## 主要功能
1. 自定义快捷键（Ctrl/Shift/Alt/F1~12）
1. 自定义用户别名（空格执行命令）
1. 用户别名自适应，同一个别名，不同的命令，少记很多命令
1. 在 CATIA 窗口自动切换输入法为英文
1. {Shift + Tab} 在多个 CATIA 窗口循环切换

## 附加功能
1. 双击 {右Ctrl} 键呼出 Everything

## 使用方法

### 1. 安装 AHK
脚本支持Autohotkey V2版本
下载地址

### 2. CATIA 设置 P2版本
CATIA 配置： 工具 - 选项 - 常规 - 用户界面样式（P2）

### 3. 双击 UCLC.ahk 启动脚本


## 用户自定义
`./config/` 目录下存放用户自定义文件，分别为`config.ini` 和 `CATAlias.ini`。
### config.ini
Section [工作台] 存放有软件对应工作台的名称，用以区分不同工作台的命令。例如：别名`S`在 [零件设计] 工作台是`草图`命令，在 [装配设计] 工作台是`捕捉`命令

### CATAlias.ini
[通用] 存放各工作台适用的命令
[HotKey_cn] 存放快捷键
```
F2=属性
```
F2执行属性命令，软件自带快捷键为`Alt+Enter`
