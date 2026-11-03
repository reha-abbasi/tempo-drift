"""render Rio's options: rio_render.py OUT STYLE... (all when none) [--stems] [--mel=-4] [--melody=a+b] [--tune=NAME | --course=baked.json]"""
import json, os, sys, time
import numpy as np
from engine import loudness, master_gain, to_mp3, to_ogg
from render import preview_gains
import rio_real as rio

HERE = os.path.dirname(os.path.abspath(__file__))
TARGET = -12.0


def render(style, out, stems=False, mel_db=0.0, melody=None, tag='', tune=None, course=None):
    t0 = time.time()
    c = json.load(open(course or os.path.join(HERE, 'courses/sunset_1.json')))
    if tune:
        import carnival
        c, dem = carnival.course(c, tune)
        print(f'{tune}: {len(c["notes"])} rings, {len(c["ghosts"])} ghosts, {dem} made ghosts (too close)', flush=True)
    L, S = rio.build(c, style, mel_db=mel_db, melody=melody)
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
    to_mp3(prev, os.path.join(out, f'{style}{tag}.mp3'))
    if stems:
        d = os.path.join(out, style)
        os.makedirs(d, exist_ok=True)
        for k, l in L.items():
            to_ogg(l.x * G * mg, os.path.join(d, k + '.ogg'), 5 if k in ('core', 'full', 'ghost', 'melA', 'melB') else 3)
    print(f'{style}{tag}: {lufs:.1f} LUFS, peak {peak:.1f} dBFS, {time.time() - t0:.0f}s', flush=True)


if __name__ == '__main__':
    out = sys.argv[1]
    md = float(next((a.split('=')[1] for a in sys.argv if a.startswith('--mel=')), 0))
    mel = next((a.split('=')[1] for a in sys.argv if a.startswith('--melody=')), None)
    tune = next((a.split('=')[1] for a in sys.argv if a.startswith('--tune=')), None)
    course = next((a.split('=', 1)[1] for a in sys.argv if a.startswith('--course=')), None)
    for s in [a for a in sys.argv[2:] if not a.startswith('--')] or rio.STYLES:
        render(s, out, stems='--stems' in sys.argv, mel_db=md, melody=mel, tune=tune, course=course,
               tag=('_' + tune if tune else '') + ('_' + mel if mel else ''))
