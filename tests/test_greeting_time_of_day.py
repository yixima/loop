"""greet() の時間帯対応のテスト（課題 0001-greeting-time-of-day）。

時刻は原則 hour= 引数で明示注入する（実行時刻に依存させないため）。
"""

import unittest
from datetime import datetime as real_datetime
from unittest import mock

from loopdemo import greet


class TestGreetTimeOfDay(unittest.TestCase):
    def test_朝5時から10時はおはようございます(self):
        for hour in range(5, 11):
            with self.subTest(hour=hour):
                self.assertEqual(greet("山田", hour=hour), "おはようございます、山田さん")

    def test_11時から17時はこんにちは(self):
        for hour in range(11, 18):
            with self.subTest(hour=hour):
                self.assertEqual(greet("山田", hour=hour), "こんにちは、山田さん")

    def test_18時から翌4時はこんばんは(self):
        for hour in list(range(18, 24)) + list(range(0, 5)):
            with self.subTest(hour=hour):
                self.assertEqual(greet("山田", hour=hour), "こんばんは、山田さん")

    def test_時間帯の境界値(self):
        cases = [
            (4, "こんばんは、山田さん"),
            (5, "おはようございます、山田さん"),
            (10, "おはようございます、山田さん"),
            (11, "こんにちは、山田さん"),
            (17, "こんにちは、山田さん"),
            (18, "こんばんは、山田さん"),
        ]
        for hour, expected in cases:
            with self.subTest(hour=hour):
                self.assertEqual(greet("山田", hour=hour), expected)

    def test_hourが範囲外ならValueError(self):
        for hour in (-1, 24, 100):
            with self.subTest(hour=hour):
                with self.assertRaises(ValueError):
                    greet("山田", hour=hour)

    def test_hourがint以外ならTypeError(self):
        for hour in ("5", 5.0, True, False):
            with self.subTest(hour=hour):
                with self.assertRaises(TypeError):
                    greet("山田", hour=hour)

    def test_hourは位置引数では渡せない(self):
        with self.assertRaises(TypeError):
            greet("山田", 5)

    def test_hour省略時は現在時刻を使う(self):
        cases = [
            (23, "こんばんは、山田さん"),
            (3, "こんばんは、山田さん"),
            (7, "おはようございます、山田さん"),
            (13, "こんにちは、山田さん"),
        ]
        for hour, expected in cases:
            with self.subTest(hour=hour):
                # 引数で注入できない経路なので、ここだけモジュールの時計を差し替える
                with mock.patch("loopdemo.greeting.datetime") as clock:
                    clock.now.return_value = real_datetime(2026, 8, 21, hour, 30)
                    self.assertEqual(greet("山田"), expected)

    def test_nameの検証がhourより先(self):
        with self.assertRaises(TypeError):
            greet(None, hour=99)  # type: ignore[arg-type]
        with self.assertRaises(ValueError):
            greet("", hour=5)

    def test_nameの例外仕様は変わらない(self):
        for name in ("", "   "):
            with self.subTest(name=name):
                with self.assertRaises(ValueError):
                    greet(name)
                with self.assertRaises(ValueError):
                    greet(name, hour=12)
        with self.assertRaises(TypeError):
            greet(None)  # type: ignore[arg-type]
        with self.assertRaises(TypeError):
            greet(None, hour=12)  # type: ignore[arg-type]

    def test_hourなしでも呼べる_シグネチャ互換(self):
        expected = {
            "おはようございます、山田さん",
            "こんにちは、山田さん",
            "こんばんは、山田さん",
        }
        for name in ("山田", "  山田  "):
            with self.subTest(name=name):
                self.assertIn(greet(name), expected)


if __name__ == "__main__":
    unittest.main()
