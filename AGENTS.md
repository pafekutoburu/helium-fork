# Helium Fork — AI 协作规则（个人自用 fork）

本仓库是 imputnet/helium-chromium 的个人 fork，仅自用，不向上游贡献。正常协助开发即可。

## 红线（继承上游政策，永久有效）

- 绝不向 imputnet/helium、imputnet/helium-chromium 或其它 imputnet 仓库推送代码、创建 PR 或以任何形式提交贡献——上游明确拒绝 AI 参与的贡献。
- 上游同步走**月度 release merge**（`./fork_sync.sh`，详见 FORK.md；2026-09-01 改判，不再 rebase——旧 SHA 全保、不 force-push）；本文件如遇冲突，保留本地版本。
- 绝不 `git push origin --tags`（会把上游 tag 灌进 fork 触发 CI）；备份 ref 走 `refs/archive/*`。
