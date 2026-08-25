#!/usr/bin/env bash
# verify.sh — 機械が判定できる合格条件（Step4）
#
# このスクリプトの終了コードが、このリポジトリにおける唯一の「停止条件」です。
#   終了コード 0 → 合格。ループを止めてよい。
#   終了コード 1 → 不合格。まだ終わっていない。
#
# AIの「できました」は主張にすぎません。ここが 0 を返すまで完了として扱わないでください。
#
# 使い方:
#   ./scripts/verify.sh            全チェック（lint + 型 + テスト）
#   ./scripts/verify.sh --quick    テストのみ（ループ内の高速な繰り返し用）
#   ./scripts/verify.sh --json     結果を JSON でも出力（他のツールから読む用）

set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
ROOT="$PWD"

QUICK=0
JSON=0
for arg in "$@"; do
  case "$arg" in
    --quick) QUICK=1 ;;
    --json)  JSON=1 ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

RESULTS=()
FAILED=0
RAN=0
SKIPPED=0

if [ -t 1 ]; then C_G=$'\033[32m'; C_R=$'\033[31m'; C_Y=$'\033[33m'; C_0=$'\033[0m'
else C_G=""; C_R=""; C_Y=""; C_0=""; fi

# run <名前> <コマンド...>
run() {
  local name="$1"; shift
  RAN=$((RAN + 1))
  echo "── ${name}"
  echo "   \$ $*"
  local out rc
  out="$("$@" 2>&1)"; rc=$?
  if [ -n "$out" ]; then printf '%s\n' "$out" | sed 's/^/   /'; fi
  if [ $rc -eq 0 ]; then
    echo "   ${C_G}PASS${C_0} ${name}"
    RESULTS+=("PASS|${name}")
  else
    echo "   ${C_R}FAIL${C_0} ${name} (exit ${rc})"
    RESULTS+=("FAIL|${name}")
    FAILED=$((FAILED + 1))
  fi
  echo
}

skip() {
  echo "── $1"
  echo "   ${C_Y}SKIP${C_0} $2"
  RESULTS+=("SKIP|$1")
  SKIPPED=$((SKIPPED + 1))
  echo
}

has() { command -v "$1" >/dev/null 2>&1; }

echo "════════════════════════════════════════════"
echo " verify.sh — 停止条件の判定"
echo " repo: ${ROOT}"
echo " mode: $([ $QUICK -eq 1 ] && echo quick || echo full)"
echo "════════════════════════════════════════════"
echo

# ── Node/TypeScript プロジェクト ─────────────────────
if [ -f package.json ]; then
  npm_script() { node -e "process.exit(require('./package.json').scripts?.['$1']?0:1)" 2>/dev/null; }
  if [ $QUICK -eq 0 ]; then
    if npm_script lint; then run "js:lint" npm run --silent lint; else skip "js:lint" "package.json に scripts.lint がありません"; fi
    if npm_script typecheck; then run "js:typecheck" npm run --silent typecheck
    elif [ -f tsconfig.json ] && has npx; then run "js:typecheck" npx --no-install tsc --noEmit
    else skip "js:typecheck" "typecheck の設定がありません"; fi
  fi
  if npm_script test; then run "js:test" npm test --silent; else skip "js:test" "package.json に scripts.test がありません"; fi
fi

# ── Python プロジェクト ───────────────────────────────
PY_FILES=$(find . -name '*.py' -not -path './.git/*' -not -path './node_modules/*' -not -path './.venv/*' -print -quit 2>/dev/null)
if [ -n "$PY_FILES" ]; then
  PY=python3; has python3 || PY=python
  # src レイアウトをどのランナーからでも import できるようにする
  [ -d src ] && export PYTHONPATH="${ROOT}/src:${PYTHONPATH:-}"
  if [ $QUICK -eq 0 ]; then
    if has ruff; then
      run "py:lint"   ruff check .
      run "py:format" ruff format --check .
    else
      # ruff が無い環境でも「文法エラー0件」だけは必ず機械判定する
      run "py:syntax" "$PY" -m compileall -q src tests
      skip "py:lint" "ruff が未インストール（./scripts/setup.sh で導入できます）"
    fi
    if has mypy; then run "py:typecheck" mypy src; else skip "py:typecheck" "mypy が未インストール"; fi
  fi
  if has pytest; then
    run "py:test" pytest -q
  else
    run "py:test" "$PY" -m unittest discover -s tests -t . -v
  fi
fi

# ── ドキュメント整合性（AIの外部記憶が腐っていないか） ──
if [ $QUICK -eq 0 ] && [ -d docs/plans ]; then
  run "docs:plans" bash -c '
    fail=0
    shopt -s nullglob
    for f in docs/plans/*.md; do
      case "$f" in *TEMPLATE*|*template*) continue;; esac
      if ! grep -q "最終更新" "$f"; then echo "$f: 「最終更新」の記載がありません"; fail=1; fi
    done
    exit $fail'
fi

if [ "$RAN" -eq 0 ]; then
  echo "${C_Y}警告: 実行できるチェックが1つもありませんでした。${C_0}"
  echo "テストが存在しない状態では停止条件を機械判定できません（Step4 未達）。"
  exit 1
fi

echo "════════════════════════════════════════════"
for r in "${RESULTS[@]}"; do printf ' %-6s %s\n' "${r%%|*}" "${r#*|}"; done
echo "════════════════════════════════════════════"

if [ $JSON -eq 1 ]; then
  {
    printf '{"failed":%d,"checks":[' "$FAILED"
    sep=""
    for r in "${RESULTS[@]}"; do printf '%s{"status":"%s","name":"%s"}' "$sep" "${r%%|*}" "${r#*|}"; sep=","; done
    printf ']}\n'
  } > .verify-result.json
  echo "JSON: .verify-result.json"
fi

if [ $FAILED -gt 0 ]; then
  echo "${C_R}NOT DONE${C_0}: ${FAILED} 件のチェックが失敗しました。完了として扱わないでください。"
  exit 1
fi

if [ $SKIPPED -gt 0 ]; then
  echo "${C_G}DONE${C_0}: 実行したチェックはすべて通りました。"
  echo "${C_Y}ただし ${SKIPPED} 件が SKIP されています。その分だけ停止条件は弱くなっています。${C_0}"
  echo "SKIP されたチェックは「合格」ではなく「未検査」です。報告時は必ず SKIP 件数を明示してください。"
  echo "解消するには ./scripts/setup.sh を実行して不足しているツールを導入します。"
  exit 0
fi

echo "${C_G}DONE${C_0}: すべてのチェックが通りました。停止条件を満たしています。"
exit 0
