"""greeting のテスト。

verify.sh の停止条件は「このテストが全件通ること」です。
テストを消したりスキップしたりして緑にすることは CLAUDE.md で禁止されています。
"""

import unittest

from loopdemo import greet


class TestGreet(unittest.TestCase):
    def test_通常の名前で挨拶文を返す(self):
        self.assertEqual(greet("山田", hour=12), "こんにちは、山田さん")

    def test_前後の空白は取り除かれる(self):
        self.assertEqual(greet("  山田  ", hour=12), "こんにちは、山田さん")

    def test_空文字はValueError(self):
        with self.assertRaises(ValueError):
            greet("")

    def test_空白のみもValueError(self):
        with self.assertRaises(ValueError):
            greet("   ")

    def test_str以外はTypeError(self):
        with self.assertRaises(TypeError):
            greet(None)  # type: ignore[arg-type]


if __name__ == "__main__":
    unittest.main()
