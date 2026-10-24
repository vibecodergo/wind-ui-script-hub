"""Convert a GIF to one uniform-FPS PNG sprite sheet. Requires Pillow."""
import argparse
import json
import math
from pathlib import Path

from PIL import Image, ImageOps


def convert(source, output, fps=24, width=128, height=128, max_size=1024):
    if not (1 <= fps <= 60 and 0 < width <= max_size and 0 < height <= max_size):
        raise ValueError("Use FPS 1..60 and positive frame dimensions within max-size")
    with Image.open(source) as gif:
        if gif.format != "GIF":
            raise ValueError("Input must be a GIF")
        durations = []
        for index in range(gif.n_frames):
            gif.seek(index)
            durations.append(max(10, int(gif.info.get("duration", 100))))
        total_ms = sum(durations)
        count = math.ceil(total_ms * fps / 1000)
        columns = min(max_size // width, count)
        rows = math.ceil(count / columns)
        if rows * height > max_size:
            raise ValueError(
                f"{count} frames do not fit in {max_size}px. Shorten the GIF, reduce "
                "FPS or frame size; this player supports one sheet."
            )
        sheet = Image.new("RGBA", (columns * width, rows * height))
        index, end_ms = 0, durations[0]
        gif.seek(0)
        for frame in range(count):
            sample_ms = frame * 1000 / fps
            while sample_ms >= end_ms and index + 1 < len(durations):
                index += 1
                end_ms += durations[index]
                gif.seek(index)
            # Pillow's GIF decoder composites frames and applies disposal modes.
            image = ImageOps.contain(gif.convert("RGBA"), (width, height), Image.Resampling.LANCZOS)
            cell = Image.new("RGBA", (width, height))
            cell.paste(image, ((width - image.width) // 2, (height - image.height) // 2))
            sheet.paste(cell, ((frame % columns) * width, (frame // columns) * height))
        output = Path(output)
        output.parent.mkdir(parents=True, exist_ok=True)
        sheet.save(output, format="PNG")
        metadata = {
            "Type": "SpriteSheet", "FPS": fps, "Columns": columns, "Rows": rows,
            "FrameCount": count, "FrameSize": [width, height],
            "SourceDurationMs": total_ms,
        }
        output.with_suffix(".json").write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
        lua = f'''-- Upload {output.name} as a Roblox image and replace the Asset ID.
return {{
    Enabled = true,
    Type = "SpriteSheet",
    Asset = "rbxassetid://REPLACE_WITH_UPLOADED_IMAGE_ID",
    FPS = {fps},
    FrameSize = Vector2.new({width}, {height}),
    Columns = {columns},
    Rows = {rows},
    FrameCount = {count},
    Transparency = 0.3,
    Loop = true,
}}
'''
        output.with_suffix(".lua").write_text(lua, encoding="utf-8")
        return metadata


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--fps", type=int, default=24)
    parser.add_argument("--width", type=int, default=128)
    parser.add_argument("--height", type=int, default=128)
    parser.add_argument("--max-size", type=int, default=1024)
    args = parser.parse_args()
    try:
        result = convert(args.source, args.output, args.fps, args.width, args.height, args.max_size)
    except (ValueError, OSError) as exc:
        parser.exit(1, f"Conversion failed: {exc}\n")
    print(json.dumps(result, indent=2))
