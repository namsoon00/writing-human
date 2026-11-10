"""Build original, limited Hangul proof from editable common jamo masters.

No existing font is opened. Coordinates in jamo-v004.json are stroke skeletons;
stroke contrast is applied AFTER layout, so narrow components keep their weight.
Run with the separate requirements-vector.txt development environment.
"""

import hashlib
import json
import math
from pathlib import Path
from xml.sax.saxutils import escape

import pathops
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.cu2quPen import Cu2QuPen
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTFont

ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / "source/jamo-v004.json"
REVIEW = ROOT / "source/review-text-v004.json"
OUT = ROOT / "proof"
L = "ㄱㄲㄴㄷㄸㄹㅁㅂㅃㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎ"
V = "ㅏㅐㅑㅒㅓㅔㅕㅖㅗㅘㅙㅚㅛㅜㅝㅞㅟㅠㅡㅢㅣ"
T = ["", "ㄱ", "ㄲ", "ㄳ", "ㄴ", "ㄵ", "ㄶ", "ㄷ", "ㄹ", "ㄺ", "ㄻ", "ㄼ", "ㄽ", "ㄾ", "ㄿ", "ㅀ", "ㅁ", "ㅂ", "ㅄ", "ㅅ", "ㅆ", "ㅇ", "ㅈ", "ㅊ", "ㅋ", "ㅌ", "ㅍ", "ㅎ"]
DOUBLE = {"ㄲ": "ㄱㄱ", "ㄸ": "ㄷㄷ", "ㅃ": "ㅂㅂ", "ㅆ": "ㅅㅅ", "ㅉ": "ㅈㅈ"}
CLUSTERS = dict(zip("ㄳㄵㄶㄺㄻㄼㄽㄾㄿㅀㅄ", ["ㄱㅅ", "ㄴㅈ", "ㄴㅎ", "ㄹㄱ", "ㄹㅁ", "ㄹㅂ", "ㄹㅅ", "ㄹㅌ", "ㄹㅍ", "ㄹㅎ", "ㅂㅅ"]))
MIXED = {"ㅘ": "ㅗㅏ", "ㅙ": "ㅗㅐ", "ㅚ": "ㅗㅣ", "ㅝ": "ㅜㅓ", "ㅞ": "ㅜㅔ", "ㅟ": "ㅜㅣ", "ㅢ": "ㅡㅣ"}
FAMILY = "Writing Human Development Proof"


def polygon(path, points):
    path.moveTo(*points[0])
    for point in points[1:]:
        path.lineTo(*point)
    path.close()


class Designer:
    def __init__(self, source):
        self.source = source
        self.path = pathops.Path()
        self.components = []

    def h(self, a, b, weight):
        """Shallow, softly swelling horizontal with a short lifted ink terminal."""
        x, y = a
        r, z = b
        z -= min(7, (r-x)*.012)
        half = self.source["horizontal_weight"] * weight / 2
        terminal = min(25 * weight, (r - x) * .17)
        p = self.path
        p.moveTo(x - 5 * weight, y - half-2*weight)
        p.cubicTo(x + (r-x)*.28, y-half+9*weight, r-2*terminal, z-half+6*weight, r-terminal, z-half)
        p.quadTo(r-8*weight, z-half-terminal*.78, r-4*weight, z-half-terminal*.75)
        p.quadTo(r+terminal*.9, z-half+1, r+terminal, z+half*.38)
        p.quadTo(r+terminal*.8, z+half, r-2*weight, z+half)
        p.cubicTo(r-(r-x)*.3, z+half+8*weight, x+16*weight, y+half+2*weight, x-3*weight, y+half)
        p.quadTo(x-7*weight, y+half*.8, x-5*weight, y-half)
        p.close()

    def v(self, a, b, weight):
        """A pen-cut shoulder, quiet waist and small curved foot; fixed ink weight."""
        x, y = a
        r, z = b
        half = self.source["vertical_weight"] * weight / 2
        p = self.path
        p.moveTo(x-half-16*weight, y-9*weight)
        p.quadTo(x-half-11*weight, y-17*weight, x+half-4*weight, y+2*weight)
        p.cubicTo(x+half+1, y+(z-y)*.23, r+half-3*weight, z-35*weight, r+half+2*weight, z-4*weight)
        p.quadTo(r+half+5*weight, z+7*weight, r+half-4*weight, z+10*weight)
        p.lineTo(r-half+2*weight, z+13*weight)
        p.quadTo(r-half-3*weight, z+6*weight, r-half, z-12*weight)
        p.cubicTo(r-half+6*weight, z-(z-y)*.3, x-half+6*weight, y+31*weight, x-half-16*weight, y-9*weight)
        p.close()

    def diagonal(self, coords, role, weight):
        """Offset an authored cubic with contrasting, gradually tapered pen ink."""
        points = [coords[i:i+2] for i in range(0, 8, 2)]
        left, right = [], []
        for i in range(41):
            t, u = i/40, 1-i/40
            x, y = [sum(k*p[j] for k, p in zip((u**3, 3*u*u*t, 3*u*t*t, t**3), points)) for j in (0, 1)]
            dx, dy = [3*u*u*(points[1][j]-points[0][j])+6*u*t*(points[2][j]-points[1][j])+3*t*t*(points[3][j]-points[2][j]) for j in (0, 1)]
            length = math.hypot(dx, dy)
            nx, ny = -dy/length, dx/length
            width = (39 if role == "left" else 67) * weight
            width *= (.77 + .23*math.sin(math.pi*t)) if role == "left" else (.76+.28*t)
            left.append((x+nx*width/2, y+ny*width/2))
            right.append((x-nx*width/2, y-ny*width/2))
        polygon(self.path, left+right[::-1])

    def oval(self, bounds, weight):
        """Common slightly upright oval, thinner crown and asymmetric side weight."""
        x, y, r, b = bounds
        p = self.path
        def loop(x, y, r, b):
            w, h = r-x, b-y
            p.moveTo(x+w*.47, y)
            p.cubicTo(x+w*.80, y-1, r, y+h*.19, r, y+h*.48)
            p.cubicTo(r, y+h*.79, x+w*.78, b, x+w*.52, b)
            p.cubicTo(x+w*.22, b+1, x, y+h*.81, x, y+h*.53)
            p.cubicTo(x, y+h*.23, x+w*.18, y+1, x+w*.47, y)
            p.close()
        loop(x, y, r, b)
        # Reverse the inner contour before union, preserving a real open counter.
        old = self.path
        inner = pathops.Path()
        self.path = inner
        p = inner
        loop(x+56*weight, y+33*weight, r-65*weight, b-34*weight)
        inner.reverse()
        old.addPath(inner)
        self.path = old

    def component(self, jamo, box, weight=1):
        x, y, r, b = box
        pair = DOUBLE.get(jamo) or CLUSTERS.get(jamo)
        if pair:
            gap = 46 if jamo not in CLUSTERS else 60
            mid = (x+r)/2
            self.component(pair[0], (x, y, mid-gap/2, b), weight*.84)
            self.component(pair[1], (mid+gap/2, y, r, b), weight*.84)
            return
        self.components.append({"jamo": jamo, "box": list(box), "weight": round(weight, 4)})
        for role, *coords in self.source["jamo"][jamo]:
            actual = [((x+(r-x)*v) if i % 2 == 0 else (y+(b-y)*v)) for i, v in enumerate(coords)]
            if role == "oval":
                self.oval(actual, weight)
            elif role == "h":
                self.h(actual[:2], actual[2:], weight)
            elif role == "v":
                self.v(actual[:2], actual[2:], weight)
            else:
                self.diagonal(actual, role, weight)

    def syllable(self, char):
        index = ord(char)-0xAC00
        initial, vowel, final = L[index//588], V[index%588//28], T[index%28]
        if vowel in MIXED:
            if final:
                lb, hb, vb = (125, 110, 450, 340), (110, 385, 530, 540), (600, 105, 805, 550)
            else:
                lb, hb, vb = (125, 145, 450, 450), (110, 510, 530, 755), (600, 120, 805, 790)
            self.component(initial, lb)
            self.component(MIXED[vowel][0], hb)
            self.component(MIXED[vowel][1], vb, .92)
            layout = "mixed-final" if final else "mixed"
        elif vowel in "ㅗㅛㅜㅠㅡ":
            if final:
                lb, vb = (230, 100, 690, 350), (110, 410, 800, 550)
            else:
                lb, vb = (220, 125, 700, 455), (110, 520, 800, 780)
            if initial in "ㅇㅎ":
                # Round forms must not be mechanically flattened into the
                # wide ㄱ box. The same oval master gets a rounder context.
                lb = (270, 100, 650, 365) if final else (265, 115, 655, 470)
            elif initial in DOUBLE:
                lb = (180, lb[1], 740, lb[3])
            self.component(initial, lb)
            self.component(vowel, vb)
            layout = "horizontal-final" if final else "horizontal"
        else:
            if final:
                lb, vb = (130, 145, 480, 520), (560, 110, 790, 550)
            else:
                lb, vb = (130, 205, 480, 705), (560, 135, 790, 785)
            self.component(initial, lb)
            self.component(vowel, vb, .94 if vowel in "ㅐㅒㅔㅖ" else 1)
            layout = "vertical-final" if final else "vertical"
        if final:
            final_box = (170, 640, 750, 810)
            if final == "ㅇ":
                final_box = (275, 610, 645, 815)
            elif final in "ㅁㅂ":
                final_box = (220, 620, 700, 810)
            elif final == "ㄹ":
                final_box = (190, 610, 730, 815)
            elif final == "ㅎ":
                final_box = (260, 600, 660, 815)
            elif final in CLUSTERS:
                final_box = (155, 610, 765, 815)
            self.component(final, final_box, .92)
        return {"decomposition": [initial, vowel, final], "layout": layout, "components": self.components}


def to_glyph(path):
    # Union overlapping strokes and normalize contour winding BEFORE quadratic
    # conversion. The Y flip makes the exterior clockwise for TrueType.
    clean = pathops.simplify(path, clockwise=False)
    pen = TTGlyphPen(None)
    clean.draw(TransformPen(Cu2QuPen(pen, max_err=.5), (1, 0, 0, -1, 0, 920)))
    return pen.glyph(), clean


def source_svg(jamo_paths):
    """Editable vector construction sheet, not an image-generator mockup."""
    items = ['<svg xmlns="http://www.w3.org/2000/svg" width="1400" height="1600" viewBox="0 0 1400 1600">', '<rect width="1400" height="1600" fill="#f7f2e8"/>', '<g fill="#70472f" font-family="sans-serif" font-size="17"><text x="50" y="45">Writing Human / original jamo masters / 0.004</text></g>']
    for index, (jamo, path) in enumerate(jamo_paths.items()):
        col, row = index%7, index//7
        pen = SVGPathPen(None)
        path.draw(pen)
        items.append(f'<g transform="translate({col*195+48} {row*280+95}) scale(.19)"><path d="{pen.getCommands()}" fill="#302c27"/></g>')
        items.append(f'<text x="{col*195+65}" y="{row*280+280}" fill="#8d7f6d" font-size="14" font-family="sans-serif">{escape(jamo)} / U+{ord(jamo):04X}</text>')
    items.append('</svg>')
    (ROOT / "source/jamo-masters-v004.svg").write_text('\n'.join(items)+'\n')


def build():
    source = json.loads(SOURCE.read_text())
    review = json.loads(REVIEW.read_text())
    text = '\n'.join(review["paragraphs"]+review["structure_rows"])
    chars = sorted({c for c in text if 0xAC00 <= ord(c) <= 0xD7A3})
    order = [".notdef", "space", "period", "comma"]
    glyphs, metrics, cmap, evidence = {}, {}, {}, {}
    missing = pathops.Path()
    polygon(missing, [(130, 100), (790, 100), (790, 820), (130, 820)])
    inner = pathops.Path()
    polygon(inner, [(180, 150), (180, 770), (740, 770), (740, 150)])
    missing.addPath(inner)
    glyphs[".notdef"], _ = to_glyph(missing)
    metrics[".notdef"] = (920, 130)
    glyphs["space"] = TTGlyphPen(None).glyph()
    metrics["space"], cmap[32] = (410, 0), "space"
    for char, name in ((".", "period"), (",", "comma")):
        d = Designer(source)
        # Small punctuation uses a filled lentil; a counter this small is noise.
        d.path = pathops.Path()
        d.path.moveTo(157, 770)
        d.path.cubicTo(198, 770, 199, 831, 160, 835)
        d.path.cubicTo(122, 837, 120, 774, 157, 770)
        d.path.close()
        if char == ",":
            d.path.moveTo(174, 812)
            d.path.cubicTo(196, 851, 164, 888, 131, 898)
            d.path.lineTo(126, 884)
            d.path.cubicTo(156, 863, 157, 845, 151, 826)
            d.path.close()
        glyphs[name], _ = to_glyph(d.path)
        metrics[name], cmap[ord(char)] = (310, 0), name
    for char in chars:
        designer = Designer(source)
        info = designer.syllable(char)
        name = f"uni{ord(char):04X}"
        glyphs[name], _ = to_glyph(designer.path)
        metrics[name] = (source["advance"], 0)
        cmap[ord(char)] = name
        order.append(name)
        evidence[char] = info
    builder = FontBuilder(1000, isTTF=True)
    builder.setupGlyphOrder(order)
    builder.setupCharacterMap(cmap)
    builder.setupGlyf(glyphs)
    for name, glyph in glyphs.items():
        if glyph.numberOfContours:
            metrics[name] = (metrics[name][0], glyph.xMin)
    builder.setupHorizontalMetrics(metrics)
    builder.setupHorizontalHeader(ascent=940, descent=-160, lineGap=100)
    builder.setupNameTable({
        "familyName": FAMILY, "styleName": "Regular",
        "uniqueFontIdentifier": "writing-human-original-vector-proof-0.005",
        "fullName": f"{FAMILY} Regular", "psName": "WritingHumanDevelopmentProof-Regular",
        "version": "Version 0.005; ORIGINAL VECTOR DEVELOPMENT PROOF",
        "description": "Original shared jamo stroke masters, contextual layouts. Limited development specimen. Not production.",
    })
    builder.setupOS2(sTypoAscender=940, sTypoDescender=-160, sTypoLineGap=100, usWinAscent=1000, usWinDescent=200, usWeightClass=400, fsSelection=0x40)
    builder.setupPost()
    builder.setupMaxp()
    builder.font["head"].fontRevision = .005
    builder.font["head"].created = builder.font["head"].modified = 3877113600
    builder.font.recalcTimestamp = False
    OUT.mkdir(exist_ok=True)
    target = OUT / "WritingHumanDevelopmentProof-Regular.ttf"
    builder.save(str(target))
    font = TTFont(target, checkChecksums=2)
    assert set(font.getBestCmap()) == set(cmap)
    assert not {ord(c) for c in text if not c.isspace()} - set(cmap)
    for char in chars:
        glyph = font["glyf"][cmap[ord(char)]]
        assert glyph.numberOfContours > 0
        assert 0 <= glyph.xMin < glyph.xMax <= 920, (char, glyph.xMin, glyph.xMax)
        assert -160 <= glyph.yMin < glyph.yMax <= 940
        assert font["hmtx"][cmap[ord(char)]][0] == source["advance"]
        evidence[char]["ink_bounds"] = [glyph.xMin, glyph.yMin, glyph.xMax, glyph.yMax]
    # A genuine inner contour must remain; this does not certify the whole shape.
    for char in "인알오한은음문":
        assert font["glyf"][cmap[ord(char)]].numberOfContours >= 2
    masters = {}
    for jamo in source["jamo"]:
        designer = Designer(source)
        designer.component(jamo, (100, 100, 800, 800))
        masters[jamo] = pathops.simplify(designer.path)
    source_svg(masters)
    manifest = {
        "status": "development-specimen-not-production", "revision": "0.005", "family": FAMILY,
        "hangul_syllables": len(chars), "characters": ''.join(chars)+" .,",
        "specimen": '\n'.join(review["paragraphs"]),
        "master_sha256": hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
        "builder_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        "review_sha256": hashlib.sha256(REVIEW.read_bytes()).hexdigest(),
        "font_sha256": hashlib.sha256(target.read_bytes()).hexdigest(),
        "source": source["method"],
        "design_intent": ["shared upright oval and open counters", "62/34 contrast before density corrections", "quiet pen-cut shoulders and curved short terminals", "six contextual syllable layouts with round and final optical variants"],
        "glyphs": evidence,
        "not_implemented": ["full Hangul and conjoining-jamo shaping", "Latin and digits", "hinting", "final optical corrections", "device review", "production app integration"],
    }
    (OUT / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+'\n')
    (ROOT / "specimen.txt").write_text(manifest["specimen"]+'\n')
    print(json.dumps({"font": str(target), "hangul": len(chars), "cmap_entries": len(cmap), "bytes": target.stat().st_size, "sha256": manifest["font_sha256"]}, ensure_ascii=False))


if __name__ == "__main__":
    build()
