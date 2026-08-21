---
name: loop-status
description: いま回っているループの状態を1画面にまとめる。「状況を教えて」「どこまで進んだ」「ループの状態は」と聞かれたときに使う。中断からの再開時、まずこれを実行して外部記憶を復元する。
---

# loop-status — ループの現在地を復元する

AIが一度に覚えられる情報量には上限があります。
状態はファイルに書き出してあるので、**中断からの再開時はまずこれを実行**して文脈を復元してください。

## 収集する

```bash
git status --short --branch
git log --oneline -10
ls docs/issues/ docs/requirements/ docs/design/ docs/plans/ docs/reviews/ 2>/dev/null
./scripts/verify.sh --quick
```

さらに:
- `docs/issues/*.md` の `状態:` 行 → 各課題の進捗
- `docs/plans/*.md` の「進行状況」「verify 実行回数」「詰まっている点」
- `docs/reviews/` の最新ファイル → 直近のレビュー指摘と未対応分

## 報告フォーマット

```
■ 課題一覧
  0001-xxx  [in-progress]  計画 4/7 完了  verify 2/5 回
  0002-yyy  [open]         未着手

■ 現在のブランチ: <branch>（origin より N コミット先行）
■ verify: PASS / FAIL（失敗内容）
■ 直近のレビュー: docs/reviews/... blocker N件（うち未対応 M件）

■ 次にやるべきこと
  1. ...

■ 人間の判断待ち
  - ...（なければ「なし」）
```

事実だけを書くこと。verify が赤いのに「順調」と書かないこと。
