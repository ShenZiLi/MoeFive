# MoeFive · 萌五子棋

> Moe 系列棋类游戏之一（与 MoeChess 同源宇宙）。
> 设计基调：**萌，但不日系** —— 纯中文原生萌（五宝 / 小五宝）+ 西式卡通萌（Fivey），拒绝「酱/君/chan」那套。

## 项目定位
- 棋种：五子棋（Gomoku / Five in a Row），基础为无禁手休闲版，后续可扩展 Renju 禁手竞技版。
- 风格：萌系角色化棋子（拟人五宝 / Fivey），轻量休闲对局。
- 系列：Moe 棋类家族第二作（一作 MoeChess 中国象棋）。

## 技术栈（已定稿 · 2026-09-20）
- 引擎：**Godot 4.7.2 stable**（本机 `C:\Dev\godot`）
- 语言：**GDScript**
- 渲染器：**Compatibility**，六端统一
- 目标平台：Windows / macOS / Linux / Android / iOS / Web（六端）
- 选型依据：`docs/技术选型评估.md`

> ⚠️ 两条硬约束：① **必须用 GDScript** —— Godot 的 C# 项目无法导出 Web；② **美术定版必须以 Compatibility 渲染器表现为基准** —— Web 导出仅支持 Compatibility，桌面若单开 Forward+ 会导致两端光影不一致。
> ⚠️ **iOS 打包需 macOS + Xcode**，Windows 出不了 IPA。
> 📌 **不复用 MoeChess 的技术与资产**，独立立项；仅保留 Moe 系列的命名与调性归属。

## 目录结构
```
project.godot            引擎配置（Compatibility 渲染器，1280×720）
main.tscn                入口场景
scripts/
  GameConfig.gd          全局常量：棋盘 / 配色 / 难度参数 / 文案表
  Board.gd               棋盘状态机（落子 · 胜负判定 · 悔棋完整回滚）
  AIPlayer.gd            三档难度 AI（共享评估函数，仅参数区分）
  BoardView.gd           棋盘视图（程序化绘制，不依赖美术资源）
  Main.gd                主流程状态机（主页 / 难度 / 对局 / 结算）
tests/
  test_core.gd           核心逻辑自测（65 项断言）
  test_smoke.gd          主场景加载冒烟测试
docs/                    设计文档（.gdignore 已屏蔽，Godot 不扫描）
```

## 开发

**运行游戏**（需 Godot 4.7.2；本机装于 `C:\Dev\godot`）
```bash
"C:/Dev/godot/Godot_v4.7.2-stable_win64.exe" --path .
```

**跑测试**（无界面，CI 友好）
```bash
G="C:/Dev/godot/Godot_v4.7.2-stable_win64_console.exe"
"$G" --headless --path . --import                    # 首次：生成全局类缓存
"$G" --headless --path . --script res://tests/test_core.gd
"$G" --headless --path . --script res://tests/test_smoke.gd
```

> ⚠️ 新增 `class_name` 脚本后必须重跑 `--import`，否则全局类无法解析。
>
> ⚠️ **中文字体目前加载系统字体**（`C:/Windows/Fonts/msyh.ttc`）—— 仅作 M1 占位，
> 打包前必须内嵌一款**授权可商用**的中文字体（影响需求 §9 的体积预算，M4 决策）。

## 进度
- [x] 仓库初始化（2026-09-20）
- [x] 需求基线 `docs/需求文档.md` v0.2 · 全部决策点拍板（2026-09-20）
- [x] 技术栈选型：Godot 4.7.2 + GDScript + Compatibility（2026-09-20）
- [x] **M1 核心对局逻辑**（双人 / 人机三档 / 无限悔棋 / 认输）— 自测 65/65 通过
- [x] M2 萌系角色与主视觉（原型图运行时底板 + 动态棋盘叠层）
- [ ] M3 动效与音效注入
- [ ] M4 六端打包
- [ ] M5 打磨与发布

© Moe 系列 · 非日系萌风
