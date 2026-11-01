"""Render an episode's soundtrack layers, master them together, and write a preview of a typical run.

usage: render.py COURSE.json STYLE FLAVOUR OUT_DIR [--stems]
"""
import json, os, sys, time
import numpy as np
from engine import *

TARGET_LUFS = -11.0


def preview_gains(S, n):
    """the band as it builds during a good run: drums and bass, then the whole band, the arpeggio, the percussion,
    and Overdrive through the C section"""
    g = {k: np.zeros(n) for k in ['core', 'full', 'arp', 'perc', 'od', 'jet', 'ghost', 'melA', 'melB']}
    for b, B in enumerate(S.bars):
        a, z = ns(b * S.bar), min(n, ns((b + 1) * S.bar))
        lvl = 1 if b < 1 else 2 if b < 5 else 3 if b < 9 else 4
        g['core'][a:z] = lvl < 2
        g['full'][a:z] = lvl >= 2
        g['arp'][a:z] = lvl >= 3
        g['perc'][a:z] = lvl >= 4
        g['od'][a:z] = B['sec'] == 'C'
    tail = ns(len(S.bars) * S.bar)
    for k in ('full', 'arp', 'perc'):
        g[k][tail:] = g[k][tail - 1]
    for k in ('ghost', 'melA', 'melB'):
        g[k][:] = 1.0
    ramp = np.ones(ns(0.06)) / ns(0.06)
    return {k: np.convolve(v, ramp, mode='same') for k, v in g.items()}


def main():
    course, style, flavour, out = sys.argv[1:5]
    stems = '--stems' in sys.argv
    c = json.load(open(course))
    mod = __import__(style)
    t0 = time.time()
    L, S = mod.build(c, flavour)
    print(f'built in {time.time() - t0:.1f}s')
    n = L['core'].n
    gains = preview_gains(S, n)
    loudest = sum(L[k].x for k in ('full', 'arp', 'perc', 'od', 'ghost', 'melA', 'melB'))
    G = 10 ** ((TARGET_LUFS - (loudness(loudest)[0] or -20)) / 20)
    for _ in range(3):
        mg = master_gain(loudest * G, ceiling_db=-1.5, glue_db=-6.0, glue_ratio=2.0)
        prev = sum(L[k].x * G * mg * gains[k] for k in gains)
        prev = prev * master_gain(prev, ceiling_db=-1.5, glue_db=40.0)   # a safety limiter on the preview itself
        lufs, peak = loudness(prev)
        print(f'  pre-gain {20 * np.log10(G):+.1f} dB -> preview {lufs:.1f} LUFS, peak {peak:.1f} dBFS')
        if lufs is None or abs(lufs - TARGET_LUFS) < 0.4:
            break
        G *= 10 ** ((TARGET_LUFS - lufs) / 20 * 0.9)
    os.makedirs(out, exist_ok=True)
    name = f"{c['map']}_{c['ep']}_{flavour}"
    to_mp3(prev, os.path.join(out, name + '.mp3'))
    if stems:
        d = os.path.join(out, name)
        os.makedirs(d, exist_ok=True)
        for k, l in L.items():
            to_ogg(l.x * G * mg, os.path.join(d, k + '.ogg'), 5 if k in ('core', 'full', 'ghost', 'melA', 'melB') else 3)
    for k, l in L.items():
        pk = 20 * np.log10(np.max(np.abs(l.x * G * mg)) + 1e-9)
        print(f'  {k:6s} peak {pk:6.1f} dBFS')
    print(f'done in {time.time() - t0:.1f}s ->', os.path.join(out, name + '.mp3'))


if __name__ == '__main__':
    main()
