![BCS_style](pic/UCLC.jpg)
# UCLC(Use CAITA Like AutoCAD)
# 像 AutoCAD 一样使用 CATIA  
---
## 简介

**UCLC** 是采用 [AutoHotkey](https://www.autohotkey.com/) 编写的一个命令管理脚本，旨在将 CATIA 的命令操作习惯替换成 AutoCAD 那样：`组合字符命令` + `空格`执行，提高画图效率

### 没有 UCLC 的快捷键实现方式

#### P1

众所周知，CATIA 在启用 P1 用户界面后，可以自定义单键来执行命令，比如自定义C画圆，L画直线…… 但是，在众多的模块中，类似的操作，命令却不相同（草图和GSD里画圆就不是同一个命令），26个字母根本不够用[掀桌]

#### P2

当切换到P2用户界面后，窗口右下角多了一个 命令输入框 --> “ 超级输入”，配置 工具 - 选项- 常规 - 搜索 - 超级输入的默认前缀 - "c: 作为 命令" ，这样我们就能通过输入`组合字符` + `回车` 来执行命令。大部分命令可以通过 工具 - 自定义- 命令 - 显示属性 来设置快捷键或者是用户别名。

但是，有相当数量的命令是跨工作台的，并且有着相同的名称，使用相同的用户别名调用会出现执行混乱。比如零件设计与GSD的布尔添加命令就是这样，都是“添加...”，所以，为了区分这两个命令，我可能会把PBA（Part Boolean Add）给零件设计工作台，GBA给GSD工作台。问题解决了，但我要多记住更多的命令。
### UCLC 的快捷键实现方式
现在，有了UCLC（Use CAITA Like AutoCAD），你可以在零件设计工作台用`BA`+`空格`来执行零件的布尔添加，在创成式外形设计工作台也用`BA`+`空格`来执行包络体的布尔添加，而不用额外记住我要用哪个工作台的布尔添加。同样，你可以用`L`来定义你在所有的工作台里画直线，不管是草图还是GSD，或者是工程图工作台……

你可能注意到了，有了UCLC，执行命令已经像AutoCAD一样是用空格键了！是的，这确实也是让CATIA操作起来更像AutoCAD的一点。

#### 启用UCLC后，使用命令在草图中绘制圆以及约束直径

![草图操作](pic/Sketch.gif)

## 主要功能
1. 自定义用户别名
1. 自定义快捷键（Ctrl/Shift/Alt/F1~12）
1. 用户别名自适应。一种功能，一种命令，不用考虑工作台。
1. 空格键 执行上次的命令

## 附加功能
1. 产品结构树自动排序，使用须知
2. 在 CATIA 自动切换输入法为英文
1. `Shift + Tab`在多个 CATIA 窗口循环切换
1. 双击 `右Ctrl` 键呼出 Everything（Everything需要设置快捷键`win+]`）
5. `ESC` 清除 Power-input 输入框的内容（测试功能）
6. `Win+鼠标滚轮`：切换虚拟桌面（Windows 11）
7. `RAlt+鼠标滚轮`：调节音量，`RAlt+鼠标中键`：静音切换

## 使用方法

### 1. 安装 AHK
脚本支持 [Autohotkey V2](https://www.autohotkey.com/)。 [下载地址](https://www.autohotkey.com/download/ahk-v2.exe)

### 2. CATIA 启用 POWER-INPUT 输入框
CATIA 配置：

- 工具 - 选项 - 常规 - 常规 - 用户界面样式（P2）
- 工具 - 选项 - 常规 - 搜索 - 超级输入的默认前缀 （下拉列表 - 无）

### 3. 配置用户自定义文件


### 4. 启动脚本

下载 [UCLC最新版本](https://github.com/zedeeee/UCLC/releases/latest)，解压后运行UCLC.ahk


## 用户自定义
***从`v2.2.1`开始，用户配置文件示例迁移到 [UCLC-config](https://github.com/zedeeee/UCLC-config.git)，欢迎大家分享的快捷键自定义方案***

用户自定义设置位于`./user-conifg/`目录下，文件结构如下

```
user-config/
    |-- CATAlias.ini			（实例文件，包含几个简单的命令）
```



### CATAlias.ini

`CATAlias.ini`用于映射自定义用户别名和Command ID

```ini
[工作台]
2001=零件设计
2002=装配设计
2003=草图编辑器
3006=创成式外形设计
2009=工程制图
2019=Generative Sheetmetal Design

[通用]
; 注释
A = ViewAlignment                      ; 对齐视点

[装配设计]
S = CATAifSnapHdr                      ; 捕捉

[零件设计]
S = CATMmrSketchHeaderHdr              ; 草图

[草图编辑器]
REC = CAT2DRectangleHdr                ; 矩形

[创成式外形设计]
X = CATShapeDesignExtrude			   ; 拉伸

[工程制图]
CC = CAT2DCircleRadiusHdr			       ; 圆
L = CAT2DLineHdr						   ; 直线

[Generative Sheetmetal Design]
S = CATMmrSketchHeaderHdr              ; 草图

[HotKey]
; ^ ： Ctrl
; + ： Shift
; ! ： Alt
F2 = CATAfrOpenPropertyHdr				; 属性
```
**[工作台]**	定义启用专有用户别名的工作台名称

**[通用]** 	存放各工作台通用的命令

**[装配设计] [零件设计] [草图编辑器]**……	每个 Section 下是对应工作台的专有用户别名

**[HotKey]** 	存放快捷键映射（需要脚本重启 ）



## 兼容性
- 系统：windows11

- CATIA: V5 R2017

- 语言：简体中文



## 联系方式
有任何兼容性问题、疑问和建议欢迎在 issues 提交

## 致谢

- [mudssky](https://github.com/mudssky/myAHKScripts) （autoIME）
- 【&杰√ （结构树自动排序）
