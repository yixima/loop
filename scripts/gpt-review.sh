#!/usr/bin/env bash
# gpt-review.sh — 別ベンダーモデル（OpenAI GPT / Codex）にレビューさせる（Step3）
#
# 原則:「自分の宿題を自分で採点させない」
# 実装は Claude、採点は GPT。開発元の違うモデルに採点させることで品質を守ります。
#
# 使い方:
#   ./scripts/gpt-review.sh                 # 既定のベース（origin/HEAD か main）との差分をレビュー
#   ./scripts/gpt-review.sh origin/main     # ベースを指定
#   ./scripts/gpt-review.sh --staged        # ステージ済みの変更をレビュー
#   ISSUE_ID=0001-login ./scripts/gpt-review.sh
#
# 認証（どちらか一方）:
#   1) ChatGPT アカウント:  codex login          （ブラウザが開きます／要人間操作）
#   2) API キー:            export OPENAI_API_KEY=sk-...  してから実行
#
# 出力: docs/reviews/<ISSUE_ID>-<timestamp>.md  ／ 終了コード 0=実行成功, 3=認証エラー, 1=その他失敗

set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

MODEL="${GPT_REVIEW_MODEL:-gpt-5.1-codex}"
ISSUE_ID="${ISSUE_ID:-$(git rev-parse --abbrev-ref HEAD 2>/dev/null | tr '/' '-')}"
TS="$(date +%Y%m%d-%H%M%S)"
OUT_DIR="docs/reviews"
OUT="${OUT_DIR}/${ISSUE_ID}-${TS}.md"
mkdir -p "$OUT_DIR"

# ── 差分を作る ──────────────────────────────────────
DIFF_FILE="$(mktemp)"
trap 'rm -f "$DIFF_FILE"' EXIT

if [ "${1:-}" = "--staged" ]; then
  RANGE="(staged changes)"
  git diff --cached > "$DIFF_FILE"
else
  BASE="${1:-}"
  if [ -z "$BASE" ]; then
    for cand in origin/HEAD origin/main origin/master main master; do
      if git rev-parse --verify --quiet "$cand" >/dev/null; then BASE="$cand"; break; fi
    done
  fi
  if [ -n "$BASE" ] && git rev-parse --verify --quiet "$BASE" >/dev/null; then
    RANGE="${BASE}...HEAD (+ 未コミットの変更)"
    { git diff "$BASE"...HEAD; git diff; git diff --cached; } > "$DIFF_FILE"
  else
    RANGE="(uncommitted changes)"
    { git diff; git diff --cached; } > "$DIFF_FILE"
  fi
fi

if [ ! -s "$DIFF_FILE" ]; then
  echo "レビュー対象の差分がありません（range: ${RANGE}）。" >&2
  exit 1
fi

DIFF_LINES=$(wc -l < "$DIFF_FILE")
echo "レビュー対象: ${RANGE}  /  ${DIFF_LINES} 行の差分"
echo "採点モデル  : ${MODEL}（開発元: OpenAI — 実装者とは別ベンダー）"

# ── レビュー指示 ────────────────────────────────────
read -r -d '' INSTRUCTIONS <<'PROMPT'
あなたは、別のAI（Anthropic Claude）が書いたコードを採点する外部レビュアーです。
実装者への忖度は不要です。「自分の宿題を自分で採点しない」ためにあなたが呼ばれています。

このリポジトリの判断の原則は CLAUDE.md に、設計意図は docs/design/ と docs/requirements/ にあります。
必要ならそれらのファイルを読んでから採点してください。

以下の観点で差分を厳しくレビューし、指摘を severity 別に分類してください。

1. **正しさ**: 実際に壊れる入力・状態はあるか。境界値、null/空、並行性、例外経路。
2. **仕様との一致**: 設計書・要件定義書の受け入れ条件を本当に満たしているか。満たしたフリをしていないか。
3. **検証の抜け穴**: テストが実質何も検証していない、スキップされている、アサーションが緩い、
   モック/ダミーがプロダクションコードに残っている、といった「緑にするための細工」がないか。
   これは最重要項目です。見つけたら必ず blocker にしてください。
4. **セキュリティ**: 秘密情報の漏洩、入力検証の欠落、インジェクション、権限の抜け。
5. **簡潔さ**: 不要な抽象化、重複、既存関数の再実装。

出力は必ず以下の Markdown 形式のみで返してください。前置きや挨拶は書かないこと。

## blocker
- `file:line` — 何が問題か / **どう壊れるか（具体的な入力と結果）**

## major
- `file:line` — ...

## minor
- `file:line` — ...

## nit
- `file:line` — ...

## 総評
（3行以内。blocker が 0 件なら「合格」、1件以上なら「不合格」と明記すること）

該当がない severity は「- なし」と書いてください。
推測で指摘を作らないこと。指摘は必ず差分または実ファイルの記述に基づくこと。
PROMPT

# ── 実行 ────────────────────────────────────────────
BODY_FILE="$(mktemp)"
RC=0

if command -v codex >/dev/null 2>&1; then
  if ! codex login status >/dev/null 2>&1 && [ -z "${OPENAI_API_KEY:-}" ]; then
    cat >&2 <<'MSG'

────────────────────────────────────────────────────────
GPT レビューを実行できません: Codex CLI が未認証です。
別ベンダーによる採点なしにレビュー合格と判定してはいけません。

次のどちらかを実行してください（人間の操作が必要です）:

  1) ChatGPT アカウントでログイン
       codex login
     ※ ブラウザが開きます。SSH/コンテナ越しの場合は
       codex login --headless  もしくは表示されたURLを手元のブラウザで開いてください。

  2) OpenAI API キーを使う
       export OPENAI_API_KEY=sk-...
       printenv OPENAI_API_KEY | codex login --with-api-key
────────────────────────────────────────────────────────
MSG
    exit 3
  fi

  printf '%s\n\n---\n\nレビュー対象の差分（range: %s）:\n\n```diff\n%s\n```\n' \
    "$INSTRUCTIONS" "$RANGE" "$(cat "$DIFF_FILE")" \
  | codex exec --model "$MODEL" --sandbox read-only --skip-git-repo-check \
      --color never -o "$BODY_FILE" - >/dev/null 2>"${BODY_FILE}.err"
  RC=$?
  if [ $RC -ne 0 ]; then
    echo "codex exec が失敗しました (exit ${RC}):" >&2
    tail -20 "${BODY_FILE}.err" >&2
    grep -qiE '401|unauthor|auth|login|credential' "${BODY_FILE}.err" && RC=3
    rm -f "${BODY_FILE}.err"
    exit $RC
  fi
  rm -f "${BODY_FILE}.err"

elif [ -n "${OPENAI_API_KEY:-}" ]; then
  echo "codex CLI が見つからないため OpenAI API を直接呼び出します。"
  GPT_REVIEW_INSTRUCTIONS="$INSTRUCTIONS" python3 - "$DIFF_FILE" "$BODY_FILE" "$MODEL" "$RANGE" <<'PY'
import json, os, sys, urllib.request, urllib.error
diff_f, out_f, model, rng = sys.argv[1:5]
instructions = os.environ["GPT_REVIEW_INSTRUCTIONS"]
diff = open(diff_f, encoding="utf-8", errors="replace").read()[:400000]
req = urllib.request.Request(
    "https://api.openai.com/v1/chat/completions",
    data=json.dumps({"model": model, "messages": [
        {"role": "system", "content": "You are a strict external code reviewer."},
        {"role": "user", "content": f"{instructions}\n\nrange: {rng}\n\n```diff\n{diff}\n```"}]}).encode(),
    headers={"Authorization": f"Bearer {os.environ['OPENAI_API_KEY']}",
             "Content-Type": "application/json"})
try:
    with urllib.request.urlopen(req, timeout=300) as r:
        body = json.load(r)["choices"][0]["message"]["content"]
except urllib.error.HTTPError as e:
    sys.stderr.write(e.read().decode()[:2000])
    sys.exit(3 if e.code in (401, 403) else 1)
open(out_f, "w", encoding="utf-8").write(body)
PY
  RC=$?
  [ $RC -ne 0 ] && exit $RC
else
  cat >&2 <<'MSG'
GPT レビューを実行できません: codex CLI も OPENAI_API_KEY も見つかりません。
  ./scripts/setup.sh を実行して Codex CLI を導入し、codex login で認証してください。
MSG
  exit 3
fi

# ── 保存 ────────────────────────────────────────────
{
  echo "# GPT レビュー結果"
  echo
  echo "- **課題ID**: \`${ISSUE_ID}\`"
  echo "- **日時**: $(date '+%Y-%m-%d %H:%M:%S %Z')"
  echo "- **採点モデル**: \`${MODEL}\`（OpenAI — 実装者 Claude とは別ベンダー）"
  echo "- **対象**: ${RANGE}（${DIFF_LINES} 行）"
  echo "- **コミット**: \`$(git rev-parse --short HEAD 2>/dev/null || echo N/A)\`"
  echo
  echo "---"
  echo
  cat "$BODY_FILE"
} > "$OUT"
rm -f "$BODY_FILE"

echo
cat "$OUT"
echo
echo "保存しました: ${OUT}"

# blocker の有無を終了コードには載せない（判定は reviewer サブエージェントの仕事）
exit 0
