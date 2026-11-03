"""An expressive melody player: makes a sampled wind or string instrument phrase like a person instead of a keyboard.

- Phrases: notes closer than ~0.6 s belong to one phrase. Within a phrase the notes are slurred: each note is held
  into the next, and every note after the first starts past its recorded attack (no new tongue or bow stroke),
  crossfading from the one before.
- Dynamics: each phrase rises toward its highest note and relaxes at its end; downbeats get a little more. The
  velocity also picks the soft or loud recordings, so the tone changes with the dynamics, as on a real instrument.
- Long notes swell a little and get a vibrato that starts after a moment and grows (for instruments recorded
  without one; recordings with a natural vibrato keep their own).
- Timing: a few milliseconds of human looseness, never enough to move a note off its ring.
Plucked and struck instruments only get the dynamics and timing (their notes are naturally separate).
kind='guitar' plays like a guitarist playing a melody: each note plucked and left ringing until the next one (up to
a couple of seconds), with the phrase dynamics and human timing.
kind='samba' plays like a samba player instead: every note tongued, short notes detached and taken from the staccato
recordings (`stac`), syncopated notes (off the eighth grid) accented, long notes held with the vibrato recordings.
"""
import numpy as np
from engine import SR
import sampler

rng = np.random.default_rng(7)


def phrases(evs, gap=0.6):
    out, cur = [], []
    for e in evs:
        if cur and e['t'] - (cur[-1]['t'] + cur[-1]['d']) > gap:
            out.append(cur); cur = []
        cur.append(e)
    if cur:
        out.append(cur)
    return out


def vibrato(x, depth_cents, rate=5.4, delay=0.18, grow=0.35):
    """time-varying pitch wobble by resampling: starts after `delay`, fades in over `grow` seconds"""
    n = x.shape[1]
    t = np.arange(n) / SR
    amt = np.clip((t - delay) / grow, 0, 1) * depth_cents
    cents = amt * np.sin(2 * np.pi * rate * t + rng.uniform(0, 6.28))
    r = 2 ** (cents / 1200)
    idx = np.cumsum(r) - r[0]
    idx = idx[idx < n - 1]
    return np.stack([np.interp(idx, np.arange(n), ch) for ch in x])


def render(inst_name, notes, ghosts, seconds, kind='wind', base_vel=84, spread=26, octave=0, vib_cents=0.0,
           legato=True, jitter=0.006, ring_len=1.0, eighth=0.25, stac=None, detach=0.8, accent=7):
    """notes, ghosts: course dicts {t, note, len}. Returns {'melA', 'melB', 'ghost'} stereo arrays."""
    inst = sampler.get(inst_name)
    short = sampler.get(stac) if stac else None
    samba = kind == 'samba'
    if samba or kind == 'guitar':
        legato = False
    n = int(seconds * SR)
    out = {k: np.zeros((2, n)) for k in ('melA', 'melB', 'ghost')}
    evs = [dict(t=x['t'], p=x['note'] + octave, d=max(0.18, x['len'] * eighth * ring_len), layer='melA' if i % 2 == 0 else 'melB')
           for i, x in enumerate(notes)]
    evs += [dict(t=g['t'], p=g['note'] + octave, d=max(0.16, g['len'] * eighth * ring_len), layer='ghost') for g in ghosts]
    evs.sort(key=lambda e: e['t'])
    beat = eighth * 2
    for ph in phrases(evs):
        lo, hi = min(e['p'] for e in ph), max(e['p'] for e in ph)
        peak = next(i for i, e in enumerate(ph) if e['p'] == hi)
        for i, e in enumerate(ph):
            # the phrase arc: up toward its peak, down after; a touch more on downbeats; ghosts softer
            arc = (i / max(1, peak)) if i <= peak else 1.0 - 0.6 * (i - peak) / max(1, len(ph) - 1 - peak)
            pitch = (e['p'] - lo) / max(1, hi - lo)
            on_beat = abs((e['t'] / beat) - round(e['t'] / beat)) < 0.06
            v = base_vel - spread / 2 + spread * (0.55 * arc + 0.45 * pitch) + (5 if on_beat else 0) + rng.normal(0, 3)
            if samba:
                off8 = abs((e['t'] / eighth) - round(e['t'] / eighth)) > 0.1
                v += accent if off8 else 0
            if e['layer'] == 'ghost':
                v -= 16 if samba else 14
            e['v'] = int(np.clip(v, 30, 124))
            nxt = ph[i + 1] if i + 1 < len(ph) else None
            e['slur_in'] = legato and kind != 'pluck' and i > 0
            e['hold'] = (nxt['t'] - e['t'] + 0.035) if (legato and kind != 'pluck' and nxt is not None) else e['d']
            if kind == 'guitar':
                e['hold'] = min(2.0, max(e['d'], (nxt['t'] - e['t'] + 0.06) if nxt is not None else e['d'] * 2))
            if samba and nxt is not None:
                e['hold'] = max(0.09, min(e['d'], (nxt['t'] - e['t']) * detach))
    for e in evs:
        x = (short if (short is not None and e['hold'] < 0.26) else inst).voice(e['p'], e['v'], e['hold'])
        if e['slur_in']:
            # start past the attack: the player didn't re-tongue, the note slurs from the previous one
            skip = int(0.07 * SR)
            x = x[:, skip:]
            f = int(0.03 * SR)
            x[:, :f] *= np.linspace(0, 1, f) ** 0.7
        if kind not in ('pluck', 'guitar'):
            m = x.shape[1]
            t = np.arange(m) / SR
            if e['hold'] > 0.35:
                # a long note swells a little and settles
                sw = 0.88 + 0.12 * np.clip(t / (0.45 * e['hold']), 0, 1)
                x = x * sw
                if vib_cents:
                    x = vibrato(x, vib_cents)
        a = int(max(0.0, e['t'] + rng.normal(0, jitter)) * SR)
        if a >= n:
            continue
        k = min(n - a, x.shape[1])
        out[e['layer']][:, a:a + k] += x[:, :k]
    return out
