extends RefCounted
class_name GameConfig
## 全局常量与配置表。
## 数值取自 docs/需求文档.md —— 改动请同步该文档，勿在此处私自调参。

# ========== 棋盘（需求 §3.1.1）==========
const BOARD_SIZE := 15
const EMPTY := 0
const BLACK := 1   # 先手 · 玩家一
const WHITE := 2   # 后手 · 玩家二 / AI

## 星位（0-based 坐标）：天元 + 四角
const STAR_POINTS := [
	Vector2i(3, 3), Vector2i(11, 3), Vector2i(7, 7),
	Vector2i(3, 11), Vector2i(11, 11),
]

# ========== 配色（需求 §4.2 · 已拍板 D2 融合路线）==========
const C_SCENE_TOP := Color("#efdcc0")
const C_SCENE_BOTTOM := Color("#c9a279")
const C_BOARD_LIGHT := Color("#e8bc7e")
const C_BOARD_DARK := Color("#d9a05b")
const C_BOARD_LINE := Color("#8b5e3c")
const C_BOARD_FRAME := Color("#b07b45")
const C_P1 := Color("#a9714b")
const C_P1_CREAM := Color("#fff6e9")
const C_P2 := Color("#8fb6dc")
const C_P2_CREAM := Color("#f5f7fa")
const C_ACCENT := Color("#e8863c")
const C_PLANT := Color("#8fb573")
const C_TEXT := Color("#5a3a22")
const C_TEXT_INV := Color("#fff9f0")
const C_STONE_BLACK := Color("#3b3430")
const C_STONE_WHITE := Color("#fff6e9")
## 全局禁用纯黑纯白（需求 §4.2 规则）
const C_OVERLAY := Color(0.30, 0.19, 0.11, 0.62)

# ========== 对局模式 ==========
enum Mode { PVP, PVE }

# ========== 难度（需求 §7.1）==========
enum Difficulty { NOVICE, NORMAL, EXPERT }

const DIFFICULTY_NAMES := ["萌新", "普通", "高手"]
const DIFFICULTY_TAGLINE := ["陪你慢慢下", "有来有回", "认真才下得过"]

## depth  向前看的手数（ply）
## width  候选点宽度（按启发值取前 N）
## blunder 主动失误概率（仅 Lv1，制造"新手能赢"的体验）
##
## ⚠️ 参数取舍：GDScript 下 depth×width 的增长很快。若让 Lv3 长期顶着
## AI_MAX_THINK_MS 被截断，返回的是"搜索到一半的最优"，反而不如
## 搜得完的浅一层结果稳定。故三档按"能完整搜完"来定参。
const DIFFICULTY_PARAMS := [
	{"depth": 1, "width": 6, "blunder": 0.25},
	{"depth": 2, "width": 8, "blunder": 0.0},
	{"depth": 3, "width": 10, "blunder": 0.0},
]

# ========== 时序（需求 §3.1.2）==========
const AI_MIN_DELAY_MS := 350    # AI 应手最短延迟，避免"秒回"失去博弈感
const AI_MAX_THINK_MS := 800    # 单步思考上限，超出即走当前最优候选

# ========== 文案（D5：场景短句池，进对局随机取一条）==========
const SCENE_QUOTES := [
	"以棋会友，快乐常在",
	"下好每一步，遇见更好的自己",
	"五子连心，棋乐无穷",
	"友谊第一，胜负第二",
	"慢慢来，好棋不怕等",
	"棋盘虽小，乐趣不少",
	"和你下棋，是最开心的事",
	"一步一步，走稳就好",
	"落子无悔……不过这里可以悔",
	"今天也要开开心心",
]

## 气泡文案
const QUOTE_P1_TURN := ["该你啦！🐾", "加油！🐾", "想想再下～", "这步交给你"]
const QUOTE_P2_TURN := ["到我了～", "来一局吧！🐾", "让我想想", "嘿嘿，接着来"]
const QUOTE_AI_THINKING := ["让我想想…", "嗯…", "等一下哦"]

## 认输二次确认（需求 §3.4：走萌系话术，不用"确定/取消"）
const CONFIRM_SURRENDER_TITLE := "真的要认输吗？"
const CONFIRM_SURRENDER_BODY := "棋还没下完呢，要不……再想想？"
const CONFIRM_SURRENDER_OK := "认输"
const CONFIRM_SURRENDER_CANCEL := "再下一会儿"

## 结算（需求 §4.6 · D4 展示悔棋次数）
const RESULT_WIN := "赢啦！"
const RESULT_LOSE := "这局让给你"
const RESULT_DRAW := "平局 · 再来一局？"
const BTN_AGAIN := "再来一局"
const BTN_HOME := "返回主页"
const BTN_UNDO := "悔棋"
const BTN_SURRENDER := "认输"
