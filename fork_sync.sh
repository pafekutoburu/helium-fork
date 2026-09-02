#!/bin/bash
# fork_sync.sh —— 月度上游同步流水线（分段、有停点）。
#
# 用法： ./fork_sync.sh <stage>     （在 helium-chromium 仓根跑；stage 见 help）
# 每月改头部参数区，然后按 stage0 → stage1 → stage2 → stage3 → audit → build 依次跑；
# 中间的补丁移植（rej 修复）是人/agent 的活，姿势见 FORK.md 与 progress/pitfalls.md
# 「上游同步（151→152）第一轮补的八条」。构建绿了之后走 tools/commitNN.sh 两段式入库。
#
# 设计：这是「可执行的 runbook」，不是全自动化——每段结束打印下一步该干嘛。
set -u

# ── 每月参数区（改这里） ────────────────────────────────────────────────
TARGET_TAG="0.16.3"            # 本仓要合的上游 release tag
MACOS_SHA="396158f08aa69842059fdb6f1cbc8e4cb274661b"  # macos 仓要合的上游 commit（无 tag 时钉 SHA）
ARCHIVE_REF="archive/pre-${TARGET_TAG}"               # 备份 ref 名
EXPECTED_FORK=63               # 我们的补丁数（series 末段）
# EXPECTED_MERGED 不硬编码：stage2 从 series.merged 现算并打印，人工核对。
# ───────────────────────────────────────────────────────────────────────

HERE="$(cd "$(dirname "$0")" && pwd)"            # helium-chromium
PLAT="$(cd "$HERE/.." && pwd)"                   # helium-macos
SRC="$PLAT/build/src"
Q() { (cd "$SRC" && quilt --quiltrc - "$@"); }    # alias 不进脚本，显式 --quiltrc -
say() { printf '\n═══ %s ═══\n' "$*"; }

stage0() {  # 预检 + 备份 ref（⚠ profile 备份和浏览器重启不在这里——见 stage2 提示）
  say "stage0 预检"
  git -C "$HERE" status --porcelain | grep -q . && { echo "⛔ 本仓不净，先处理"; exit 1; }
  echo "本仓 HEAD: $(git -C "$HERE" log --oneline -1)"
  echo "平台仓状态（merged 态的 untracked 属正常，series 删除态也正常）:"
  git -C "$PLAT" status --porcelain | head -3; echo "  …共 $(git -C "$PLAT" status --porcelain | wc -l | tr -d ' ') 条"
  df -h / | tail -1
  say "推备份 ref（refs/archive/*，不触发 CI）"
  git -C "$HERE" push origin "arc-main:refs/$ARCHIVE_REF"
  git -C "$PLAT" push origin "arc-main:refs/$ARCHIVE_REF"
  echo "→ 下一步: ./fork_sync.sh stage1"
}

stage1() {  # 退开发态 + 两仓合流（先子仓后父仓）
  say "he unmerge（老树保持满打态，不 pop）"
  (cd "$PLAT" && zsh -c 'source dev.sh >/dev/null 2>&1 && he unmerge') || exit 1
  git -C "$PLAT" status --porcelain | grep -q . && { echo "⚠ unmerge 后平台仓不净（series 空行回写？），先 git checkout -- patches/series 再重跑"; exit 1; }
  git -C "$HERE" status --porcelain | grep -q . && { echo "⛔ unmerge 后本仓不净"; exit 1; }

  say "子仓 merge $TARGET_TAG"
  git -C "$HERE" fetch upstream --tags
  if ! git -C "$HERE" merge "$TARGET_TAG" --no-edit; then
    cat <<'GUIDE'
⚠ 冲突（预期只在 patches/series）。解法定案：
  上游新增的 EOF 行在前，我们 helium-fork 段整段在后（保持是最后一段、平台块之前）。
  解完自证: grep -v '^$' patches/series | tail -63 应全为 helium-fork/；然后 git add + git merge --continue。
  之后手动跑父仓那半（本 stage 重跑会先撞 unmerge 检查，直接照下面三行）：
    git -C ../  fetch upstream && git -C ../ merge <MACOS_SHA> --no-edit
    git -C ../ add helium-chromium && git -C ../ commit
GUIDE
    exit 2
  fi
  say "父仓 merge $MACOS_SHA"
  git -C "$PLAT" fetch upstream
  git -C "$PLAT" merge "$MACOS_SHA" --no-edit || {
    echo "⚠ 预期冲突＝gitlink。解法: git -C \"$PLAT\" add helium-chromium && git -C \"$PLAT\" commit（指向子仓刚才的 merge commit）"; exit 2; }
  echo "→ 下一步: 处理日用浏览器与 profile（见 stage2 开头的提示），然后 ./fork_sync.sh stage2"
}

stage2() {  # 树重建
  cat <<'GUIDE'
⚠ 动树前人工确认三件事（脚本不代劳）：
  1. 老 out/Rel 若正被日用：优雅退出浏览器 → 备份 profile（cp -a net.imput.helium.dev{,.bak-preXXX}）
     → 本 stage 跑完后把 run-rel.sh 临时指向 build/src-<旧版>，再后台拉回（open -g）。
     ⚠ 新版首次打开 profile 即单向前迁 schema，旧版从此打不开——备份是回退的唯一后路。
  2. build/src 将被挪走成 build/src-<旧主版本>（.pc 快照是移植参考、旧 Rel 是兜底，验收过才删）。
  3. 磁盘：双树共存约需 100Gi+。
GUIDE
  read -r -p "继续？[y/N] " a; [ "$a" = y ] || exit 1
  OLDV=$(sed -n '1p' "$HERE/chromium_version.txt" | cut -d. -f1)   # merge 后这是新版本号——挪树名用旧的
  [ -e "$SRC" ] && { OLD="$PLAT/build/src-old-$(date +%m%d)"; mv "$SRC" "$OLD"; echo "老树 → $OLD"; }
  say "he presetup（下载/展开/prune/工具链/资源/盖版本）"
  (cd "$PLAT" && zsh -c 'source dev.sh >/dev/null 2>&1 && he presetup') || {
    echo "⛔ presetup 非零退出：必须 rm -rf build/src 重来（它见 out/ 存在会静默 no-op，半熟树拖到 build 才炸）"; exit 1; }
  say "he merge 生成 series.merged"
  (cd "$PLAT" && zsh -c 'source dev.sh >/dev/null 2>&1 && he merge') || exit 1
  N=$(grep -c . "$PLAT/patches/series.merged"); F=$(grep -c '^helium-fork/' "$PLAT/patches/series.merged")
  echo "series.merged: 总 $N / fork $F（期望 fork=$EXPECTED_FORK）"
  [ "$F" = "$EXPECTED_FORK" ] || { echo "⛔ fork 计数不对"; exit 1; }
  echo "→ 下一步: ./fork_sync.sh stage3"
}

stage3() {  # 受控重推（⛔ 不用 he setup 的 push -a --refresh）+ 缺创建扫描
  say "缺创建扫描（补丁改了某文件但无人创建、新树又没有 → 先补创建段）"
  python3 - "$PLAT" <<'PY'
import re, sys
from pathlib import Path
plat = Path(sys.argv[1]); pd = plat/'patches'; tree = plat/'build/src'
series = [l.strip() for l in (pd/'series.merged').read_text().splitlines() if l.strip().startswith('helium-fork/')]
seen, created = {}, {}
for pn in series:
    txt = (pd/pn).read_text(errors='replace')
    for m in re.finditer(r'^Index: src/(\S+)\n=+\n--- [^\n]*\n\+\+\+ [^\n]*\n(@@ [^\n]*)', txt, re.M):
        f, h = m.group(1), m.group(2)
        seen.setdefault(f, pn)
        if re.match(r'@@ -0,0 ', h): created.setdefault(f, pn)
bad = [(f,p) for f,p in seen.items() if f not in created and not (tree/f).exists()]
print(f"涉及 {len(seen)} 文件，创建段 {len(created)}，缺创建且树上没有: {len(bad)}")
for f,p in bad: print(f"  ⛔ {f}  ← 首个属主 {p}（修法见 pitfalls 同步轮第 1 条）")
sys.exit(1 if bad else 0)
PY
  [ $? -eq 0 ] || { echo "先修上面的缺创建，再重跑 stage3"; exit 1; }
  say "quilt push -a（无 --refresh；日志 → /tmp/fork_sync_push.log）"
  Q push -a >/tmp/fork_sync_push.log 2>&1
  RC=$?; APPLIED=$(wc -l < "$SRC/.pc/applied-patches" | tr -d ' ')
  echo "push exit=$RC applied=$APPLIED"
  awk '/^Applying patch/{p=$3} /with fuzz/{print "fuzz:",p,$0}' /tmp/fork_sync_push.log
  grep -n 'FAILED\|does not apply\|find file to patch' /tmp/fork_sync_push.log | tail -5
  if [ $RC -ne 0 ]; then
    cat <<'GUIDE'
→ 停在首个 rej。修复循环（每层）：
   quilt --quiltrc - push -f   （先！快照要干净——⛔ 不许先改树）
   按 .rej 手工移植（对照老树 src-*/ 的最终态与 152 新结构）→ 删 .rej
   本层要动补丁未涉及的文件先 quilt add；然后
   QUILT_REFRESH_ARGS="--no-timestamps" quilt --quiltrc - refresh
   重跑 ./fork_sync.sh stage3 直到 push 全绿。
GUIDE
    exit 2
  fi
  echo "→ 全栈已推满。下一步: ./fork_sync.sh audit"
}

audit() {  # fuzz 清零终审（整栈重放；⚠ 会动全部补丁文件 mtime → 之后首次编译是全量）
  say "pop -a && push -a 重放"
  Q pop -a >/dev/null 2>&1; Q push -a >/tmp/fork_sync_audit.log 2>&1 || { echo "⛔ 重放失败"; exit 1; }
  echo "applied=$(wc -l < "$SRC/.pc/applied-patches" | tr -d ' ')"
  echo "── fuzz 清单（唯一允许项＝helium/macos/updater/sparkle2-integration 恒 fuzz 2）──"
  awk '/^Applying patch/{p=$3} /with fuzz/{print p": "$0}' /tmp/fork_sync_audit.log
  N=$(awk '/^Applying patch/{p=$3} /with fuzz/{if (p != "helium/macos/updater/sparkle2-integration.patch") n++} END{print n+0}' /tmp/fork_sync_audit.log)
  [ "$N" = 0 ] && echo "✅ fuzz 清零达成" || cat <<'GUIDE'
⛔ 还有 fuzz：对每个层 quilt pop <层> → QUILT_REFRESH_ARGS="--no-timestamps" refresh →
   push 到下一个 fuzz 层再 refresh……最后 push -a，重跑 audit。
GUIDE
  echo "→ 下一步: ./fork_sync.sh build"
}

build() {  # configure + 编译 + 单测（编译错按属主层归位后再批量 refresh）
  say "he configure"
  (cd "$PLAT" && zsh -c 'source dev.sh >/dev/null 2>&1 && he configure') || exit 1
  say "编译 chrome + helium_workspace_unittests（tools/build.sh 有真实错误计数）"
  zsh "$PLAT/../tools/build.sh" chrome helium_workspace_unittests || true
  echo "→ 绿了之后：跑单测二进制、守卫 1/2/3、fold_rebuild=0、0.0-* 机器项、Rel 构建交验收；"
  echo "   入库照 tools/commitNN.sh 两段式（新计数自己数）。流程细节见 progress/runbook.md。"
}

case "${1:-help}" in
  stage0) stage0;; stage1) stage1;; stage2) stage2;; stage3) stage3;;
  audit) audit;; build) build;;
  *) sed -n '2,10p' "$0"; grep -E '^(stage|audit|build)[0-9]*\(\)' "$0" | sed 's/() *{ *#/  —/;s/^/  /';;
esac
