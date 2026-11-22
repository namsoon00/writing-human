"""Original deterministic synthetic sounds; no external samples or recordings."""
import array
import math
from pathlib import Path
import random
import wave
RATE=22050

def write(name,seconds,sample):
    pcm=array.array('h')
    rng=random.Random(221123)
    low=0.
    for i in range(int(RATE*seconds)):
        t=i/RATE
        low=.95*low+.05*rng.uniform(-1,1)
        envelope=min(1,t/.02,(seconds-t)/.08)
        value=sample(t,low,rng)*envelope
        pcm.append(round(max(-.8,min(.8,value))*32767))
    peak=max(map(abs,pcm)) or 1
    level={'bell':.32,'tea':.38,'water':.45}[name]
    pcm=array.array('h',(round(v*32767*level/peak) for v in pcm))
    with wave.open(str(Path('assets/audio')/f'cafe-{name}.wav'),'wb') as f:
        f.setnchannels(1);f.setsampwidth(2);f.setframerate(RATE);f.writeframes(pcm.tobytes())

write('bell',5,lambda t,n,r: sum(a*math.exp(-t*d)*math.sin(2*math.pi*freq*t) for freq,a,d in [(660,.18,.85),(1327,.07,1.4),(1881,.035,2.5),(2772,.02,3.8)]))
write('tea',2.2,lambda t,n,r: (.07*n+.018*r.uniform(-1,1))*(.7+.3*math.sin(t*18))+.014*math.sin(2*math.pi*(800*t+25*math.sin(t*8)))*math.sin(t*35)**12)
write('water',8,lambda t,n,r: .07*n+.006*math.sin(2*math.pi*1200*t)*max(0,math.sin(t*6))**20)
