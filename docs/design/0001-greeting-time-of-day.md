# 設計書: 時間帯に応じた挨拶を返せるようにする

- **課題ID**: `0001-greeting-time-of-day`
- **対応する要件定義書**: `docs/requirements/0001-greeting-time-of-day.md`
- **作成**: architect サブエージェント / 2026-08-21
- **更新**: 2026-08-21（人間の決定 Q1=案B / Q2=TypeError(bool拒否) / Q3=キーワード専用 を反映）
- **更新**: 2026-08-21（GPT レビュー指摘を反映: 8.1 ロールバック手順を「確認→退避→承認→実行→検証」に書き換え。6章 T11・8章リスク1 の差分確認コマンドを merge-base 比較へ修正）
- **状態**: approved（未確定事項なし。実装フェーズへ進んでよい）

## 1. 方針（3行で）

- `greet()` に **キーワード専用引数 `hour: int | None = None`** を1つ足すだけにとどめ、公開APIも関数の数も増やさない。
- 挨拶語は `5〜10 / 11〜17 / それ以外` の3分岐（`if/elif/else`）で決める。日またぎ（18〜4）は「それ以外」に自然に落ちるので特別扱いしない。
- テストの時刻は **原則すべて `hour=` 引数で明示注入**（既存2件も `hour=12` に書き換える／人間の決定・案B）。
  引数で注入できない「`hour` 省略時の経路」だけ、`unittest.mock.patch("loopdemo.greeting.datetime")` で時計を固定する。

## 2. 調査した既存の仕組み

> **推測で書かない。** 実際に読んだファイルとその要点を挙げる。

| 調べた対象 | 分かったこと |
|---|---|
| `src/loopdemo/greeting.py:4` | 現在のシグネチャは `def greet(name: str) -> str:`。引数は1つのみ。 |
| `src/loopdemo/greeting.py:5-15` | Google スタイルの日本語 docstring（Args / Returns / Raises）。この形式を踏襲する。 |
| `src/loopdemo/greeting.py:16-17` | 非str は `TypeError(f"name は str である必要があります: {type(name).__name__}")`。型チェックが**最初**に来る。 |
| `src/loopdemo/greeting.py:18-20` | `name.strip()` した結果が空なら `ValueError("name が空です")`。 |
| `src/loopdemo/greeting.py:21` | 戻り値は `f"こんにちは、{stripped}さん"`。読点は全角「、」、敬称は「さん」。 |
| `src/loopdemo/__init__.py:8-10` | 公開APIは `greet` のみ（`__all__ = ["greet"]`）。ここは増やさない。 |
| `tests/test_greeting.py:14,17` | `greet("山田")` / `greet("  山田  ")` が `"こんにちは、山田さん"` を期待。**案Bで書き換える対象の2行**。 |
| `tests/test_greeting.py:19-29` | 空文字・空白のみ・非str の3件。**無変更で通り続ける対象**。 |
| `tests/test_greeting.py:1-9` | `unittest.TestCase` ベース、テスト名は日本語、`from loopdemo import greet` でパッケージ経由の import。新テストもこれに合わせる。 |
| `grep -rn "greet"`（リポジトリ全体） | `greet()` の呼び出し元は `tests/test_greeting.py` のみ。src 内に他の呼び出し元はない。 |
| `pyproject.toml:5` | `requires-python = ">=3.10"` → `int \| None` 記法が使える（`typing.Optional` は ruff `UP` に抵触）。 |
| `pyproject.toml:7-9` | pytest は `pythonpath=["src"]`, `testpaths=["tests"]`。`tests/` 直下に追加したファイルは自動で収集される。 |
| `pyproject.toml:11-16` | ruff: `line-length = 100`、`select = ["E","F","I","UP","B"]`（import順 `I` も対象）。 |
| `pyproject.toml:18-21` | mypy 設定はあるが、この環境に mypy は未インストール。`verify.sh` では SKIP になる。 |
| `scripts/verify.sh:92-100` | ruff があれば `ruff check .` と `ruff format --check .` の両方を実行。**format 崩れも FAIL になる**。 |
| `scripts/verify.sh:102-106` | pytest があれば `pytest -q`、無ければ `python -m unittest discover -s tests -t .`。**pytest 固有機能（conftest.py・fixture）に依存したテストは後者で効かない**。 |
| `scripts/verify.sh:110-119` | `docs/plans/*.md` に「最終更新」の記載がないと `docs:plans` が FAIL。実装計画書の更新は verify の合否に直結する。 |
| 実機での挙動確認（スクラッチパッド、リポジトリ外） | `mock.patch("<module>.datetime")` + `mock.now.return_value = datetime(...)` で `.hour` を固定できることを実行して確認した（T7 で使う）。 |

## 3. 変更するファイル

| ファイル | 新規/変更 | 内容 |
|---|---|---|
| `src/loopdemo/greeting.py` | 変更 | `from datetime import datetime` を追加。`greet` にキーワード専用引数 `hour` を追加し、時間帯分岐とバリデーションを実装。docstring を更新。 |
| `tests/test_greeting_time_of_day.py` | 新規 | 本課題のテスト T1〜T10, T12。 |
| `tests/test_greeting.py` | 変更（**許可された2行のみ**） | `:14` → `greet("山田", hour=12)`、`:17` → `greet("  山田  ", hour=12)`。**他の3件・import・クラス名・docstring には一切触れない**（→ T11）。 |
| `docs/plans/0001-greeting-time-of-day.md` | 変更 | 進捗・verify 実行回数・作業ログの更新（実装者が随時）。 |
| `src/loopdemo/__init__.py` | **変更しない** | 公開APIは増やさない。 |
| `tests/conftest.py` | **作らない** | 案C不採用（7章参照）。 |

## 4. インターフェース設計

### 4.1 シグネチャ（論点1・Q3の決着）

```python
def greet(name: str, *, hour: int | None = None) -> str: ...
```

- `hour` は **キーワード専用**（`*` の後ろ）。人間の決定（Q3）により確定。`greet("山田", 5)` は `TypeError`（Python が送出）→ F12 / T12。
  狭い契約から始める判断であり、後から位置引数を許すことはできるが、逆はできない。
- デフォルトは `None`。「未指定」を表すためのセンチネルであり、`None` は「現在時刻を使う」の意味を持つ。
  `0` は有効な時刻なので `hour=0` と未指定を区別する必要があり、`hour: int = -1` のような番兵は使わない。
- `greet("山田")` は引数の数・順序が変わらないため、既存の呼び出し側は無変更で呼べる（シグネチャ互換 → F10 / T10）。

### 4.2 時間帯マッピング（論点2の決着）

| `hour` の範囲 | 挨拶語 | 境界の扱い |
|---|---|---|
| 5, 6, 7, 8, 9, 10 | おはようございます | 4 は含まない / 5 から含む |
| 11, 12, ..., 17 | こんにちは | 10 は含まない / 11 から含む、17 まで含む |
| 18, 19, ..., 23, 0, 1, 2, 3, 4 | こんばんは | 17 は含まない / 18 から含む、日をまたいで 4 まで |

日またぎは `18 <= hour or hour <= 4` のような明示条件を書かず、**先の2条件に当たらない残り全部**として扱う。
`hour` は事前に 0〜23 に制限済みなので、これで過不足なく一致する（条件式が1つ減り、取りこぼしの余地がなくなる）。

### 4.3 バリデーションの順序（論点4・Q2の決着）

1. `name` の型（非str → `TypeError`）… **既存のまま、最初**
2. `name` の空判定（空/空白のみ → `ValueError`）… **既存のまま**
3. `hour is None` なら現在時刻から解決（この経路は 0〜23 が保証されるので検証不要）
4. `hour` が指定されている場合: **bool 判定 → int 判定（`TypeError`）→ 範囲判定 0〜23（`ValueError`）**
5. 時間帯マッピング → 文字列生成

**`name` の検証を先に置く理由**: 既存の例外仕様を1ミリも動かさないため。
`greet(None, hour=99)` は「非str の `TypeError`」であって「hour の `ValueError`」ではない（→ T8）。
型を範囲より先に見るのは、既存 `name` の並び（型 → 内容）と揃えるため。
**bool を int より先に弾く理由**: `bool` は `int` のサブクラスであり、`isinstance(True, int)` は `True`。
先に弾かないと `hour=True` が黙って1時として通る（人間の決定 Q2 により `TypeError`）。

### 4.4 実装スケッチ（実装者向け。この通りに書く必要はないが、振る舞いはこの通りであること）

```python
"""挨拶文を組み立てるサンプル実装。"""

from datetime import datetime


def greet(name: str, *, hour: int | None = None) -> str:
    """名前と時間帯を受け取って挨拶文を返す。

    Args:
        name: 挨拶する相手の名前。前後の空白は取り除かれる。
        hour: 挨拶に使う時刻（0〜23）。省略した場合はローカルの現在時刻を使う。

    Returns:
        "<時間帯の挨拶>、<name>さん" 形式の文字列。
        5〜10 は "おはようございます"、11〜17 は "こんにちは"、18〜4 は "こんばんは"。

    Raises:
        TypeError: name が str でない場合、または hour が int でない場合。
        ValueError: name が空、または空白のみの場合。hour が 0〜23 の範囲外の場合。
    """
    if not isinstance(name, str):
        raise TypeError(f"name は str である必要があります: {type(name).__name__}")
    stripped = name.strip()
    if not stripped:
        raise ValueError("name が空です")

    if hour is None:
        hour = datetime.now().hour
    else:
        # bool は int のサブクラスなので、先に弾かないと True が 1 時として通ってしまう
        if isinstance(hour, bool) or not isinstance(hour, int):
            raise TypeError(f"hour は int である必要があります: {type(hour).__name__}")
        if not 0 <= hour <= 23:
            raise ValueError(f"hour は 0〜23 である必要があります: {hour}")

    if 5 <= hour <= 10:
        phrase = "おはようございます"
    elif 11 <= hour <= 17:
        phrase = "こんにちは"
    else:
        phrase = "こんばんは"
    return f"{phrase}、{stripped}さん"
```

### 4.5 時刻の注入方式（論点3・Q1=案Bの決着）

**二段構えにする。原則は引数注入、例外的に時計のパッチ。**

**(1) 既定の方式 — `hour=` による引数注入（テストの大半・既存2件を含む）**

時刻に依存する検証はすべて `hour` を明示的に渡して行う。既存テストも同じ方式に揃える（人間の決定・案B）。

```python
# tests/test_greeting.py（許可された2行の書き換え後）
self.assertEqual(greet("山田", hour=12), "こんにちは、山田さん")
self.assertEqual(greet("  山田  ", hour=12), "こんにちは、山田さん")
```

- `hour=12` を選ぶ理由: 「こんにちは」帯（11〜17）の中央で、境界値ではないため、境界仕様を将来変えても
  この2件が巻き添えで落ちない。既存の期待値 `"こんにちは、山田さん"` を変えずに済む。
- 利点: pytest / unittest のどちらのランナーでも決定的。モックが一切不要で、テストが読んだままの意味になる。

**(2) `hour` を省略した経路だけ — `unittest.mock.patch` で時計を固定（T7 専用）**

省略時の経路は引数で注入できないため、ここだけモジュール属性の `datetime` を差し替える。

```python
from datetime import datetime as real_datetime
from unittest import mock

with mock.patch("loopdemo.greeting.datetime") as clock:
    clock.now.return_value = real_datetime(2026, 8, 21, 23, 30)
    self.assertEqual(greet("山田"), "こんばんは、山田さん")
```

この方式を選ぶ理由:

1. **スコープを守れる**。課題のスコープ外に「`greet()` 以外の関数の追加・変更」がある。
   `_current_hour()` のような時計関数を新設すると関数が1つ増える。この方式なら増えない。
2. **プロダクションコードにテスト専用の穴を作らない**（CLAUDE.md 原則3）。
   時計を差し替えるための引数（`now=` / `clock=`）を公開シグネチャに足さずに済む。
3. **決定的**で、追加依存（freezegun 等）も不要。`unittest.mock` は標準ライブラリなので unittest ランナーでも動く。
4. 実機で `.hour` を固定できることを確認済み。

前提条件（実装者はここを守ること）: `greeting.py` は `from datetime import datetime` の形で import し、
`greet` の**中で** `datetime.now()` を呼ぶこと。モジュール読み込み時に時刻を確定させたり、
`import datetime` 形式にしたりすると、上のパッチ対象名が変わって T7 が壊れる。

**(3) やってはいけないこと**

- テストの中で `datetime.now()` を呼び、その値を期待値の計算に使う（実行時刻に依存し、時報をまたぐと落ちる）。
- `tests/conftest.py` などでテスト全体の時計を暗黙に固定する（案C。7章の理由により不採用）。

## 5. エラー処理と異常系

| 起きうる異常 | 検知方法 | 振る舞い |
|---|---|---|
| `name` が str でない（既存） | `isinstance(name, str)` | `TypeError("name は str である必要があります: <型名>")`。メッセージも既存のまま。 |
| `name` が空 / 空白のみ（既存） | `name.strip()` が偽 | `ValueError("name が空です")`。既存のまま。 |
| `hour` が bool（`True` / `False`） | `isinstance(hour, bool)` を int 判定より**先に** | `TypeError`。bool は int のサブクラスなので明示的に弾かないと `True` が 1 時として通る（決定 Q2）。 |
| `hour` が int でない（`"5"`, `5.0` など） | `isinstance(hour, int)` | `TypeError("hour は int である必要があります: <型名>")`（決定 Q2） |
| `hour` が範囲外（-1, 24, 100 など） | `0 <= hour <= 23` | `ValueError("hour は 0〜23 である必要があります: <値>")` |
| `hour` を位置引数で渡す（`greet("山田", 5)`） | キーワード専用宣言により Python が検出 | `TypeError`（メッセージは Python 標準のもの。決定 Q3） |
| `name` と `hour` が同時に不正 | 4.3 の検証順序 | `name` 側の例外が優先される（既存挙動の保存）。 |
| 実行環境の時計が異常（未設定など） | 検知しない | スコープ外。`datetime.now()` の結果をそのまま使う（タイムゾーンもローカルのまま）。 |

## 6. テスト設計

- 新規ファイル `tests/test_greeting_time_of_day.py`（`unittest.TestCase`、テスト名は日本語、既存スタイル踏襲）に T1〜T10・T12 を置く。
- T11 は既存ファイル `tests/test_greeting.py` 側の回帰。**新規に書き直さず、許可された2行だけを書き換える**。
- 複数の `hour` をまとめて検証するものは `with self.subTest(hour=h):` を使い、どの値で落ちたか分かるようにする。
- T7 以外は時計をパッチしない（`hour=` で注入する）。

| # | テスト名（案） | 種別 | 検証する受け入れ条件 |
|---|---|---|---|
| T1 | `test_朝5時から10時はおはようございます` — h=5..10 の6件を subTest で総当たり | unit | F1 |
| T2 | `test_11時から17時はこんにちは` — h=11..17 の7件を subTest で総当たり | unit | F2 |
| T3 | `test_18時から翌4時はこんばんは` — h=18..23 と h=0..4 の11件を subTest で総当たり | unit | F3 |
| T4 | `test_時間帯の境界値` — (4,こんばんは),(5,おはようございます),(10,おはようございます),(11,こんにちは),(17,こんにちは),(18,こんばんは) を明示的に検証 | unit | F4 |
| T5 | `test_hourが範囲外ならValueError` — -1, 24, 100 で `assertRaises(ValueError)` | unit | F5 |
| T6 | `test_hourがint以外ならTypeError` — `"5"`, `5.0`, `True`, `False` で `assertRaises(TypeError)` | unit | F6 |
| T7 | `test_hour省略時は現在時刻を使う` — `mock.patch("loopdemo.greeting.datetime")` で 23時/3時/7時/13時を固定し、こんばんは/こんばんは/おはようございます/こんにちは を検証。**実時刻を参照しない** | unit | F7 |
| T8 | `test_nameの検証がhourより先` — `greet(None, hour=99)` → `TypeError`、`greet("", hour=5)` → `ValueError` | unit | F8 |
| T9 | `test_nameの例外仕様は変わらない` — `greet("")` / `greet("   ")` → `ValueError`、`greet(None)` → `TypeError`、および `hour=12` を付けた同3ケースも同じ例外 | unit | F9 |
| T10 | `test_hourなしでも呼べる_シグネチャ互換` — `greet("山田")` と `greet("  山田  ")` が例外を出さず、`{"おはようございます、山田さん","こんにちは、山田さん","こんばんは、山田さん"}` のいずれかに一致する（時計をパッチせずに実行しても、どの時刻でも成立する） | unit | F10 |
| T11 | 既存 `tests/test_greeting.py` の5件（2件は `hour=12` へ書き換え済み、3件は無変更）が pass。加えて**ベース（merge-base）と比べた**増減行が計4行であること（許可範囲を超えた変更の検出）。確認コマンドは表の直後の注記を参照 | regression | F11 |
| T12 | `test_hourは位置引数では渡せない` — `greet("山田", 5)` で `assertRaises(TypeError)` | unit | F12 |

> **T11 の確認コマンド**（表の中はパイプ `|` がセル区切りと衝突するため、ここに置く。要件定義書 F11 の注記と同じもの）
>
> ```bash
> git diff -U0 "$(git merge-base HEAD claude/setup-article-method-env-fezjb1)" -- tests/test_greeting.py | grep -c '^[+-][^+-]'
> # => 4
> ```
>
> **素の `git diff -U0 tests/test_greeting.py` を使わないこと。** 素の `git diff` は working tree と index を比べるため、
> 変更を `git add` 済み／コミット済みだと常に `0` を返す。`0` を「差分なし＝合格」と誤読すると、既存テスト改ざんの検出が無言で死ぬ。
> 必ずベースのコミットを指定して比較すること（2026-08-21 に、ベース指定で `4`・素の `git diff` で `0` が返ることを実測済み）。

> テストは実装より先に書く（Step4: テストがそのまま停止条件になる）。

## 7. 検討したが採用しなかった案

| 案 | 不採用の理由 |
|---|---|
| **案C: `tests/conftest.py` の autouse フィクスチャでテスト中の時計を 12:00 に固定する**（既存テストを1行も変えずに済む案） | **人間の決定により不採用**。conftest.py と fixture は pytest 固有の仕組みで、`scripts/verify.sh:102-106` は pytest が無い環境では `python -m unittest discover` にフォールバックする。その環境では時計が固定されず、既存テストが再び実行時刻に依存して 18時以降に赤くなる。「唯一の停止条件」である verify.sh が環境依存で揺れるのは許容できない。加えて、テストの時刻依存を暗黙のフィクスチャに隠すため、テストを読んだだけでは前提が分からなくなる。 |
| **案D: `hour` 省略時は現在時刻を使わず「こんにちは」固定のままにする** | 後方互換は完全だが、課題の目的（深夜通知で時間帯が分かること）を満たさない。人間の決定により不採用。 |
| 既存テスト5件を1件も変更しないまま「省略時は現在時刻」を実装する | テストの成否が実行時刻に左右され、実装が正しくても verify が赤くなる。案B採用により、この受け入れ条件自体を取り下げた（要件定義書6章に記録）。 |
| `hour` を位置引数にする（`def greet(name, hour=None)`） | 受け入れ条件は `hour=` のキーワード呼び出しだけを要求している。位置で受け付けると第2引数の意味を将来にわたって縛る。狭い契約から始める（決定 Q3）。 |
| `hour: int = -1` などの番兵値で未指定を表す | `0` が有効値なので、未指定との区別に `None` 以外を使う理由がない。型注釈も嘘になる。 |
| `_current_hour()` という私的な時計関数を新設し、テストでそれを patch する | テスト容易性は同等だが、課題のスコープ外「`greet()` 以外の関数の追加」に触れる。`datetime` 属性の差し替えで同じことができるため、関数を増やす利得がない。 |
| 時計を引数で注入する（`greet(name, *, hour=None, now=datetime.now)`） | テストのためだけに公開APIを1つ増やすことになる。CLAUDE.md 原則1（先回りして作らない）・原則3に反する。 |
| freezegun 等のライブラリで時刻を固定する | 追加依存が増える。標準ライブラリの `unittest.mock` で足りる。 |
| 挨拶語を dict や定数テーブル（24要素）で持つ | 連続する範囲の3分岐に対して過剰。`if/elif/else` の方が境界が読みやすく、最小の実装という原則に沿う。 |
| 日またぎを `if hour >= 18 or hour <= 4:` と明示的に書く | 範囲検証済みなら `else` と等価で、条件が1つ増えるだけ取りこぼしのリスクが上がる。ただし可読性を理由に明示する実装も許容する（振る舞いが同じであること）。 |
| 新テストを既存 `tests/test_greeting.py` に追記する | 既存ファイルの差分を「許可された2行だけ」に保てなくなり、T11 の機械的チェック（増減4行）が成立しなくなる。新規ファイルに分ける。 |
| `hour` の bool を許容する（`isinstance(hour, int)` だけで判定） | `greet("山田", hour=True)` が 1時として静かに通り、発見しづらいバグになる。人間の決定 Q2 により明示的に弾く。 |

## 8. リスクと後戻り手段

- **リスク1**: 既存テストの書き換えが許可範囲（`:14` と `:17` の2行）を超えて広がること。テストを都合よく緩める行為に滑りやすい。
  → 対策: T11 で**ベース（merge-base）と比べた** `tests/test_greeting.py` の増減行が計4行であることを確認する
    （コマンドは6章の表直後の「T11 の確認コマンド」注記）。残り3件は絶対に触らない。
    **素の `git diff -U0 tests/test_greeting.py` は使わないこと。** working tree と index の比較なので、
    `git add` 済み／コミット後は常に `0` を返す。`0` を「差分なし＝合格」と読むとこのリスクの検出が無言で死ぬ。
- **リスク2**: 4.5(2) の前提（`from datetime import datetime` + 関数内で `now()` を呼ぶ）が崩れると T7 だけが謎の失敗をする。
  → 対策: 実装スケッチのコメントとして残し、T7 が落ちたらまず import 形式を疑う。
- **リスク3**: `ruff format --check` は整形崩れも FAIL にする（`scripts/verify.sh:94`）。
  → 対策: 実装計画書のタスク9で `ruff format` を通してから verify を回す。
- **リスク4**: `greet("山田")` の戻り値が時間帯で変わるため、このリポジトリ**外**の呼び出し側が固定文言を前提にしていると影響が出る。
  → 対策: リポジトリ内に呼び出し元がないことは確認済み（`grep -rn "greet"`）。外部への影響は本課題のスコープ外であり、
    人間が本番反映を判断する際の確認事項として報告する（CLAUDE.md 原則18）。

### 8.1 ロールバック方法

変更は `src/loopdemo/greeting.py`、`tests/test_greeting.py` の2行、新規 `tests/test_greeting_time_of_day.py` の3ファイルに閉じている。
DB・設定・外部サービスへの影響はない。

ただし **戻す操作そのものが破壊的**である。`git checkout --` と `rm -f` は確認を出さずに消すため、
対象ファイルに本課題**以外**の未コミット変更が乗っていると、その変更まで復元不能に失われる。
したがって「確認 → 退避 → 人間の承認 → 実行 → 検証」の順序を守る（CLAUDE.md 原則6・原則20）。

**手順1: 確認する（読むだけ。無条件に実行してよい）**

何が消えるのかを、消す前に実際に読む。

```bash
git status --short                                                   # 3ファイルに他の変更が乗っていないか
git diff -- src/loopdemo/greeting.py tests/test_greeting.py          # 破棄されようとしている中身を読む
git status --short -- tests/test_greeting_time_of_day.py             # 未追跡か、追跡済み（＝他の変更を含みうる）か
```

本課題外の変更が1行でも混ざっていたら、**手順2以降へ進まず、その内容を人間に報告して止まる**。

**手順2: 退避する（破棄より先に、戻せる状態を作る）**

| 状況 | 採る手段 | 理由 |
|---|---|---|
| 未コミットのまま戻したい | `git stash push -u -m "rollback-0001" -- src/loopdemo/greeting.py tests/test_greeting.py tests/test_greeting_time_of_day.py` | 破棄ではなく**退避**。判断を誤っても `git stash pop` で復旧できる。**第一候補はこれ。** |
| すでにコミット済み | `git revert <対象コミット>` | 履歴を書き換えずに打ち消す。復旧可能。 |
| — | `git reset --hard` / `git push --force` は**使わない** | CLAUDE.md 原則6で人間の承認なしの実行を禁止している操作。承認を得た場合でも、上の2手段で足りるなら選ばない。 |

**手順3: 人間の承認を得る（ここが停止点）**

手順1で読み取った「消える差分の一覧」と、手順2で選んだ手段を人間に提示し、**明示的な承認を得る**。
承認がない状態で `git checkout --` / `rm -f` / `git reset --hard` / `git push --force` を実行しない。
判断に迷ったら実行せずに止まる（原則20）。

**手順4: 実行する（承認後のみ）**

承認された手段だけを、対象ファイルを明示して実行する。ワイルドカードや `-rf` は使わない。
新規ファイル `tests/test_greeting_time_of_day.py` の削除は最後に回し、削除の直前にもう一度 `git status --short` で
「未追跡であり、本課題で作ったものである」ことを確かめる。

**手順5: 検証する**

`./scripts/verify.sh` が終了コード 0 で終わること、および手順1で確認した**本課題外の変更が残っていること**を確認する。

> 上に並べたコマンドは**手順の説明であって、上から順にコピペで流してよい手順書ではない**。
> 手順1〜3 を飛ばして手順4 のコマンドだけを実行すると、本課題外の未コミット変更が復元不能に失われる。
