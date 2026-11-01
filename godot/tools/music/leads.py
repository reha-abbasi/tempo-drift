"""Melody instruments: each takes (MIDI note, held seconds, accent) and returns the note's sound.

Most are modelled on how the real instrument makes sound (a struck wooden bar, a plucked string, breath through a
flute) rather than built from synth waveforms, so they sound less like a MIDI keyboard.
"""
import math
import numpy as np
import numba as nb
from engine import *


def marimba(note, dur, accent=True):
    """a struck rosewood bar over a tuned tube: a few inharmonic modes ringing down, and the mallet's knock"""
    f = float(mtof(note))
    n = ns(min(1.6, dur + 0.9))
    t = np.arange(n) / SR
    hi = (note - 60) / 24.0
    x = np.zeros(n)
    for ratio, amp, dec in ((1.0, 1.0, 0.75 - 0.3 * hi), (3.99, 0.32, 0.22), (10.65, 0.1, 0.06), (2.0, 0.08, 0.4)):
        if f * ratio < SR * 0.45:
            x += amp * np.sin(2 * np.pi * f * ratio * t + rng.random()) * np.exp(-t / dec)
    knock = bp(noise(n), 2400.0, 0.4) * np.exp(-t / 0.004) * 0.25
    x = (x + knock) * np.clip(t / 0.0015, 0, 1)
    return fade(x * (1.0 if accent else 0.8), 0.0005, 0.05)


def glass_keys(note, dur, accent=True):
    """an FM electric piano: a bright tine at the attack over a round body, like a DX7 Rhodes"""
    f = float(mtof(note))
    n = ns(dur + 0.7)
    t = np.arange(n) / SR
    tine_i = 2.2 * np.exp(-t / 0.05)
    tine = np.sin(2 * np.pi * f * t + tine_i * np.sin(2 * np.pi * f * 14.0 * t)) * 0.35 * np.exp(-t / 0.25)
    body_i = 1.3 * np.exp(-t / 0.4) + 0.3
    body = np.sin(2 * np.pi * f * t + body_i * np.sin(2 * np.pi * f * t))
    amp = env_adsr(n, 0.002, 0.9, 0.35, 0.35, dur)
    return fade((body + tine) * amp * (1.0 if accent else 0.8), 0.0005, 0.05)


@nb.njit(cache=True)
def _ks(excite, period, damp, n):
    """Karplus-Strong: a burst runs round a delay line one period long, softened a little each time round"""
    buf_len = int(period) + 3
    buf = np.zeros(buf_len)
    out = np.zeros(n)
    w = 0
    prev = 0.0
    for i in range(n):
        # read one period back (fractional, linear)
        r = w - period
        while r < 0:
            r += buf_len
        i0 = int(r)
        fr = r - i0
        a = buf[i0 % buf_len]
        b = buf[(i0 + 1) % buf_len]
        y = a + (b - a) * fr
        # the loop filter: a gentle average (loses highs), slightly lossy
        v = damp * (0.5 * y + 0.5 * prev)
        prev = y
        if i < excite.shape[0]:
            v += excite[i]
        buf[w] = v
        out[i] = v
        w += 1
        if w >= buf_len:
            w = 0
    return out


def string_pluck(note, dur, accent=True):
    """a plucked nylon string (physically modelled), with a wooden body"""
    f = float(mtof(note))
    n = ns(min(2.0, dur + 1.0))
    burst = lp(noise(ns(0.012)), 3500.0 if accent else 2500.0) * np.hanning(ns(0.012))
    period = SR / f - 0.5
    x = _ks(burst, period, 0.9965, n)
    x = eq(x, pb.PeakFilter(220, 3.0, 1.0), pb.PeakFilter(2400, 2.0, 1.2), pb.HighpassFilter(90))[0]
    t = np.arange(n) / SR
    x = x * np.where(t < dur + 0.15, 1.0, np.exp(-(t - dur - 0.15) / 0.12))
    return fade(x * 2.2 * (1.0 if accent else 0.8), 0.0003, 0.05)


def breath_flute(note, dur, accent=True):
    """a breathy flute: a pure tone with a little breath noise, a puff at the start and vibrato that grows"""
    f = float(mtof(note))
    n = ns(dur + 0.35)
    t = np.arange(n) / SR
    vib = 1.0 + 0.006 * np.clip((t - 0.18) / 0.3, 0, 1) * np.sin(2 * np.pi * 5.2 * t)
    ff = f * vib
    tone = sine(ff, n) + 0.18 * sine(ff * 2, n) + 0.06 * sine(ff * 3, n)
    breath = bp(noise(n), f * 2.0, 0.55) * 0.22
    chiff = bp(noise(n), f * 4.0, 0.3) * np.exp(-t / 0.03) * 0.5
    amp = env_adsr(n, 0.045, 0.25, 0.8, 0.12, dur)
    return fade((tone + breath) * amp + chiff * np.clip(t / 0.003, 0, 1), 0.001, 0.05) * (1.0 if accent else 0.8)


def analog_pluck(note, dur, accent=True):
    """a warm single-oscillator analog pluck (two saws a few cents apart through a ladder filter)"""
    f = float(mtof(note))
    n = ns(dur + 0.45)
    x = saw(f * 1.0023, n, 0.0) * 0.5 + saw(f * 0.9977, n, 0.37) * 0.5
    fe = env_ad(n, 0.002, 0.16)
    fc = 380.0 + (3600.0 if accent else 2600.0) * fe + f * 0.5
    y = ladder(x, fc, res=0.3, drive=1.2)
    return y * env_adsr(n, 0.002, 0.45, 0.4, 0.15, dur) * 1.4


OPTIONS = {
    'marimba': (marimba, 'Marimba', 'A wooden marimba, played with soft mallets. Warm and natural, with a clear attack on every note.'),
    'keys': (glass_keys, 'Glass keys', 'A glassy electric piano, like a classic Rhodes. Bell-like shimmer on top of a round tone.'),
    'string': (string_pluck, 'Plucked string', 'A nylon string, modelled on a real plucked string with a wooden body. Like a harp or a soft guitar.'),
    'flute': (breath_flute, 'Breathy flute', 'An airy flute with breath and gentle vibrato, the kind melodic techno often uses for its hooks.'),
    'analog': (analog_pluck, 'Analog pluck', 'One warm vintage-synth voice, clean and round. Much simpler than the current lead.'),
}
