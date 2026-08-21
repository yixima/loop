#!/usr/bin/env bash
# loop.sh — 外側のループ本体
#
# 「停止条件が満たされるまでエージェントが作業サイクルを繰り返す」を、そのままシェルにしたものです。
# 人間が「次はこれ」と言い続ける代わりに、このループが次の一手をAIに決めさせ、
# verify.sh という客観的な証拠が揃うまで回し続けます。
#
# 使い方:
#   ./scripts/loop.sh docs/issues/0001-greeting-time-of-day.md
#   MAX_ATTEMPTS=8 ./scripts/loop.sh docs/issues/0001-xxx.md
#   DRY_RUN=1 ./scripts/loop.sh docs/issues/0001-xxx.md    # 何を実行するか表示するだけ
#
# 停止条件:
#   1. verify.sh が終了コード 0        → 成功で停止
#   2. 試行回数が MAX_ATTEMPTS に到達  → 未完了として報告し停止（成功と偽らない）
#   3. AI が「STOP:」で始まる行を出力  → 人間の判断待ちとして停止

set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

ISSUE="${1:-}"
MAX_ATTEMPTS="${MAX_ATTEMPTS:-5}"
DRY_RUN="${DRY_RUN:-0}"
PERMISSION_MODE="${PERMISSION_MODE:-acceptEdits}"
LOG_DIR=".loop-logs"

if [ -z "$ISSUE" ] || [ ! -f "$ISSUE" ]; then
  echo "使い方: $0 <課題ファイル>" >&2
  echo "例:     $0 docs/issues/0001-greeting-time-of-day.md" >&2
  echo >&2
  echo "利用できる課題ファイル:" >&2
  ls docs/issues/*.md 2>/dev/null | sed 's/^/  /' >&2 || echo "  (まだありません。/new-issue で作成してください)" >&2
  exit 2
fi

command -v claude >/dev/null 2>&1 || { echo "claude コマンドが見つかりません。./scripts/setup.sh を実行してください。" >&2; exit 2; }

ISSUE_ID="$(basename "$ISSUE" .md)"
mkdir -p "$LOG_DIR"

echo "════════════════════════════════════════════"
echo " 外側のループを開始します"
echo " 課題      : ${ISSUE_ID}"
echo " 最大試行  : ${MAX_ATTEMPTS} 回"
echo " 停止条件  : ./scripts/verify.sh が終了コード 0"
echo "════════════════════════════════════════════"

attempt=0
while [ "$attempt" -lt "$MAX_ATTEMPTS" ]; do
  attempt=$((attempt + 1))
  echo
  echo "──────────── 試行 ${attempt}/${MAX_ATTEMPTS} ────────────"

  # 1) 先に停止条件を確認する（既に満たしているなら回さない）
  if ./scripts/verify.sh --quick >/dev/null 2>&1; then
    if [ "$attempt" -gt 1 ]; then
      echo "verify（quick）が通りました。フルチェックへ進みます。"
      if ./scripts/verify.sh; then
        echo
        echo "✅ 停止条件を満たしました（試行 ${attempt} 回目）"
        echo "   次はレビューです: ISSUE_ID=${ISSUE_ID} ./scripts/gpt-review.sh"
        exit 0
      fi
    fi
  fi

  # 2) AI に次の一手を決めさせて実行させる
  PROMPT=$(cat <<EOF
issue-to-merge スキルに従って、課題 ${ISSUE_ID} を前に進めてください。

課題ファイル: ${ISSUE}
これは自動ループの ${attempt} 回目の試行です（上限 ${MAX_ATTEMPTS} 回）。

まず docs/plans/${ISSUE_ID}.md を読み、前回どこまで進んだかを復元してください。
存在しなければ、まず architect サブエージェントで設計3文書を作るところから始めます。

このターンでやること:
1. 実装計画書の未完了タスクのうち、次の1〜2件だけを進める
2. ./scripts/verify.sh を実行する
3. docs/plans/${ISSUE_ID}.md のチェックボックスと作業ログを必ず更新する

守ること:
- テストを消す・スキップする・アサーションを緩めることで緑にしない
- verify が通っていないものを「完了」と呼ばない
- 判断に迷ったら、実装せず "STOP: <理由>" とだけ出力して止まる
EOF
)

  LOG="${LOG_DIR}/${ISSUE_ID}-attempt${attempt}.log"

  if [ "$DRY_RUN" = "1" ]; then
    echo "[DRY_RUN] claude -p --permission-mode ${PERMISSION_MODE} <<PROMPT"
    echo "$PROMPT" | sed 's/^/[DRY_RUN]   /'
    echo "[DRY_RUN] ログ出力先: ${LOG}"
    exit 0
  fi

  claude -p "$PROMPT" --permission-mode "$PERMISSION_MODE" 2>&1 | tee "$LOG"

  # 3) AI からの明示的な停止要求
  if grep -q '^STOP:' "$LOG"; then
    echo
    echo "⏸  AI が人間の判断を求めて停止しました:"
    grep '^STOP:' "$LOG" | sed 's/^/   /'
    echo "   ログ: ${LOG}"
    exit 2
  fi
done

# 4) 上限に到達 — 成功と偽らずに未完了で終わる
echo
echo "════════════════════════════════════════════"
echo "⛔ 未完了: ${MAX_ATTEMPTS} 回試行しましたが停止条件を満たしませんでした。"
echo "   AIの「できました」は主張であって事実ではありません。ここでは完了としません。"
echo
./scripts/verify.sh || true
echo
echo "   実装計画書: docs/plans/${ISSUE_ID}.md"
echo "   ログ:       ${LOG_DIR}/${ISSUE_ID}-attempt*.log"
echo "   人間が状況を確認し、課題の分割や設計の見直しを判断してください。"
echo "════════════════════════════════════════════"
exit 1
