"""The sound engine: oscillators, filters, envelopes, drums, synths and the mix tools the songs are built from.

Everything is rendered offline into numpy arrays at 44.1 kHz. Mono sounds are 1-D float arrays; stereo is (2, n).
Effects that JUCE does well (reverb, delay, chorus, compression, EQ) come from Spotify's pedalboard.
"""
import math
import numpy as np
import numba as nb
import pedalboard as pb

SR = 44100
rng = np.random.default_rng(7)


def mtof(m):
    return 440.0 * 2.0 ** ((np.asarray(m, dtype=np.float64) - 69.0) / 12.0)


def ns(seconds):
    return max(1, int(round(seconds * SR)))


# ------------------------------------------------------------------ oscillators (band-limited with PolyBLEP)

def _phase(freq, n, ph0=0.0):
    f = np.broadcast_to(np.asarray(freq, dtype=np.float64), (n,)) / SR
    p = (ph0 + np.cumsum(f)) % 1.0
    return p, f


def _blep(t, dt):
    y = np.zeros_like(t)
    m = t < dt
    x = t[m] / dt[m]
    y[m] = x + x - x * x - 1.0
    m = t > 1.0 - dt
    x = (t[m] - 1.0) / dt[m]
    y[m] = x * x + x + x + 1.0
    return y


def saw(freq, n, ph0=None):
    p, dt = _phase(freq, n, rng.random() if ph0 is None else ph0)
    return (2.0 * p - 1.0) - _blep(p, dt)


def square(freq, n, pw=0.5, ph0=None):
    p, dt = _phase(freq, n, rng.random() if ph0 is None else ph0)
    s = np.where(p < pw, 1.0, -1.0) + _blep(p, dt) - _blep((p - pw) % 1.0, dt)
    return s


def sine(freq, n, ph0=0.0):
    p, _ = _phase(freq, n, ph0)
    return np.sin(2.0 * np.pi * p)


def tri(freq, n, ph0=0.0):
    p, _ = _phase(freq, n, ph0)
    return 4.0 * np.abs(p - 0.5) - 1.0


def noise(n):
    return rng.uniform(-1.0, 1.0, n)


def supersaw(freq, n, voices=7, detune=0.18, stereo=True):
    """detuned saws (detune in semitones across the spread), panned across the field"""
    out = np.zeros((2, n))
    for v in range(voices):
        k = (v / (voices - 1) - 0.5) * 2.0 if voices > 1 else 0.0
        f = freq * 2.0 ** (k * detune / 12.0)
        s = saw(f, n)
        pan = k * 0.8 if stereo else 0.0
        out[0] += s * math.cos((pan + 1) * math.pi / 4) * math.sqrt(2)
        out[1] += s * math.sin((pan + 1) * math.pi / 4) * math.sqrt(2)
    return out / math.sqrt(voices)


# ------------------------------------------------------------------ filters

@nb.njit(cache=True)
def _svf(x, fc, res, mode):
    out = np.empty_like(x)
    ic1 = 0.0
    ic2 = 0.0
    k = 2.0 - 2.0 * min(res, 0.985)
    for i in range(x.shape[0]):
        f = min(max(fc[i], 20.0), SR * 0.45)
        g = math.tan(math.pi * f / SR)
        a1 = 1.0 / (1.0 + g * (g + k))
        a2 = g * a1
        a3 = g * a2
        v3 = x[i] - ic2
        v1 = a1 * ic1 + a2 * v3
        v2 = ic2 + a2 * ic1 + a3 * v3
        ic1 = 2.0 * v1 - ic1
        ic2 = 2.0 * v2 - ic2
        if mode == 0:
            out[i] = v2
        elif mode == 1:
            out[i] = v1
        else:
            out[i] = x[i] - k * v1 - v2
    return out


def lp(x, fc, res=0.0):
    return _svf(np.ascontiguousarray(x, dtype=np.float64), np.broadcast_to(np.asarray(fc, dtype=np.float64), x.shape).copy(), res, 0)


def bp(x, fc, res=0.3):
    return _svf(np.ascontiguousarray(x, dtype=np.float64), np.broadcast_to(np.asarray(fc, dtype=np.float64), x.shape).copy(), res, 1)


def hp(x, fc, res=0.0):
    return _svf(np.ascontiguousarray(x, dtype=np.float64), np.broadcast_to(np.asarray(fc, dtype=np.float64), x.shape).copy(), res, 2)


@nb.njit(cache=True)
def _ladder(x, fc, res, drive):
    """a 4-pole transistor ladder with saturation in the loop (run twice per sample for stability up high)"""
    out = np.empty_like(x)
    s0 = s1 = s2 = s3 = 0.0
    for i in range(x.shape[0]):
        f = min(max(fc[i], 20.0), 16000.0)
        g = 1.0 - math.exp(-2.0 * math.pi * f / (SR * 2.0))
        for _ in range(2):
            u = math.tanh(drive * x[i] - 4.0 * res * s3)
            s0 += g * (u - s0)
            s1 += g * (math.tanh(s0) - s1)
            s2 += g * (s1 - s2)
            s3 += g * (s2 - s3)
        out[i] = s3 * (1.0 + res * 1.2)
    return out


def ladder(x, fc, res=0.5, drive=1.0):
    return _ladder(np.ascontiguousarray(x, dtype=np.float64), np.broadcast_to(np.asarray(fc, dtype=np.float64), x.shape).copy(), res, drive)


# ------------------------------------------------------------------ envelopes and shaping

def env_ad(n, attack, decay, curve=1.0):
    t = np.arange(n) / SR
    a = np.clip(t / max(attack, 1e-4), 0.0, 1.0)
    d = np.exp(-np.maximum(t - attack, 0.0) / max(decay, 1e-4)) ** curve
    return a * d


def env_adsr(n, attack, decay, sustain, release, gate):
    t = np.arange(n) / SR
    e = np.where(t < attack, t / max(attack, 1e-4),
                 sustain + (1.0 - sustain) * np.exp(-(t - attack) / max(decay, 1e-4)))
    at_gate = sustain + (1.0 - sustain) * math.exp(-max(gate - attack, 0.0) / max(decay, 1e-4)) if gate > attack else gate / max(attack, 1e-4)
    rel = at_gate * np.exp(-np.maximum(t - gate, 0.0) / max(release, 1e-4))
    return np.where(t < gate, e, rel)


def sat(x, drive=1.0):
    return np.tanh(drive * x) / math.tanh(drive)


def fade(x, fin=0.002, fout=0.01):
    n = x.shape[-1]
    a, b = ns(fin), ns(fout)
    w = np.ones(n)
    w[:min(a, n)] = np.linspace(0.0, 1.0, min(a, n))
    w[max(0, n - b):] *= np.linspace(1.0, 0.0, n - max(0, n - b))
    return x * w


def pan(x, p=0.0, width=None):
    """mono -> stereo with an equal-power pan"""
    th = (p + 1.0) * math.pi / 4.0
    return np.stack([x * math.cos(th) * math.sqrt(2), x * math.sin(th) * math.sqrt(2)])


def st(x):
    return x if x.ndim == 2 else pan(x)


# ------------------------------------------------------------------ effects (pedalboard)

def fx(x, *plugins):
    x = st(x).astype(np.float32)
    return pb.Pedalboard(list(plugins))(x, SR)


def reverb(x, size=0.6, damp=0.5, wet=0.3, dry=1.0, width=1.0, pre_hp=0.0):
    x = st(x).astype(np.float32)
    send = x if pre_hp <= 0 else pb.HighpassFilter(pre_hp)(x, SR)
    w = pb.Reverb(room_size=size, damping=damp, wet_level=1.0, dry_level=0.0, width=width)(send, SR)
    return x * dry + w * wet


def delay(x, seconds, feedback=0.4, mix=0.3, hp_hz=300.0, lp_hz=5000.0, pingpong=True):
    """a filtered, optionally ping-pong echo"""
    x = st(x).astype(np.float64)
    n = x.shape[1]
    d = ns(seconds)
    out = x.copy()
    tap = np.stack([x[0] * 0.5 + x[1] * 0.5, x[0] * 0.5 + x[1] * 0.5])
    g = mix
    side = 0
    for k in range(1, 12):
        off = d * k
        if off >= n or g < 0.01:
            break
        tap = st(pb.Pedalboard([pb.HighpassFilter(hp_hz), pb.LowpassFilter(lp_hz)])(tap.astype(np.float32), SR)).astype(np.float64)
        if pingpong:
            out[side, off:] += tap[side, :n - off] * g * 1.4
        else:
            out[:, off:] += tap[:, :n - off] * g
        side ^= 1
        g *= feedback
    return out


def eq(x, *plugins):
    return fx(x, *plugins)


# ------------------------------------------------------------------ drums (one-shots)

def kick(f_lo=47.0, f_hi=210.0, pitch_decay=0.032, decay=0.42, click=0.5, drive=2.2, length=0.9):
    n = ns(length)
    t = np.arange(n) / SR
    f = f_lo + (f_hi - f_lo) * np.exp(-t / pitch_decay)
    body = np.sin(2 * np.pi * np.cumsum(f) / SR)
    amp = np.clip(t / 0.0015, 0, 1) * np.where(t < 0.04, 1.0, np.exp(-(t - 0.04) / decay))
    k = body * amp
    c = hp(noise(n), 1800.0) * np.exp(-t / 0.0035) * click + np.sin(2 * np.pi * 1600 * t) * np.exp(-t / 0.004) * click * 0.6
    return fade(sat(k + c, drive), 0.0005, 0.05)


def clap(decay=0.16, tone=1250.0, length=0.6):
    n = ns(length)
    t = np.arange(n) / SR
    e = np.zeros(n)
    for k, off in enumerate([0.0, 0.011, 0.023, 0.034]):
        tt = t - off
        e += np.where(tt >= 0, np.exp(-np.maximum(tt, 0) / (0.006 if k < 3 else decay)), 0.0)
    x = bp(noise(n), tone, 0.55) * e
    x = x + hp(noise(n), 3000) * e * 0.25
    return fade(sat(x * 1.6, 1.5), 0.0005, 0.05)


METAL = np.array([205.3, 304.4, 369.6, 522.7, 540.0, 800.0])


def hat(decay=0.045, open_=False, tone=1.0, length=None):
    length = length or (decay * 6 + 0.05)
    n = ns(length)
    t = np.arange(n) / SR
    m = sum(square(f * 2.4 * tone, n) for f in METAL) / 6.0
    x = m * 0.6 + noise(n) * 0.5
    x = hp(bp(x, 9500 * tone, 0.2), 6500 * tone)
    e = np.clip(t / 0.0008, 0, 1) * np.exp(-t / decay)
    return fade(x * e * 2.2, 0.0003, 0.02)


def ride(decay=0.9, length=1.6):
    n = ns(length)
    t = np.arange(n) / SR
    m = sum(square(f * 4.1, n) for f in METAL) / 6.0
    bell = bp(m, 3200, 0.7) * np.exp(-t / 0.25) * 0.6
    x = hp(bp(m + noise(n) * 0.25, 8000, 0.2), 4500) + bell
    return fade(x * np.exp(-t / decay) * 1.6, 0.0005, 0.1)


def crash(decay=1.6, length=3.0):
    n = ns(length)
    t = np.arange(n) / SR
    m = sum(square(f * 3.3, n) for f in METAL) / 6.0
    x = hp(m * 0.5 + noise(n) * 0.8, 3500)
    return fade(x * np.exp(-t / decay) * np.clip(t / 0.002, 0, 1) * 1.2, 0.0005, 0.2)


def shaker(decay=0.028, length=0.12):
    n = ns(length)
    t = np.arange(n) / SR
    e = np.clip(t / 0.006, 0, 1) * np.exp(-t / decay)
    return hp(bp(noise(n), 6500, 0.3), 3000) * e * 1.5


def rim(length=0.08):
    n = ns(length)
    t = np.arange(n) / SR
    x = np.sin(2 * np.pi * 1700 * t) * 0.7 + np.sin(2 * np.pi * 2550 * t) * 0.4 + bp(noise(n), 3000, 0.6) * 0.5
    return fade(x * np.exp(-t / 0.012), 0.0002, 0.01)


def tom(f=110.0, decay=0.22, length=0.6):
    n = ns(length)
    t = np.arange(n) / SR
    ff = f * (1 + 0.6 * np.exp(-t / 0.03))
    x = np.sin(2 * np.pi * np.cumsum(ff) / SR) * np.exp(-t / decay) + bp(noise(n), f * 3, 0.4) * np.exp(-t / 0.01) * 0.3
    return fade(sat(x, 1.3), 0.0005, 0.03)


def snare(decay=0.16, tone=190.0, length=0.6):
    n = ns(length)
    t = np.arange(n) / SR
    body = np.sin(2 * np.pi * np.cumsum(tone * (1 + 0.5 * np.exp(-t / 0.02))) / SR) * np.exp(-t / 0.06)
    nz = bp(noise(n), 4200, 0.25) * np.exp(-t / decay)
    return fade(sat(body * 0.8 + nz * 1.0, 1.4), 0.0003, 0.03)


def riser(length, f0=300.0, f1=6000.0):
    n = ns(length)
    t = np.linspace(0, 1, n)
    fc = f0 * (f1 / f0) ** (t ** 2)
    x = bp(noise(n), fc, 0.55) * t ** 1.5
    return x


# ------------------------------------------------------------------ the mix

class Layer:
    """one soundtrack layer: a stereo buffer that sounds are placed into by time"""

    def __init__(self, seconds):
        self.n = ns(seconds)
        self.x = np.zeros((2, self.n))

    def add(self, sig, t, gain=1.0, p=0.0):
        s = st(sig) if sig.ndim == 2 else pan(sig, p)
        i = int(round(t * SR))
        if i >= self.n:
            return
        j = min(self.n, i + s.shape[1])
        a = max(0, -i)
        self.x[:, max(i, 0):j] += s[:, a:j - i] * gain

    def mix(self, other, gain=1.0):
        self.x += other.x * gain


def sidechain(n, kicks, depth=0.7, release=0.16, attack=0.003, shape=1.0):
    """a gain curve that ducks under every kick and swells back"""
    g = np.ones(n)
    rel = ns(release * 4)
    t = np.arange(rel) / SR
    curve = 1.0 - depth * np.clip(t / attack, 0, 1) ** 0.5 * np.exp(-t / release) ** shape
    for k in kicks:
        i = int(round(k * SR))
        if i >= n:
            continue
        j = min(n, i + rel)
        g[i:j] = np.minimum(g[i:j], curve[:j - i])
    return g


@nb.njit(cache=True)
def _limiter_gain(peak, thresh, att, rel):
    g = np.ones_like(peak)
    cur = 1.0
    for i in range(peak.shape[0]):
        want = 1.0 if peak[i] <= thresh else thresh / peak[i]
        if want < cur:
            cur += (want - cur) * att
        else:
            cur += (want - cur) * rel
        g[i] = cur
    return g


def master_gain(mix, ceiling_db=-1.0, glue_db=-10.0, glue_ratio=2.5, lookahead=0.004):
    """the gain curve a bus compressor and a look-ahead peak limiter would apply to the full mix; applied to every
    layer alike, so the layers still add up to the mastered song"""
    mono = np.max(np.abs(mix), axis=0)
    n = mono.shape[0]
    # glue: an RMS-ish compressor (10 ms attack, 150 ms release)
    env = np.sqrt(lp(mono ** 2, 8.0) .clip(0))
    env_db = 20 * np.log10(np.maximum(env, 1e-6))
    over = np.maximum(env_db - glue_db, 0.0)
    glue = 10 ** (-(over * (1 - 1 / glue_ratio)) / 20)
    y = mono * glue
    # limiter: the peak over a look-ahead window, fast attack, smooth release
    from scipy.ndimage import maximum_filter1d
    la = ns(lookahead)
    pk = maximum_filter1d(y, size=la * 2 + 1, origin=-la)   # the loudest peak in the next few milliseconds
    thresh = 10 ** (ceiling_db / 20)
    lim = _limiter_gain(pk, thresh, 0.5, 1.0 - math.exp(-1.0 / (0.08 * SR)))
    return glue * lim


def to_ogg(x, path, q=5):
    import soundfile as sf, subprocess, os
    wav = path + '.wav'
    sf.write(wav, np.clip(x.T, -1, 1).astype(np.float32), SR, subtype='FLOAT')
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', wav, '-c:a', 'libvorbis', '-q:a', str(q), path], check=True)
    os.unlink(wav)


def to_mp3(x, path, start=0.0, length=None, fade_out=2.0):
    import soundfile as sf, subprocess, os
    a = ns(start)
    b = x.shape[1] if length is None else min(x.shape[1], a + ns(length))
    y = x[:, a:b].copy()
    f = min(ns(fade_out), y.shape[1])
    y[:, -f:] *= np.linspace(1, 0, f)
    wav = path + '.wav'
    sf.write(wav, np.clip(y.T, -1, 1).astype(np.float32), SR, subtype='FLOAT')
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', wav, '-c:a', 'libmp3lame', '-b:a', '224k', path], check=True)
    os.unlink(wav)


def loudness(x):
    """integrated loudness (LUFS) and true-ish peak of a stereo buffer, measured by ffmpeg's EBU R128 meter"""
    import soundfile as sf, subprocess, os, tempfile, re
    fd, wav = tempfile.mkstemp(suffix='.wav')
    os.close(fd)
    sf.write(wav, np.clip(x.T, -4, 4).astype(np.float32), SR, subtype='FLOAT')
    r = subprocess.run(['ffmpeg', '-hide_banner', '-nostats', '-i', wav, '-af', 'ebur128=peak=true', '-f', 'null', '-'],
                       capture_output=True, text=True)
    os.unlink(wav)
    lufs = re.findall(r'I:\s+(-?[\d.]+) LUFS', r.stderr)
    peak = re.findall(r'Peak:\s+(-?[\d.]+) dBFS', r.stderr)
    return float(lufs[-1]) if lufs else None, float(peak[-1]) if peak else None


def active_rms_db(x):
    """the RMS level of a part while it plays (silent stretches don't count)"""
    m = st(x).mean(axis=0)
    f = ns(0.05)
    k = m.shape[0] // f
    if k == 0:
        return -120.0
    p = (m[:k * f].reshape(k, f) ** 2).mean(axis=1)
    p = p[p > 1e-8]
    return -120.0 if p.size == 0 else 10 * np.log10(p.mean())


def level(x, db):
    """scale a part so it plays at the given RMS level"""
    cur = active_rms_db(x)
    return x if cur <= -119 else x * 10 ** ((db - cur) / 20)
