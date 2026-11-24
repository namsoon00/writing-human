"""Compare actual font ink geometry and rendered reading samples, not mockups."""
import argparse
import hashlib
import json
from pathlib import Path
from statistics import median
from fontTools.ttLib import TTFont
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
APP = ROOT.parents[1]
SAMPLES = [
    '가나다라마바사아자차카타파하',
    '고노도모보소오조초코토포호',
    '구누두무부수우주추쿠투푸후',
    '그느드므브스으즈츠크트프흐',
    '기니디미비시이지치키티피히',
    '각간갈감갑강 꽃값흙삶앉읊',
    '왜외웨위의 괜괄괌괍괏광괗',
    '나는 이제 너 없이도 너를 좋아할 수 있다.',
    '괜찮다. 서두르지 않아도 된다.',
    '2026년 Writing Human, 오늘도 한 쪽.',
]


def measurements(font):
    cmap = font.getBestCmap()
    columns = {name: [] for name in ['width', 'height', 'bottom']}
    for cp in range(0xAC00, 0xD7A4):
        g = font['glyf'][cmap[cp]]
        for name, value in [('width', g.xMax-g.xMin), ('height', g.yMax-g.yMin), ('bottom', g.yMin)]:
            columns[name].append(value)
    return {name: {'min': min(values), 'median': median(values), 'max': max(values), 'spread': max(values)-min(values)}
            for name, values in columns.items()}


def compare(reference, candidate, out):
    before, after = TTFont(reference), TTFont(candidate)
    old_map, new_map = before.getBestCmap(), after.getBestCmap()
    assert old_map == new_map, 'Character coverage changed'
    for cp, name in old_map.items():
        assert before['hmtx'][name][0] == after['hmtx'][name][0], f'Advance changed: {cp:04X}'
        if not 0xAC00 <= cp <= 0xD7A3:
            old_coords = before['glyf'][name].getCoordinates(before['glyf'])
            new_coords = after['glyf'][name].getCoordinates(after['glyf'])
            assert old_coords == new_coords, f'Non-Hangul outline changed: {cp:04X}'
    for tag in ['hhea', 'OS/2', 'GSUB', 'GPOS']:
        assert before[tag].compile(before) == after[tag].compile(after), f'{tag} changed'
    old, new = measurements(before), measurements(after)
    assert new['height']['spread'] < old['height']['spread'] / 3
    assert new['width']['spread'] < old['width']['spread'] / 2
    assert new['bottom']['spread'] <= 6
    result = {'reference_sha256': hashlib.sha256(reference.read_bytes()).hexdigest(),
              'candidate_sha256': hashlib.sha256(candidate.read_bytes()).hexdigest(),
              'before': old, 'after': new, 'unchanged_advances': len(old_map),
              'unchanged': ['cmap', 'non-Hangul outlines', 'line metrics', 'NFC/NFD GSUB', 'Latin kerning'],
              'scope': 'Exhaustive ink bounds plus actual FreeType renders; not final optical approval or physical-device review'}
    out.mkdir(parents=True, exist_ok=True)
    (out/'balance-audit.json').write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n')
    label_path = str(APP/'assets/fonts/NanumGothic-Regular.ttf')
    label = ImageFont.truetype(label_path, 27)
    small = ImageFont.truetype(label_path, 19)
    # Same point size and baseline on each side. No per-letter image resizing.
    page = Image.new('RGB', (1800, 1370), '#f7f2e8')
    d = ImageDraw.Draw(page)
    for x, title in [(55, '이전 0.008'), (935, '보정 0.009')]:
        d.text((x, 35), title, font=label, fill='#70472f')
    for row, text in enumerate(SAMPLES):
        y = 145 + row*112
        for x, path in [(55, reference), (935, candidate)]:
            f = ImageFont.truetype(str(path), 45)
            lines = ['']
            for word in text.split(' '):
                proposal = (lines[-1] + ' ' + word).strip()
                if d.textlength(proposal, font=f) > 805:
                    lines.append(word)
                else:
                    lines[-1] = proposal
            for line_index, line in enumerate(lines):
                baseline = y + 50 * line_index
                d.line((x, baseline-4.5, x+810, baseline-4.5), fill='#ddd4c7')
                d.text((x, baseline), line, font=f, fill='#302c27', anchor='ls')
    d.text((55, 1300), '실제 TTF / 같은 45px / FreeType 렌더 · 실기기 캡처 아님', font=small, fill='#70472f')
    page.save(out/'balance-comparison.png')
    # Integer raster sizes represent the app's actual small labels and body.
    page = Image.new('RGB', (1300, 1080), '#f7f2e8'); d=ImageDraw.Draw(page)
    for x, title in [(40, '이전 0.008'), (690, '보정 0.009')]:
        d.text((x, 30), title, font=label, fill='#70472f')
    y=120
    for size in [14, 18, 20, 24, 30, 42]:
        d.text((40, y-size*.9-30), f'{size}px', font=small, fill='#70472f')
        for x,path in [(40,reference),(690,candidate)]:
            f=ImageFont.truetype(str(path),size)
            d.text((x,y),'작은 하루를 기록해요.',font=f,fill='#302c27',anchor='ls')
            d.text((x,y+size*1.9),'괜찮다. 꽃과 흙. 2026',font=f,fill='#302c27',anchor='ls')
        y += size*3.6+40
    page.save(out/'reading-sizes.png')
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('reference',type=Path)
    p.add_argument('candidate',type=Path)
    p.add_argument('--output',type=Path,default=APP/'artifacts/typeface/v009')
    args=p.parse_args();compare(args.reference,args.candidate,args.output)
