"""Rio de Janeiro on real performances: loops recorded by real players (CC0, Freesound), stretched to Rio's 120 BPM and
laid on its bar grid, the guitar loops shifted onto Rio's chords. Only the melody is played note by note (real trumpet,
trombone and violin recordings from VSCO 2 CE), so the rings stay put. Sources and licences: loops/meta.json.
"""
import os, json, subprocess
import numpy as np
import soundfile as sf
import pedalboard as pb
from engine import *
from arr import Song, LAYERS, ease_for, lead_levels, finish_lead
import sampler
from sampler import RPart

# the loops' mp3s (fetched with loops/fs_get.py; not in the repo)
LOOPS = os.environ.get('LOOPS', os.path.join(os.path.dirname(os.path.abspath(__file__)), 'loops/raw'))
_cache = {}


def raw(sid):
    if sid not in _cache:
        w = os.path.join(LOOPS, f'{sid}.wav')
        if not os.path.exists(w):
            subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', os.path.join(LOOPS, f'{sid}.mp3'), '-ar', str(SR), '-ac', '2', w], check=True)
        x, _ = sf.read(w, always_2d=True, dtype='float32')
        _cache[sid] = x.T.astype(np.float64)
    return _cache[sid]


def fit(x, seconds, semis=0.0):
    """stretch (and shift) a loop to exactly `seconds`, with tiny fades so it joins cleanly"""
    factor = x.shape[1] / (seconds * SR)
    y = pb.time_stretch(x.astype(np.float32), SR, stretch_factor=float(factor), pitch_shift_in_semitones=float(semis),
                        high_quality=True).astype(np.float64)
    n = int(round(seconds * SR))
    if y.shape[1] < n:
        y = np.pad(y, ((0, 0), (0, n - y.shape[1])))
    y = y[:, :n].copy()
    f = int(0.004 * SR)
    y[:, :f] *= np.linspace(0, 1, f)
    y[:, -f:] *= np.linspace(1, 0, f)
    return y


class Bed:
    def __init__(self, n):
        self.x = np.zeros((2, n))

    def put(self, y, t, gain=1.0):
        a = int(round(t * SR))
        if a >= self.x.shape[1]:
            return
        m = min(self.x.shape[1] - a, y.shape[1])
        self.x[:, a:a + m] += y[:, :m] * gain


def tile(bed, S, loop, bars, which, gain=1.0):
    """lay a loop that is `bars` long on every bar b where which(b) is true (aligned to multiples of `bars`)"""
    for b in range(0, len(S.bars), bars):
        if which(b):
            bed.put(loop, b * S.bar, gain)


def beat_phase(x, period):
    """where the beats fall in a recording (seconds into the first period), from its onsets"""
    m = x.mean(0)
    hop = 256
    env = np.abs(np.diff(np.log1p(np.abs(m[::hop]) * 50)))
    fps = SR / hop
    best, arg = -1, 0.0
    for off in np.arange(0, period, 0.01):
        idx = (off + np.arange(0, len(env) / fps - period, period)) * fps
        s = env[np.clip(idx.astype(int), 0, len(env) - 1)].sum()
        if s > best:
            best, arg = s, off
    return arg


# the bossa guitarist's one-bar loops (90 BPM), and how far to shift each onto Rio's chords
GUITAR = {'G': ('74201', -3), 'E': ('74194', -4), 'C': ('74193', 0), 'D': ('74199', 0), 'D2': ('74200', 0)}
NOTE = {55: 'G', 43: 'G', 52: 'E', 40: 'E', 48: 'C', 60: 'C', 50: 'D', 38: 'D'}


def guitar_bed(S, n, which, gain=1.0):
    bed = Bed(n)
    made = {}
    for b in range(len(S.bars)):
        if not which(b):
            continue
        root, iv = S.chord(b)
        k = NOTE.get(root, 'G')
        if k == 'D' and b % 2:
            k = 'D2'
        if k not in made:
            sid, semis = GUITAR[k]
            made[k] = fit(raw(sid), S.bar, semis)
        bed.put(made[k], b * S.bar, gain)
    return bed.x


def low(root, lo=31):
    while root >= lo + 12:
        root -= 12
    while root < lo:
        root += 12
    return root


STYLES = ['escola', 'bossa', 'baiao', 'bloco', 'ijexa', 'eletronico']
TITLES = {'escola': 'Escola de Samba', 'bossa': 'Bossa Nova', 'baiao': 'Baião', 'bloco': 'Bloco de Rua',
          'ijexa': 'Ijexá', 'eletronico': 'Carnaval Eletrônico'}


MELODIES = {
    # name: (instrument, kind, octave, natural vibrato?, synthetic vibrato cents, base velocity, tame dB)
    'trumpet': ('trumpet_vib', 'wind', 0, True, 0.0, 60, -7.0),
    'sax': ('tenor_vib', 'wind', -12, True, 0.0, 80, -4.0),
    'violin': ('solo_violin', 'wind', 0, True, 0.0, 70, -9.0),
    'piano': ('upright_piano', 'pluck', 0, False, 0.0, 80, 0.0),
    'trombone': ('trombone', 'wind', -12, False, 16.0, 76, -3.0),
    'sax_samba': ('tenor_vib', 'samba', -12, True, 0.0, 82, -4.0),
    'guitar': ('iowa_guitar', 'guitar', 0, True, 0.0, 84, -3.0),
    'guitar_low': ('iowa_guitar', 'guitar', -12, True, 0.0, 84, -3.0),
    'guitar_warm': ('iowa_guitar', 'guitar', 0, True, 0.0, 78, -7.0),
}


def build(c, style, ease=None, mel_db=0.0, melody=None):
    ease = ease_for(c) if ease is None else ease
    S = Song(c)
    D = S.dur
    bpm = c['bpm']
    L = {k: Layer(D) for k in LAYERS}
    n = L['core'].n
    bar = S.bar
    secs = [B['sec'] for B in S.bars]
    lv = [B.get('lvl', 0) if B['sec'] == 'I' else 3 for B in S.bars]
    play = lambda b: secs[b] != 'E'
    band = lambda b: secs[b] in ('A', 'B', 'C', 'O')
    big = lambda b: secs[b] in ('B', 'C', 'O')
    lay = {k: [] for k in ('core', 'band', 'arp', 'perc', 'od')}
    seed = [0]

    def part(inst, jitter=0.006):
        seed[0] += 1
        return RPart(sampler.get(inst), jitter, 0.0, seed[0])

    def pizz_bass(pattern):
        p = part('bass_pizz', 0.008)
        for b in range(len(S.bars)):
            if secs[b] == 'E':
                p.note(b * bar, 2.0, low(S.chord(b)[0]), 90)
                continue
            if secs[b] == 'I' and lv[b] < 1:
                continue
            r = low(S.chord(b)[0])
            for st, dv in pattern:
                p.note(b * bar + st * bar / 16, bar / 16 * 3, r + dv, 88)
        return p.render(bpm, D)

    def brass_hits(steps, inst='trumpet_stac', which=big, vel=92):
        p = part(inst, 0.004)
        for b in range(len(S.bars)):
            if which(b):
                root, iv = S.chord(b)
                for st in steps:
                    for q in sorted({((root + x - 62) % 12) + 62 for x in iv}):
                        p.note(b * bar + st * bar / 16, bar / 16 * 1.5, q, vel)
        return eq(p.render(bpm, D), pb.PeakFilter(3200, -5.0, 0.7))

    def crash():
        p = part('parlour_kit', 0.0)
        for b in range(0, len(S.bars), 4):
            if band(b):
                p.note(b * bar, 1.5, 49, 70)
        return p.render(bpm, D)

    lead, tame, ring, lead_vel = [('trumpet', 0, 0.0)], -5.0, 0.95, 104

    if style == 'escola':
        # a samba school's bateria: the real surdo, pandeiro and tamborim loops recorded together (120.9 BPM), a
        # second tamborim pattern and shaker answering, the Carnival crowd far behind; trombones swell in the chorus
        surdo, pand, tamb = fit(raw('36126'), 2 * bar), fit(raw('36134'), 2 * bar), fit(raw('36128'), 2 * bar)
        shake, tamb2 = fit(raw('36123'), 2 * bar), fit(raw('36130'), 2 * bar)
        core, full, perc = Bed(n), Bed(n), Bed(n)
        tile(core, S, surdo, 2, play)
        tile(core, S, pand, 2, lambda b: band(b) or lv[b] >= 1)
        tile(full, S, tamb, 2, band)
        tile(perc, S, shake, 2, band)
        tile(perc, S, tamb2, 2, big, 0.8)
        crowd = fit(raw('334469')[:, :int(40 * SR)], 40.0)
        perc.put(np.tile(crowd, (1, int(np.ceil(D / 40)) + 1))[:, :n], 0.0, 0.25)
        bones = part('trombone', 0.01)
        for b in range(len(S.bars)):
            if big(b):
                root, iv = S.chord(b)
                for q in sorted({((root + x - 50) % 12) + 50 for x in iv}):
                    bones.note(b * bar, bar * 0.9, q, 70)
        lay['core'] += [(core.x, -18, 0.12, 0.5)]
        lay['band'] += [(full.x, -22, 0.12, 0.5), (bones.render(bpm, D), -25, 0.3, 0.7)]
        lay['perc'] += [(perc.x, -24, 0.15, 0.6)]
        lay['od'] += [(brass_hits((0, 3, 6, 10)), -22, 0.3, 0.7), (crash(), -28, 0.3, 0.7)]

    elif style == 'bossa':
        # Ipanema: the real bossa guitarist (his loops shifted onto Rio's chords), his tantan drum, a real shaker,
        # upright bass; soft strings in the chorus; the tune on a muted trumpet
        tant, shake = fit(raw('74190'), bar), fit(raw('36123'), 2 * bar)
        core, perc = Bed(n), Bed(n)
        tile(core, S, tant, 1, lambda b: play(b) and (band(b) or lv[b] >= 1))
        tile(perc, S, shake, 2, band)
        strings = part('violins', 0.01)
        for b in range(len(S.bars)):
            if big(b):
                root, iv = S.chord(b)
                for q in sorted({((root + x - 64) % 12) + 64 for x in list(iv) + [11 if iv[1] == 4 else 10]}):
                    strings.note(b * bar, bar * 0.98, q, 56)
        lay['core'] += [(core.x, -22, 0.12, 0.5), (pizz_bass(((0, 0), (6, 7), (8, 0), (14, 7))), -21, 0.1, 0.4)]
        lay['band'] += [(guitar_bed(S, n, lambda b: play(b) and (band(b) or lv[b] >= 2)), -19, 0.2, 0.5)]
        lay['arp'] += [(eq(strings.render(bpm, D), pb.PeakFilter(3000, -5.0, 0.7)), -27, 0.45, 0.85)]
        lay['perc'] += [(perc.x, -28, 0.15, 0.5)]
        lay['od'] += [(crash(), -30, 0.3, 0.7)]
        # (a Harmon-muted trumpet measured almost all 2-5 kHz, piercing on phones: the open trumpet, played softly)
        lead, tame, lead_vel = [('trumpet', 0, 0.0)], -6.0, 52

    elif style == 'baiao':
        # the north-east's baiao: a real drummer on brushes (his one-bar grooves, varied bar to bar), the real forro
        # triangle, upright bass on the baiao rhythm, the guitarist's chords; the tune on a fiddle (rabeca)
        grooves = [fit(raw(s), bar) for s in ('74371', '74379', '74380', '74381')]
        tri = fit(raw('405415')[:, :int(raw('405415').shape[1] // 2)], 8 * bar)
        core, perc = Bed(n), Bed(n)
        for b in range(len(S.bars)):
            if play(b) and (band(b) or lv[b] >= 1):
                core.put(grooves[0 if b % 4 != 3 else 1 + (b // 4) % 3], b * bar)
        tile(perc, S, tri, 8, band)
        lay['core'] += [(core.x, -19, 0.12, 0.5), (pizz_bass(((0, 0), (6, 0), (8, 7), (14, 7))), -21, 0.1, 0.4)]
        lay['band'] += [(guitar_bed(S, n, lambda b: band(b)), -23, 0.2, 0.5)]
        lay['perc'] += [(perc.x, -26, 0.15, 0.5)]
        lay['od'] += [(brass_hits((2, 6, 10)), -23, 0.3, 0.7), (crash(), -28, 0.3, 0.7)]
        lead, tame = [('solo_violin', 0, 0.0)], -9.0

    elif style == 'bloco':
        # a street bloco at Carnival: a field recording of a real Brazilian street Carnival band (119.5 BPM, no strong
        # key, so it doesn't clash), lined up on the beat, the real surdo loop to keep it steady, a brass fanfarra
        # answering; the tune on a trumpet
        rec = raw('334469')
        st = fit(rec, rec.shape[1] / SR * 119.5 / 120.0)
        ph = beat_phase(st, S.beat)
        st = st[:, int(ph * SR):]
        street = np.tile(st, (1, int(np.ceil(n / st.shape[1])) + 1))[:, :n]
        surdo = fit(raw('36126'), 2 * bar)
        core = Bed(n)
        tile(core, S, surdo, 2, play)
        g = np.zeros(n)
        for b in range(len(S.bars)):
            if band(b) or lv[b] >= 1:
                g[int(b * bar * SR):int((b + 1) * bar * SR)] = 1.0
        g = np.convolve(g, np.ones(int(0.3 * SR)) / int(0.3 * SR), mode='same')
        street = eq(street, pb.HighpassFilter(55), pb.HighpassFilter(55))     # the street's rumble, which phones can't play
        lay['core'] += [(core.x, -21, 0.1, 0.5), (street * g, -20, 0.05, 0.4)]
        fan = part('trombone_short', 0.006)
        for b in range(len(S.bars)):
            if band(b):
                root, iv = S.chord(b)
                for stp in (0, 3, 6, 10):
                    for q in sorted({((root + x - 50) % 12) + 50 for x in iv}):
                        fan.note(b * bar + stp * bar / 16, bar / 16 * 1.6, q, 84)
        lay['band'] += [(fan.render(bpm, D), -24, 0.25, 0.6), (pizz_bass(((0, 0), (8, 7))), -24, 0.1, 0.4)]
        lay['od'] += [(brass_hits((0, 3, 6, 10)), -22, 0.3, 0.7), (crash(), -28, 0.3, 0.7)]

    elif style == 'ijexa':
        # ijexa, the gentle Afro-Brazilian groove of the Carnival afoxes: a real agbe / shekere performance (100 BPM)
        # stretched to 120, the tantan, upright bass, the guitarist's chords; the tune on a trombone
        rec = raw('816654')
        ag = fit(rec, rec.shape[1] / SR * 100.0 / 120.0)
        ph = beat_phase(ag, S.beat)
        ag = ag[:, int(ph * SR):]
        agbe = np.tile(ag, (1, int(np.ceil(n / ag.shape[1])) + 1))[:, :n]
        tant = fit(raw('74191'), 2 * bar)
        core = Bed(n)
        tile(core, S, tant, 2, lambda b: play(b) and (band(b) or lv[b] >= 1))
        g = np.zeros(n)
        for b in range(len(S.bars)):
            if play(b):
                g[int(b * bar * SR):int((b + 1) * bar * SR)] = 1.0
        lay['core'] += [(core.x, -21, 0.15, 0.5), (agbe * g, -21, 0.1, 0.5),
                        (pizz_bass(((0, 0), (3, 0), (8, 7), (11, 7), (14, 5))), -21, 0.1, 0.4)]
        lay['band'] += [(guitar_bed(S, n, lambda b: play(b) and (band(b) or lv[b] >= 2)), -20, 0.25, 0.6)]
        lay['od'] += [(brass_hits((2, 6, 10), 'trombone_short'), -24, 0.3, 0.7), (crash(), -30, 0.3, 0.7)]
        lead, tame = [('trombone', -12, 0.0)], -3.0

    elif style == 'eletronico':
        # Carnival through a DJ: a produced Carnival percussion loop (136 BPM) stretched to 120, a deep 808 on every
        # bar, the guitarist's chords filtered like a club edit, brass stabs; the tune on a trumpet
        rec = raw('824144')
        lp = fit(rec, 8 * bar)
        core = Bed(n)
        tile(core, S, lp, 8, lambda b: play(b) and (band(b) or lv[b] >= 1))
        sub = Layer(D)
        K = kick(45, 160, 0.04, 0.5, 0.4, 2.0)
        for b in range(len(S.bars)):
            if play(b) and band(b):
                for q in range(4):
                    sub.add(K, b * bar + q * S.beat, 0.8)
        from techno import phone_bass
        lay['core'] += [(core.x, -19, 0.1, 0.4), (phone_bass(sub.x), -22, 0.0, 0.3)]
        gt = guitar_bed(S, n, band)
        lay['band'] += [(eq(gt, pb.HighpassFilter(300), pb.LowpassFilter(5000)), -22, 0.3, 0.6),
                        (brass_hits((2, 7, 10), which=band, vel=96), -24, 0.25, 0.5)]
        lay['od'] += [(crash(), -27, 0.3, 0.7)]

    def mix(items):
        x = np.zeros((2, n))
        for arr, db, wet, size in items:
            arr = arr[:, :n] if arr.shape[1] >= n else np.pad(arr, ((0, 0), (0, n - arr.shape[1])))
            if np.abs(arr).max() < 1e-7:
                continue
            y = level(eq(arr, pb.HighpassFilter(30)), db)
            x += reverb(y, size=size, damp=0.5, wet=wet) if wet else y
        return x

    L['core'].x = mix(lay['core'])
    L['full'].x = L['core'].x + mix(lay['band'])
    L['arp'].x = mix(lay['arp'])
    L['perc'].x = mix(lay['perc'])
    L['od'].x = mix(lay['od'])
    jet = part('parlour_kit', 0.0)
    for b in range(len(S.bars)):
        jet.note(b * bar, 0.3, 36, 60)
        jet.note(b * bar + 2 * S.beat, 0.3, 36, 44)
    L['jet'].x = level(eq(jet.render(bpm, D)[:, :n], pb.LowpassFilter(2000)), -30)

    ringg, ghost_g, _, _ = lead_levels(ease)
    eighth = S.beat / 2
    for k in ('melA', 'melB', 'ghost'):
        L[k].x = np.zeros((2, n))
    if melody:
        # the expressive player: phrases slurred, shaped, with vibrato where the recording has none
        import expr
        parts = melody.split('+')               # 'sax_samba+guitar': two players in unison, each a little softer
        for name in parts:
            inst, kind, octv, natural, vib, bv, tm = MELODIES[name]
            mel = expr.render(inst, c['notes'], c['ghosts'], D, kind=kind, base_vel=bv, octave=octv,
                              vib_cents=0.0 if natural else vib, eighth=eighth, ring_len=1.0 if kind != 'pluck' else 1.4,
                              stac='tenor_stac' if kind == 'samba' else None)
            for k, x in mel.items():
                x = eq(x[:, :n], pb.HighpassFilter(100 if octv < 0 else 150))
                if tm:
                    x = eq(x, pb.PeakFilter(3200, tm, 0.7), pb.HighShelfFilter(6000, -3.0), pb.LowpassFilter(9000))
                L[k].x += level(x, -15 + mel_db - (4.0 if len(parts) > 1 else 0.0)) * (ringg if k != 'ghost' else ghost_g) / 0.55
        lead = []
    for inst, octv, db in lead:
        mel = {k: part(inst, 0.003) for k in ('melA', 'melB', 'ghost')}
        for i, nt in enumerate(c['notes']):
            mel['melA' if i % 2 == 0 else 'melB'].note(nt['t'], max(0.22, nt['len'] * eighth * ring), nt['note'] + octv, lead_vel)
        for g in c['ghosts']:
            mel['ghost'].note(g['t'], max(0.2, g['len'] * eighth * ring), g['note'] + octv, int(lead_vel * 0.8))
        for k, p in mel.items():
            x = eq(p.render(bpm, D)[:, :n], pb.HighpassFilter(100 if octv < 0 else 150))
            if tame:
                x = eq(x, pb.PeakFilter(3200, tame, 0.7), pb.HighShelfFilter(6000, -3.0), pb.LowpassFilter(9000 if tame > -10 else 5000))
            L[k].x += level(x, -15 + mel_db + db) * (ringg if k != 'ghost' else ghost_g) / 0.55
    finish_lead(L, S, ease, [], hp_hz=120, bright_db=0.0, room_size=0.6)
    return L, S
