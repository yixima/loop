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
        TypeError: name が str でない場合、または hour が int（bool を除く）でない場合。
        ValueError: name が空、または空白のみの場合。hour が 0〜23 の範囲外の場合。
    """
    if not isinstance(name, str):
        raise TypeError(f"name は str である必要があります: {type(name).__name__}")
    stripped = name.strip()
    if not stripped:
        raise ValueError("name が空です")

    if hour is None:
        # 呼び出しのたびに現在時刻を評価する。モジュール読み込み時に固定すると挨拶が変わらない
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
