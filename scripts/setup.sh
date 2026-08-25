#!/usr/bin/env bash
# setup.sh — ループエンジニアリング環境のセットアップ
#
#   ./scripts/setup.sh          導入と診断
#   ./scripts/setup.sh --check  診断のみ（何もインストールしない）

set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

CHECK_ONLY=0
[ "${1:-}" = "--check" ] && CHECK_ONLY=1

if [ -t 1 ]; then G=$'\033[32m'; R=$'\033[31m'; Y=$'\033[33m'; Z=$'\033[0m'
else G=""; R=""; Y=""; Z=""; fi

ok()   { echo "  ${G}OK${Z}   $1"; }
warn() { echo "  ${Y}WARN${Z} $1"; }
bad()  { echo "  ${R}NG${Z}   $1"; MISSING=$((MISSING+1)); }
has()  { command -v "$1" >/dev/null 2>&1; }
MISSING=0

echo "════════════════════════════════════════════"
echo " ループエンジニアリング環境のセットアップ"
echo "════════════════════════════════════════════"
echo
echo "[1/4] 前提ツール"
for c in git node npm python3; do
  if has "$c"; then ok "$c ($($c --version 2>&1 | head -1))"; else bad "$c が見つかりません"; fi
done

echo
echo "[2/4] エージェント CLI"
if has claude; then ok "claude ($(claude --version 2>&1 | head -1))"
else bad "Claude Code が未導入です → npm install -g @anthropic-ai/claude-code"; fi

if has codex; then
  ok "codex ($(codex --version 2>&1 | head -1))"
elif [ $CHECK_ONLY -eq 0 ]; then
  echo "  Codex CLI（GPT側レビュアー）を導入します..."
  if npm install -g @openai/codex >/dev/null 2>&1; then ok "codex を導入しました"
  else bad "codex の導入に失敗しました → npm install -g @openai/codex を手動で実行してください"; fi
else
  bad "codex が未導入です → npm install -g @openai/codex"
fi

echo
echo "[3/4] Python ツール（lint / typecheck / test）"
for pkg in pytest ruff mypy; do
  if has "$pkg"; then ok "$pkg"
  elif [ $CHECK_ONLY -eq 0 ]; then
    echo "  $pkg を導入します..."
    if has uv; then uv pip install --system "$pkg" >/dev/null 2>&1 || pip3 install --break-system-packages -q "$pkg" >/dev/null 2>&1
    else pip3 install --break-system-packages -q "$pkg" >/dev/null 2>&1; fi
    has "$pkg" && ok "$pkg を導入しました" || warn "$pkg の導入に失敗。verify.sh の該当チェックが SKIP されます（停止条件が1つ減ります）"
  else
    warn "$pkg が未導入。verify.sh の該当チェックが SKIP されます（停止条件が1つ減ります）"
  fi
done

echo
echo "[4/4] 認証状態"
if [ -n "${ANTHROPIC_API_KEY:-}" ]; then ok "Claude: ANTHROPIC_API_KEY が設定されています"
elif [ -f "$HOME/.claude/.credentials.json" ]; then ok "Claude: ログイン済み"
else warn "Claude: 未認証の可能性があります → claude コマンドを起動してログインしてください"; fi

if has codex && codex login status >/dev/null 2>&1; then
  ok "GPT: Codex CLI ログイン済み（$(codex login status 2>&1 | head -1)）"
elif [ -n "${OPENAI_API_KEY:-}" ]; then
  ok "GPT: OPENAI_API_KEY が設定されています"
else
  bad "GPT: 未認証 — レビュー担当（別ベンダー採点）が動きません"
  cat <<'MSG'

       ┌──────────────────────────────────────────────────┐
       │ 人間の操作が必要です。次のどちらかを実行してください │
       └──────────────────────────────────────────────────┘

       1) ChatGPT アカウントでログイン（Plus/Pro/Business 契約が必要）
            codex login
          ブラウザが開きます。リモート/コンテナなどブラウザを開けない環境では
            codex login --device-auth
          を使い、表示されたコードを手元の端末のブラウザで入力してください。

       2) OpenAI API キーを使う（従量課金）
            export OPENAI_API_KEY=sk-...
            printenv OPENAI_API_KEY | codex login --with-api-key

MSG
fi

echo
echo "════════════════════════════════════════════"
if [ $MISSING -eq 0 ]; then
  echo "${G}準備完了${Z} — 次の一歩:"
  echo
  echo "  claude                          # Claude Code を起動"
  echo "  > /new-issue 〜という機能を作りたい   # 課題を起票"
  echo "  > /issue-to-merge 0001-xxx       # 外側のループを回す"
else
  echo "${R}${MISSING} 件の未解決項目があります。${Z}上のメッセージに従って解消してください。"
fi
echo "════════════════════════════════════════════"
exit $MISSING
