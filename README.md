# loop — ループエンジニアリングを試すための環境

> 「もうコーディングエージェントにプロンプトを書くべきではない。エージェントをプロンプトするループを設計するべきだ」
> — Peter Steinberger（OpenClaw 作者）

ビジネス+IT の記事「[「Claude Code×GPT」自律ループが凄すぎ、仕事が"3つ"に減る5ステップ](https://www.sbbit.jp/article/cont1/186558)」で
紹介されている **ループエンジニアリング** を、実際に手元で回せる形にしたリポジトリです。

手法そのものの解説は **[docs/loop-engineering.md](docs/loop-engineering.md)** にまとめてあります。

---

## クイックスタート

```bash
git clone https://github.com/yixima/loop.git
cd loop

./scripts/setup.sh          # 必要なツールの導入と認証状態の診断
./scripts/verify.sh         # 停止条件が機械判定できることの確認（緑になるはず）

claude                      # Claude Code を起動
> /loop-status                              # いまの状態を確認
> /issue-to-merge 0001-greeting-time-of-day  # サンプル課題でループを回す
```

シェルから直接ループを回すこともできます。

```bash
./scripts/loop.sh docs/issues/0001-greeting-time-of-day.md
DRY_RUN=1 ./scripts/loop.sh docs/issues/0001-greeting-time-of-day.md   # 実行内容の確認だけ
```

---

## 記事の5ステップとの対応

記事は「いきなり全自動化はNG。順番は逆」と強調しています。
判断の原則と検証の仕組みがない状態で自動化すると、**間違った方向へ高速で突き進むシステム**ができあがるためです。
このリポジトリは Step1 から順に土台を組み、最後に外側のループをつないでいます。

| Step | 記事の内容 | 実体 |
|:--:|---|---|
| **1** | 判断の原則を書く（迷ったときのルールを10〜20個） | [`CLAUDE.md`](CLAUDE.md) — 21項目 |
| **2** | 文書をAIの外部記憶にする（要件定義書・設計書・実装計画書） | [`docs/templates/`](docs/templates/) → `docs/requirements/` `docs/design/` `docs/plans/` |
| **3** | 作る係と評価する係を分ける | [`.claude/agents/`](.claude/agents/) の3エージェント ＋ [`scripts/gpt-review.sh`](scripts/gpt-review.sh) |
| **4** | 合格を機械が判定できるようにする | [`scripts/verify.sh`](scripts/verify.sh) — **このリポジトリ唯一の停止条件** |
| **5** | 繰り返す作業を標準手順書にする | [`.claude/skills/`](.claude/skills/) |
| **最後** | 外側のループをつなぐ | [`/issue-to-merge`](.claude/skills/issue-to-merge/SKILL.md) ＋ [`scripts/loop.sh`](scripts/loop.sh) |

---

## 構成

```
CLAUDE.md                       Step1: 判断の原則（AIが迷ったときの基準）
docs/
  loop-engineering.md           手法の解説（記事のまとめ）
  templates/                    Step2: 要件定義書・設計書・実装計画書・課題のテンプレート
  issues/                       課題ファイル = ループの入り口
  requirements/ design/ plans/  AIの外部記憶（課題IDごとに生成される）
  reviews/                      GPTによるレビュー結果の保存先
.claude/
  settings.json                 権限設定（破壊的操作は deny、push は ask）
  agents/
    architect.md                設計担当 — ドキュメントだけを書く。実装しない
    implementer.md              実装担当 — TDDで書く。合否判定はしない
    reviewer.md                 レビュー担当 — GPTに採点させ、結果を整理する
  skills/
    issue-to-merge/             外側のループ本体
    new-issue/                  課題の起票（受け入れ条件を機械判定可能な形に落とす）
    loop-status/                中断からの再開時に状態を復元する
scripts/
  setup.sh                      環境セットアップと診断
  verify.sh                     Step4: 停止条件の判定（終了コード 0 = 合格）
  gpt-review.sh                 別ベンダーモデルによる採点
  loop.sh                       外側のループをシェルから回す
src/ tests/                     動作確認用サンプル（実プロジェクト開始時は削除可）
```

---

## 3つの役割分担（Step3）

記事の「**自分の宿題を自分で採点させない**」を、ベンダーを跨いで実装しています。

```
課題ファイル
    │
    ▼
[architect]  Claude   設計3文書を書く。コードは書かない
    │                 ── 人間の関与①: 設計書を斜め読みして指摘する
    ▼
[implementer] Claude  テストを先に書き、最小実装で通す
    │  ▲
    │  └────── verify.sh が緑になるまで（最大5回）
    ▼
[reviewer]   Claude + **GPT (OpenAI)**  ← 開発元の違うモデルが採点する
    │  │
    │  └─ blocker があれば implementer に差し戻し（最大3周）
    ▼
コミット & push
    │
    ▼
── 人間の関与②: 本番反映のタイミング判断（意図的に自動化していません）
```

---

## 停止条件の考え方

記事が最も強調している点です。

- ❌ **悪いゴール**: 「ログイン機能を完成させろ」
  → AIが「できました」と言えば終わってしまう
- ✅ **良いゴール**: 「テストが全件通り、lintエラーが0件になるまで修正する。5回試して駄目なら状況を報告して止まる」

このリポジトリでは、次の3層で停止条件を機械化しています。

| 層 | 実体 |
|---|---|
| 合格の判定 | `./scripts/verify.sh` の終了コード（0 = 合格、それ以外は完了と呼ばない） |
| 試行回数の上限 | `loop.sh` の `MAX_ATTEMPTS`（既定5回）／ レビュー往復は最大3周 |
| 人間へのエスカレーション | AIが `STOP: <理由>` を出力するとループが止まる |

> AIの「できました」は事実ではなく、ただの主張である。
> テスト結果という証拠がそろうまで、完了として扱ってはならない。 — Proof-or-Stop

---

## 認証について

このリポジトリは **2つのベンダーのモデル** を使います。どちらも人間による認証操作が必要です。

| 用途 | ツール | 認証方法 |
|---|---|---|
| 設計・実装 | Claude Code | `claude` を起動してログイン、または `ANTHROPIC_API_KEY` |
| レビュー（採点） | Codex CLI (OpenAI) | `codex login`（ChatGPT アカウント／ブラウザが開きます）<br>ブラウザを開けない環境では `codex login --device-auth`<br>または `OPENAI_API_KEY` |

現在の状態は `./scripts/setup.sh --check` で確認できます。

**GPT 側が未認証のときは、レビューを飛ばして「合格」と判定してはいけません。**
`gpt-review.sh` は終了コード 3 を返し、`reviewer` エージェントはそこで停止するよう指示されています。
別ベンダーによる採点がないレビューは、この手法の要である「自分の宿題を自分で採点しない」を破ってしまうためです。

---

## 期待値について

2026年7月末に公開されたベンチマーク **LoopsBench**（112件の長時間開発タスク）では、
Claude Opus 4.7 + Claude Code の組み合わせでも **完全解決率は 25%**、
実際の GitHub 上の複雑な連続タスクに限れば **3%台** でした。

ループエンジニアリングは「放っておけば完成する魔法」ではありません。

> **失敗するAIを前提に、失敗を検出し、修正させ、再試行させ、それでも駄目なら安全に止める。
> そのための制御の仕組みを作る技術。**

だからこのリポジトリでは、成功パスより先に **停止条件・試行上限・別ベンダー採点・人間の関与ポイント** を用意しています。

---

## 実際のプロジェクトで使い始めるとき

1. `src/`、`tests/`、`docs/issues/0001-greeting-time-of-day.md` のサンプルを削除する
2. `CLAUDE.md` の原則を自分のプロジェクトに合わせて書き換える（削るより足す方が安全です）
3. `scripts/verify.sh` が自分のプロジェクトの lint / test を拾うか確認する（Node と Python は自動判別します）
4. `/new-issue` で最初の課題を起票する
5. `/issue-to-merge` でループを回す
