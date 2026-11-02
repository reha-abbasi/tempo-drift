"""Main-menu themes: one original tune for Tempo Drift, arranged four ways, each a seamless loop.

The loop is rendered three times back to back and the middle copy is kept, so the reverb and note tails at the end of
the loop are the ones that ring into its start: it loops with no seam.

usage: menu.py OUT_DIR [STYLE ...]     styles: traveller, lofi, neon, eras
"""
import os, sys
import numpy as np
from engine import *
import sampler
from sampler import RPart

BPM = 96
BEAT = 60.0 / BPM
BAR = 4 * BEAT
E = BEAT / 2                       # an eighth

# the chords, 8 bars in D major: D - Bm7 - Gmaj7 - A(sus) | D/F# - G - Em7 - A7
CHORDS = [(50, [0, 4, 7, 11]), (47, [0, 3, 7, 10]), (43, [0, 4, 7, 11]), (45, [0, 5, 7, 10]),
          (50, [0, 4, 7, 9]), (43, [0, 4, 7, 14]), (52, [0, 3, 7, 10]), (45, [0, 4, 7, 10])]

# the tune: (bar, eighth, MIDI note, length in eighths). A rising call, an answer, a lift, and a home.
TUNE = [
    (0, 0, 78, 3), (0, 3, 76, 1), (0, 4, 74, 2), (0, 6, 69, 2),
    (1, 0, 71, 2), (1, 2, 74, 2), (1, 4, 76, 2), (1, 6, 78, 2),
    (2, 0, 79, 3), (2, 3, 78, 1), (2, 4, 76, 2), (2, 6, 74, 2),
    (3, 0, 76, 6), (3, 6, 69, 2),
    (4, 0, 78, 3), (4, 3, 76, 1), (4, 4, 74, 2), (4, 6, 81, 2),
    (5, 0, 79, 2), (5, 2, 78, 2), (5, 4, 76, 2), (5, 6, 74, 2),
    (6, 0, 76, 3), (6, 3, 74, 1), (6, 4, 71, 2), (6, 6, 73, 2),
    (7, 0, 74, 8),
]
LOOP_BARS = 16                     # the 8 bars twice: first time quieter, second time fuller


def chord_at(b):
    return CHORDS[b % 8]


def voicing(root, iv, lo, hi):
    ps = sorted({((root + x - lo) % 12) + lo for x in iv})
    return sorted(p if p <= hi else p - 12 for p in ps)


def swing_t(t, amt=0.0):
    """lay an off-beat eighth back a little (amt 0..1 of an eighth's third)"""
    k = t / E
    if amt and abs(k - round(k)) < 1e-6 and int(round(k)) % 2 == 1:
        return t + amt * E / 3
    return t


class Song:
    """three copies of the loop on one timeline; parts add notes with loop-relative times"""

    def __init__(self, loops=3):
        self.loops = loops
        self.L = LOOP_BARS * BAR
        self.D = self.L * loops + 4.0
        self.n = ns(self.D)

    def each(self):
        for k in range(self.loops):
            for b in range(LOOP_BARS):
                yield k * self.L + b * BAR, b

    def middle(self, x):
        a, z = ns(self.L), ns(2 * self.L)
        return x[:, a:z]


def tune_part(song, part, vel=96, octave=0, legato=0.95, half=None, sw=0.0):
    for t0, b in song.each():
        if b % 8 != 0:
            continue
        second = b >= 8
        if half == 'second' and not second:
            continue
        if half == 'first' and second:
            continue
        for bb, e, note, ln in TUNE:
            t = swing_t(t0 + bb * BAR + e * E, sw)
            part.note(t, ln * E * legato, note + octave, vel + (8 if second else 0))


def surge_part(patch, notes, seconds):
    import surge_render as sr
    p = sr.load(os.path.join(sr.PATCHES, patch + '.fxp'))
    return sr.render_notes(p, notes, seconds)


def drums_engine(song, style):
    """my own drums: soft for the menu"""
    L = Layer(song.D)
    K = kick(48, 180, 0.03, 0.3, 0.5, 1.6)
    SN = snare(0.14, 200)
    CH = hat(0.03)
    CL = reverb(clap(0.14, 1300), size=0.4, wet=0.25)
    for t0, b in song.each():
        for q in range(4):
            if style == 'neon' or q in (0, 2) or (q == 3 and b % 4 == 3):
                L.add(K, t0 + q * BEAT, 0.8 if style == 'neon' else 0.6)
        for q in (1, 3):
            L.add(CL if style == 'neon' else SN, t0 + q * BEAT, 0.4)
        for e in range(8):
            L.add(CH, t0 + e * E, 0.5 if e % 2 else 0.3, 0.2)
    return L.x


def kit_part(song, kit, pattern, gain=1.0):
    p = RPart(sampler.get(kit), 0.004)
    for t0, b in song.each():
        if pattern == 'brush':
            for e in range(8):
                p.note(swing_t(t0 + e * E, 0.6), 0.1, 38, 40 if e % 2 else 52)
            for q in (0, 2):
                p.note(t0 + q * BEAT, 0.1, 36, 50)
            for q in (1, 3):
                p.note(t0 + q * BEAT, 0.1, 44, 46)
        elif pattern == 'pub':
            for q in (0, 2):
                p.note(t0 + q * BEAT, 0.1, 36, 80)
            for q in (1, 3):
                p.note(t0 + q * BEAT, 0.1, 38, 70)
            for e in range(8):
                p.note(swing_t(t0 + e * E, 0.6), 0.1, 42, 50 if e % 2 else 40)
            if b % 8 == 0:
                p.note(t0, 1.5, 49, 60)
    return p.render(BPM, song.D)


def build(style):
    song = Song()
    D = song.D
    mix = []

    def add(x, db, rev=0.25, size=0.6, lo=40, hi=12000):
        x = eq(x, pb.HighpassFilter(lo), pb.LowpassFilter(hi))
        mix.append(reverb(level(x, db), size=size, damp=0.5, wet=rev))

    if style == 'traveller':
        # cinematic: strings carry the chords, the piano ripples, a soft trumpet sings the tune (second time), a
        # violin section takes it the first time; timpani-like low drum on the phrase starts
        strings = RPart(sampler.get('violins'), 0.006)
        piano = RPart(sampler.get('upright_piano'), 0.006)
        bass = RPart(sampler.get('bass_pizz'), 0.006)
        for t0, b in song.each():
            root, iv = chord_at(b)
            for p in voicing(root, iv, 62, 76):
                strings.note(t0, BAR * 0.98, p, 60 if b < 8 else 72)
            arp = voicing(root, iv, 57, 72)
            arp = arp + [arp[0] + 12] + arp[::-1][1:]
            for e in range(8):
                piano.note(t0 + e * E, E * 1.6, arp[e % len(arp)], 64 if e % 2 else 74)
            bass.note(t0, BEAT * 1.8, root - 12 if root > 45 else root, 90)
            bass.note(t0 + 2 * BEAT, BEAT * 1.8, root - 12 + iv[2] if root > 45 else root + iv[2], 80)
        lead1 = RPart(sampler.get('violins'), 0.004)
        lead2 = RPart(sampler.get('trumpet'), 0.004)
        tune_part(song, lead1, 70, -12, half='first')
        tune_part(song, lead2, 84, -12, half='second')
        add(eq(strings.render(BPM, D), pb.PeakFilter(3000, -5.0, 0.7), pb.HighShelfFilter(6000, -3.0)), -24, 0.4, 0.85)
        add(piano.render(BPM, D), -23, 0.3, 0.7)
        add(bass.render(BPM, D), -21, 0.15, 0.5, 30, 3000)
        add(eq(lead1.render(BPM, D), pb.PeakFilter(3000, -5.0, 0.7), pb.HighShelfFilter(6000, -3.0)), -19, 0.35, 0.8)
        lead = eq(lead2.render(BPM, D), pb.PeakFilter(3200, -5.0, 0.7), pb.HighShelfFilter(6000, -3.0))
        add(lead, -17, 0.35, 0.8, 120, 9000)
        add(kit_part(song, 'parlour_kit', 'brush'), -30, 0.25, 0.6)

    elif style == 'lofi':
        # relaxed: jazzy piano chords laid back, plucked upright bass, brushes, the tune on the piano's top
        piano = RPart(sampler.get('upright_piano'), 0.012, 0.01)
        bass = RPart(sampler.get('bass_pizz'), 0.01)
        mel = RPart(sampler.get('upright_piano'), 0.006)
        for t0, b in song.each():
            root, iv = chord_at(b)
            v = voicing(root, iv + [14], 55, 69)
            for e, d, vel in ((0, 3, 62), (3, 2, 56), (6, 2, 52)):
                for k, p in enumerate(v):
                    piano.note(swing_t(t0 + e * E, 0.6) + k * 0.012, d * E, p, vel)
            line = [root - 12 if root > 45 else root, None, root - 12 + iv[2] if root > 45 else root + iv[2], None]
            for q, p in enumerate(line):
                if p:
                    bass.note(t0 + q * BEAT, BEAT * 1.5, p, 84)
        tune_part(song, mel, 70, 0, legato=1.3, sw=0.6)
        add(piano.render(BPM, D), -22, 0.25, 0.6, 60, 7000)
        add(bass.render(BPM, D), -21, 0.1, 0.4, 30, 2500)
        add(mel.render(BPM, D), -19, 0.3, 0.7, 100, 8000)
        add(kit_part(song, 'parlour_kit', 'brush'), -28, 0.2, 0.5, 60, 9000)

    elif style in ('neon', 'eras'):
        # synthwave on the Surge sounds from Berlin: warm pad, deep bass in eighths, a plucked arpeggio, the smooth
        # synth lead; my own soft drums. 'eras': the first 8 bars are the London pub band, then the synths arrive
        n_band = []
        pad_n, bass_n, arp_n, lead_n = [], [], [], []
        for t0, b in song.each():
            if style == 'eras' and b < 8:
                continue
            root, iv = chord_at(b)
            for p in voicing(root, iv, 57, 72):
                pad_n.append((t0, BAR * 0.98, p, 80))
            for e in range(8):
                bass_n.append((t0 + e * E, E * 0.8, (root - 12 if root > 40 else root), 100 if e % 2 == 0 else 84))
            arp = voicing(root, iv, 64, 79)
            for s in range(16):
                arp_n.append((t0 + s * E / 2, E * 0.4, arp[s % len(arp)] + (12 if (s // 4) % 2 else 0), 90 if s % 4 == 0 else 70))
        for t0, b in song.each():
            if b % 8 == 0 and not (style == 'eras' and b < 8):
                for bb, e, note, ln in TUNE:
                    lead_n.append((t0 + bb * BAR + e * E, ln * E * 0.95, note, 100))
        sec = D
        add(surge_part('Pads/MKS-70 Warm Pad', pad_n, sec), -23, 0.35, 0.8)
        from techno import phone_bass
        # the same phone-friendly bass as Berlin: less deep sub, a soft octave a phone can play
        add(phone_bass(surge_part('Basses/Deep End', bass_n, sec)), -22, 0.05, 0.3, 30, 1800)
        add(surge_part('Plucks/Nice Pluck 1', arp_n, sec), -27, 0.3, 0.7, 300, 9000)
        lead = surge_part('Leads/Butter', lead_n, sec)
        add(lead, -18, 0.3, 0.75, 150, 9000)
        dr = drums_engine(song, 'neon')
        if style == 'eras':
            # the synth half: drums come in with the synths
            g = np.zeros(song.n)
            for t0, b in song.each():
                if b >= 8:
                    g[ns(t0):ns(t0 + BAR)] = 1.0
            dr = dr * g
            # the London half: pub piano, tuba, strumstick, the tune on the trumpet, the pub kit
            piano = RPart(sampler.get('pub_piano'), 0.008)
            tuba = RPart(sampler.get('tuba_sus'), 0.006)
            strum = RPart(sampler.get('strumstick'), 0.008)
            trumpet = RPart(sampler.get('trumpet'), 0.004)
            for t0, b in song.each():
                if b >= 8:
                    continue
                root, iv = chord_at(b)
                tuba.note(t0, BEAT * 1.6, root - 12 if root > 45 else root, 92)
                tuba.note(t0 + 2 * BEAT, BEAT * 1.6, (root - 12 if root > 45 else root) + iv[2], 84)
                for q in (1, 3):
                    for p in voicing(root, iv, 55, 68):
                        piano.note(t0 + q * BEAT, BEAT * 0.5, p, 74)
                for q in range(4):
                    for j, p in enumerate(voicing(root, iv, 57, 69)):
                        strum.note(t0 + q * BEAT + j * 0.006, BEAT * 0.4, p, 86 if q % 2 else 66)
            tune_part(song, trumpet, 86, -12, half='first')
            g = np.zeros(song.n)
            for t0, b in song.each():
                if b < 8:
                    g[ns(t0):ns(t0 + BAR + 0.6)] = 1.0
            pub_kit = kit_part(song, 'parlour_kit', 'pub') * g
            add(piano.render(BPM, D), -23, 0.3, 0.7)
            add(tuba.render(BPM, D), -20, 0.12, 0.5, 30, 3000)
            add(strum.render(BPM, D), -24, 0.25, 0.6)
            tr = eq(trumpet.render(BPM, D), pb.PeakFilter(3200, -5.0, 0.7), pb.HighShelfFilter(6000, -3.0))
            add(tr, -17, 0.35, 0.8, 120, 9000)
            add(pub_kit, -26, 0.2, 0.5)
        add(dr, -24, 0.1, 0.4)
        if style == 'eras':
            # a time warp into each era: a rising sweep over the last bar before the synths, and before the loop
            # returns to London
            w = Layer(D)
            for t0, b in song.each():
                if b in (7, 15):
                    w.add(riser(BAR, 200.0, 7000.0), t0, 1.0)
            add(eq(w.x, pb.LowpassFilter(4500)), -31, 0.5, 0.9, 150, 5000)
    x = sum(mix)
    x = song.middle(x)
    return x


def master(x, target=-14.0):
    """menu music sits a bit under the episodes; a gentle glue and a safety limiter"""
    G = 10 ** ((target - loudness(x)[0]) / 20)
    for _ in range(4):
        y = x * G
        y = y * master_gain(y, ceiling_db=-1.5, glue_db=-10.0, glue_ratio=1.6)
        lufs, peak = loudness(y)
        if abs(lufs - target) < 0.3:
            break
        G *= 10 ** ((target - lufs) / 20)
    return y, lufs, peak


if __name__ == '__main__':
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    for st in sys.argv[2:] or ['traveller', 'lofi', 'neon', 'eras']:
        x = build(st)
        y, lufs, peak = master(x)
        # two passes of the loop in the preview, so the seam can be heard
        prev = np.concatenate([y, y], axis=1)
        to_mp3(prev, os.path.join(out, f'menu_{st}.mp3'), fade_out=0.0)
        to_ogg(y, os.path.join(out, f'menu_{st}.ogg'), 5)
        print(f'{st}: {y.shape[1] / SR:.1f} s loop, {lufs:.1f} LUFS, peak {peak:.1f} dBFS', flush=True)
