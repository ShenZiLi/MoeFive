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

## 目录规划（待 M1 随 Godot 骨架定稿）
- `res://scenes/` 场景（主页 / 难度选择 / 对局 / 结算）
- `res://scripts/` GDScript（棋盘状态机 / 胜负判定 / 悔棋栈 / AI）
- `res://assets/` 萌系美术与音频资源
- `docs/` 设计文档（`需求文档.md` / `技术选型评估.md` / `原型图.png`）

## 进度
- [x] 仓库初始化（2026-09-20）
- [x] 需求基线 `docs/需求文档.md` v0.2（2026-09-20）
- [x] 技术栈选型：Godot 4.7.2 + GDScript + Compatibility（2026-09-20）
- [ ] M1 核心对局逻辑（双人 / 人机 / 悔棋 / 认输）
- [ ] M2 萌系角色与主视觉
- [ ] M3 动效与音效注入
- [ ] M4 六端打包
- [ ] M5 打磨与发布

© Moe 系列 · 非日系萌风