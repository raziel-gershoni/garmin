"""Generates the 1-bit assets: the slot icon font and the seven-segment time font (BMFont .fnt +
.png), launcher icons and the dithered grey of the date band.

Icons are a font so they draw in whatever colour the face uses (dark or light theme).
No dependencies; run with:  python3 tools/make_assets.py
"""
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# Glyph character -> 13x13 pixel art. The characters are what Slots.mc draws.
ICONS = {
    "H": """
.............
..###...###..
.#####.#####.
#############
#############
#############
.###########.
..#########..
...#######...
....#####....
.....###.....
......#......
.............""",  # heart rate
    "B": """
.............
.............
.............
###########..
#.........#..
#.#######.###
#.#######.###
#.#######.###
#.........#..
###########..
.............
.............
.............""",  # battery
    "S": """
..##.........
.####........
.####....##..
.####...####.
..##....####.
........####.
.##......##..
.##..........
.........##..
.........##..
.............
.............
.............""",  # steps
    "A": """
.............
.............
.....#.......
....###......
...#####.#...
..#######.#..
..########.#.
.###########.
.############
#############
#############
.............
.............""",  # altitude
    "R": """
......#......
.....###.....
....#.#.#....
......#......
.#....#....#.
..#.......#..
....#####....
...#######...
..#########..
.............
#############
.............
.............""",  # sunrise
    "T": """
......#......
......#......
....#.#.#....
.....###.....
.#....#....#.
..#.......#..
....#####....
...#######...
..#########..
.............
#############
.............
.............""",  # sunset
    "Y": """
......###....
.....###.....
....###......
...###.......
..#######....
.....###.....
....###......
...###.......
..##.........
.##..........
#............
.............
.............""",  # body battery
    "O": """
......#......
.#....#....#.
..#.......#..
.....###.....
....#####....
...#######...
##.#######.##
...#######...
....#####....
.....###.....
..#.......#..
.#....#....#.
......#......""",  # solar intensity
    "N": """
......#......
.....###.....
....#####....
...#######...
...#######...
...#######...
...#######...
..#########..
.###########.
.............
.....###.....
......#......
.............""",  # notifications
    "C": """
......#......
......##.....
.....###.....
....####.#...
....#######..
...########..
..####.####..
..###...###..
..###...###..
..####.####..
...#######...
....#####....
.............""",  # calories
}
SIZE = 13
ADVANCE = 14


def write_png(path, width, height, rows, color_type):
    """rows: list of bytes, already in the PNG pixel format for color_type (0 = gray8, 2 = rgb8)."""
    raw = b"".join(b"\x00" + r for r in rows)

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, color_type, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(png)


def bitmap_font(out_dir, name, face, glyphs, height):
    """Writes name.fnt and name.png (BMFont text format, one strip of white glyphs on black).
    glyphs: character -> (rows of '#'/'.', all `height` tall, xadvance)."""
    width = sum(advance for _, advance in glyphs.values())
    pixels = [[0] * width for _ in range(height)]
    lines = []
    left = 0
    for ch, (art, advance) in glyphs.items():
        assert len(art) == height and len({len(row) for row in art}) == 1 and len(art[0]) <= advance, ch
        for y, row in enumerate(art):
            for x, c in enumerate(row):
                if c == "#":
                    pixels[y][left + x] = 255
        lines.append(f"char id={ord(ch)} x={left} y=0 width={len(art[0])} height={height} "
                     f"xoffset=0 yoffset=0 xadvance={advance} page=0 chnl=15")
        left += advance
    write_png(out_dir / f"{name}.png", width, height, [bytes(r) for r in pixels], 0)
    fnt = [
        f'info face="{face}" size={height} bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=0,0',
        f"common lineHeight={height} base={height} scaleW={width} scaleH={height} pages=1 packed=0",
        f'page id=0 file="{name}.png"',
        f"chars count={len(lines)}",
        *lines,
    ]
    (out_dir / f"{name}.fnt").write_text("\n".join(fnt) + "\n")


def icon_font(out_dir):
    glyphs = {ch: (art.strip("\n").splitlines(), ADVANCE) for ch, art in ICONS.items()}
    bitmap_font(out_dir, "icons", "HebrewFaceIcons", glyphs, SIZE)


# Lit segments per digit: a top, b top right, c bottom right, d bottom, e bottom left, f top left,
# g middle.
SEGMENTS = {"0": "abcdef", "1": "bc", "2": "abged", "3": "abgcd", "4": "fgbc", "5": "afgcd",
            "6": "afgedc", "7": "abc", "8": "abcdefg", "9": "abcdfg"}


def segment(x, y, w, h, t):
    """What lights the pixel at (x, y) in a w x h digit with t-thick strokes: a list of segment
    sets, any one of them fully lit lights it. Strokes meet on 45-degree mitres, so a stroke whose
    neighbour is unlit ends in a point; where both are lit they join solid."""
    r = w - 1 - x
    b = h - 1 - y
    mid = (h - 1) / 2
    m = abs(y - mid)
    left, right, top, bottom, middle = x < t, r < t, y < t, b < t, m < t / 2
    side = "f" if y < mid else "e"
    pair = "fe"
    if right:
        side = "b" if y < mid else "c"
        pair = "bc"
    if (top or bottom) and (left or right):
        d = x if left else r
        edge = y if top else b
        across = "a" if top else "d"
        if d == edge:
            return [{across, side}]
        return [{across if edge < d else side}]
    if middle and (left or right):
        d = x if left else r
        if abs(m - d) < 0.75:
            return [{"g", side}, set(pair)]
        return [{"g"}, set(pair)] if m < d else [{side}]
    if top:
        return [{"a"}]
    if bottom:
        return [{"d"}]
    if middle:
        return [{"g"}]
    return [{side}] if left or right else []


def time_font(out_dir, w=12, h=21, t=3, gap=2):
    """Seven-segment digits and a colon for the time line: w x h digits with t-thick strokes, gap
    pixels apart. Every digit has the same advance, so the time never shifts sideways."""
    glyphs = {}
    for ch, lit in SEGMENTS.items():
        glyphs[ch] = (["".join("#" if any(s <= set(lit) for s in segment(x, y, w, h, t)) else "."
                               for x in range(w)) for y in range(h)], w + gap)
    dots = {round((t + h / 2) / 2 - t / 2), round(h - (t + h / 2) / 2 - t / 2)}
    glyphs[":"] = (["#" * t if any(d <= y < d + t for d in dots) else "." * t for y in range(h)], t + gap)
    bitmap_font(out_dir, "time", "HebrewFaceTime", glyphs, h)


def launcher_icon(path, crescent, n=62):
    """n x n (62 for the Instinct, 54 for the Venu): a ring with a crescent moon (face) or a filled
    disk with a crescent cut-out (glance), drawn proportionally to n."""
    k = n / 62
    c = 30.5 * k
    rows = []
    for y in range(n):
        row = bytearray()
        for x in range(n):
            d = (((x - c) ** 2 + (y - c) ** 2) ** 0.5) / k
            moon = d < 17 and (((x - c - 8 * k) ** 2 + (y - c + 5 * k) ** 2) ** 0.5) / k > 14
            if crescent:
                on = (27 <= d <= 30) or moon
            else:
                on = d <= 30 and not moon
            v = 255 if on else 0
            row += bytes((v, v, v))
        rows.append(bytes(row))
    write_png(path, n, n, rows, 2)


def band(path, width=176, height=49):
    """The date band's grey: a 50% checkerboard, the only grey a 1-bit screen can show."""
    rows = [bytes(255 if (x + y) % 2 == 0 else 0 for x in range(width)) for y in range(height)]
    write_png(path, width, height, rows, 0)


if __name__ == "__main__":
    icon_font(ROOT / "face" / "resources-instinct" / "fonts")
    time_font(ROOT / "face" / "resources-instinct" / "fonts")
    launcher_icon(ROOT / "face" / "resources" / "drawables" / "launcher_icon.png", True)
    launcher_icon(ROOT / "glance" / "resources" / "drawables" / "launcher_icon.png", False)
    launcher_icon(ROOT / "face" / "resources-round" / "drawables" / "launcher_icon.png", True, 54)
    launcher_icon(ROOT / "glance" / "resources-round" / "drawables" / "launcher_icon.png", False, 54)
    band(ROOT / "common" / "resources-instinct" / "drawables" / "band.png")
    print("assets written")
