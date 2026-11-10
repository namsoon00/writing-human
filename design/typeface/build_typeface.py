"""Build the full-coverage development font from original editable masters.

The 0.005 proof and its renderer remain reproducible. No third-party font is
read: Hangul uses project jamo, Latin/punctuation use authored SVG centerlines.
"""

import argparse
import hashlib
import json
from pathlib import Path

import pathops
from fontTools.feaLib.builder import addOpenTypeFeaturesFromString
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.svgLib.path import parse_path
from fontTools.ttLib import TTFont, newTable

from build_vector_proof import Designer, L, V, T, MIXED, SOURCE, to_glyph as base_to_glyph, polygon

ROOT = Path(__file__).resolve().parent
APP = ROOT.parents[1] / "assets/fonts"
OUT = ROOT / "release"
LATIN = ROOT / "source/latin-v006.json"
PROFILE = ROOT / "source/reading-v007.json"
READING = json.loads(PROFILE.read_text())
REVISION = READING["revision"]
FILENAME = "WritingHumanDevelopment-Regular.ttf"


def to_glyph(path):
    # Expand filled vector contours; their counters shrink by the same amount.
    # Keeping advances fixed preserves spacing and the NFC/NFD composition map.
    clean = pathops.simplify(path, clockwise=False)
    edge = pathops.Path(clean)
    edge.stroke(READING["outline_expansion"] * 2,
                pathops.LineCap.ROUND_CAP, pathops.LineJoin.ROUND_JOIN, 4)
    edge.convertConicsToQuads(.1)
    expanded = pathops.op(clean, edge, pathops.PathOp.UNION)
    return base_to_glyph(expanded)


class Layout(Designer):
    """Collect positions without redrawing repeated outlines for each syllable."""

    def component(self, jamo, box, weight=1):
        self.components.append((jamo, tuple(box), weight))


def name_for(cp):
    return f"uni{cp:04X}"


def latin_path(svg):
    # Expand centerlines in stretched Y space: vertical ink 62, horizontal 34.
    # This keeps stroke contrast consistent with the Hangul masters.
    path = pathops.Path()
    parse_path(svg, TransformPen(path.getPen(), (1, 0, 0, 62 / 34, 0, 0)))
    path.stroke(62, pathops.LineCap.ROUND_CAP, pathops.LineJoin.ROUND_JOIN, 4)
    path.convertConicsToQuads(.1)
    return path.transform(1, 0, 0, 34 / 62, 0, 0)


def standalone(source, jamo):
    d = Designer(source)
    if jamo in MIXED:
        a, b = MIXED[jamo]
        d.component(a, (130, 485, 530, 780))
        d.component(b, (600, 135, 800, 795), .92)
    elif jamo in "ㅗㅛㅜㅠㅡ":
        d.component(jamo, (135, 340, 785, 675))
    elif jamo in V:
        d.component(jamo, (325, 150, 615, 800))
    else:
        d.component(jamo, (175, 185, 745, 780))
    return d.path


def punctuation():
    # Original pen paths; wide Korean punctuation has its own advance.
    return {
        "‘": (280, "M 175 135 C 100 185 105 235 125 295"),
        "’": (280, "M 155 135 C 175 195 150 245 105 295"),
        "“": (460, "M 175 135 C 100 185 105 235 125 295 M 355 135 C 280 185 285 235 305 295"),
        "”": (460, "M 155 135 C 175 195 150 245 105 295 M 335 135 C 355 195 330 245 285 295"),
        "–": (650, "M 70 515 L 580 515"),
        "—": (920, "M 70 515 L 850 515"),
        "…": (920, "M 160 795 L 160 815 M 460 795 L 460 815 M 760 795 L 760 815"),
        "·": (310, "M 155 485 L 155 505"),
        "ㆍ": (920, "M 460 485 L 460 505"),
        "、": (920, "M 170 750 L 285 875"),
        "。": (920, "M 205 730 C 95 730 95 875 205 875 C 315 875 315 730 205 730 Z"),
        "〈": (600, "M 455 115 L 135 505 L 455 895"),
        "〉": (600, "M 145 115 L 465 505 L 145 895"),
        "《": (820, "M 445 115 L 125 505 L 445 895 M 690 115 L 370 505 L 690 895"),
        "》": (820, "M 130 115 L 450 505 L 130 895 M 375 115 L 695 505 L 375 895"),
        "「": (600, "M 485 115 L 185 115 L 185 595"),
        "」": (600, "M 415 415 L 415 895 L 115 895"),
        "『": (650, "M 535 115 L 185 115 L 185 595 L 285 595 L 285 215 L 535 215 Z"),
        "』": (650, "M 115 795 L 365 795 L 365 415 L 465 415 L 465 895 L 115 895 Z"),
        "【": (600, "M 455 115 L 155 115 L 155 895 L 455 895 M 255 115 L 255 895"),
        "】": (600, "M 145 115 L 445 115 L 445 895 L 145 895 M 345 115 L 345 895"),
        "₩": (940, "M 75 155 L 265 815 L 470 245 L 675 815 L 865 155 M 75 425 L 865 425 M 75 575 L 865 575"),
        "×": (600, "M 120 310 L 480 700 M 480 310 L 120 700"),
        "÷": (600, "M 80 505 L 520 505 M 300 275 L 300 295 M 300 715 L 300 735"),
        "−": (600, "M 90 505 L 510 505"),
        "±": (600, "M 90 415 L 510 415 M 300 205 L 300 625 M 90 795 L 510 795"),
        "•": (400, "M 200 455 L 200 535"),
        "※": (920, "M 135 175 L 785 825 M 785 175 L 135 825 M 460 175 L 460 195 M 460 805 L 460 825 M 135 490 L 135 510 M 785 490 L 785 510"),
    }


def shaping_features():
    # Two ordered lookups also support shapers with normalization disabled.
    lines = ["languagesystem DFLT dflt;", "languagesystem hang dflt;",
             "languagesystem latn dflt;", "lookup ComposeLV useExtension {"]
    for l in range(19):
        for v in range(21):
            lv = 0xAC00 + (l * 21 + v) * 28
            lines.append(f"sub {name_for(0x1100+l)} {name_for(0x1161+v)} by {name_for(lv)};")
    lines.append("} ComposeLV;\nlookup ComposeLVT useExtension {")
    for lv in range(0xAC00, 0xD7A4, 28):
        for t in range(1, 28):
            lines.append(f"sub {name_for(lv)} {name_for(0x11A7+t)} by {name_for(lv+t)};")
    lines.append("} ComposeLVT;\nfeature ccmp { lookup ComposeLV; lookup ComposeLVT; } ccmp;")
    return "\n".join(lines)


def build(install=False):
    source = json.loads(SOURCE.read_text())
    latin = json.loads(LATIN.read_text())
    glyphs, metrics, cmap = {}, {}, {}
    layouts = {}

    def add(cp, path=None, width=920):
        name = name_for(cp)
        glyphs[name] = to_glyph(path)[0] if path is not None else TTGlyphPen(None).glyph()
        metrics[name] = (width, 0)
        cmap[cp] = name

    missing = pathops.Path()
    polygon(missing, [(130, 100), (790, 100), (790, 820), (130, 820)])
    polygon(missing, [(180, 150), (180, 770), (740, 770), (740, 150)])
    glyphs[".notdef"] = to_glyph(missing)[0]
    metrics[".notdef"] = (920, 130)
    for cp, width in {32: 410, 160: 410, 0x3000: 920, 0x200B: 0,
                      0x200C: 0, 0x200D: 0, 0x115F: 0, 0x1160: 0,
                      0x3164: 920, 0xFEFF: 0}.items():
        add(cp, width=width)
    for char, (width, svg) in {**latin["glyphs"], **punctuation()}.items():
        add(ord(char), latin_path(svg), width)
    # U+318D archaic araea is punctuation only, not general Old Hangul shaping.
    for cp in range(0x3131, 0x3164):
        add(cp, standalone(source, chr(cp)))
    for start, jamos in ((0x1100, L), (0x1161, V), (0x11A8, T[1:])):
        for i, jamo in enumerate(jamos):
            add(start + i, standalone(source, jamo))
    parts = {}
    for cp in range(0xAC00, 0xD7A4):
        d = Layout(source)
        evidence = d.syllable(chr(cp))
        layouts[evidence["layout"]] = layouts.get(evidence["layout"], 0) + 1
        pen = TTGlyphPen(glyphs)
        for spec in d.components:
            if spec not in parts:
                jamo, box, weight = spec
                part = Designer(source)
                part.component(jamo, box, weight)
                part_name = f"part{len(parts):04d}"
                glyphs[part_name] = to_glyph(part.path)[0]
                metrics[part_name] = (920, 0)
                parts[spec] = part_name
            pen.addComponent(parts[spec], (1, 0, 0, 1, 0, 0))
        name = name_for(cp)
        glyphs[name] = pen.glyph(componentFlags=0)
        cmap[cp] = name
        metrics[name] = (920, 0)
    fb = FontBuilder(1000, isTTF=True)
    fb.setupGlyphOrder([".notdef"] + list(parts.values()) + [cmap[cp] for cp in sorted(cmap)])
    fb.setupCharacterMap(cmap)
    fb.setupGlyf(glyphs)
    for name, glyph in glyphs.items():
        if glyph.numberOfContours:
            metrics[name] = (metrics[name][0], glyph.xMin)
    fb.setupHorizontalMetrics(metrics)
    fb.setupHorizontalHeader(ascent=1060, descent=-200, lineGap=0)
    fb.setupNameTable({
        "familyName": "Writing Human Development", "styleName": "Regular",
        "uniqueFontIdentifier": f"writing-human-original-vector-{REVISION}",
        "fullName": "Writing Human Development Regular",
        "psName": "WritingHumanDevelopment-Regular",
        "version": f"Version {REVISION}; FULL MODERN HANGUL DEVELOPMENT",
        "description": "Original project-authored jamo and Latin masters. Full modern Hangul coverage. Development font pending optical and device approval.",
    })
    fb.setupOS2(sTypoAscender=1060, sTypoDescender=-200, sTypoLineGap=0,
                usWinAscent=1060, usWinDescent=200, usWeightClass=400,
                fsSelection=0x40, sxHeight=500, sCapHeight=660)
    for name_id, value in {1: "쓰는 인간체 개발판", 2: "Regular",
                           4: "쓰는 인간체 개발판 Regular"}.items():
        fb.font["name"].setName(value, name_id, 3, 1, 0x0412)
    fb.setupPost()
    fb.setupMaxp()
    features = shaping_features() + "\nfeature kern {\n"
    for pair, adjustment in latin["kerning"].items():
        left, right = pair
        features += f"pos {name_for(ord(left))} {name_for(ord(right))} {adjustment};\n"
    features += "} kern;\n"
    addOpenTypeFeaturesFromString(fb.font, features)
    # Smooth at all sizes. No instruction-based hinting has been claimed.
    fb.font["gasp"] = newTable("gasp")
    fb.font["gasp"].gaspRange = {65535: 10}
    fb.font["head"].fontRevision = float(REVISION)
    fb.font["head"].created = fb.font["head"].modified = 3877113600
    fb.font.recalcTimestamp = False
    OUT.mkdir(exist_ok=True)
    target = OUT / FILENAME
    fb.save(str(target))
    font = TTFont(target, checkChecksums=2)
    blanks = {cp for cp, name in cmap.items() if not font["glyf"][name].numberOfContours}
    bounds = []
    for cp, name in cmap.items():
        g = font["glyf"][name]
        if cp in blanks:
            continue
        assert g.numberOfContours > 0 or g.isComposite(), hex(cp)
        assert 0 <= g.xMin < g.xMax <= metrics[name][0], (hex(cp), g.xMin, g.xMax, metrics[name])
        assert -200 <= g.yMin < g.yMax <= 1060, (hex(cp), g.yMin, g.yMax)
        bounds.append([g.xMin, g.yMin, g.xMax, g.yMax])
    manifest = {
        "status": "development-full-coverage", "revision": REVISION,
        "flutter_family": "WritingHumanDevelopment", "hangul_syllables": 11172,
        "compatibility_jamo": 51, "conjoining_jamo": 67,
        "ascii_printable": 95, "cmap_entries": len(cmap),
        "shared_hangul_parts": len(parts),
        "reading_profile": READING,
        "characters": "".join(chr(cp) for cp in sorted(cmap)),
        "blank_codepoints": sorted(blanks), "layouts": layouts,
        "font_sha256": hashlib.sha256(target.read_bytes()).hexdigest(),
        "source_sha256": {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                          for p in [SOURCE, LATIN, PROFILE, Path(__file__), ROOT / "build_vector_proof.py"]},
        "fallback": ["NanumMyeongjo", "NanumGothic"],
        "source": "Original project-authored vector jamo and Latin; design/typeface/build_typeface.py",
        "not_implemented": ["Old Hangul shaping", "Hanja", "extended Latin", "instruction-based hinting", "final optical approval", "physical iOS/Android readability review"],
    }
    (OUT / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    if install:
        # Build and validate first; never install a partially generated font.
        (APP / FILENAME).write_bytes(target.read_bytes())
        (APP / "WritingHumanDevelopment-info.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({k: manifest[k] for k in ("revision", "hangul_syllables", "cmap_entries", "layouts", "font_sha256")}))
    print(f"{target}: {target.stat().st_size:,} bytes; installed={install}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--install", action="store_true", help="copy audited output to Flutter assets")
    build(parser.parse_args().install)
