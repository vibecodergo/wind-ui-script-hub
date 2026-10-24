"""python -m unittest discover -s tests -p test_gif_to_sheet.py (requires Pillow)."""
import importlib.util
import tempfile
import unittest
from pathlib import Path

from PIL import Image

spec = importlib.util.spec_from_file_location("converter", Path(__file__).parents[1] / "tools/gif_to_sheet.py")
converter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(converter)


class ConversionTests(unittest.TestCase):
    def test_variable_duration_sampling_and_metadata(self):
        with tempfile.TemporaryDirectory() as temp:
            source, output = Path(temp) / "input.gif", Path(temp) / "sheet.png"
            red = Image.new("RGB", (16, 16), "red")
            blue = Image.new("RGB", (16, 16), "blue")
            red.save(source, save_all=True, append_images=[blue], duration=[100, 300], loop=0)
            result = converter.convert(source, output, fps=10, width=16, height=16, max_size=32)
            self.assertEqual(result["FrameCount"], 4)
            self.assertEqual((result["Columns"], result["Rows"]), (2, 2))
            with Image.open(output) as sheet:
                self.assertEqual(sheet.size, (32, 32))
                self.assertEqual(sheet.getpixel((8, 8)), (255, 0, 0, 255))
                for point in [(24, 8), (8, 24), (24, 24)]:
                    self.assertEqual(sheet.getpixel(point), (0, 0, 255, 255))
            self.assertTrue(output.with_suffix(".json").exists())
            self.assertIn("Vector2.new(16, 16)", output.with_suffix(".lua").read_text())
            with self.assertRaises(ValueError):
                converter.convert(source, output, fps=60, width=32, height=32, max_size=32)

    def test_invalid_fps(self):
        with self.assertRaises(ValueError):
            converter.convert("unused.gif", "unused.png", fps=0)


if __name__ == "__main__":
    unittest.main()
