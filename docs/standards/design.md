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

## 2. 颜色规则

### 2.1 只用主题 token

- 颜色一律通过 `PaperFlowColors` / `PaperFlowTheme`（`lib/src/core/theme/`）取用，禁止在 Widget 中硬编码 `Color(0x...)`。
- 现有代码中的历史硬编码色属于遗留：逐步迁移到主题 token（迁移作为独立提交，遵循 `version-control.md` 提交原则）；历史遗留不构成新代码硬编码的例外。
- 中性层级：`ink`（主文字）→ `muted`（次要文字）→ `subtle`（弱化）→ `line`（分割线）→ `canvas` / `card` / `surface*`（表面）。
- 主题色三档：`primary`（实色，选中与主要行动）、`primarySoft`（浅底）、`primaryPale`（更浅底）。
- 表面堆叠用色阶（`canvas` → `card` → `surfaceMuted` → `surfaceStrong`），不用阴影模拟层级。

### 2.2 语义色边界

- `danger` 是唯一已注册的语义色，用于危险操作与错误反馈（含 `dangerSoft` 浅底）。
- 新增语义色（成功、警告、信息）必须先注册到主题层（`PaperFlowColors` + `ThemeData` 颜色映射），不得在页面内自造色值。
- 语义色只表示状态反馈，不作为普通装饰色。

## 3. 字体与组件

- 字体经 `ThemeData.fontFamilyFallback` 统一配置（PingFang SC / Microsoft YaHei / Segoe UI / Arial），不单独加载字体文件、不在 Widget 内局部指定字体族。
- 通用组件放入 `lib/src/core/widgets/`，业务组件留在 `features/<模块>/presentation/`。
- 新 UI 优先复用 `core/widgets/` 与 Material 3 组件，不重复造轮子；确需新组件时按 `code-structure.md` 的归属规则放置。

## 4. 检查清单

- [ ] 颜色是否全部来自主题 token？
- [ ] 主题色是否只用于选中态与主要行动？
- [ ] 语义色是否只表达状态反馈？
- [ ] 新增组件是否放对 `core/widgets/` 或业务 `presentation/`？
