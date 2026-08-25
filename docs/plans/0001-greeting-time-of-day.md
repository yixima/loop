# 実装計画書: 時間帯に応じた挨拶を返せるようにする

- **課題ID**: `0001-greeting-time-of-day`
- **対応する設計書**: `docs/design/0001-greeting-time-of-day.md`
- **作成**: architect サブエージェント / 2026-08-21
- **更新**: 2026-08-21（人間の決定 Q1=案B / Q2=TypeError(bool拒否) / Q3=キーワード専用 を反映し、計画を最終化）

> このファイルは **AIの外部記憶** です。作業を1つ終えるたびにチェックを更新し、
> 「いま何が終わっていて次に何をするか」が、これを読むだけで分かる状態を保つこと。

## 進行状況

- **現在のステップ**: 11/11 完了（レビュー3周まで実施。人間の決定によりマージへ）
- **verify 実行回数**: 10 回実行 / 修正試行での FAIL 0 回（上限 5 回）
- **最終更新**: 2026-08-25

## タスク分解

各タスクは「テストを書く → 実装する → verify を通す」を1単位とすること。
タスク中の `--quick` は `./scripts/verify.sh --quick`（テストのみ）を指す。最後は必ずフルの verify を回す。
**タスク番号 / 依存 / 並行可否**は下の一覧のとおり。依存が満たされていないタスクに着手しない。

- [x] **1.** テストを追加: T1〜T4（時間帯マッピングと境界値）。新規ファイル `tests/test_greeting_time_of_day.py` を作成し、
      `hour=` を明示注入する形で書く。この時点では `hour` 引数が無いので `TypeError` で落ちることを確認する
      （＝テストが本当に検証していることの証拠）。
      依存: なし（起点） / 並行: **不可**（タスク3・5と同じファイルを触る）
- [x] **2.** T1〜T4 を通す最小実装: `src/loopdemo/greeting.py` に `def greet(name: str, *, hour: int | None = None) -> str` と
      3分岐（5〜10 / 11〜17 / else）を実装。`--quick` で T1〜T4 が緑になること。
      依存: 1 / 並行: 不可
- [x] **3.** テストを追加: T5・T6・T12（範囲外 `ValueError` / 非int・bool は `TypeError` / 位置引数 `greet("山田", 5)` は `TypeError`）。落ちることを確認。
      依存: 2 / 並行: 不可
- [x] **4.** T5・T6・T12 を通す実装: 設計書4.3 の順序（name型 → name空 → **bool → int** → 範囲）でバリデーションを追加。
      `isinstance(hour, bool)` を int 判定より**先に**置くこと（`hour=True` が1時として通らないように）。
      依存: 3 / 並行: 不可
- [x] **5.** テストを追加: T7（`hour` 省略時に現在時刻を使う）。`mock.patch("loopdemo.greeting.datetime")` で 23/3/7/13時を固定。落ちることを確認。
      **テスト内で `datetime.now()` の値を期待値の計算に使わないこと。**
      依存: 4 / 並行: 不可
- [x] **6.** T7 を通す実装: `hour is None` のとき `datetime.now().hour` を使う（`from datetime import datetime` 形式で import し、関数内で呼ぶ）。
      **この時点で既存 `tests/test_greeting.py` が実行時刻によって落ちうる状態になる。必ずタスク7まで続けて実施すること。**
      依存: 5 / 並行: 不可
- [x] **7.** **既存テストの書き換え（許可された2行のみ）** — 人間の決定（Q1=案B）に基づく。`tests/test_greeting.py` を次のとおり変更する。
      - `:14` `greet("山田")` → `greet("山田", hour=12)`（期待値 `"こんにちは、山田さん"` は変えない）
      - `:17` `greet("  山田  ")` → `greet("  山田  ", hour=12)`（期待値は変えない）
      - **この2行以外は触らない。** 残り3件（空文字 `ValueError` / 空白のみ `ValueError` / 非str `TypeError`）、
        import 文、クラス名、テスト名、docstring、空行 — いずれも変更・整形・並べ替えをしない。
      - 完了条件: ベース（merge-base）と比べた `tests/test_greeting.py` の増減行が **計4行**（`-` 2行 / `+` 2行）であること。
        確認コマンド: `git diff -U0 "$(git merge-base HEAD claude/setup-article-method-env-fezjb1)" -- tests/test_greeting.py | grep -c '^[+-][^+-]'` が `4` を返す。→ T11
      - **注意: 素の `git diff -U0 tests/test_greeting.py` を使わないこと。** 素の `git diff` は working tree と index の比較なので、
        変更を `git add` 済み／コミット済みだと **常に `0` を返す**。0 を「差分なし＝合格」と読むと、既存テスト改ざんの検出が無言で死ぬ。
        必ず上記のようにベースのコミットを指定して比較すること（2026-08-21 に `4` が返ることを実測済み）。
      依存: 6 / 並行: 不可（タスク6の直後に必ず実施）
- [x] **8.** テストを追加: T8・T9・T10（検証順序 / `name` 例外仕様の不変 / シグネチャ互換 `greet("山田")` が例外なく動く）。
      T10 は時計をパッチせず、戻り値が3種の挨拶文のいずれかに一致することを確認する（どの時刻でも決定的に緑になる書き方）。
      依存: 7 / 並行: 不可
- [x] **9.** 仕上げ（テストは緑のまま）: docstring の更新（Args に `hour`、Raises に `TypeError`/`ValueError` を追記）、
      `ruff check .` と `ruff format .` を通す。行長 100 以内。`src/loopdemo/__init__.py` は変更しない。
      依存: 8 / 並行: 不可
- [x] **10.** `./scripts/verify.sh` が全件 PASS（終了コード 0）することを確認し、あわせて T11 の差分チェックを実行。
      期待される内訳: `py:lint` PASS / `py:format` PASS / `py:test` PASS / `docs:plans` PASS（mypy 未導入環境では `py:typecheck` は SKIP）。
      このファイルの「進行状況」「verify 実行回数」「作業ログ」を更新する。
      依存: 9 / 並行: 不可
- [x] **11.** `ISSUE_ID=0001-greeting-time-of-day ./scripts/gpt-review.sh` によるレビューと指摘の反映。3周実施（詳細は作業ログ）。
      指摘を反映したらタスク10（検証）からやり直す。往復は最大3周。
      依存: 10 / 並行: 不可

## 並行実行できるタスク

> 依存関係のないタスクは複数のサブエージェントで手分けできる。

- **並行実行できるタスクは無い。全タスクを 1 → 11 の順で直列に実行する。**
  - 理由1: 触るファイルが `src/loopdemo/greeting.py` と `tests/test_greeting_time_of_day.py` の実質2つしかなく、
    テスト追加タスク（1・3・5・8）はすべて同じテストファイルへの追記になるため、同時に走らせると編集が衝突する。
  - 理由2: 各テスト追加タスクは「直前の実装が入った状態で落ちること」を確認する手順を含むため、実装タスクと交互に並ぶ必要がある。
  - テストファイルを4つに分割すれば形式上は並行化できるが、ファイルが増える不利益の方が大きいので採らない。
- 特に守る順序: **6 → 7**（6 単独で止めると既存テストが実行時刻に依存する不安定な状態で放置される）、**9 → 10 → 11**

## 停止条件（機械が判定できる形）

- **成功で停止**: 次のすべてを満たしたとき。
  1. `./scripts/verify.sh` が終了コード 0
  2. `git diff -U0 "$(git merge-base HEAD claude/setup-article-method-env-fezjb1)" -- tests/test_greeting.py | grep -c '^[+-][^+-]'` が `4`（許可範囲を超えた既存テストの変更がない）
     — 素の `git diff -U0 tests/test_greeting.py` は不可。ステージ済み／コミット後は常に `0` を返し、チェックとして機能しない。
  3. T1〜T12 に対応するテストがすべて存在し pass
  4. `git diff --exit-code src/loopdemo/__init__.py` が 0（公開APIを増やしていない）
  5. gpt-review の blocker が 0 件
- **失敗で停止**: 同じ失敗に対する修正を **5回** 試しても verify が通らない → それ以上試さず、試したこと・分かったこと・仮説を報告。
- **質問で停止**: 設計書に無い判断が必要になった → 実装せず報告。
- テストのスキップ・削除・アサーション緩和で緑にすることは禁止（CLAUDE.md 原則9）。
  既存テストの変更は、タスク7で明示的に許可された2行の書き換えのみ。

## 作業ログ

| 日時 | やったこと | verify の結果 | 次にやること |
|---|---|---|---|
| 2026-08-21 16:00 | architect が要件定義書・設計書・実装計画書を作成。既存コード/テスト/verify.sh を調査し、「hour 省略時に現在時刻」と「既存テスト無変更」の矛盾（Q1）を検出して停止 | 未実行（実装前） | 人間の回答待ち |
| 2026-08-21 16:00 | 人間の決定（Q1=案B / Q2=TypeError・bool拒否 / Q3=キーワード専用）を3文書に反映。未確定事項0件、計画を最終化 | 未実行（実装前） | タスク1（T1〜T4 のテスト追加）から着手 |
| 2026-08-21 17:10 | タスク1: tests/test_greeting_time_of_day.py を新規作成し T1〜T4 を追加。実装前に落ちることを確認 | --quick FAIL（想定どおり: greet() got an unexpected keyword argument 'hour'） | タスク2（T1〜T4 を通す最小実装） |
| 2026-08-21 17:15 | タスク2: greet に キーワード専用 hour を追加し 5〜10/11〜17/else の3分岐を実装（hour 省略時はタスク6まで従来どおり「こんにちは」） | --quick PASS（T1〜T4 と既存5件が緑） | タスク3（T5・T6・T12 のテスト追加） |
| 2026-08-21 17:20 | タスク3: T5（範囲外 ValueError）・T6（非int/bool は TypeError）・T12（位置引数は TypeError）を追加。T5 と T6(5.0/True/False) が実装前に落ちることを確認（T12 はタスク2 のキーワード専用宣言により既に緑） | --quick FAIL（想定どおり 6 subtest が赤） | タスク4（バリデーションの実装） |
| 2026-08-21 17:25 | タスク4: 設計書4.3 の順序（name型 → name空 → bool → int → 範囲）で hour のバリデーションを追加 | --quick PASS（T1〜T6・T12 と既存5件が緑） | タスク5（T7 のテスト追加） |
| 2026-08-21 17:30 | タスク5: T7（hour 省略時は現在時刻）を mock.patch("loopdemo.greeting.datetime") で追加。実装前に AttributeError（greeting に datetime 属性なし）で落ちることを確認 | --quick FAIL（想定どおり 4 subtest が赤） | タスク6（hour 省略時に datetime.now().hour を使う実装） |
| 2026-08-21 17:35 | タスク6: from datetime import datetime を追加し、hour is None のとき関数内で datetime.now().hour を使うよう実装（バリデーションは else 側へ） | --quick PASS（T7 が緑。実行時の時刻が17時だったため既存2件はたまたま緑だが、時刻依存の不安定な状態なのでタスク7を即実施） | タスク7（既存テストの許可2行の書き換え） |
| 2026-08-21 17:40 | タスク7: tests/test_greeting.py の :14 と :17 のみ hour=12 を明示注入する形に書き換え。ベース比較の増減行は 4 行（実測。当時は未ステージだったので素の git diff でも 4 だったが、ステージ／コミット後は 0 になるため、以後は必ず merge-base を指定して比較すること） | --quick PASS（既存5件と新規T1〜T7・T12 が緑） | タスク8（T8・T9・T10 のテスト追加） |
| 2026-08-21 17:45 | タスク8: T8（検証順序）・T9（name の例外仕様不変）・T10（シグネチャ互換、時計をパッチせず3種のいずれかに一致）を追加。既存の振る舞いを固定するテストなので追加時点から緑。実効性の証拠として、リポジトリ外のコピーに「hour 検証を name より先にする」変異を入れ、T8 が落ちること（ValueError: hour は 0〜23…）を確認した | --quick PASS（16 tests / 45 subtests） | タスク9（docstring 更新と ruff） |
| 2026-08-21 17:50 | タスク9: docstring を更新（Args に hour、Returns に時間帯、Raises に TypeError/ValueError）。ruff check / ruff format --diff が指摘0件、100文字超の行なし。src/loopdemo/__init__.py は無変更 | ruff check PASS / ruff format --diff 差分なし | タスク10（フルの verify.sh と停止条件の確認） |
| 2026-08-21 17:55 | タスク10: フルの ./scripts/verify.sh を実行し終了コード 0 を確認（py:lint PASS / py:format PASS / py:typecheck SKIP / py:test PASS 16 tests・45 subtests / docs:plans PASS）。停止条件も確認: 既存テストの差分 4 行、src/loopdemo/__init__.py 無変更 | フル verify PASS（exit 0） | タスク11（reviewer による別ベンダーモデルのレビュー。実装担当は着手しない） |
| 2026-08-21 17:50 | タスク11 レビュー1周目: GPT(codex-default) blocker 0 / major 0 / minor 0 / nit 1（greeting.py:28 のテスト都合コメント）。総評「合格」 | 合格 | reviewer による裏取り |
| 2026-08-21 17:57 | reviewer(Claude) が裏取り。変異テスト13種すべて検知、TZ 13通りで全緑、subtest 数45が内訳と一致。GPT が見落としていた minor 2件（F11 の確認コマンドが壊れている／unittest フォールバックの別課題化漏れ）を追加検出 | 合格（blocker 0） | minor 2件と nit 1件を修正 |
| 2026-08-21 18:01 | nit 修正（greeting.py:28 のコメントを業務上の理由に書き換え）、minor 修正（F11 の確認コマンドを merge-base 形に統一）、課題0002 を起票。レビュー2周目: blocker 0 / major 1（設計書8章のロールバック手順が確認・承認なしに破壊的操作を実行させる）。総評「合格」 | 合格 | major 1件を修正 |
| 2026-08-21 18:05 | 設計書8章を「確認→退避→承認→実行→検証」の5手順に修正。設計書に残っていた壊れた git diff も修正。レビュー3周目: blocker 2件（verify.sh に F11 が組み込まれていない／F11 が行数しか見ていない）。総評「不合格」 | 不合格・往復上限3周に到達 | 人間に判断を委ねて停止 |
| 2026-08-25 | 人間の決定: blocker は 0001 のスコープ外（verify.sh の変更が必要）のため `docs/issues/0003-verify-detect-test-tampering.md`（優先度 high）として切り出し、0001 は現状でマージ。本番反映は不要（src/loopdemo は使い捨てのサンプルで外部に呼び出し元なし）。課題0002 は優先度 medium・修正方針（`-t .` を外す）を確定 | 決定 | コミット・push |


## 詰まっている点 / 人間への確認事項

- なし（Q1〜Q3 は 2026-08-21 に人間が決定済み。記録は要件定義書6章）。
- ただし本番反映（デプロイ）は人間の判断（CLAUDE.md 原則18）。`greet("山田")` の戻り値が時間帯で変わるため、
  このリポジトリ外の呼び出し側が固定文言を前提にしていないかは、反映前に人間が確認すること。
- 実装スコープ外の観察（本課題では直さない）: `scripts/verify.sh:105` の unittest フォールバック
  （`python -m unittest discover -s tests -t .`）は Python 3.13 では `tests/` に `__init__.py` が無いため
  `ImportError: Start directory is not importable` で失敗する。**変更前の HEAD でも同じ**なので本課題の変更が
  原因ではなく、この環境では pytest があるため verify.sh は pytest 経路を通り PASS している。
  新規テストは pytest 固有機能を使っておらず、`python -m unittest test_greeting test_greeting_time_of_day` で
  16 件 OK であることを確認済み。恒久対応が要るなら別課題として起票すること（CLAUDE.md 原則5）。
