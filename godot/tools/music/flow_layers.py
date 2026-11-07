"""Flow music: the extra layers that make a city's band grander the longer you play without missing.

usage: flow_layers.py old_0|sunset_1|rain_5 [OUT_DIR] [--check]

Each city's song is built again exactly as it was rendered for the game (same course, same style, same random
seeds), mastered the same way, and the new layers are built on top of it and given the very same master gain curve,
so they add up with the existing layers in the game. The existing layers are not written again (they stay as they
are); --check compares the rebuilt ones with the game's files to prove the gain matches.

The new layers (scripts/flow_music.gd fades them in, in order, as the band grows):
  up1 .. up4  the band's grander parts (each city its own: bigger drums, strings, brass, a fuller bateria...)
  rise        a fill on the last beat of every bar and a crash on every downbeat: opened only on the beat before
              the band grows a step, so each new step arrives with a fill
"""
import json, os, sys, time
import numpy as np
import pedalboard as pb

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.abspath(os.path.join(HERE, '..', '..'))
SCRATCH = os.environ.get('SCRATCH', '/tmp/claude-1000/-workspaces-Claude-sandbox/cf9a3551-fa16-4fcd-9ea5-d1354809ee47/scratchpad')
os.environ.setdefault('LOOPS', os.path.join(SCRATCH, 'loops/raw'))
sys.path.insert(0, HERE)

from engine import *          # noqa: E402
from render import preview_gains   # noqa: E402

BAND = ('full', 'arp', 'perc', 'od', 'ghost', 'melA', 'melB')


def master(L, S, target, glue_db, glue_ratio, tries):
    """the master gain curve exactly as the city's render script computed it (jazz_render / rio_render / surge game)"""
    gains = preview_gains(S, L['core'].n)
    loudest = sum(L[k].x for k in BAND)
    G = 10 ** ((target - loudness(loudest)[0]) / 20)
    for _ in range(tries):
        mg = master_gain(loudest * G, ceiling_db=-1.5, glue_db=glue_db, glue_ratio=glue_ratio)
        prev = sum(L[k].x * G * mg * gains[k] for k in gains)
        prev = prev * master_gain(prev, ceiling_db=-1.5, glue_db=40.0)
        lufs, peak = loudness(prev)
        if abs(lufs - target) < 0.3:
            break
        G *= 10 ** ((target - lufs) / 20)
    return G * mg


def read_ogg(path, n):
    import soundfile as sf, subprocess, tempfile
    fd, wav = tempfile.mkstemp(suffix='.wav')
    os.close(fd)
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', path, '-ar', str(SR), wav], check=True)
    x, _ = sf.read(wav, always_2d=True, dtype='float64')
    os.unlink(wav)
    x = x.T
    out = np.zeros((2, n))
    m = min(n, x.shape[1])
    out[:, :m] = x[:, :m]
    return out


def check(L, gm, ep):
    """the rebuilt layers against the game's files: how far apart (dB below the layer) and the level difference"""
    for k in ('core', 'full', 'perc', 'od', 'melA'):
        f = os.path.join(GAME, 'audio', ep, k + '.ogg')
        if not os.path.exists(f):
            continue
        mine = L[k].x * gm
        theirs = read_ogg(f, mine.shape[1])
        rms = lambda a: 10 * np.log10(np.mean(a ** 2) + 1e-20)
        print(f'  check {k}: level {rms(mine) - rms(theirs):+.2f} dB, difference {rms(mine - theirs) - rms(theirs):.1f} dB',
              flush=True)


# ------------------------------------------------------------------ London 1890: the pub band grows into a music hall

def london(c):
    import jazz, sampler
    from arr import voicing
    L, S = jazz.build(c, 'pub_full', mel_db=-4.0)
    gm = master(L, S, -12.0, -8.0, 1.8, 4)
    n = L['core'].n
    D = S.dur
    bpm = c['bpm']
    at, beat, bar = S.at, S.beat, S.bar
    rng = np.random.default_rng(1890)
    hv = lambda v, s=0.08: v * (1.0 + rng.uniform(-s, s))
    secs = [B['sec'] for B in S.bars]
    play = lambda b: secs[b] not in ('I', 'E')
    big = lambda b: secs[b] in ('B', 'C')
    seed = [100]

    def part(ins, jitter=0.008, lag=0.004):
        seed[0] += 1
        return sampler.RPart(sampler.get(ins), jitter, lag, seed[0])

    def room(x, size=0.45, wet=0.18):
        return reverb(x, size=min(0.95, size + 0.3), damp=0.55, wet=wet * 1.8)

    def warm(x, lo=50.0, hi=10000.0):
        return eq(x, pb.HighpassFilter(lo), pb.LowpassFilter(hi), pb.LowShelfFilter(250, 1.0))

    def tame(x, db=-4.0):
        return eq(x, pb.PeakFilter(3200, db, 0.7), pb.HighShelfFilter(6000, -3.0), pb.LowpassFilter(9000))

    notes = c['notes']
    # up1: the music-hall drummer opens up: the big bass drum on every beat, the cymbal ringing on the swung eighths,
    # press rolls into every phrase
    bd, cy = part('parlour_kit', 0.004, 0.0), part('parlour_kit', 0.004, 0.0)
    for b in range(len(S.bars)):
        if not play(b):
            continue
        for q in range(4):
            bd.note(at(b, q * 2), 0.2, 36, hv(74 if q % 2 == 0 else 58))
        for e in range(8):
            if e % 2 == 0 or e in (3, 7):
                cy.note(at(b, e), 0.4, 51, hv(80 if e in (2, 6) else 62))
        if b % 4 == 3:
            for k in range(8):
                cy.note(at(b, 4) + k * beat / 4, 0.05, 38, 46 + 5 * k)
        if b % 4 == 0:
            cy.note(at(b, 0), 1.5, 49, hv(64))
    up1 = room(level(warm(bd.render(bpm, D), 45, 6000), -30) + level(warm(cy.render(bpm, D), 200, 12000), -29), 0.45, 0.16)

    # up2: the violins take a counter-line: long notes a sixth under the tune in the verses, soaring a third over it
    # in the choruses, each held until the next ring
    vl = part('violins', 0.01, 0.0)
    for i, x in enumerate(notes):
        b = int(x['t'] // bar)
        if b >= len(S.bars) or not play(b):
            continue
        root, iv = S.chord(b)
        pcs = {(root + k) % 12 for k in iv}
        nxt = notes[i + 1]['t'] if i + 1 < len(notes) else x['t'] + beat * 2
        d = float(np.clip(nxt - x['t'], beat * 0.9, beat * 4))
        p = x['note'] + (4 if big(b) else -8)
        while p % 12 not in pcs:
            p += -1 if not big(b) else 1
        while p > 84:
            p -= 12
        while p < 62:
            p += 12
        vl.note(x['t'], d * 0.98, p, hv(78 if big(b) else 66))
    up2 = room(level(tame(warm(vl.render(bpm, D), 180, 10000), -3.0), -26), 0.55, 0.24)

    # up3: the brass section: trumpets and trombones holding the chords and swelling into the next bar, a shout
    # chorus behind the tune
    tp, tb = part('trumpet', 0.01, 0.0), part('trombone', 0.01, 0.0)
    for b in range(len(S.bars)):
        if not play(b):
            continue
        root, iv = S.chord(b)
        for k in voicing(root, iv, 60, 72, True)[:3]:
            tp.note(at(b, 0), bar * 0.5, k, hv(60))
            tp.note(at(b, 4) - beat * 0.5 * S.swing, bar * 0.45, k, hv(72 if big(b) else 64))
        for k in voicing(root, iv, 48, 60):
            tb.note(at(b, 0), bar * 0.95, k, hv(66 if big(b) else 58))
    brass = level(tame(warm(tp.render(bpm, D), 150, 10000), -5.0), -29) + level(tame(warm(tb.render(bpm, D), 80, 8000), -2.0), -28)
    t = np.arange(n) / SR
    swell = 0.75 + 0.25 * np.clip(((t % bar) / bar) * 1.3, 0, 1)      # each bar grows into the next
    up3 = room(brass * swell, 0.55, 0.22)

    # rise: a snare roll on the last beat of every bar and the cymbal and big drum on every downbeat
    rs = part('parlour_kit', 0.0, 0.0)
    for b in range(len(S.bars)):
        for k in range(6):
            rs.note(b * bar + 3 * beat + k * beat / 6, 0.05, 38, 54 + 9 * k)
        rs.note((b + 1) * bar, 1.2, 49, 96)
        rs.note((b + 1) * bar, 0.4, 36, 100)
    rise = room(level(warm(rs.render(bpm, D), 40, 12000), -26), 0.45, 0.18)
    rise = choke_downbeats(rise, S, beats=2.0)
    # the anthem (step 8): the violins join the tune an octave up, each note on the double of its melody layer
    up = {}
    for k, par in (('melUpA', 0), ('melUpB', 1)):
        v = part('violins', 0.004, 0.0)
        for i, x in enumerate(notes):
            if i % 2 == par:
                v.note(x['t'], max(0.35, x['len'] * beat * 0.55), x['note'] + 12, 74)
        up[k] = room(level(tame(warm(v.render(bpm, D), 400, 9000), -7.0), active_rms_db(L['melA'].x) - 7.0), 0.55, 0.25)
    return L, S, gm, dict(up1=up1, up2=up2, up3=up3, rise=rise, **up)


def doubles(L, S, notes, render, below_db, hp=300.0, tame_db=-6.0):
    """the anthem's doubles of the two melody layers: render(notes) -> stereo, each note on its own layer's double,
    tamed in the 2-5 kHz bite, set below_db under the melody, with the melody's echo and room"""
    up = {}
    for k, par in (('melUpA', 0), ('melUpB', 1)):
        x = render([nt for i, nt in enumerate(notes) if i % 2 == par])
        x = eq(x, pb.HighpassFilter(hp), pb.PeakFilter(3200, tame_db, 0.7), pb.HighShelfFilter(6000, -4.0), pb.LowpassFilter(9000))
        x = delay(x, S.beat * 0.75, feedback=0.35, mix=0.12, hp_hz=500, lp_hz=6000)
        up[k] = level(reverb(x, size=0.7, wet=0.22), active_rms_db(L['melA'].x) - below_db)
    return up


def choke_downbeats(x, S, beats=2.0):
    """the rise layer is only ever open from a bar's last beat to a beat or two after the next downbeat: let each
    downbeat's crash die away within `beats`, so closing the layer never cuts a ringing cymbal"""
    n = x.shape[1]
    t = np.arange(n) / SR
    ph = (t % S.bar) / S.beat              # beats since the bar line
    g = np.where(ph < beats, np.clip(1.0 - (ph / beats) ** 2, 0, 1), 0.0)
    g = np.where(ph >= 3.0, 1.0, g)         # the fill itself, on the last beat
    ramp = np.ones(ns(0.01)) / ns(0.01)
    return x * np.convolve(g, ramp, mode='same')


# ------------------------------------------------------------------ Rio de Janeiro: the samba school fills the avenue

def rio_city(c):
    import rio_real as rio, sampler
    from arr import voicing
    L, S = rio.build(c, 'escola', mel_db=0.0, melody='sax_samba+guitar_low')
    gm = master(L, S, -12.0, -8.0, 1.8, 4)
    n = L['core'].n
    D = S.dur
    bpm = c['bpm']
    bar, beat = S.bar, S.beat
    rng = np.random.default_rng(1965)
    hv = lambda v, s=0.08: v * (1.0 + rng.uniform(-s, s))
    secs = [B['sec'] for B in S.bars]
    band = lambda b: secs[b] in ('A', 'B', 'C', 'O')
    big = lambda b: secs[b] in ('B', 'C', 'O')
    seed = [200]

    def part(ins, jitter=0.006):
        seed[0] += 1
        return sampler.RPart(sampler.get(ins), jitter, 0.0, seed[0])

    def mix(items):
        x = np.zeros((2, n))
        for arr, db, wet, size in items:
            arr = arr[:, :n] if arr.shape[1] >= n else np.pad(arr, ((0, 0), (0, n - arr.shape[1])))
            y = level(eq(arr, pb.HighpassFilter(30)), db)
            x += reverb(y, size=size, damp=0.5, wet=wet) if wet else y
        return x

    def loop(sid, bars, which, gain=1.0):
        bed = rio.Bed(n)
        rio.tile(bed, S, rio.fit(rio.raw(sid), bars * bar), bars, which, gain)
        return bed.x

    def hits(sid, keep=0.35):
        """one-shots cut from a recording of single strokes (each a moment apart)"""
        x = rio.raw(sid)
        m = np.abs(x).mean(0)
        hop = 441
        env = np.array([m[i:i + hop].max() for i in range(0, len(m) - hop, hop)])
        db = 20 * np.log10(env + 1e-9)
        out, last = [], -99
        for i in range(1, len(db)):
            if db[i] - db[i - 1] > 9 and db[i] > db.max() - 30 and i - last > 30:
                a = max(0, i * hop - 220)
                y = x[:, a:a + int(keep * SR)].copy()
                y[:, -256:] *= np.linspace(1, 0, 256)
                out.append(y / (np.abs(y).max() + 1e-9))
                last = i
        return out

    def place(bed, shots, t, vel):
        bed.put(shots[int(rng.integers(len(shots)))], t, vel)

    # up1 (step 3): the surdos of the second and third line join: the bateria's low end doubles
    up1 = mix([(loop('36127', 4, band), -21, 0.12, 0.5), (loop('36125', 2, band, 0.8), -24, 0.12, 0.5)])

    # up2 (step 5): the repiniques drive the sixteenths, a caixa-like tamborim pattern and a second pandeiro under
    rim, head, hand = hits('329749'), hits('329750'), hits('329751')
    rep = rio.Bed(n)
    pat = 'RhHHRhH.RhHHRHHh'
    for b in range(len(S.bars)):
        if not band(b):
            continue
        for k, ch in enumerate(pat):
            t = b * bar + k * beat / 4 + float(rng.normal(0, 0.004))
            if ch == 'R':
                place(rep, rim, t, hv(1.0 if k % 8 == 0 else 0.8))
            elif ch == 'H':
                place(rep, head, t, hv(0.55))
            elif ch == 'h':
                place(rep, hand, t, hv(0.4))
        if b % 4 == 3:      # the repinique's call into the next phrase
            for k in range(12, 16):
                place(rep, rim, b * bar + k * beat / 4, 0.7 + 0.1 * (k - 12))
    up2 = mix([(eq(rep.x, pb.PeakFilter(3500, -4.0, 0.8), pb.LowpassFilter(11000)), -26, 0.15, 0.5),
               (loop('36132', 4, band, 0.9), -27, 0.12, 0.5), (loop('36116', 4, big, 0.8), -28, 0.12, 0.5)])

    # up3 (step 6): the horn section: trumpets and trombones punch a riff between the tune's notes (off the stabs
    # Overdrive plays), and the trombones swell on the chords
    notes = c['notes']
    note_ts = [x['t'] for x in notes]
    tp, tb, tbs = part('trumpet_stac', 0.005), part('trombone_short', 0.006), part('trombone', 0.01)
    for b in range(len(S.bars)):
        if not band(b):
            continue
        root, iv = S.chord(b)
        tones = voicing(root, iv, 64, 76, True)
        low = sorted({((root + x - 50) % 12) + 50 for x in iv})
        for j, st in enumerate((2, 7, 14) if b % 2 == 0 else (2, 7, 11)):
            t0 = b * bar + st * beat / 4
            if any(abs(t0 - x) < 0.1 for x in note_ts):
                continue
            for q in tones[:3]:
                tp.note(t0, beat * 0.3, q, hv(92 if st == 7 else 82))
            for q in low:
                tb.note(t0, beat * 0.3, q, hv(88 if st == 7 else 78))
        for q in low:
            tbs.note(b * bar + 2 * beat, bar * 0.45, q, 60 if not big(b) else 68)
    horns = mix([(eq(tp.render(bpm, D), pb.PeakFilter(3200, -5.0, 0.7), pb.HighShelfFilter(6000, -3.0)), -24, 0.3, 0.7),
                 (tb.render(bpm, D), -25, 0.3, 0.7), (tbs.render(bpm, D), -29, 0.35, 0.7)])
    up3 = horns

    # up4 (step 7): the whole avenue: violins high over the band, bright chocalhos, the crowd a little nearer
    vl = part('violins', 0.01)
    for b in range(len(S.bars)):
        if not band(b):
            continue
        root, iv = S.chord(b)
        for q in voicing(root, iv, 67, 81):
            vl.note(b * bar, bar * 0.98, q, 70 if big(b) else 62)
    crowd = rio.raw('334469')[:, -int(40 * SR):]     # (the recording's last 40 s, at its own pace: a street band plays in it)
    crowd = np.tile(crowd, (1, int(np.ceil(D / 40)) + 1))[:, :n]
    g = np.zeros(n)
    for b in range(len(S.bars)):
        if band(b):
            g[int(b * bar * SR):int((b + 1) * bar * SR)] = 1.0
    g = np.convolve(g, np.ones(int(0.5 * SR)) / int(0.5 * SR), mode='same')
    up4 = mix([(eq(vl.render(bpm, D), pb.PeakFilter(3000, -5.0, 0.7), pb.HighShelfFilter(6000, -3.0), pb.LowpassFilter(9000)), -27, 0.4, 0.8),
               (loop('36124', 2, band, 0.8), -30, 0.1, 0.4), (crowd * g, -30, 0.0, 0.5)])

    # rise: the repinique's call on the last beat, a surdo accent and a soft cymbal on the downbeat
    rs = rio.Bed(n)
    kit = part('parlour_kit', 0.0)
    for b in range(len(S.bars)):
        for k in range(4):
            place(rs, rim, b * bar + 3 * beat + k * beat / 4, 0.6 + 0.13 * k)
        kit.note((b + 1) * bar, 1.2, 49, 80)
        kit.note((b + 1) * bar, 0.5, 36, 110)
    rise = choke_downbeats(mix([(rs.x, -26, 0.15, 0.5), (kit.render(bpm, D), -27, 0.2, 0.6)]), S, beats=2.0)
    # the anthem (step 8): a trumpet on the tune, an octave over the sax
    def trumpet(ns_):
        p = part('trumpet_vib', 0.003)
        for x in ns_:
            p.note(x['t'], max(0.25, x['len'] * beat * 0.55), x['note'], 80)
        return p.render(bpm, D)
    up = doubles(L, S, c['notes'], trumpet, 8.0, hp=200.0, tame_db=-7.0)
    return L, S, gm, dict(up1=up1, up2=up2, up3=up3, up4=up4, rise=rise, **up)


# ------------------------------------------------------------------ Berlin 2075: the club lifts off

def berlin(c):
    import surge_render as sr, techno
    sr.VST = os.path.join(SCRATCH, 'music/surge/root/usr/lib/vst3/Surge XT.vst3')
    sr.PATCHES = os.path.join(SCRATCH, 'music/surge/root/usr/share/surge-xt/patches_factory')
    title, parts, mel, style, newmel = sr.VERSIONS3['mel_tron']

    def ext(prt, nn, seconds):
        p = sr.load(os.path.join(sr.PATCHES, parts[prt] + '.fxp'))
        y = sr.render_notes(p, nn, seconds + 1.0)
        if prt == 'lead':
            soft = -10.0 if 'Brass' in parts['lead'] else -5.0
            y = pb.Pedalboard([pb.HighShelfFilter(2500, soft), pb.LowpassFilter(7000 if soft < -5 else 9000)])(y.astype(np.float32), SR).astype(np.float64)
        return y

    L, S = techno.build(c, 'melodic', ext=ext, mel=dict(mel, phone=True), style=style)
    gm = master(L, S, -11.0, -6.0, 2.0, 4)
    n = L['core'].n
    D = S.dur
    bar, beat = S.bar, S.beat
    secs = [B['sec'] for B in S.bars]
    band = lambda b: secs[b] in ('A', 'B', 'C', 'O')
    big = lambda b: secs[b] in ('B', 'C')
    kicks = [S.t(b, q) for b in range(len(S.bars)) for q in range(4) if secs[b] != 'E']
    sc_pad = sidechain(n, kicks, 0.75, 0.24)
    sc_mid = sidechain(n, kicks, 0.55, 0.18)
    # (the techno parts aren't levelled to fixed levels like the acoustic bands: set the new ones by the arpeggio's
    # and the percussion's own levels)
    arp_db, perc_db = active_rms_db(L['arp'].x), active_rms_db(L['perc'].x)
    print(f'  Berlin levels: arp {arp_db:.1f} dB, percussion {perc_db:.1f} dB, core {active_rms_db(L["core"].x):.1f} dB', flush=True)

    def surge(patch, nn):
        p = sr.load(os.path.join(sr.PATCHES, patch + '.fxp'))
        y = sr.render_notes(p, nn, D + 1.0)[:, :n]
        out = np.zeros((2, n))
        out[:, :y.shape[1]] = y
        return out

    # up1 (step 5): the lift: a wide anthem pad an octave over the chords, pumping with the kick
    nn = []
    for b in range(len(S.bars)):
        if band(b):
            root, iv = S.chord(b)
            nn += [(S.t(b, 0), bar * 0.98, q, 84 if big(b) else 72) for q in techno.voicing(root, iv, 69, 84)]
    lift = surge('Polysynths/Anthemish 1', nn)
    lift = eq(lift, pb.HighpassFilter(300), pb.PeakFilter(3500, -4.0, 0.7), pb.HighShelfFilter(7000, -3.0))
    lift = reverb(fx(lift, pb.Chorus(rate_hz=0.3, depth=0.3, mix=0.35)), size=0.9, damp=0.4, wet=0.35, pre_hp=300)
    up1 = level(lift * sc_pad, arp_db + 4.0)

    # up2 (step 6): bigger drums: a gated snare in a big room on two and four, rolling sixteenth hats, a ride
    dr = Layer(D)
    g = reverb(snare(0.2, 185), size=0.95, damp=0.3, wet=1.2, dry=1.0)
    gate = np.clip((0.26 * SR - np.arange(g.shape[-1])) / (0.03 * SR), 0, 1)
    GS = eq(g * gate, pb.LowpassFilter(5000), pb.PeakFilter(3500, -4.0, 0.8))
    CH, RD = hat(0.03, tone=1.1), ride()
    for b in range(len(S.bars)):
        if not band(b):
            continue
        for q in (1, 3):
            dr.add(GS, S.t(b, q), 0.7)
        for s16 in range(16):
            dr.add(CH, S.t(b, s16 / 4), 0.55 if s16 % 4 == 2 else 0.3, 0.3 if s16 % 2 else -0.3)
        for q in range(4):
            dr.add(RD, S.t(b, q + 0.5), 0.3, -0.35)
        if b % 4 == 3:
            for s16 in range(8, 16):
                dr.add(tom(196.0 - 9 * s16), S.t(b, s16 / 4), 0.35 + 0.03 * s16, 0.4 - 0.05 * s16)
    up2 = level(eq(dr.x, pb.HighpassFilter(120), pb.HighShelfFilter(9000, -2.0)), perc_db + 4.5)

    # up3 (step 7): a counter-line of bells an octave over the arpeggio, on dotted eighths, echoing
    nn = []
    for b in range(len(S.bars)):
        if band(b):
            root, iv = S.chord(b)
            tones = techno.voicing(root, iv, 72, 86)
            seq = tones + [tones[0] + 12] + tones[::-1][1:]
            for j, s16 in enumerate(range(0, 16, 3)):
                nn.append((S.t(b, s16 / 4), 0.16, seq[(b * 2 + j) % len(seq)], 92 if s16 == 0 else 76))
    bells = surge('Plucks/Bell 1', nn)
    bells = eq(bells, pb.HighpassFilter(400), pb.PeakFilter(3500, -5.0, 0.7), pb.HighShelfFilter(6500, -4.0), pb.LowpassFilter(10000))
    bells = reverb(delay(bells, beat * 0.75, feedback=0.4, mix=0.3, hp_hz=600, lp_hz=6000), size=0.8, wet=0.3)
    up3 = level(bells * sc_mid, arp_db + 1.5)

    # rise: a snare roll on the last beat into a crash and a sub boom on the downbeat, a short swell under the roll
    rs = Layer(D)
    SN, CR = snare(0.12), crash()
    boom = sine(np.linspace(70, 38, ns(0.9)), ns(0.9)) * env_ad(ns(0.9), 0.003, 0.35)
    for b in range(len(S.bars)):
        for s16 in range(12, 16):
            rs.add(SN, S.t(b, s16 / 4), 0.35 + 0.15 * (s16 - 12))
        rs.add(riser(beat, 800.0, 7000.0), S.t(b, 3), 0.35)
        rs.add(CR, S.t(b + 1, 0), 0.55)
        rs.add(boom, S.t(b + 1, 0), 0.8)
    rise = choke_downbeats(level(eq(rs.x, pb.HighShelfFilter(8000, -2.0)), perc_db + 3.0), S, beats=2.0)
    # the anthem (step 8): a soft sine lead doubles the tune an octave up
    def sine_lead(ns_):
        return surge('Leads/Sine Lead', [(x['t'], max(0.12, x['len'] * beat * 0.5 * 0.85), x['note'] + 12, 100) for x in ns_])
    up = doubles(L, S, c['notes'], sine_lead, 7.0, hp=300.0, tame_db=-4.0)
    return L, S, gm, dict(up1=up1, up2=up2, up3=up3, rise=rise, **up)


def headroom(every, new, ceiling_db=-1.0, lookahead=0.004, release=0.08):
    """a gain curve for the new layers only: where the whole band with them on would go over the ceiling, they
    back off (smoothly, with a look-ahead), so the existing layers never change"""
    from scipy.ndimage import minimum_filter1d, uniform_filter1d
    c = 10 ** (ceiling_db / 20)
    e = np.max(np.abs(every), axis=0)
    s = np.max(np.abs(every + new), axis=0)
    nn = np.max(np.abs(new), axis=0) + 1e-9
    h = np.where(s > c, np.clip((c - e) / nn, 0.0, 1.0), 1.0)
    w = ns(lookahead)
    h = minimum_filter1d(h, size=2 * w + 1, origin=-w)
    h = uniform_filter1d(h, size=2 * w + 1, origin=w)
    return _release(h, 1.0 - math.exp(-1.0 / (release * SR)))


import numba as nb   # noqa: E402
import math          # noqa: E402


@nb.njit(cache=True)
def _release(h, k):
    out = np.empty_like(h)
    g = 1.0
    for i in range(h.shape[0]):
        g = h[i] if h[i] < g else g + (h[i] - g) * k
        out[i] = g
    return out


CITIES = {'old_0': ('old_0.json', london), 'sunset_1': ('sunset_1.json', rio_city), 'rain_5': ('rain_5.json', berlin)}
# the band step each new layer joins at (scripts/flow_music.gd: LADDER, LADDERS), and the game's mix per step
STEP_OF = {'old_0': {'up1': 5, 'up2': 6, 'up3': 7}, 'sunset_1': {'up1': 3, 'up2': 5, 'up3': 6, 'up4': 7},
           'rain_5': {'up1': 5, 'up2': 6, 'up3': 7}}
ANTHEM = 8
ROOM_FOR = [0.0, -1.5, -3.0, -4.0, -5.0]     # dB, by how many grand parts are on (the anthem: 1 dB more)
ANTHEM_LIFT = 4.0    # dB: the anthem's double over the level it was built at (7 dB under the melody: too shy)
LIFT = 2.0    # dB: the grand parts over the levels they were built at, so each step adds to the band
WIDTH = [0.94, 0.96, 0.98, 1.0, 1.06, 1.12, 1.18, 1.22]


def widen(x, w):
    m = (x[0] + x[1]) / 2
    return np.stack([m + (x[0] - m) * w, m + (x[1] - m) * w])


def main():
    ep = sys.argv[1]
    out = next((a for a in sys.argv[2:] if not a.startswith('--')), os.path.join(GAME, 'audio', ep))
    t0 = time.time()
    course, fn = CITIES[ep]
    c = json.load(open(os.path.join(GAME, 'data', course)))
    os.makedirs(out, exist_ok=True)
    cache = os.path.join(out, 'built.npz')
    if '--cached' in sys.argv and os.path.exists(cache):
        # (the mix only: the parts as last built)
        z = np.load(cache)
        own, od, lead = z['own'], z['od'], z['lead']
        ys = {k[2:]: z[k] for k in z.files if k.startswith('y_')}
        n = own.shape[1]
    else:
        L, S, gm, new = fn(c)
        print(f'{ep}: built in {time.time() - t0:.0f}s', flush=True)
        if '--check' in sys.argv:
            check(L, gm, ep)
        n = L['core'].n
        own = sum(L[k].x for k in ('full', 'arp', 'perc')) * gm
        od = L['od'].x * gm
        lead = sum(L[k].x for k in ('ghost', 'melA', 'melB')) * gm
        ys = {}
        for k, x in new.items():
            y = np.zeros((2, n))
            y[:, :min(n, x.shape[1])] = x[:, :n]
            ys[k] = y * gm
        f32 = lambda a: a.astype(np.float32)
        np.savez(cache, own=f32(own), od=f32(od), lead=f32(lead), **{'y_' + k: f32(v) for k, v in ys.items()})
    for k in ys:
        if k.startswith('up'):
            ys[k] = ys[k] * 10 ** (LIFT / 20)
        if k.startswith('melUp'):
            ys[k] = ys[k] * 10 ** (ANTHEM_LIFT / 20)
        # each new part on its own compressor and limiter (as a horn section or a drum bus would be), so its peaks
        # sit no more than 9 dB over its body and it adds to the band without the band having to duck it
        r = active_rms_db(ys[k])
        ys[k] = level(ys[k] * master_gain(ys[k], ceiling_db=r + 9.0, glue_db=r + 6.0, glue_ratio=2.0), r)
    steps = dict(STEP_OF[ep], melUpA=ANTHEM, melUpB=ANTHEM, rise=1)
    first = min(v for k, v in steps.items() if k != 'rise')

    def at_step(s, with_od):
        # the game's mix at a step: the song's own layers eased down to make room, the grand parts and the anthem on
        g = 10 ** ((ROOM_FOR[sum(1 for k, v in steps.items() if k.startswith('up') and v <= s)] - (1.0 if s >= ANTHEM else 0.0)) / 20)
        band = widen((own + (od if with_od else 0)) * g, WIDTH[s - 1])
        add = sum(ys[k] for k in ys if steps[k] <= s and not k.startswith('melUp'))
        top = sum(ys[k] for k in ys if k.startswith('melUp')) if s >= ANTHEM else 0
        return band + lead, widen(add, WIDTH[s - 1]), top

    # the grand parts give way (briefly) only where the band with them would pass the ceiling; the anthem's double
    # on its own, over everything else
    h = np.ones(n)
    for s in range(first, ANTHEM + 1):
        for with_od in (False, True):
            e, x, top = at_step(s, with_od)
            h = np.minimum(h, headroom(e, x, ceiling_db=-0.7, release=0.03))
    ht = np.ones(n)
    for with_od in (False, True):
        e, x, top = at_step(ANTHEM, with_od)
        ht = np.minimum(ht, headroom(e + x * h, top, ceiling_db=-0.7, release=0.03))
    print(f'  the grand parts back off (more than 1 dB) {100 * np.mean(h < 0.89):.1f}% of the time, the anthem\'s '
          f'double {100 * np.mean(ht < 0.89):.1f}%', flush=True)
    e, x, _ = at_step(4, False)
    base = loudness(e + x)[0]
    print(f'  step 4 (the song as it was, no Overdrive): {base:.1f} LUFS', flush=True)
    for s in range(first, ANTHEM + 1):
        e, x, top = at_step(s, False)
        lufs = loudness(e + x * h + top * ht)[0]
        e, x, top = at_step(s, True)
        print(f'  step {s}: {lufs:+.1f} LUFS ({lufs - base:+.1f} dB), sample peak with Overdrive '
              f'{20 * np.log10(np.abs(e + x * h + top * ht).max()):.1f} dBFS', flush=True)
    for k, y in ys.items():
        ys[k] = y * (ht if k.startswith('melUp') else h)
        to_ogg(ys[k], os.path.join(out, k + '.ogg'), 4)
        print(f'  {k}: peak {20 * np.log10(np.abs(ys[k]).max() + 1e-12):.1f} dBFS', flush=True)
    print(f'  done in {time.time() - t0:.0f}s', flush=True)


if __name__ == '__main__':
    main()
