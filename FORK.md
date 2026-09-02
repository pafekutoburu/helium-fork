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
- helium-macos 侧：gitlink、`.gitmodules`（URL→我们的 fork）、`flags.macos.gn`（PCH 关闭 4 行）。

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
