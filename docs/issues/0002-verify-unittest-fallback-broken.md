# 課題: verify.sh の unittest フォールバックが動かない

- **ID**: `0002-verify-unittest-fallback-broken`
- **起票日**: 2026-08-21
- **優先度**: medium
- **状態**: open

> 課題 `0001-greeting-time-of-day` の実装中に implementer が発見し、reviewer が裏取りした欠陥です。
> CLAUDE.md 原則5（1つの課題では1つのことだけをやる）に従い、0001 では修正せず切り出しました。
> **優先度 medium・修正方針は人間が決定済み（2026-08-25）。下記「原因と修正方針」のとおり着手してください。**

## 背景（なぜやるのか）

`scripts/verify.sh` は pytest が無い環境でもテストを実行できるよう、
`python -m unittest discover -s tests -t .` にフォールバックする作りになっている（`scripts/verify.sh:102-106`）。

しかしこの経路は**現在まったく動かない**。`tests/` に `__init__.py` が無いため、
Python 3.13 では次のエラーで即座に失敗する:

```
ImportError: Start directory is not importable: '/Users/yoshitakaikushima/loop/tests'
```

この欠陥は 0001 の変更が原因ではない。`git archive HEAD` で取り出した無変更のツリーでも同一に再現する
（0001 の implementer が確認済み）。この環境には pytest があるため verify.sh は pytest 経路を通り PASS しており、
**壊れていることが誰にも気づかれない状態**になっていた。

困るのは、pytest が未導入の環境で `./scripts/verify.sh` を回したときに、
テストの中身とは無関係に必ず FAIL することである。verify.sh はこのリポジトリの唯一の停止条件なので、
停止条件そのものが環境依存で壊れることになる。

## ゴール（何が達成されたら終わりか）

pytest が入っていない環境でも `./scripts/verify.sh` がテストを正しく実行し、
テストが全件通るなら終了コード0で完了する状態。

## 受け入れ条件（機械が判定できる形で）

- [ ] pytest を一時的に無効化した状態（例: `PATH` から外す、あるいは import できない状態にする）で
      `./scripts/verify.sh` が終了コード 0 で完了する
- [ ] そのとき `py:test` の実行ログに、実際に実行されたテスト件数が表示される（0件で緑にならないこと）
- [ ] pytest がある通常の環境でも `./scripts/verify.sh` が従来どおり終了コード 0 で完了する
- [ ] 上記2つの環境で、実行されるテストの件数が一致する
- [ ] `./scripts/verify.sh` が終了コード 0 で完了する

## スコープ外（やらないこと）

- テスト自体の追加・変更・削除
- `src/` 配下の変更
- pytest への一本化（フォールバックを消して解決した、とはしない。
  フォールバックが必要かどうかを判断するのは人間）
- CI の追加

## 制約・前提

- 対象ファイルは `scripts/verify.sh` と `tests/` 配下の設定ファイル（`__init__.py` 等）のみ
- 既存のテスト5件＋11件（`tests/test_greeting.py`, `tests/test_greeting_time_of_day.py`）は
  1件も変更しないこと。これらは pytest 固有機能に依存していない
  （`python -m unittest test_greeting test_greeting_time_of_day` で 16件 OK を確認済み）
- 「フォールバック経路を削除する」「テストを減らす」ことで緑にしてはいけない（CLAUDE.md 原則9）

## 原因と修正方針（2026-08-25 人間が診断・決定済み）

**原因**: `scripts/verify.sh:105` の

```bash
python3 -m unittest discover -s tests -t .
```

で `-t`（top level directory）を start dir と別に指定していること。
こうすると unittest は `tests` を**パッケージとして import できること**を要求するため、
`tests/__init__.py` が無い現状では `ImportError: Start directory is not importable` になる。

**修正方針**: `-t .` を外す。

```bash
python3 -m unittest discover -s tests
```

**実測（2026-08-25 確認済み）**:

```
$ PYTHONPATH="$PWD/src" python3 -m unittest discover -s tests
................
Ran 16 tests in 0.002s
OK
終了コード: 0
```

16件はいずれも pytest 固有機能に依存しておらず、unittest ランナーで全件通る。

**採らない案**: `tests/__init__.py` を追加する案でも直るが、
テストを import 可能にするためだけの余計なファイルが増えるため採用しない（人間の決定）。

## 未確定事項

- なし（2026-08-25 に人間が原因特定・方針決定済み）

## 停止条件

- 受け入れ条件をすべて満たし `./scripts/verify.sh` が通ったら完了。
- 修正を **5回** 試して通らなければ、状況を報告して停止する。
- 判断に迷う仕様変更が必要になったら、実装せず質問して停止する。
