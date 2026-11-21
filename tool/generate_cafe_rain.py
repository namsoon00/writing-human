"""Deterministic, synthetic quiet rain; no recording or third-party samples."""
import array
import math
import random
import wave
from pathlib import Path

rate = 22050
seconds = 8
rng = random.Random(20261122)
low = 0.0
samples = []
for i in range(rate * seconds):
    noise = rng.uniform(-1.0, 1.0)
    low = 0.91 * low + 0.09 * noise
    envelope = 0.84 + 0.09 * math.sin(2 * math.pi * i / (rate * seconds))
    samples.append((0.075 * noise + 0.15 * low) * envelope)
# Match the loop endpoints without a gap or a sudden click.
fade = int(rate * 0.12)
for i in range(fade):
    t = i / fade
    mixed = samples[-fade + i] * (1 - t) + samples[i] * t
    samples[i] = mixed
pcm = array.array('h', (int(max(-1, min(1, value)) * 32767) for value in samples))
path = Path('assets/audio/cafe-rain.wav')
with wave.open(str(path), 'wb') as sound:
    sound.setnchannels(1)
    sound.setsampwidth(2)
    sound.setframerate(rate)
    sound.writeframes(pcm.tobytes())
