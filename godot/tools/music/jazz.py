"""The Past's jazz: acoustic period bands on recorded instruments (no techno beat), built around a course's melody and
chords. Each style is a band: its drums (jazz sticks, brushes or a music-hall kit, or none), its bass (upright,
tuba or the pianist's left hand), its rhythm section, a part that answers the melody, and the lead instrument.

The layers are the game's: core = drums and bass, full = the whole band, arp = the answering part, perc = extra
percussion, od = the band's big hits (Overdrive), jet = a low heartbeat, ghost / melA / melB = the melody.
"""
import numpy as np
from engine import *
from arr import *
from gm import Part
import sampler
from techno import wind

# drum kits (bank 128) and the GM drum notes used here
KIT = {'jazz': 32, 'brush': 40, 'standard': 0}
KICK, STICK, SNARE, SWIRL, HH_FOOT, HH, RIDE, BELL, CRASH, TAMB, WOOD_HI, WOOD_LO, TRI, SHAKER, LOW_TOM = \
    36, 37, 38, 40, 44, 42, 51, 53, 49, 54, 76, 77, 81, 70, 41

# instrument: (GM program, bank)
PIANO, MELLOW_PIANO, HONKY, VIBES, ACCORDION = (0, 0), (0, 8), (3, 0), (11, 0), (21, 0)
NYLON, STEEL, JAZZ_GTR, BANJO = (24, 0), (25, 0), (26, 0), (105, 0)
UPRIGHT, TUBA, BASS_PIZZ = (32, 0), (58, 0), (45, 50)
VIOLIN, VIOLA, STRINGS, PIZZ = (40, 0), (41, 0), (48, 0), (45, 0)
TRUMPET, MUTED, TROMBONE, BRASS, BRASS2 = (56, 0), (59, 0), (57, 0), (61, 0), (61, 8)
CLARINET, ALTO, TENOR = (71, 0), (65, 0), (66, 0)

STYLES = {
    'ragtime': dict(title='Ragtime Piano', lead=PIANO, ring=1.5, drums=None, bass=('stride', PIANO),
                    comp=[('stride', PIANO, -19)], fill=('answer', PIANO), perc='wood', od=('hits', HONKY),
                    core_comp=True),
    'musichall': dict(title='Music Hall Band', lead=TRUMPET, tame=True, ring=0.95, drums=('twobeat', 'standard'), bass=('two', TUBA),
                      comp=[('oompah', TROMBONE, -23), ('stride_rh', PIANO, -22)], fill=('counter', CLARINET), perc='tamb',
                      od=('hits', BRASS)),
    'dixieland': dict(title='Dixieland Street Band', lead=TRUMPET, tame=True, ring=0.95, drums=('dixie', 'jazz'), bass=('two', TUBA),
                      comp=[('banjo', BANJO, -21), ('tailgate', TROMBONE, -24)], fill=('answer', CLARINET), perc='wood',
                      od=('hits', BRASS)),
    'gypsy': dict(title='Gypsy Jazz Cafe', lead=VIOLIN, tame=True, ring=0.95, drums=None, bass=('two', UPRIGHT),
                  comp=[('pompe', STEEL, -19)], fill=('answer', STEEL), perc='shaker', od=('hits', ACCORDION),
                  core_comp=True),
    'noir': dict(title='Foggy Noir Trio', lead=MUTED, oct=-12, tame=True, ring=0.95, drums=('brush', 'brush'), bass=('walk', UPRIGHT),
                 comp=[('shells', MELLOW_PIANO, -21)], fill=('answer', VIBES), perc='rim', od=('hits', BRASS2)),
    'bigband': dict(title='Swing Big Band', lead=ALTO, oct=-12, tame=True, ring=0.95, drums=('ride', 'jazz'), bass=('walk', UPRIGHT),
                    comp=[('shells', PIANO, -22), ('pads', TENOR, -25), ('horns', BRASS, -24)], fill=('counter', CLARINET),
                    perc='hh', od=('hits', BRASS)),
    'pub': dict(title='Pub Knees-Up', lead=HONKY, ring=1.4, drums=('twobeat', 'standard'), bass=('two', TUBA),
                comp=[('banjo', BANJO, -21), ('oompah', ACCORDION, -23)], fill=('answer', ACCORDION), perc='tamb',
                od=('hits', BRASS)),
    'vibes': dict(title='Vibraphone Lounge', lead=VIBES, ring=1.6, drums=('brush', 'brush'), bass=('walk', UPRIGHT),
                  comp=[('shells', MELLOW_PIANO, -22), ('pompe', JAZZ_GTR, -25)], fill=('answer', JAZZ_GTR),
                  perc='shaker', od=('pads_hit', STRINGS)),
    'parlour': dict(title='Parlour Strings', lead=CLARINET, tame=True, ring=0.95, drums=('brush', 'brush'), bass=('two', BASS_PIZZ),
                    comp=[('pizz', PIZZ, -21), ('pads', STRINGS, -27)], fill=('counter', VIOLA), perc='tri',
                    od=('pads_hit', STRINGS)),
    'smoky': dict(title='Smoky Sax', lead=TENOR, oct=-12, tame=True, ring=0.95, drums=('ride', 'jazz'), bass=('walk', UPRIGHT),
                  comp=[('stride_rh', MELLOW_PIANO, -21)], fill=('answer', MELLOW_PIANO), perc='rim',
                  od=('hits', BRASS2)),
    # the pub band again, on real recordings: a detuned pub upright, a strummed strumstick for the banjo, a chromatic
    # harmonica for the accordion (the same free-reed sound), a concert tuba, a rope-tension snare kit, a tambourine
    'pub_real': dict(title='Pub Knees-Up (real instruments)', lead='pub_piano', ring=1.4, drums=('twobeat', 'standard'),
                     real_kit='parlour_kit', bass=('two', 'tuba_sus'),
                     comp=[('banjo', 'strumstick', -21), ('oompah', 'harmonica', -24)], fill=('answer', 'harmonica'),
                     perc='tamb', od=('hits', 'upright_piano'), humanize=True),

    # the fuller pub band: the pub piano moves into the band (chords on the off-beats), a trombone holds long notes and
    # slides into each chord, a soft violin section warms the middle, trumpet hits for the big moments, the whole band
    # in a music hall; the melody on a trumpet (the music-hall cornet sound) or a solo violin (a pub fiddle)
    'pub_full': dict(title='Pub Band, fuller (trumpet melody)', lead='trumpet', tame=True, ring=0.95,
                     drums=('twobeat', 'standard'), real_kit='parlour_kit', bass=('two', 'tuba_sus'),
                     comp=[('banjo', 'strumstick', -22), ('stride_rh', 'pub_piano', -22), ('oompah', 'harmonica', -26),
                           ('tailgate', 'trombone', -24), ('pads', 'violins', -28)],
                     fill=('answer', 'harmonica'), perc='tamb', od=('hits', 'trumpet_stac'), humanize=True, hall=1.0),
    'pub_full_violin': dict(title='Pub Band, fuller (violin melody)', lead='solo_violin', tame=True, tame_db=-8.0, lead_vel=60,
                            ring=0.95,
                            drums=('twobeat', 'standard'), real_kit='parlour_kit', bass=('two', 'tuba_sus'),
                            comp=[('banjo', 'strumstick', -22), ('stride_rh', 'pub_piano', -22), ('oompah', 'harmonica', -26),
                                  ('tailgate', 'trombone', -24), ('pads', 'violins', -29)],
                            fill=('answer', 'trumpet_stac'), perc='tamb', od=('hits', 'trumpet_stac'), humanize=True, hall=1.0),
}


def _walk(root, iv, nxt_root, rng):
    """a walking bass bar: root, a chord tone, a chord tone, then a half step into the next chord"""
    base = root
    while base > 45:
        base -= 12
    while base < 33:
        base += 12
    third, fifth = base + iv[1], base + iv[2]
    tgt = nxt_root
    while tgt - base > 6:
        tgt -= 12
    while base - tgt > 6:
        tgt += 12
    approach = tgt - 1 if rng.random() < 0.6 else tgt + 1
    return [base, third if rng.random() < 0.6 else fifth, fifth if rng.random() < 0.6 else base + 12, approach]


def _low(root, lo=36):
    while root >= lo + 12:
        root -= 12
    while root < lo:
        root += 12
    return root


def build(c, style='noir', ease=None, mel_db=0.0):
    st = STYLES[style]
    ease = ease_for(c) if ease is None else ease
    S = Song(c)
    D = S.dur
    bpm = c['bpm']
    L = {k: Layer(D) for k in LAYERS}
    n_bars = len(S.bars)
    at, hv, rng = S.at, S.hv, S.rng
    beat = S.beat

    hum = st.get('humanize', False)
    seed = [0]

    def mk(ins, jitter=0.009, lag=0.004):
        # a General MIDI sound (program, bank), or a recorded instrument from the sample libraries (its name);
        # recorded players are humanised: a few ms off the grid at random, laid back a touch
        if not isinstance(ins, str):
            return Part(*ins)
        seed[0] += 1
        return sampler.RPart(sampler.get(ins), jitter if hum else 0.0, lag if hum else 0.0, seed[0])

    kit = st['drums'][1] if st['drums'] else 'jazz'
    real_kit = st.get('real_kit')
    dr = sampler.RPart(sampler.get(real_kit), 0.004 if hum else 0.0) if real_kit else Part(KIT[kit], drums=True)   # the kit
    pc = sampler.RPart(sampler.get(real_kit)) if real_kit else Part(KIT['standard'], drums=True)   # extra percussion
    od_dr = sampler.RPart(sampler.get(real_kit)) if real_kit else Part(KIT['standard'], drums=True)
    jet = sampler.RPart(sampler.get(real_kit)) if real_kit else Part(KIT['standard'], drums=True)
    bpart = mk(st['bass'][1])
    comps = [(pat, mk(ins), db) for pat, ins, db in st['comp']]
    fill = mk(st['fill'][1])
    odp = mk(st['od'][1])

    notes = c['notes']
    note_ts = [x['t'] for x in notes]

    for b in range(n_bars):
        B = S.bars[b]
        sec = B['sec']
        root, iv = S.chord(b)
        nxt = S.chord(min(b + 1, n_bars - 1))[0]
        lvl = B.get('lvl', 0) if sec == 'I' else 3
        big = sec in ('B', 'C')
        v = voicing(root, iv, 55, 68, True)
        if sec == 'E':
            if st['drums']:
                dr.note(at(b, 0), 2.0, CRASH, 90)
                dr.note(at(b, 0), 0.3, KICK, 90)
            bpart.note(at(b, 0), S.bar, _low(root, 31 if st['bass'][0] != 'stride' else 36), 96)
            for pat, p, _ in comps:
                for q in v:
                    p.note(at(b, 0), S.bar * 0.9, q, 80)
            continue

        # ---- drums
        if st['drums']:
            pat = st['drums'][0]
            if pat == 'ride':
                for e in (0, 2, 3, 4, 6, 7):
                    dr.note(at(b, e), beat * 0.4, RIDE, hv(84 if e in (0, 4) else 66 if e in (3, 7) else 76))
                for q in (1, 3):
                    dr.note(at(b, q * 2), 0.1, HH_FOOT, hv(70))
                for q in range(4):
                    dr.note(at(b, q * 2), 0.1, KICK, hv(38))
                if sec != 'I' and rng.random() < 0.6:
                    dr.note(at(b, rng.choice([3, 5, 7])), 0.1, SNARE, hv(48))
            elif pat == 'brush':
                for e in range(8):
                    dr.note(at(b, e), beat * 0.4, SNARE, hv(62 if e in (2, 6) else 44 if e % 2 else 50))
                for q in (0, 2):
                    dr.note(at(b, q * 2), beat * 1.8, SWIRL, hv(52))
                for q in (1, 3):
                    dr.note(at(b, q * 2), 0.1, HH_FOOT, hv(64))
                for q in (0, 2):
                    dr.note(at(b, q * 2), 0.1, KICK, hv(40))
            elif pat == 'twobeat':
                for q in (0, 2):
                    dr.note(at(b, q * 2), 0.1, KICK, hv(80))
                if sec != 'I':
                    for q in (1, 3):
                        dr.note(at(b, q * 2), 0.1, SNARE, hv(74))
                for e in range(8):
                    dr.note(at(b, e), 0.1, HH, hv(58 if e % 2 == 0 else 44))
                if b % 4 == 3 and sec != 'I':
                    for k in range(6):
                        dr.note(at(b, 6) + k * beat / 6, 0.05, SNARE, 50 + 6 * k)
            elif pat == 'dixie':
                for q in (0, 2):
                    dr.note(at(b, q * 2), 0.1, KICK, hv(78))
                if sec != 'I':
                    for q in (1, 3):
                        for k in range(3):    # a press roll: three quick strokes
                            dr.note(at(b, q * 2) + k * 0.035, 0.05, SNARE, hv(70 - 10 * k))
                for e in (1, 3, 5, 7) if big else (3, 7):
                    dr.note(at(b, e), 0.1, WOOD_HI, hv(58))
                if b % 8 == 7:
                    dr.note(at(b, 7), 0.6, CRASH, 70)

        # ---- bass
        bp = st['bass'][0]
        if not (sec == 'I' and lvl < 1):
            if bp == 'walk':
                for q, p in enumerate(_walk(root, iv, nxt, rng)):
                    bpart.note(at(b, q * 2), beat * 0.9, p, hv(100 if q == 0 else 88))
            elif bp == 'two':
                lo = _low(root, 33)
                for q, p in ((0, lo), (2, lo + iv[2] if lo + iv[2] <= 50 else lo - 12 + iv[2])):
                    bpart.note(at(b, q * 2), beat * 1.6, p, hv(98 if q == 0 else 88))
            elif bp == 'stride':
                lo = _low(root, 36)
                for q, p in ((0, lo), (2, lo + iv[2] - 12 if lo + iv[2] - 12 >= 31 else lo + iv[2])):
                    bpart.note(at(b, q * 2), beat * 0.8, p, hv(92))
        if sec == 'I' and lvl < 2:
            continue

        # ---- the rhythm section and the band
        for pat, p, _ in comps:
            if pat in ('stride', 'stride_rh'):
                for q in (1, 3):
                    for k in v:
                        p.note(at(b, q * 2), beat * 0.55, k, hv(80))
            elif pat == 'oompah':
                vv = voicing(root, iv, 52, 64)
                for q in (1, 3):
                    for k in vv:
                        p.note(at(b, q * 2), beat * 0.5, k, hv(78))
            elif pat in ('banjo', 'pompe'):
                for q in range(4):
                    for j, k in enumerate(v):
                        p.note(at(b, q * 2) + j * 0.006, beat * (0.35 if pat == 'pompe' else 0.5), k,
                               hv(92 if q % 2 else 70))
            elif pat == 'shells':
                vv = voicing(root, iv + [10 if iv[1] == 3 else 11] if len(iv) < 4 else iv, 52, 66, True)
                for e, d, vel in (((0, 1.5, 70), (3, 1.0, 76)) if not big else ((2, 0.8, 74), (5, 1.0, 80), (7, 0.7, 70))):
                    for k in vv:
                        p.note(at(b, e) + rng.uniform(-0.008, 0.008), d * beat * 0.5, k, hv(vel))
            elif pat == 'pads':
                for k in voicing(root, iv, 55, 70):
                    p.note(at(b, 0), S.bar * 0.97, k, 58 if not big else 66)
            elif pat == 'pizz':
                for q in (1, 3):
                    for k in voicing(root, iv, 55, 67):
                        p.note(at(b, q * 2), beat * 0.4, k, hv(82))
            elif pat == 'tailgate':      # trombone: a long note sliding toward the next chord's root
                lo = _low(root, 43)
                p.note(at(b, 0), beat * 2.5, lo + iv[1], hv(72))
                p.note(at(b, 6), beat * 0.9, _low(nxt, 43), hv(66))
            elif pat == 'horns' and big:
                for e, d in ((0, 1.2), (3, 0.9)):
                    for k in voicing(root, iv, 58, 72, True):
                        p.note(at(b, e), d * beat * 0.5, k, hv(80))

        # ---- the part that answers the melody (band level 3)
        fp = st['fill'][0]
        t0, t1 = b * S.bar, (b + 1) * S.bar
        if fp == 'answer':
            # a short run of chord tones wherever the melody rests for two beats or more
            tones = voicing(root, iv, 62, 76, True)
            e = 0
            while e < 8:
                t = at(b, e)
                busy = any(t - 0.05 <= x < t + beat * 2 for x in note_ts)
                if not busy and e <= 4:
                    run = tones[rng.randrange(len(tones)):] + tones
                    for k in range(3):
                        fill.note(at(b, e + k), beat * 0.45, run[k] - (12 if run[k] > 74 else 0), hv(78 - 6 * k))
                    e += 4
                else:
                    e += 2
        elif fp == 'counter':
            # a soft harmony line: each ring note a sixth below, held
            for x in notes:
                if t0 <= x['t'] < t1:
                    p = x['note'] - 9
                    pcs = {(root + k) % 12 for k in iv} | {(root + 2) % 12}
                    while p % 12 not in pcs:
                        p -= 1
                    fill.note(x['t'], max(0.25, x['len'] * beat * 0.5 * 0.95), p, hv(62))

        # ---- extra percussion (band level 4)
        pp = st['perc']
        if pp == 'tamb':
            for q in (1, 3):
                pc.note(at(b, q * 2), 0.1, TAMB, hv(70))
            for e in (1, 3, 5, 7):
                pc.note(at(b, e), 0.1, TAMB, hv(42))
        elif pp == 'wood':
            for e in (2, 5, 7):
                pc.note(at(b, e), 0.1, WOOD_LO if e == 2 else WOOD_HI, hv(54))
        elif pp == 'shaker':
            for e in range(8):
                pc.note(at(b, e), 0.1, SHAKER, hv(52 if e % 2 else 38))
        elif pp == 'rim':
            pc.note(at(b, 6), 0.1, STICK, hv(66))
            if b % 2:
                pc.note(at(b, 3), 0.1, STICK, hv(50))
        elif pp == 'tri':
            pc.note(at(b, 0), 0.6, TRI, hv(50))
            pc.note(at(b, 4), 0.4, TRI, hv(38))
        elif pp == 'hh':
            for e in (1, 3, 5, 7):
                pc.note(at(b, e), 0.1, HH, hv(46))

        # ---- Overdrive: the band's big hits on the Charleston, a crash on each phrase
        if b % 4 == 0:
            od_dr.note(at(b, 0), 1.5, CRASH, 76)
        if st['od'][0] == 'hits':
            for e, d in ((0, 1.4), (3, 0.9), (6, 0.9)):
                for k in voicing(root, iv, 60, 74, True):
                    odp.note(at(b, e), d * beat * 0.5, k, hv(92))
        else:
            for k in voicing(root, iv, 60, 76):
                odp.note(at(b, 0), S.bar * 0.95, k, 74)

        # ---- the jetpack: a soft low tom heartbeat
        for q in (0, 2):
            jet.note(at(b, q * 2), 0.3, LOW_TOM, 60 if q == 0 else 46)

    n = L['core'].n
    R_dr = dr.render(bpm, D)
    R_bass = bpart.render(bpm, D)
    R_comp = [(pat, p.render(bpm, D), db) for pat, p, db in comps]

    hall = st.get('hall', 0.0)      # 0: a small dry room; 1: a music hall, the whole band in one warm space

    def room(x, size=0.45, wet=0.18):
        return reverb(x, size=min(0.95, size + 0.3 * hall), damp=0.55, wet=wet * (1.0 + 0.8 * hall))

    def warm(x, lo=50.0, hi=10000.0):
        """a gentle period colour: no rumble, the very top eased, nothing gritty"""
        return eq(x, pb.HighpassFilter(lo), pb.LowpassFilter(hi), pb.LowShelfFilter(250, 1.0))

    drums_x = room(level(warm(R_dr, 40, 12000), -22), 0.4, 0.15) if st['drums'] else np.zeros((2, n))
    bass_db = -20 if st['bass'][0] != 'stride' else -21
    bass_x = level(warm(R_bass, 35, 6000), bass_db)
    core = drums_x + bass_x
    band = sum(room(level(eq(warm(x), pb.PeakFilter(3000, -3.0, 0.8)), db)) for pat, x, db in R_comp)
    if st.get('core_comp'):
        core = core + band
        L['core'].x = core
        L['full'].x = core
    else:
        L['core'].x = core
        L['full'].x = core + band
    L['arp'].x = room(level(warm(fill.render(bpm, D), 120), -25 + 2 * (1 - ease)), 0.5, 0.22)
    L['perc'].x = room(level(warm(pc.render(bpm, D), 200, 12000), -29), 0.4, 0.15)
    L['od'].x = room(level(warm(od_dr.render(bpm, D), 80, 12000), -28)
                     + level(eq(warm(odp.render(bpm, D), 120), pb.PeakFilter(3000, -4.0, 0.8)), -22), 0.55, 0.22)
    L['jet'].x = level(warm(jet.render(bpm, D), 40, 3000), -30) + wind(n) * 0.3

    # ---- the melody, on the style's lead instrument
    ring, ghost_g, _, _ = lead_levels(ease)
    eighth = beat / 2.0
    mel = {k: mk(st['lead'], 0.003, 0.0) for k in ('melA', 'melB', 'ghost')}     # the melody stays tight on the rings
    o = st.get('oct', 0)      # saxes and the muted trumpet play an octave down, in their warm range (the rings don't move)
    for i, nt in enumerate(notes):
        mel['melA' if i % 2 == 0 else 'melB'].note(nt['t'], max(0.25, nt['len'] * eighth * st['ring']), nt['note'] + o, st.get('lead_vel', 110))
    for g in c['ghosts']:
        mel['ghost'].note(g['t'], max(0.22, g['len'] * eighth * st['ring']), g['note'] + o, 88)
    kicks = []
    for k, p in mel.items():
        x = warm(p.render(bpm, D), 120 if o else 150, 11000)
        if st.get('tame'):
            # horns, reeds and the violin: ease the 2-5 kHz bite so they sing instead of squeak
            td = st.get('tame_db', -5.0)
            x = eq(x, pb.PeakFilter(3200, td, 0.7), pb.HighShelfFilter(6000, -3.0 + 0.5 * (td + 5.0)), pb.LowpassFilter(9000 if td > -6 else 7000))
        x = level(x, -15 + mel_db)     # mel_db: the user's melody trim (London picks: -4 dB)
        L[k].x = x * (ring if k != 'ghost' else ghost_g) / 0.55
    finish_lead(L, S, ease, kicks, hp_hz=150, bright_db=0.0, room_size=0.5)
    return L, S
