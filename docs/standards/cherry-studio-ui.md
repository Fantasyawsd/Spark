# Cherry Studio UI/UX 提取

> 来源：`../../../references/cherry-studio/DESIGN.md`、`packages/ui/src/styles/`、
> `packages/ui/src/components/primitives/` 与 `src/renderer/assets/styles/animation.css`。
> 本文描述 PaperFlow 的 Flutter 映射，不复制 React、Tailwind、Radix 或 Electron 的框架代码。

## 设计语言

| 规则 | Cherry Studio 语义 | PaperFlow 映射 |
| --- | --- | --- |
| 色彩 | 使用 `background`、`card`、`popover`、`accent` 等语义角色，主色只承担关键动作和已选状态 | `PaperFlowColors` 保留主题主色，增加 `popover`、`accent` 与前景/边框层级 |
| 深度 | 静态内容依靠表面层级和 1px 边框区分；阴影只给悬浮层与交互反馈 | `CherrySurfaceLevel.flat` 默认无阴影；`interactive`、`floating` 才使用 token 阴影 |
| 圆角 | 控件 8px、卡片 10px、浮层 14px、对话框 22px | `PaperFlowDesignTokens.radiusMd/Lg/Xl/3Xl` |
| 间距 | 4px 基准，控件内边距紧凑、页面与区块间距清晰 | `PaperFlowDesignTokens.space1` 到 `space8` |
| 操作密度 | 低强调动作优先图标按钮，并始终提供提示文本 | `CherryIconButton` 以 Tooltip 和固定尺寸承载搜索、筛选等操作 |

## 可复用组件

- `CherryButton`：主操作、描边、次级、幽灵和危险动作五种变体；支持 loading 与禁用状态。
- `CherryIconButton`：32px 起的图标操作，支持选中态和状态徽标。
- `CherrySurface`：平面、交互、悬浮三种表面层级；`SurfaceCard` 已以它作为兼容包装。
- `PaperFlowDesignTokens`：集中管理间距、圆角、边框和阴影，避免在页面中散落视觉常量。

## 动效规则

- 常规内容进入：220ms、`easeOutCubic`、透明度加 3.5% 纵向位移与 0.985 到 1 的缩放。
- 标签和导航反馈：220ms，选中背景与指示器平滑变化。
- 轻量交互反馈：140ms；浮层预留 260ms 过渡。
- 所有新动效都读取 `MediaQuery.disableAnimations`，系统要求减少动态效果时直接落到最终视觉状态。

`CherryEntryAnimation` 是 Flutter 对 Cherry Studio 浮层/选择器进入动效的等价实现；
`PaperEntryAnimation` 已委托给它，因此现有页面不需要迁移调用点。

## 迁移边界

- 不引入 Cherry Studio 的 React、Radix、Tailwind 或 Electron 运行时代码。
- 不复制其桌面侧栏信息架构；PaperFlow 仍以 Android 论文发现和阅读流程为主。
- 不把主题色用于装饰；错误、成功、警告等状态仍必须依据真实业务状态呈现。
- 不为普通静态卡片添加阴影，避免密集论文内容产生多层卡片感。
