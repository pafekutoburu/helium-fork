# helium-fork（pafekutoburu）

Fork of [imputnet/helium](https://github.com/imputnet/helium) that rebuilds the
browser shell around an **Arc-style sidebar** (favorites grid, pinned entries,
Today section, real folders). Not affiliated with the upstream project.

## 两仓结构（镜像上游，别合并）

| 仓 | 上游 | 我们的 origin | 装什么 |
|---|---|---|---|
| helium（本仓） | imputnet/helium | pafekutoburu/helium-fork | 跨平台核心：全部补丁、版本号、工具 |
| helium-macos | imputnet/helium-macos | pafekutoburu/helium-macos-fork | macOS 打包壳，以 submodule 钉住本仓 |

保持两仓的理由只有一个：**镜像上游的形状，月度同步才便宜**（各自 fetch → 各自 merge 一次，
冲突面＝series 一个文件 + gitlink 一处）。

## 携带集（自描述，不靠历史形状）

- `patches/helium-fork/`：全部自有补丁，**series 末尾自成一段**（平台块之前）。补丁名描述内容
  ——月度同步时按名定位，序号每轮都会漂。
- `patches/series`：末段的 helium-fork 行。
- `resources/favicons/favicon_ntp_{16,32}.png`、`AGENTS.md`、本文件、`fork_sync.sh`。
- `CLAUDE.md` → `AGENTS.md` 符号链接：上游 0.20 删了它（1fe0fe98「claude code reads AGENTS.md now」），
  但 Claude Code 默认只在工作目录及以上**没有** `CLAUDE.md` 时才读 `AGENTS.md`；工作区根有自己的
  `CLAUDE.md`，删了链接本仓的红线就不进上下文了（2026-10-29 核文档）。合并时它被静默删掉、不报冲突。
- helium-macos 侧：gitlink、`.gitmodules`（URL→我们的 fork）、`flags.macos.gn`（PCH 关闭 4 行）、
  `patches/helium/macos/helium-immersive-fullscreen.patch` 里的 7 个 hunk（6 个在 `browser_view.{h,cc}`、
  1 个在 `browser_frame_view_mac.mm`；2026-10-04 152→154 同步改 6 个、10-10 再改 1 个、10-29 154→156 同步时
  把我们挡路的行挪开后回到 6 个、11-21 第四十四次 +1＝第 19 个）。
  这个平台补丁排在我们的补丁段之后，会碰到我们改过的 Zen 判断和 BrowserView 成员区，另有一段是它自己加的
  代码、我们必须改在里面：
  第 19 个（`UpdateHeliumFullscreenWindowControls`：Arc 外壳里全屏的红绿灯替身用窗口态同一个 caption 矩形、
  同一个透明度——sync156 反馈问题 1；整个函数是这个平台补丁加的，我们的改动只能住在它里面）、
  第 22 个（`browser_view.h` 成员区上下文）、第 23–25 个（`StartZenCollapseTimer` /
  `UpdateZenModeRevealFromCursor` / `UpdateZenModeReveal` 的暂停判断按我们的条件写）、
  第 29 个（全屏过渡结束、解除暂停时，对隐藏侧栏补一次按光标判断）、
  第 26 个（`FullscreenStateChanging` 里插悬停暂停那段的首行上下文 `return;` → `EndArcComposerEdit();`——
  layout/arc-visual-r1005-r1017 在 `IsClosed()` 早退之后先结束带子的 ⌘L 编辑）。
  上游再改这个补丁时 merge 会在这里冲突：取上游新版，再照 `tasks/evidence/sync154/port-log.md`
  的「macOS 块 #448」重做 22–25、29，照 `tools/fold_backup_r10/scripts/step1b_adapt_immersive.py` 重做 26，
  照 `tools/fold_backup_fsp/scripts/step1b_split_immersive.py` 重做 19（三方合并里落在平台补丁自己那段
  代码里的改动归平台补丁，其余进我们的层）。
- ⛔ **别把我们的行贴着这个平台补丁的插入点写**（2026-10-29 154→156 同步定）：它在我们的补丁段之后打，
  我们在它插入点 3 行以内加的任何一行都会变成它的上下文、多一个要携带的 hunk。10-29 因此挪开了
  `browser_frame_view_mac.h`（r1025 红绿灯内缩的声明）、`browser_frame_view_mac.mm`（一行 `#import`）、
  `browser_native_widget_window_mac.{h,mm}`（`setTitlebarWidgetInset:`）四处；我们的 mac 源文件
  （`helium_sf_symbol_image_mac.mm`、`space_swipe_monitor_mac.{h,mm}`、`widget_mouse_events_mac.mm`）
  也从上游 `chrome/browser/ui/BUILD.gn` 的 `is_mac` 源列表挪进了紧跟其后的我们自己的 `if (is_mac)` 块——
  新增 mac 源文件放那个块，别放回上游的列表。挪不开的才进携带集，每次同步用
  `tools/fold_backup_r1032/scripts/step1b_adapt_immersive.py` 机械重算（三方合并求「我们的树去掉平台补丁」，
  只重生成撞上的 hunk，正向重放逐字节回到原树）。

## 红线

1. **绝不向 imputnet 任何仓库 push / 开 PR**（上游拒绝 AI 贡献）。upstream remote 只拉不推。
2. **绝不 `git push origin --tags`**（会把 fetch 来的上游 tag 灌进 fork，逐个触发 tag CI）。
3. 备份 ref 走 `refs/archive/*` 命名空间（不触发 CI）。

## 月度同步 SOP

**姿势＝git merge 上游 release**（2026-09-01 拍板；不 rebase——旧 SHA 全保、不 force-push、
平台仓指针提交不用重演）。流水线：`./fork_sync.sh <stage>`，分段有停点，`./fork_sync.sh help`
看全部阶段。核心不变式：

- 上游补丁段必须**零 fuzz** 通过（他们的 CI 对着同一 tarball 验过；出 fuzz＝git 层合错了）。
- 我们的补丁段 **fuzz 清零是铁律**：rej 逐层 push -f + 手工移植 + 保风格 refresh
  （`QUILT_REFRESH_ARGS="--no-timestamps"`，别让 `-p ab` 改写 Index: 风格）；修完整栈
  `pop -a && push -a` 重放终审（唯一豁免＝`helium/macos/updater/sparkle2-integration.patch` 恒 fuzz 2）。
- 改动**按属主层归位**（pop 到那层再 refresh），不许都吸进顶层。
- 同步前跑缺创建扫描（fork_sync.sh stage3 自带）：补丁改了某文件但无人创建、新树又没有 → 老账，
  先补创建段再推。

## 降级策略

某条补丁移植不动时：**停下，把冲突和实测摆给用户拍板**——绝不静默丢弃、绝不默默换方案。
用户可以选择本轮暂禁该补丁（从 series 注释掉 + 在 PROGRESS 记账），下轮再还。

## 深度知识在哪

工作区根目录的 `PROGRESS.md` + `progress/`（pitfalls / decisions / runbook / archive）：
每层补丁的归属账本、回归套件（0.0-a…0.0-p）、守卫脚本、历轮同步的坑与判决
（首轮 151→152 的移植对照表在 decisions「M5 上游同步 轮0」）。
