"""Original seamless leaf rustle and a quiet four-note cafe motif. No samples."""
from pathlib import Path
import array
import math
import random
import wave

RATE = 22050
ROOT = Path(__file__).resolve().parents[1]


def write(name, values):
    peak = max(abs(v) for v in values) or 1
    # Small PCM peaks leave room for four concurrent, independently mixed loops.
    pcm = array.array('h', (round(v / peak * .26 * 32767) for v in values))
    path = ROOT / 'assets' / 'audio' / f'cafe-{name}.wav'
    with wave.open(str(path), 'wb') as audio:
        audio.setnchannels(1)
        audio.setsampwidth(2)
        audio.setframerate(RATE)
        audio.writeframes(pcm.tobytes())
    print(name, len(values) / RATE, path.stat().st_size)


def leaves():
    seconds = 8
    rng = random.Random(20261124)
    slow = fast = 0.0
    values = []
    for i in range(RATE * seconds):
        t = i / RATE
        n = rng.uniform(-1, 1)
        slow = .985 * slow + .015 * n
        fast = .73 * fast + .27 * n
        breath = .23 + .77 * (.5 - .5 * math.cos(2 * math.pi * t / seconds)) ** 2
        values.append((fast - slow) * breath)
    # Endpoint crossfade is periodic; no silence or step at the loop boundary.
    count = int(RATE * .15)
    tail = values[-count:]
    for i in range(count):
        f = i / count
        values[-count + i] = tail[i] * (1 - f) + values[i] * f
    return values[count:]


def music():
    seconds = 24
    notes = [(0, 196), (6.7, 293.665), (13.1, 246.942), (19.2, 220)]
    values = []
    for i in range(RATE * seconds):
        t = i / RATE
        value = 0
        for onset, frequency in notes:
            age = (t - onset) % seconds
            if age > 7:
                continue
            # A rounded attack, soft decay and a silent end before wrapping.
            envelope = min(1, age / .045) * math.exp(-age * .7) * min(1, (7 - age) / .4)
            wave_t = math.sin(2 * math.pi * frequency * age)
            wave_t += .16 * math.sin(2 * math.pi * frequency * 2 * age) * math.exp(-age)
            value += wave_t * envelope
        values.append(value)
    return values


if __name__ == '__main__':
    write('leaves', leaves())
    write('music', music())
