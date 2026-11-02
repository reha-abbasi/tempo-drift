"""The Future's techno, in two flavours, built around a course's melody and chords.

warehouse: dark Berlin techno. A punchy 909 kick with a reverb rumble under it, offbeat bass, dub chord stabs echoing
           into the distance, and the melody on a squelchy acid line.
melodic:   big-room melodic techno. A deep kick, a rolling sixteenth bass that pumps around it, wide supersaw pads,
           a plucked arpeggio and the melody on a breathy flute.
"""
import numpy as np
from engine import *
from arr import ease_for, place_lead, finish_lead
import leads

LAYERS = ['core', 'full', 'arp', 'perc', 'od', 'jet', 'ghost', 'melA', 'melB']


class Song:
    def __init__(self, c):
        self.c = c
        self.beat = c['beat']
        self.bar = c['bar']
        self.bars = c['bars']
        self.dur = c['len'] * c['bar'] + 3.0

    def t(self, b, beats):
        return b * self.bar + beats * self.beat

    def chord(self, b):
        B = self.bars[min(b, len(self.bars) - 1)]
        return B['root'], B['iv']


def bass_note(root, lo=33):
    p = root % 12 + lo - lo % 12
    while p < lo:
        p += 12
    while p >= lo + 12:
        p -= 12
    return p


def voicing(root, iv, lo, hi):
    ps = sorted({((root + x - lo) % 12) + lo for x in iv})
    return [p if p <= hi else p - 12 for p in ps]


# ------------------------------------------------------------------ instruments

def acid(note, dur, accent=True, res=0.84):
    n = ns(dur + 0.3)
    f = mtof(note)
    osc = saw(f, n) * 0.7 + square(f, n, 0.5) * 0.15
    fe = env_ad(n, 0.002, 0.2 if accent else 0.12)
    fc = 260.0 + (4600.0 if accent else 2200.0) * fe
    y = ladder(osc, fc, res=res, drive=1.8)
    amp = env_adsr(n, 0.003, 0.3, 0.75, 0.035, dur)
    return sat(y * amp * (1.6 if accent else 1.2), 2.2)


def pluck_lead(note, dur):
    n = ns(dur + 0.5)
    f = mtof(note)
    s = supersaw(f, n, voices=5, detune=0.14)
    s += pan(square(f / 2, n, 0.35) * 0.35)
    fe = env_ad(n, 0.002, 0.28)
    amp = env_adsr(n, 0.002, 0.35, 0.45, 0.18, dur)
    fc = 700.0 + 6500.0 * fe
    out = np.stack([lp(s[0], fc, 0.25), lp(s[1], fc, 0.25)]) * amp
    return out * 0.9


def blip(note, dur=0.09, bright=1.0):
    n = ns(dur + 0.08)
    f = mtof(note)
    x = square(f, n, 0.3) * 0.6 + sine(f * 2, n) * 0.3
    fe = env_ad(n, 0.001, 0.045)
    y = lp(x, 500.0 + 3800.0 * bright * fe, 0.35)
    return y * env_adsr(n, 0.001, 0.06, 0.2, 0.03, dur)


def pluck(note, dur=0.12, bright=1.0):
    n = ns(dur + 0.25)
    f = mtof(note)
    x = saw(f, n) * 0.6 + square(f * 1.003, n) * 0.3
    fe = env_ad(n, 0.001, 0.09)
    y = lp(x, 450.0 + 4500.0 * bright * fe, 0.2)
    return y * env_adsr(n, 0.001, 0.12, 0.15, 0.08, dur)


def offbass(note, dur=0.2, bright=1.0):
    n = ns(dur + 0.06)
    f = mtof(note)
    x = saw(f, n) * 0.6 + square(f, n) * 0.4
    fe = env_ad(n, 0.002, 0.09)
    y = ladder(x, 160.0 + 950.0 * bright * fe, res=0.35, drive=2.0)
    sub = sine(f, n) * 0.6
    amp = env_adsr(n, 0.002, 0.12, 0.45, 0.03, dur)
    return sat((y * 1.1 + sub) * amp, 1.6)


def rollbass(note, dur=0.11, bright=1.0):
    n = ns(dur + 0.04)
    f = mtof(note)
    x = saw(f, n)
    fe = env_ad(n, 0.001, 0.06)
    y = lp(x, 140.0 + 1100.0 * bright * fe, 0.15)
    sub = sine(f, n)
    amp = env_adsr(n, 0.001, 0.07, 0.45, 0.02, dur)
    return sat((y * 1.0 + sub * 1.0) * amp, 1.7)


def stab(notes, dur=0.16, bright=1.0):
    n = ns(dur + 0.1)
    x = np.zeros(n)
    for p in notes:
        f = mtof(p)
        x += saw(f, n) * 0.5 + saw(f * 1.006, n) * 0.4 + square(f * 0.5, n) * 0.15
    fe = env_ad(n, 0.001, 0.14)
    y = lp(x / len(notes), 520.0 + 3200.0 * bright * fe, 0.35)
    return y * env_adsr(n, 0.001, 0.14, 0.45, 0.06, dur)


def pad(notes, dur, bright=1.0):
    n = ns(dur + 1.2)
    s = np.zeros((2, n))
    for p in notes:
        s += supersaw(mtof(p), n, voices=7, detune=0.2)
    s /= len(notes)
    fc = 1400.0 + 2200.0 * bright
    s = np.stack([lp(s[0], fc, 0.1), lp(s[1], fc, 0.1)])
    return s * env_adsr(n, 0.25, 0.8, 0.85, 0.9, dur)


def wind(n, seconds_per_sweep=4.0):
    t = np.arange(n) / SR
    fc = 900.0 + 700.0 * np.sin(2 * np.pi * t / seconds_per_sweep) + 300.0 * np.sin(2 * np.pi * t / 1.7)
    return np.stack([bp(noise(n), fc, 0.6), bp(noise(n), fc * 1.1, 0.6)]) * 0.35


# ------------------------------------------------------------------ arrangement

def phone_bass(x):
    """bass you can hear on a phone: phone speakers play almost nothing under ~150 Hz, so the deep sub alone sounds
    like a strained speaker there. Cut the rumble under 30 Hz, ease the sub a little, and add a soft octave above the
    bass (a gently bent copy of the 45-120 Hz band, kept under 450 Hz) so a small speaker still hears the bass line.
    Kept low and smooth on purpose: overtones up to 1 kHz made the bass sound harsh (v29 first try)"""
    low = eq(x, pb.HighpassFilter(45), pb.LowpassFilter(120), pb.LowpassFilter(120))
    pk = np.max(np.abs(low)) + 1e-9
    u = low / pk
    octave = np.tanh(2.0 * u * u) * pk                 # even overtones: mostly the octave, no buzz
    over = eq(octave, pb.HighpassFilter(110), pb.HighpassFilter(110), pb.LowpassFilter(450), pb.LowpassFilter(450))
    over = level(over, active_rms_db(low) - 9.0)
    y = eq(x, pb.HighpassFilter(30), pb.HighpassFilter(30), pb.LowShelfFilter(60, -3.0, 0.7))
    return y + over


def build(c, flavour='melodic', ease=None, ext=None, mel=None, style=None):
    """ext: optional fn(part, notes, seconds) -> stereo audio that plays the bass / chords / arp instead of the built-in
    synths (notes: (start s, length s, MIDI note, velocity)); used to try Surge XT sounds.
    mel: optional melody changes that keep every note on its ring: {'lead': part name ext plays the melody on,
    'double': keep the flute under it, 'octave': semitones to shift, 'ring_len': how long notes are held,
    'ghosts': False drops the in-between notes}"""
    mel = mel or {}
    # style: None, 'tron' (80s film score: a big gated snare instead of the clap) or 'cyber' (darker, driven drums)
    ease = ease_for(c) if ease is None else ease
    S = Song(c)
    D = S.dur
    L = {k: Layer(D) for k in LAYERS}
    drums, bassL, rumble_src, chords, hats_open, ride_l = (Layer(D) for _ in range(6))
    arp, perc, od, odst, jet = (Layer(D) for _ in range(5))
    warehouse = flavour == 'warehouse'

    K = kick(49, 240, 0.028, 0.24, 0.7, 2.6) if warehouse else kick(47, 225, 0.03, 0.32, 0.85, 2.9)
    CL = reverb(clap(0.14, 1300), size=0.35, wet=0.22)
    SN = snare(0.14)
    CH = hat(0.032)
    CH2 = hat(0.022, tone=1.15)
    OH = hat(0.2, tone=0.95)
    RD = ride()
    CR = crash()
    SH = shaker()
    RM = rim()
    if style == 'tron':
        # the 80s gated snare: a fat snare into a big room, the room cut off sharply after a quarter second
        g = reverb(snare(0.2, 185), size=0.95, damp=0.3, wet=1.2, dry=1.0)
        gate = np.clip((0.26 * SR - np.arange(g.shape[-1])) / (0.03 * SR), 0, 1)
        GS = eq(g * gate, pb.LowpassFilter(5000), pb.PeakFilter(3500, -4.0, 0.8))
    if style == 'cyber':
        K = kick(42, 200, 0.03, 0.4, 0.9, 4.0)
    kicks = []
    n_bars = len(S.bars)
    notes = {'bass': [], 'chords': [], 'arp': []}

    for b in range(n_bars):
        B = S.bars[b]
        sec = B['sec']
        root, iv = S.chord(b)
        lvl = B.get('lvl', 0) if sec == 'I' else 3
        bright = {'I': 0.4, 'A': 0.7, 'B': 1.0, 'C': 1.25, 'O': 0.6, 'E': 0.5}[sec]
        if sec == 'E':
            drums.add(K, S.t(b, 0), 1.0)
            kicks.append(S.t(b, 0))
            drums.add(CR, S.t(b, 0), 0.5)
            bn = bass_note(root)
            bassL.add(sine(mtof(bn), ns(2.5)) * env_ad(ns(2.5), 0.005, 0.7), S.t(b, 0), 0.9)
            chords.add(pad(voicing(root, iv, 57, 72), S.bar * 1.0, 0.6) if not warehouse else stab(voicing(root, iv, 55, 70), 0.6, 0.6), S.t(b, 0), 0.6)
            continue
        # ---- drums
        for q in range(4):
            drums.add(K, S.t(b, q), 0.85 if warehouse else 0.95)
            kicks.append(S.t(b, q))
        if sec != 'I':
            for q in (1, 3):
                if style == 'tron':
                    drums.add(GS, S.t(b, q), 0.75)
                    continue
                drums.add(CL, S.t(b, q), 0.55 if warehouse else 0.42)
                if not warehouse:
                    drums.add(SN, S.t(b, q), 0.22 if style != 'cyber' else 0.4)
        for q in range(4):
            if sec in ('B', 'C'):
                hats_open.add(OH, S.t(b, q + 0.5), 1.0, 0.15)
            else:
                drums.add(CH, S.t(b, q + 0.5), 1.5 if sec != 'I' else 0.8 + 0.2 * lvl, 0.1)
        if sec in ('A', 'B', 'C', 'O'):
            for s16 in range(16):
                if s16 % 2 == 1:
                    drums.add(CH2, S.t(b, s16 / 4), 0.5 + 0.25 * (s16 % 4 == 3), -0.25)
        if sec in ('B', 'C') or (warehouse and sec == 'A' and b % 2 == 1):
            for q in range(4):
                ride_l.add(RD, S.t(b, q), 0.45, 0.3)
        # ---- bass
        bn = bass_note(root, 33 if warehouse else 31)
        if sec != 'I' or lvl >= 1:
            if warehouse:
                for q in range(4):
                    bassL.add(offbass(bn, 0.19, bright), S.t(b, q + 0.5), 0.7)
                if sec in ('B', 'C'):
                    bassL.add(offbass(bn + 12, 0.08, bright), S.t(b, 3.75), 0.45)
            else:
                for s16 in range(16):
                    if s16 % 4 == 0:
                        continue
                    p = bn + (12 if s16 % 4 == 3 and sec in ('B', 'C') else 0)
                    if s16 >= 14 and b % 2 == 1:
                        p = bn + iv[2]
                    bassL.add(rollbass(p, 0.1, bright), S.t(b, s16 / 4), 0.92 if s16 % 4 != 2 else 1.08)
                    notes['bass'].append((S.t(b, s16 / 4), 0.1, p, 92 if s16 % 4 != 2 else 108))
        # ---- harmony
        if sec != 'I':
            if warehouse:
                v = voicing(root, iv + [10 if iv[1] == 3 else 11], 55, 70) if sec == 'C' else voicing(root, iv, 55, 70)
                for pos in ((0.75, 2.5) if sec != 'C' else (0.75, 1.75, 2.5, 3.5)):
                    chords.add(stab(v, 0.22, bright), S.t(b, pos), 2.2)
            else:
                v = voicing(root, iv, 57, 72) + [bass_note(root, 45)]
                chords.add(pad(v, S.bar * 0.98, bright), S.t(b, 0), 1.15)
                notes['chords'] += [(S.t(b, 0), S.bar * 0.98, q, 80) for q in v]
        # ---- arpeggio (band level 3)
        if sec not in ('I',):
            tones = voicing(root, iv, 64, 76)
            seq = tones + [tones[0] + 12] + tones[::-1][1:]
            for s16 in range(16):
                if warehouse:
                    if s16 % 3 == 2:
                        continue
                    p = seq[(s16 * 5) % len(seq)] + (12 if s16 % 8 == 7 else 0)
                    arp.add(blip(p, 0.07, bright), S.t(b, s16 / 4), 1.3 if s16 % 4 == 0 else 0.9, -0.4 if s16 % 2 else 0.4)
                else:
                    p = seq[s16 % len(seq)] + (12 if (s16 // 4) % 2 else 0)
                    arp.add(pluck(p, 0.1, bright), S.t(b, s16 / 4), 1.0 if s16 % 4 == 0 else 0.75, -0.5 if s16 % 2 else 0.5)
                    notes['arp'].append((S.t(b, s16 / 4), 0.1, p, 100 if s16 % 4 == 0 else 78))
        # ---- percussion (band level 4)
        if sec != 'I':
            for s16 in range(16):
                perc.add(SH, S.t(b, s16 / 4), 0.6 if s16 % 2 else 0.35, 0.35)
            for s16 in (3, 6, 11, 14) if warehouse else (3, 7, 10, 14):
                perc.add(RM, S.t(b, s16 / 4), 0.6, -0.35)
            for s16, f in ((7, 98.0), (13, 131.0)) if warehouse else ((6, 147.0), (11, 110.0), (15, 98.0)):
                perc.add(tom(f), S.t(b, s16 / 4), 0.45, 0.2 if f > 120 else -0.2)
        # ---- Overdrive
        if sec != 'I':
            od.add(CR, S.t(b, 0), 0.38)
            v = voicing(root, iv, 60, 76)
            for q in range(4):
                odst.add(pluck_lead(v[0], 0.14) + pluck_lead(v[1], 0.14) + pluck_lead(v[-1], 0.14), S.t(b, q + 0.5), 0.3)
            if b % 4 == 3:
                for s16 in range(12, 16):
                    od.add(SN, S.t(b, s16 / 4), 0.18 + 0.06 * (s16 - 12))
                od.add(riser(S.bar), S.t(b, 0), 0.25)
        # ---- jetpack: the heartbeat
        for q in (0, 2):
            hb = sine(mtof(bass_note(root, 28)), ns(0.25)) * env_ad(ns(0.25), 0.004, 0.08)
            jet.add(hb, S.t(b, q), 0.6)
            jet.add(hb, S.t(b, q + 0.3), 0.4)

    n = L['core'].n
    if ext:
        # the outside instrument takes over each part, at the level the built-in synth played it
        for part, layer in (('bass', bassL), ('chords', chords), ('arp', arp)):
            if notes[part]:
                x = ext(part, notes[part], D)[:, :n]
                y = np.zeros((2, n)); y[:, :x.shape[1]] = x
                layer.x = level(y, active_rms_db(layer.x))
    sc_hard = sidechain(n, kicks, 1.0, 0.24)
    sc_bass = sidechain(n, kicks, 0.55 if warehouse else 0.9, 0.1 if warehouse else 0.12)
    sc_mid = sidechain(n, kicks, 0.55, 0.18)
    sc_pad = sidechain(n, kicks, 0.75, 0.24)
    sc_lead = sidechain(n, kicks, 0.2, 0.12)

    # the rumble: the kick through a big dark room, low-passed, driven and pumping
    kick_only = Layer(D)
    for k in kicks:
        kick_only.add(K, k, 1.0)
    rum = reverb(kick_only.x, size=0.92, damp=0.85, wet=1.0, dry=0.0, width=0.3)
    rum = np.stack([lp(rum[0], 100.0, 0.2), lp(rum[1], 100.0, 0.2)])
    rum = sat(rum * 3.0, 2.5) * sc_hard * (0.2 if warehouse else 0.1)

    drums_x = eq(drums.x, pb.HighShelfFilter(7000, 4.0))
    if style == 'cyber':
        # driven and darker: the whole kit through saturation, the top end rolled off
        dr = active_rms_db(drums_x)
        drums_x = level(eq(sat(drums_x * 2.2, 2.0), pb.LowpassFilter(8500), pb.PeakFilter(180, 2.5, 0.8)), dr + 0.5)
    if ext:
        # Surge's basses already carry their own overtones: no 900 Hz lift, and the top rounded off so a saw bass
        # doesn't buzz
        bass_x = eq(bassL.x * sc_bass, pb.HighpassFilter(32), pb.PeakFilter(900, -2.0, 0.8), pb.LowpassFilter(1800),
                    pb.LowShelfFilter(75, 1.5))
    else:
        bass_x = eq(bassL.x * sc_bass, pb.HighpassFilter(32), pb.PeakFilter(900, 2.0, 1.0), pb.LowShelfFilter(75, 0.0 if warehouse else 1.5))
    # the intro: the bass starts dark (only its low end) and opens up as the band comes in, so it never sounds bare
    first = next((b for b, B in enumerate(S.bars) if B['sec'] != 'I'), 0)
    if first:
        lo_part = eq(bass_x, pb.LowpassFilter(220), pb.LowpassFilter(220))
        hi_part = bass_x - lo_part
        t = np.arange(n) / SR
        t_open = first * S.bar
        open_ = np.clip(0.2 + 0.8 * (t - (t_open - S.bar)) / S.bar, 0.2, 1.0)    # 20 %, opening over the last intro bar
        bass_x = lo_part + hi_part * open_
    if warehouse:
        ch = delay(chords.x, S.beat * 0.75, feedback=0.55, mix=0.45, hp_hz=400, lp_hz=2800)
        ch = reverb(ch, size=0.85, damp=0.6, wet=0.35, pre_hp=300)
        ch = eq(ch, pb.HighpassFilter(180)) * sc_mid
    else:
        ch = fx(chords.x, pb.Chorus(rate_hz=0.4, depth=0.25, mix=0.4))
        ch = reverb(ch, size=0.9, damp=0.4, wet=0.4, pre_hp=200)
        ch = eq(ch, pb.HighpassFilter(160)) * sc_pad
    oh_x = hats_open.x
    ride_x = eq(ride_l.x, pb.HighpassFilter(2500))

    core = drums_x + bass_x + rum
    if mel.get('phone', True):
        core = phone_bass(core)
    L['core'].x = core
    L['full'].x = core + ch + oh_x + ride_x

    a = delay(arp.x, S.beat * 0.75, feedback=0.4, mix=0.35, hp_hz=500, lp_hz=6000)
    L['arp'].x = reverb(a, size=0.6, wet=0.2) * sc_mid * (0.55 + 0.4 * (1 - ease))
    L['perc'].x = reverb(perc.x, size=0.4, wet=0.15)
    o = reverb(odst.x, size=0.8, wet=0.35, pre_hp=300) * sc_pad
    L['od'].x = od.x + eq(o, pb.HighpassFilter(250))
    L['jet'].x = jet.x + wind(n) * 0.5

    # the melody: every ring note on melA / melB, the in-between notes on ghost; clearer in the early cities
    # (melodic: the breathy flute the user picked, 6 dB above its own level, which was already 3 dB above the options
    # page where it was matched to the old lead)
    lead = acid if warehouse else (lambda p, d, accent=True: leads.breath_flute(p, d, accent) * 10 ** (6.0 / 20))
    shift = mel.get('octave', 0)
    rl = mel.get('ring_len', 0.85)
    cc = dict(c, notes=[dict(x, note=x['note'] + shift) for x in c['notes']],
              ghosts=[dict(x, note=x['note'] + shift) for x in c['ghosts']] if mel.get('ghosts', True) else [])
    place_lead(L, cc, lead, ease, ring_len=rl)
    if ext and mel.get('lead'):
        # the outside instrument plays the melody, each line at the flute's level (or under it, doubling it)
        eighth = c['beat'] / 2.0
        lines = {'melA': [x for i, x in enumerate(cc['notes']) if i % 2 == 0],
                 'melB': [x for i, x in enumerate(cc['notes']) if i % 2 == 1], 'ghost': cc['ghosts']}
        for k, xs in lines.items():
            if not xs:
                continue
            nn = [(x['t'], max(0.1, x['len'] * eighth * rl), x['note'], 100 if k != 'ghost' else 72) for x in xs]
            y = np.zeros((2, n)); z = ext(mel['lead'], nn, D)[:, :n]; y[:, :z.shape[1]] = z
            want = active_rms_db(L[k].x)
            L[k].x = level(y, want) + L[k].x * 0.6 if mel.get('double') else level(y, want)
    finish_lead(L, S, ease, kicks, room_size=0.5 if warehouse else 0.85, bright_db=3.0)
    return L, S
