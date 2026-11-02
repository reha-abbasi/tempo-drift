"""render London's jazz options: jazz_render.py OUT STYLE... (all styles when none given); --stems writes game layers"""
import json, os, sys, time
import numpy as np
from engine import loudness, master_gain, to_mp3, to_ogg
from render import preview_gains
import jazz

HERE = os.path.dirname(os.path.abspath(__file__))
TARGET = -12.0


def render(style, out, course='courses/old_0.json', stems=False, mel_db=0.0):
    t0 = time.time()
    c = json.load(open(os.path.join(HERE, course)))
    L, S = jazz.build(c, style, mel_db=mel_db)
    gains = preview_gains(S, L['core'].n)
    loudest = sum(L[k].x for k in ('full', 'arp', 'perc', 'od', 'ghost', 'melA', 'melB'))
    G = 10 ** ((TARGET - loudness(loudest)[0]) / 20)
    for _ in range(4):
        mg = master_gain(loudest * G, ceiling_db=-1.5, glue_db=-8.0, glue_ratio=1.8)
        prev = sum(L[k].x * G * mg * gains[k] for k in gains)
        prev = prev * master_gain(prev, ceiling_db=-1.5, glue_db=40.0)
        lufs, peak = loudness(prev)
        if abs(lufs - TARGET) < 0.3:
            break
        G *= 10 ** ((TARGET - lufs) / 20)
    os.makedirs(out, exist_ok=True)
    to_mp3(prev, os.path.join(out, f'{style}.mp3'))
    if stems:
        d = os.path.join(out, style)
        os.makedirs(d, exist_ok=True)
        for k, l in L.items():
            to_ogg(l.x * G * mg, os.path.join(d, k + '.ogg'), 5 if k in ('core', 'full', 'ghost', 'melA', 'melB') else 3)
    print(f'{style}: {lufs:.1f} LUFS, peak {peak:.1f} dBFS, {time.time() - t0:.0f}s', flush=True)


if __name__ == '__main__':
    out = sys.argv[1]
    styles = [a for a in sys.argv[2:] if not a.startswith('--')] or list(jazz.STYLES)
    for s in styles:
        md = float(next((a.split('=')[1] for a in sys.argv if a.startswith('--mel=')), 0))
        render(s, out, stems='--stems' in sys.argv, mel_db=md)
