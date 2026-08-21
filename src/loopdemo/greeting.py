"""挨拶文を組み立てるサンプル実装。"""


def greet(name: str) -> str:
    """名前を受け取って挨拶文を返す。

    Args:
        name: 挨拶する相手の名前。前後の空白は取り除かれる。

    Returns:
        "こんにちは、<name>さん" 形式の文字列。

    Raises:
        ValueError: name が空、または空白のみの場合。
    """
    if not isinstance(name, str):
        raise TypeError(f"name は str である必要があります: {type(name).__name__}")
    stripped = name.strip()
    if not stripped:
        raise ValueError("name が空です")
    return f"こんにちは、{stripped}さん"
