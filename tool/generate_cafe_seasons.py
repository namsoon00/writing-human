"""Original tonal scores and short footsteps; CC0 recorded porch rain.

The removed broadband ambient loops are never read. Intermediate PCM/downloads
are confined to a named TemporaryDirectory and removed on success or failure.
Requires the macOS system afconvert only to encode compact AAC assets.
"""
from pathlib import Path
import array
import hashlib
import json
import math
import random
import subprocess
import tempfile
import urllib.request
import wave

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/audio'
RATE = 24000


def write(path, values, peak=.25):
    maximum = max(map(abs, values)) or 1
    data = array.array('h', (round(v / maximum * peak * 32767) for v in values))
    with wave.open(str(path), 'wb') as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(data.tobytes())


def score(theme):
    samples = array.array('d', [0]) * (RATE * 64)
    # A complete sparse sixteen-bar phrase, with a quiet four-second tail.
    roots = [48, 45, 53, 48, 43, 45, 53, 48]
    melody = [67, 64, 62, 64, 69, 67, 65, 64, 62, 60, 64, 67, 65, 64, 62, 60]
    events = [(i * 7.5, root, .52) for i, root in enumerate(roots)]
    events += [(1.3 + i * 3.55, n + (0 if theme == 'paper' else -12), .65) for i, n in enumerate(melody)]
    for onset, midi, volume in events:
        frequency = 440 * 2 ** ((midi - 69) / 12)
        length = 4.2 if theme == 'paper' else 3.2
        for i in range(int(RATE * length)):
            age = i / RATE
            index = int(onset * RATE) + i
            if index >= len(samples):
                break
            envelope = min(1, age / .022) * min(1, (length - age) / .4)
            tone = 0
            for harmonic, gain in [(1, 1), (2, .27), (3, .12), (4, .045)]:
                decay = (.85 if theme == 'paper' else 1.1) + harmonic * .14
                tone += gain * math.sin(2 * math.pi * frequency * harmonic * age) * math.exp(-age * decay)
            samples[index] += tone * envelope * volume
    return samples


def footstep(snow):
    rng = random.Random(81 if snow else 52)
    result = []
    filtered = 0
    for i in range(int(RATE * .42)):
        t = i / RATE
        filtered = .75 * filtered + .25 * rng.uniform(-1, 1)
        # Discrete contact bursts with silence between; never an ambient bed.
        envelope = sum(math.exp(-((t - c) / .017) ** 2) for c in ([.055, .11, .17] if snow else [.04, .12, .23]))
        result.append(filtered * envelope)
    return result


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='writing-cafe-season-audio-') as directory:
        temp = Path(directory)
        for theme in ['paper', 'dusk']:
            pcm = temp / (theme + '.wav')
            write(pcm, score(theme))
            subprocess.run(['/usr/bin/afconvert', str(pcm), str(OUT / f'cafe-score-{theme}.m4a'), '-f', 'm4af', '-d', 'aac', '-b', '64000'], check=True)
        for name in ['leaf', 'snow']:
            write(OUT / f'cafe-season-{name}.wav', footstep(name == 'snow'), peak=.16)
        source = 'https://cdn.freesound.org/previews/398/398740_5923045-hq.mp3'
        downloaded = temp / 'porch.mp3'
        downloaded.write_bytes(urllib.request.urlopen(source, timeout=45).read())
        pcm = temp / 'porch.wav'
        subprocess.run(['/usr/bin/afconvert', str(downloaded), str(pcm), '-f', 'WAVE', '-d', 'LEI16@24000', '-c', '1'], check=True)
        with wave.open(str(pcm)) as f:
            raw = array.array('h', f.readframes(f.getnframes()))
        # Gentle lowpass softens bright recording hiss; DC removal and edge
        # fades preserve the recorded drops. This is not a synthetic noise bed.
        mean = sum(raw) / len(raw)
        low = 0
        values = []
        for i, sample in enumerate(raw):
            low += .30 * (sample - mean - low)
            edge = min(1, i / (RATE * .8), (len(raw) - i) / (RATE * .8))
            values.append(low * edge)
        quiet = temp / 'rain.wav'
        write(quiet, values, peak=.22)
        subprocess.run(['/usr/bin/afconvert', str(quiet), str(OUT / 'cafe-season-rain.m4a'), '-f', 'm4af', '-d', 'aac', '-b', '64000'], check=True)
        credits = {'rain': {'title': 'rain - drops on porch', 'author': 'Anthousai', 'source': 'https://freesound.org/people/Anthousai/sounds/398740/', 'download': source, 'license': 'CC0-1.0', 'licenseUrl': 'https://creativecommons.org/publicdomain/zero/1.0/', 'edits': 'mono 24kHz, DC removal, low-pass, edge fade, level reduction, AAC'}, 'scores': 'Original sixteen-bar sparse tonal renderings; no sampled or copyrighted melody', 'footsteps': 'Original short contact bursts; no continuous noise loop', 'files': {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(OUT.glob('cafe-s*.m4a'))}}
        (OUT / 'cafe-seasons-credits.json').write_text(json.dumps(credits, indent=2) + '\n')
    print('Seasonal audio generated; temporary PCM and downloads cleaned.')


if __name__ == '__main__':
    main()
