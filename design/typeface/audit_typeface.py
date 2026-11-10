"""Exhaustive coverage/geometry/shaping audit. Does not certify visual quality."""

import argparse
import hashlib
import json
import unicodedata
from pathlib import Path

import uharfbuzz as hb
from fontTools.ttLib import TTFont

ROOT = Path(__file__).resolve().parent


def audit(path, reference=None):
    raw = path.read_bytes()
    font = TTFont(path, checkChecksums=2)
    cmap = font.getBestCmap()
    manifest = json.loads((ROOT / "release/manifest.json").read_text())
    assert hashlib.sha256(raw).hexdigest() == manifest["font_sha256"]
    assert set(cmap) == {ord(c) for c in manifest["characters"]}
    assert set(range(32, 127)) <= cmap.keys()
    assert set(range(0xAC00, 0xD7A4)) <= cmap.keys()
    assert set(range(0x3131, 0x3164)) <= cmap.keys()
    expected_blank = set(manifest["blank_codepoints"])
    assert expected_blank == {32, 160, 0x3000, 0x200B, 0x200C, 0x200D,
                              0x115F, 0x1160, 0x3164, 0xFEFF}
    outlines = set()
    for cp, name in cmap.items():
        g = font["glyf"][name]
        advance, lsb = font["hmtx"][name]
        assert (g.numberOfContours == 0) == (cp in expected_blank), hex(cp)
        if cp in expected_blank:
            continue
        assert 0 <= g.xMin < g.xMax <= advance, (hex(cp), g.xMin, g.xMax)
        assert -200 <= g.yMin < g.yMax <= 1060, (hex(cp), g.yMin, g.yMax)
        assert lsb == g.xMin
        if 0xAC00 <= cp <= 0xD7A3:
            assert advance == 920
            coords, ends, _ = g.getCoordinates(font["glyf"])
            outline = (tuple(coords), tuple(ends))
            assert outline not in outlines, f"Duplicate Hangul outline {hex(cp)}"
            outlines.add(outline)
    face = hb.Face(raw)
    shaping_font = hb.Font(face)

    def shape(text):
        buffer = hb.Buffer()
        buffer.add_str(text)
        buffer.guess_segment_properties()
        hb.shape(shaping_font, buffer)
        return [(g.codepoint, p.x_advance, p.x_offset, p.y_offset)
                for g, p in zip(buffer.glyph_infos, buffer.glyph_positions)]

    for cp in range(0xAC00, 0xD7A4):
        expected = [(font.getGlyphID(cmap[cp]), 920, 0, 0)]
        assert shape(chr(cp)) == expected, hex(cp)
        assert shape(unicodedata.normalize("NFD", chr(cp))) == expected, hex(cp)
    sample = "똠뷁힣 꽃잎 값싼 닭 흙 읊다 괜찮다 2026 Writing Human ‘쉼’…"
    assert all(g[0] != 0 for g in shape(sample))
    kerned = shape("AV")
    assert sum(g[1] for g in kerned) == sum(font["hmtx"][cmap[ord(c)]][0] for c in "AV") - 65
    # Verify all explicit GSUB rules as well as HarfBuzz's normalization path.
    lookups = font["GSUB"].table.LookupList.Lookup
    rules = {}
    for lookup in lookups:
        for table in lookup.SubTable:
            table = getattr(table, "ExtSubTable", table)
            for first, ligatures in getattr(table, "ligatures", {}).items():
                for lig in ligatures:
                    rules[(first, *lig.Component)] = lig.LigGlyph
    for l in range(19):
        for v in range(21):
            lv = 0xAC00 + (l * 21 + v) * 28
            assert rules[(cmap[0x1100 + l], cmap[0x1161 + v])] == cmap[lv]
            for t in range(1, 28):
                assert rules[(cmap[lv], cmap[0x11A7 + t])] == cmap[lv + t]
    # Every mapped visible character shapes without selecting .notdef.
    for cp in cmap:
        if cp not in expected_blank:
            assert all(g[0] != 0 for g in shape(chr(cp))), hex(cp)
    result = {
        "font": str(path), "sha256": hashlib.sha256(raw).hexdigest(),
        "cmap_entries": len(cmap), "unique_hangul_outlines": len(outlines),
        "nfc_nfd_syllables_checked": 11172, "explicit_composition_rules": len(rules),
        "geometry": "pass", "shaping": "pass", "harfbuzz": hb.version_string(),
        "scope": "Font tables and HarfBuzz; not physical device or optical approval",
    }
    if reference:
        previous = TTFont(reference)
        previous_cmap = previous.getBestCmap()

        def contours(f, glyph_name):
            coords, ends, flags = f["glyf"][glyph_name].getCoordinates(f["glyf"])
            result, start = [], 0
            for end in ends:
                contour = list(zip(coords[start:end + 1], flags[start:end + 1]))
                # Contour order and starting point do not change the curves.
                pivot = min(range(len(contour)), key=contour.__getitem__)
                result.append(tuple(contour[pivot:] + contour[:pivot]))
                start = end + 1
            return sorted(result)

        for cp in range(0xAC00, 0xD7A4):
            assert contours(font, cmap[cp]) == contours(previous, previous_cmap[cp]), hex(cp)
            assert font["hmtx"][cmap[cp]] == previous["hmtx"][previous_cmap[cp]], hex(cp)
        result["reference_geometry_identical"] = 11172
        result["reference_sha256"] = hashlib.sha256(reference.read_bytes()).hexdigest()
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("font", type=Path, nargs="?", default=ROOT / "release/WritingHumanDevelopment-Regular.ttf")
    parser.add_argument("--output", type=Path)
    parser.add_argument("--reference", type=Path, help="compare full Hangul curves/metrics against an expanded-outline build")
    args = parser.parse_args()
    result = audit(args.font, args.reference)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
