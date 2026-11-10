"""Render actual TTF proofs with FreeType. No font fallback or image synthesis."""

from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
FONT = ROOT / "release/WritingHumanDevelopment-Regular.ttf"
OUT = ROOT.parents[1] / "artifacts/typeface/v007"
INK = "#302c27"
PAPER = "#f7f2e8"


def render():
    OUT.mkdir(parents=True, exist_ok=True)
    page = Image.new("RGB", (1500, 1700), PAPER)
    draw = ImageDraw.Draw(page)
    y = 90
    samples = [
        (64, "쓰는 인간체"),
        (28, "0.007 / 실제 TTF / 전체 문자 개발판 / FreeType 렌더"),
        (38, "꽃잎을 읽는 마음, 곁에 두고 싶은 문장."),
        (38, "괜찮다. 천천히 써도 한 권의 기록이 된다."),
        (38, "값싼 흙, 닭, 삶, 앉다, 읊다, 똠뷁힣"),
        (38, "Writing Human — Paper & Ink, 2026."),
        (34, "ABCDEFGHIJKLMNOPQRSTUVWXYZ"),
        (34, "abcdefghijklmnopqrstuvwxyz"),
        (40, "0123456789  ₩12,345  09:41  +−×÷=±"),
        (38, "‘마음’ “문장” … · 「기록」 『책』 〈제목〉"),
        (34, "ㄱㄲㄳㄴㄵㄶㄷㄸㄹㄺㄻㄼㄽㄾㄿㅀㅁㅂㅃㅄ"),
        (34, "ㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎㅏㅐㅑㅒㅓㅔㅕㅖㅗㅘㅙㅚㅛㅜㅝㅞㅟㅠㅡㅢㅣ"),
    ]
    for size, text in samples:
        font = ImageFont.truetype(str(FONT), size)
        draw.text((80, y), text, font=font, fill=INK)
        y += size * 2 + 10
    page.save(OUT / "specimen-freetype.png")
    # Full 19 initial x 21 vowel x 28 final grid: every Hangul appears once.
    for initial in range(19):
        sheet = Image.new("RGB", (1500, 1900), PAPER)
        draw = ImageDraw.Draw(sheet)
        font = ImageFont.truetype(str(FONT), 36)
        label = ImageFont.truetype(str(FONT), 22)
        start = 0xAC00 + initial * 588
        draw.text((55, 25), f"{initial + 1:02d} / U+{start:04X} – U+{start+587:04X}", font=label, fill=INK)
        for final in range(28):
            for vowel in range(21):
                cp = start + vowel * 28 + final
                draw.text((55 + vowel * 68, 85 + final * 63), chr(cp), font=font, fill=INK)
        sheet.save(OUT / f"hangul-{initial + 1:02d}.png")
    print(f"Wrote specimen and 19 exhaustive Hangul sheets to {OUT}")


if __name__ == "__main__":
    render()
