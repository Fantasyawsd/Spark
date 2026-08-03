# PaperFlow 设计规范

> 状态：强制执行
> 适用范围：全部界面与主题代码（`lib/src/core/theme/` 与各 `presentation/`）
> 最近更新：2026-08-03

## 1. 设计哲学

PaperFlow 的视觉语言是「中性界面 + 内容出彩」：

- 界面 chrome 保持中性（灰阶、卡片、细线），让论文内容和 AI 对话成为界面中最有色彩的部分。
- 主题色（`PaperThemeColor`）只用于品牌识别、选中态和主要行动，不铺满界面。
- 语义色只用于反馈（危险、错误），不用于装饰。
- 全应用只有一个主题色来源（`ThemeController`），页面不得引入局部品牌色。

## 2. Cherry Studio 设计语言映射

> 来源：`../references/cherry-studio/DESIGN.md`、`packages/ui/src/styles/`、
> `packages/ui/src/components/primitives/` 与 `src/renderer/assets/styles/animation.css`。
> 本节描述 PaperFlow 的 Flutter 映射，不复制 React、Tailwind、Radix 或 Electron 的框架代码。

| 规则 | Cherry Studio 语义 | PaperFlow 映射 |
| --- | --- | --- |
| 色彩 | 使用 `background`、`card`、`popover`、`accent` 等语义角色，主色只承担关键动作和已选状态 | `PaperFlowColors` 保留主题主色，增加 `popover`、`accent` 与前景/边框层级 |
| 深度 | 静态内容依靠表面层级和 1px 边框区分；阴影只给悬浮层与交互反馈 | `CherrySurfaceLevel.flat` 默认无阴影；`interactive`、`floating` 才使用 token 阴影 |
| 圆角 | 控件 8px、卡片 10px、浮层 14px、对话框 22px | `PaperFlowDesignTokens.radiusMd/Lg/Xl/3Xl` |
| 间距 | 4px 基准，控件内边距紧凑、页面与区块间距清晰 | `PaperFlowDesignTokens.space1` 到 `space8` |
| 操作密度 | 低强调动作优先图标按钮，并始终提供提示文本 | `CherryIconButton` 以 Tooltip 和固定尺寸承载搜索、筛选等操作 |

## 3. 颜色规则

### 3.1 只用主题 token

- 颜色一律通过 `PaperFlowColors` / `PaperFlowTheme`（`lib/src/core/theme/`）取用，禁止在 Widget 中硬编码 `Color(0x...)`。
- 现有代码中的历史硬编码色属于遗留：逐步迁移到主题 token（迁移作为独立提交，遵循 `version-control.md` 提交原则）；历史遗留不构成新代码硬编码的例外。
- 中性层级：`ink`（主文字）→ `muted`（次要文字）→ `foregroundTertiary`（时间戳/弱化）→ `foregroundDisabled`（禁用）→ `line`（分割线）→ `lineStrong`（高强调边框）→ `canvas` / `card` / `popover` / `surface*`（表面）。
- 主题色三档：`primary`（实色，选中与主要行动）、`primarySoft`（浅底）、`primaryPale`（更浅底）。
- `accent` / `accentForeground`：选中态与悬停背景（交互角色，不是状态反馈色）。
- 表面堆叠用色阶（`canvas` → `card` → `surfaceMuted` → `surfaceStrong`），不用阴影模拟层级。

### 3.2 语义色边界

- `danger` 是唯一已注册的语义色，用于危险操作与错误反馈（含 `dangerSoft` 浅底）。
- 新增语义色（成功、警告、信息）必须先注册到主题层（`PaperFlowColors` + `ThemeData` 颜色映射），不得在页面内自造色值。
- 语义色只表示状态反馈，不作为普通装饰色。

## 4. 动效规则

- 常规内容进入：220ms、`easeOutCubic`、透明度加 3.5% 纵向位移与 0.985 到 1 的缩放。
- 标签和导航反馈：220ms，选中背景与指示器平滑变化。
- 轻量交互反馈：140ms；浮层预留 260ms 过渡。
- 所有新动效都读取 `MediaQuery.disableAnimations`，系统要求减少动态效果时直接落到最终视觉状态。
- 时长统一来自 `MotionTokens`（`pageDuration` / `tabDuration` / `feedbackDuration` / `entryDuration` / `popoverDuration`），不在 Widget 内散落 `Duration` 字面量。

`CherryEntryAnimation` 是 Flutter 对 Cherry Studio 浮层/选择器进入动效的等价实现；
`PaperEntryAnimation` 已委托给它，因此现有页面不需要迁移调用点。

## 5. 组件与字体

### 5.1 可复用组件

- `CherryButton`：主操作、描边、次级、幽灵和危险动作五种变体；支持 loading 与禁用状态。
- `CherryIconButton`：32px 起的图标操作，支持选中态和状态徽标。
- `CherrySurface`：平面、交互、悬浮三种表面层级；`SurfaceCard` 已以它作为兼容包装。
- `PaperFlowDesignTokens`：集中管理间距、圆角、边框和阴影，避免在页面中散落视觉常量。

通用组件放入 `lib/src/core/widgets/`，业务组件留在 `features/<模块>/presentation/`。
新 UI 优先复用 `core/widgets/` 与 Material 3 组件，不重复造轮子；确需新组件时按 `code-structure.md` 的归属规则放置。

### 5.2 字体

- 字体经 `ThemeData.fontFamilyFallback` 统一配置（PingFang SC / Microsoft YaHei / Segoe UI / Arial），不单独加载字体文件、不在 Widget 内局部指定字体族。

## 6. 迁移边界

- 不引入 Cherry Studio 的 React、Radix、Tailwind 或 Electron 运行时代码。
- 不复制其桌面侧栏信息架构；PaperFlow 仍以 Android 论文发现和阅读流程为主。
- 不把主题色用于装饰；错误、成功、警告等状态仍必须依据真实业务状态呈现。
- 不为普通静态卡片添加阴影，避免密集论文内容产生多层卡片感。

## 7. 检查清单

- [ ] 颜色是否全部来自主题 token？
- [ ] 主题色是否只用于选中态与主要行动？
- [ ] 语义色是否只表达状态反馈？
- [ ] 动效时长与曲线是否来自 `MotionTokens` 并处理 `disableAnimations`？
- [ ] 新增组件是否放对 `core/widgets/` 或业务 `presentation/`？
