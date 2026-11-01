"""What every era's arrangement shares: the course, chords, the melody on its layers, and how much the melody stands out."""
import random
import numpy as np
from engine import *

LAYERS = ['core', 'full', 'arp', 'perc', 'od', 'jet', 'ghost', 'melA', 'melB']
ERAS = ['old', 'sunset', 'rain']


def ease_for(c):
    """1.0 in the first city (London 1890), falling evenly to 0.0 in the last (Las Vegas 2099). The easier the city,
    the more the melody you swipe to stands out from the band."""
    g = ERAS.index(c['map']) * 8 + int(c['ep'])
    return 1.0 - g / 23.0


class Song:
    def __init__(self, c):
        self.c = c
        self.beat = c['beat']
        self.bar = c['bar']
        self.bars = c['bars']
        self.swing = c.get('swing', 0.0)
        self.dur = c['len'] * c['bar'] + 3.0
        self.rng = random.Random(c['map'] + str(c['ep']))

    def t(self, b, beats):
        """a time in a bar, in beats (straight)"""
        return b * self.bar + beats * self.beat

    def at(self, b, eighth):
        """the time of an eighth in a bar, swung like the melody"""
        e = eighth + (self.swing if eighth % 2 else 0.0)
        return b * self.bar + e * self.beat / 2.0

    def chord(self, b):
        B = self.bars[min(b, len(self.bars) - 1)]
        return B['root'], B['iv']

    def hv(self, v, spread=0.08):
        return v * (1.0 + self.rng.uniform(-spread, spread))


def bass_note(root, lo=33):
    p = root % 12 + lo - lo % 12
    while p < lo:
        p += 12
    while p >= lo + 12:
        p -= 12
    return p


def voicing(root, iv, lo, hi, color=False):
    ps = sorted({((root + x - lo) % 12) + lo for x in iv})
    if color and len(iv) >= 3 and iv[1] in (3, 4):
        ninth = ((root + 2 - lo) % 12) + lo
        if ninth not in ps and len(ps) < 4:
            ps.append(ninth)
    return sorted(p if p <= hi else p - 12 for p in ps)


def lead_levels(ease):
    """ring-note gain, in-between-note gain, echo and room for the melody"""
    ring = 0.55 * 10 ** (4.0 * ease / 20)       # up to +4 dB in the first city
    ghost = 0.55 * (0.8 - 0.5 * ease)            # in-between notes pulled back where it's easy
    echo = 0.06 + 0.22 * (1 - ease)              # fewer echoes to mistake for notes where it's easy
    room = 0.08 + 0.24 * (1 - ease)
    return ring, ghost, echo, room


def place_lead(L, c, note_fn, ease, ring_len=0.85):
    """synthesized melody: every ring note on melA / melB, the in-between notes on ghost"""
    ring, ghost, _, _ = lead_levels(ease)
    eighth = c['beat'] / 2.0
    for i, nt in enumerate(c['notes']):
        d = max(0.12, nt['len'] * eighth * ring_len)
        L['melA' if i % 2 == 0 else 'melB'].add(note_fn(nt['note'], d, True), nt['t'], ring)
    for g in c['ghosts']:
        d = max(0.1, g['len'] * eighth * ring_len * 0.95)
        L['ghost'].add(note_fn(g['note'], d, False), g['t'], ghost)


def finish_lead(L, S, ease, kicks, hp_hz=200.0, bright_db=2.0, room_size=0.8):
    """the melody's echo and room, less of both where it's easy; it ducks a little under the kick only where it's hard"""
    _, _, echo, room = lead_levels(ease)
    sc = sidechain(L['melA'].n, kicks, 0.25 * (1 - ease), 0.12) if kicks else 1.0
    for k in ('melA', 'melB', 'ghost'):
        x = delay(L[k].x, S.beat * 0.75, feedback=0.35 + 0.1 * (1 - ease), mix=echo, hp_hz=500, lp_hz=6500)
        x = reverb(x, size=room_size, wet=room)
        L[k].x = eq(x, pb.HighpassFilter(hp_hz), pb.HighShelfFilter(3000, bright_db)) * sc


def vinyl(n, level=0.03):
    """the crackle and hiss of an old record"""
    x = hp(noise(n), 2500) * 0.08
    clicks = np.zeros(n)
    for i in rng.integers(0, n, int(n / SR * 9)):
        clicks[i:i + 12] += rng.uniform(-1, 1) * np.exp(-np.arange(min(12, n - i)) / 3.0)
    x += bp(clicks, 3000, 0.3) * 1.5
    return pan(x * level)
