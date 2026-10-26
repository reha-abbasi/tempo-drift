#!/usr/bin/env python3
"""Arranges an episode's song for a real band and renders its soundtrack layers with recorded instruments.

The melody (every ring's note, and the notes the band plays between them) comes from the baked course, so the music
lines up with the rings to the millisecond. Around it this writes a full arrangement in the era's style (for the Past:
a swing band with brushes, walking upright bass, piano comping, strings, celesta and a horn section for Overdrive),
writes each layer as MIDI and renders it with FluidSynth and the MuseScore General sample library.

usage: python3 godot/tools/arrange.py old 0
"""
import json, math, os, random, struct, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
SF2 = '/usr/share/sounds/sf2/MuseScore_General_Full.sf2'
PPQ = 480
SR = 44100

# the lead instrument of each song (General MIDI programs)
LEADS = {'piano': 0, 'oud': 24, 'accordion': 21, 'clarinet': 71, 'trumpet': 56, 'violin': 40, 'mandolin': 25,
         'pluck': 46, 'bell': 14, 'square': 80, 'acid': 87, 'brass': 61, 'glass': 9, 'koto': 107, 'sax': 65,
         'flute': 73, 'chip': 80, 'saw': 81, 'hero': 81, 'stab': 62}
# how long each lead lets a note ring, in eighths per eighth of written length (plucked and struck notes ring longer)
RING = {'piano': 1.6, 'oud': 1.2, 'mandolin': 1.0, 'koto': 1.2, 'bell': 2.0, 'glass': 1.8}

# ---------------------------------------------------------------- a minimal MIDI file writer

def vlq(n):
    out = [n & 0x7F]
    n >>= 7
    while n:
        out.insert(0, (n & 0x7F) | 0x80)
        n >>= 7
    return bytes(out)

class Track:
    def __init__(self):
        self.ev = []   # (tick, order, bytes)

    def program(self, ch, prog, bank=0, tick=0):
        self.ev.append((tick, 0, bytes([0xB0 | ch, 0, bank])))
        self.ev.append((tick, 0, bytes([0xC0 | ch, prog])))

    def cc(self, ch, num, val, tick=0):
        self.ev.append((tick, 0, bytes([0xB0 | ch, num, val])))

    def note(self, ch, tick, dur, pitch, vel):
        pitch = max(0, min(127, int(pitch)))
        vel = max(1, min(127, int(vel)))
        self.ev.append((max(0, int(tick)), 2, bytes([0x90 | ch, pitch, vel])))
        self.ev.append((max(1, int(tick + max(1, dur))), 1, bytes([0x80 | ch, pitch, 0])))

    def encode(self, tempo_us):
        evs = sorted(self.ev, key=lambda e: (e[0], e[1]))
        data = b'\x00\xFF\x51\x03' + struct.pack('>I', tempo_us)[1:]
        last = 0
        for tick, _, b in evs:
            data += vlq(tick - last) + b
            last = tick
        data += b'\x00\xFF\x2F\x00'
        return b'MTrk' + struct.pack('>I', len(data)) + data

def write_midi(path, track, bpm):
    hdr = b'MThd' + struct.pack('>IHHH', 6, 0, 1, PPQ)
    with open(path, 'wb') as f:
        f.write(hdr + track.encode(int(60_000_000 / bpm)))

# ---------------------------------------------------------------- the arrangement

class Song:
    def __init__(self, c):
        self.c = c
        self.beat = c['beat']
        self.bar = c['bar']
        self.swing = c['swing']
        self.bars = c['bars']
        self.rng = random.Random(c['map'] + str(c['ep']))

    def tick(self, seconds):
        return seconds / self.beat * PPQ

    def at(self, bar, eighth):
        """the time of an eighth in a bar, swung like the melody"""
        e = eighth + (self.swing if eighth % 2 else 0.0)
        return bar * self.bar + e * self.beat / 2.0

    def chord(self, b):
        B = self.bars[b]
        return B['root'], B['iv']

    def hv(self, v, spread=8):
        return v + self.rng.randint(-spread, spread)

def voicing(root, iv, lo=55, hi=68, color=True):
    """close voicing of the chord in a range, with a ninth on top for colour where it fits"""
    ps = sorted({((root + x - lo) % 12) + lo for x in iv})
    if color and len(iv) >= 3 and (iv[1] == 4 or iv[1] == 3):
        ninth = ((root + 2 - lo) % 12) + lo
        if ninth not in ps and len(ps) < 4:
            ps.append(ninth)
    return sorted(p if p <= hi else p - 12 for p in ps)

def walking_line(root, iv, nxt_root, rng):
    """four quarter notes: the root, two chord tones, and a chromatic step into the next bar's root"""
    base = root - 12
    while base > 45:
        base -= 12
    while base < 31:
        base += 12
    third = base + iv[1]
    fifth = base + iv[2]
    tgt = nxt_root - 12
    while tgt - base > 6:
        tgt -= 12
    while base - tgt > 6:
        tgt += 12
    approach = tgt - 1 if rng.random() < 0.6 else tgt + 1
    line = [base, third if rng.random() < 0.6 else fifth, fifth if rng.random() < 0.6 else base + 12, approach]
    return line

# each city's band in the Past: drum kit, what accompanies (comp), the pad, the arpeggio and the duet voice
STYLES = {
    ('old', 0): {'kit': 'brush', 'comp': 'charleston', 'comp_prog': 0, 'pad': 49, 'arp': 8, 'duet': 11},          # London: music-hall swing
    ('old', 1): {'kit': 'darbuka', 'comp': 'kanun', 'comp_prog': 46, 'pad': 48, 'arp': 15, 'duet': 40},          # Istanbul: oud, kanun, santur, violin
    ('old', 2): {'kit': 'brush', 'comp': 'pompe', 'comp_prog': 25, 'pad': 49, 'arp': 8, 'duet': 71},            # Paris: gypsy jazz, accordion, clarinet
    ('old', 3): {'kit': 'swing', 'comp': 'charleston', 'comp_prog': 0, 'pad': 59, 'arp': 11, 'duet': 65},       # New York: big band, muted brass, sax
    ('old', 4): {'kit': 'latin', 'comp': 'montuno', 'comp_prog': 0, 'pad': 61, 'arp': 12, 'duet': 57},          # Havana: son, montuno, trumpet, trombone
    ('old', 5): {'kit': 'brush', 'comp': 'oompah', 'comp_prog': 45, 'pad': 48, 'arp': 46, 'duet': 42},          # Vienna: salon orchestra, violin, cello
    ('old', 6): {'kit': 'darbuka', 'comp': 'kanun', 'comp_prog': 46, 'pad': 48, 'arp': 15, 'duet': 77},         # Cairo: oud, kanun, santur, nay
    ('old', 7): {'kit': 'brush', 'comp': 'ripple', 'comp_prog': 24, 'pad': 21, 'arp': 8, 'duet': 40},          # Rome: mandolin, guitar, accordion, violin
}

def arrange_swing(S):
    """the Past: a small band in each city's style"""
    st = STYLES.get((S.c['map'], S.c['ep']), STYLES[('old', 0)])
    L = {k: Track() for k in ['core', 'full', 'arp', 'perc', 'od', 'jet', 'ghost', 'melA', 'melB', 'harmA', 'harmB']}
    DR = 9  # drums
    for k in L:
        L[k].cc(0, 91, 60); L[k].cc(1, 91, 50); L[k].cc(2, 91, 70); L[k].cc(DR, 91, 40)
    kit_prog = 40 if st['kit'] == 'brush' else 0
    # (drum kits: 40 brushes, 0 standard; congas, bongos and claves are in the standard kit)
    L['core'].program(DR, kit_prog, 128)     # the brush kit (or a standard kit for hand drums)
    L['core'].program(1, 32)                 # upright bass
    L['full'].program(DR, kit_prog, 128)
    L['full'].program(1, 32)
    L['full'].program(2, st['comp_prog'])    # piano, kanun or rhythm guitar
    L['full'].program(3, st['pad'])          # strings
    L['full'].cc(3, 91, 90)
    L['arp'].program(4, st['arp'])           # celesta or santur
    L['arp'].cc(4, 91, 90)
    L['perc'].program(DR, 0, 128)
    L['od'].program(DR, 0, 128)
    L['od'].program(5, 61)                   # brass section
    L['jet'].program(6, 47)                  # timpani
    L['jet'].program(7, 122)                 # wind (seashore)
    lead = LEADS.get(S.c['lead'], 0)
    for k in ['ghost', 'melA', 'melB']:
        L[k].program(0, lead)
        L[k].cc(0, 91, 64)
    n_bars = len(S.bars)
    q = PPQ  # a quarter note
    T = S.tick
    for b in range(n_bars):
        B = S.bars[b]
        sec = B['sec']
        root, iv = S.chord(b)
        nxt_root = S.chord(min(b + 1, n_bars - 1))[0]
        bt = T(b * S.bar)
        if sec == 'E':
            # the last chord: everyone together, a cymbal and a long held chord
            for k in ['core', 'full']:
                L[k].note(DR, bt, q, 49, 90)
                L[k].note(DR, bt, q, 36, 80)
                L[k].note(1, bt, q * 4, root - 24 if root - 24 > 28 else root - 12, 95)
            for p in voicing(root, iv, 60, 74):
                L['full'].note(2, bt, q * 4, p, 72)
                L['full'].note(3, bt, q * 4, p, 60)
            continue
        lvl = B.get('lvl', 0) if sec == 'I' else 0
        bright = sec in ('B', 'C')
        for k in ['core', 'full']:
            tr = L[k]
            if st['kit'] == 'latin':
                # son: the clave (3-2 across two bars), conga tumbao, bongo martillo, and the bass anticipating the chord
                clave = [0, 3, 6] if b % 2 == 0 else [2, 4]
                for e in clave:
                    tr.note(DR, T(S.at(b, e)), q // 4, 75, S.hv(70, 4))
                for e, p, v in [(2, 62, 64), (3, 62, 48), (6, 63, 74), (7, 64, 70)]:
                    tr.note(DR, T(S.at(b, e)), q // 3, p, S.hv(v, 5))
                for e in range(8):
                    tr.note(DR, T(S.at(b, e)), q // 4, 60 if e % 2 == 0 else 61, S.hv(40 if e % 2 else 50, 4))
                if not (sec == 'I' and lvl < 2):
                    base = root - 24 if root - 24 >= 31 else root - 12
                    nb2 = nxt_root - 24 if nxt_root - 24 >= 31 else nxt_root - 12
                    tr.note(1, T(S.at(b, 3)), q * 1.4, base + 7, S.hv(84, 4))
                    tr.note(1, T(S.at(b, 6)), q * 1.9, nb2, S.hv(88, 4))
                continue
            if st['kit'] == 'darbuka':
                # the maksum rhythm on hand drums: doum on one and three, teks between, finger cymbals on the off-beats
                for e, p, v in [(0, 64, 84), (1, 62, 58), (3, 63, 70), (4, 64, 80), (5, 62, 56), (6, 63, 66), (7, 62, 50)]:
                    tr.note(DR, T(S.at(b, e)), q // 2, p, S.hv(v, 6))
                for e in (1, 3, 5, 7):
                    tr.note(DR, T(S.at(b, e)), q // 4, 54, S.hv(34, 4))
                if not (sec == 'I' and lvl < 2):
                    # the bass on the root and fifth, with the doum
                    base = root - 24 if root - 24 >= 31 else root - 12
                    for e, p in [(0, base), (3, base + 7), (4, base), (6, base + 7)]:
                        tr.note(1, T(S.at(b, e)), q * 0.7, p, S.hv(82, 5))
                continue
            # brushes: the ride "ding, ding-a ding" on the swung eighths, a swish on 2 and 4, a feathered bass drum
            swing_kit = st['kit'] == 'swing'
            for beat in range(4):
                tb = T(S.at(b, beat * 2))
                ride = 51 if bright or swing_kit else 59
                tr.note(DR, tb, q // 2, ride, S.hv(58 if beat % 2 == 0 else 64))
                if beat % 2 == 1:
                    tr.note(DR, T(S.at(b, beat * 2 + 1)), q // 4, ride, S.hv(44))
                    tr.note(DR, tb, q // 2, 38 if swing_kit else 40, S.hv(52 if swing_kit else 46))   # snare (or brush swish)
                    tr.note(DR, tb, q // 4, 44, S.hv(40))       # hi-hat foot
                tr.note(DR, tb, q // 2, 36, S.hv(44 if swing_kit else 34))   # feathered kick
            if sec == 'I' and lvl < 2:
                continue
            # walking bass
            line = walking_line(root, iv, nxt_root, S.rng)
            for beat, p in enumerate(line):
                tr.note(1, T(S.at(b, beat * 2)), q * 0.9, p, S.hv(86 if beat == 0 else 76, 5))
        if sec == 'I':
            continue
        v = voicing(root, iv, 58 if bright else 55, 72 if bright else 68)
        if st['comp'] == 'charleston':
            # piano comping: the Charleston (beat one, the "and" of two), brighter and on 2 and 4 in the B section
            hits = [(0, 3), (3, 1)] if not bright else [(2, 1), (6, 1), (7, 1)]
            for e, dur in hits:
                tb = T(S.at(b, e)) + S.rng.randint(-12, 12)
                for p in v:
                    L['full'].note(2, tb, q * dur * 0.5 * 0.95, p, S.hv(54 if e else 62, 5))
        elif st['comp'] == 'pompe':
            # la pompe: a short, damped chord on every beat, harder on two and four
            for beat in range(4):
                tb = T(S.at(b, beat * 2)) + S.rng.randint(-8, 8)
                for j, p in enumerate(v):
                    L['full'].note(2, tb + j * 10, q * 0.32, p, S.hv(70 if beat % 2 else 52, 5))
        elif st['comp'] == 'montuno':
            # the piano montuno: a syncopated figure in octaves and chord tones, pushing into the next bar
            lo = voicing(root, iv, 60, 72, color=False)
            hi = [p + 12 for p in lo]
            for e, chordal in [(0, False), (1, True), (3, False), (4, True), (6, True), (7, False)]:
                tb = T(S.at(b, e))
                ps = hi if chordal else [lo[0], lo[0] + 12]
                for p in ps:
                    L['full'].note(2, tb, q * 0.4, p, S.hv(64 if chordal else 58, 5))
        elif st['comp'] == 'oompah':
            # oom-pah: pizzicato chords on two, three and four (the bass takes one)
            for beat in (1, 2, 3):
                tb = T(S.at(b, beat * 2))
                for p in v:
                    L['full'].note(2, tb, q * 0.35, p, S.hv(62 if beat != 2 else 54, 5))
        elif st['comp'] == 'ripple':
            # a guitar rippling through the chord in eighths
            ap = voicing(root, iv, 52, 67, color=False)
            ap = ap + ap[1:][::-1]
            for e in range(8):
                L['full'].note(2, T(S.at(b, e)), q * 0.8, ap[e % len(ap)], S.hv(56 if e % 2 == 0 else 48, 5))
        else:
            # kanun: the chord rippled upward in eighths, the top note ringing
            ap = voicing(root, iv, 60, 79, color=False) + [voicing(root, iv, 72, 84, color=False)[0]]
            for e in range(8):
                L['full'].note(2, T(S.at(b, e)), q * 0.9, ap[e % len(ap)], S.hv(60 if e % 2 == 0 else 50, 5))
        # strings: a soft held chord, swelling a little into the bar
        for p in voicing(root, iv, 62, 76, color=False):
            L['full'].note(3, bt, q * 4 * 0.98, p, 44 if not bright else 52)
        # celesta arpeggio climbing through the chord (band 3)
        ap = voicing(root, iv, 72, 88)
        for e in range(8):
            p = ap[e % len(ap)] + (12 if e >= 4 else 0)
            L['arp'].note(4, T(S.at(b, e)), q * 0.45, p, S.hv(48 if e % 2 else 58, 4))
        # claps and a shaker (band 4)
        for e in range(8):
            L['perc'].note(DR, T(S.at(b, e)), q // 4, 70, S.hv(38 if e % 2 else 52, 4))
        for beat in (1, 3):
            L['perc'].note(DR, T(S.at(b, beat * 2)), q // 4, 39, S.hv(60, 5))
        # overdrive: the horns hit the Charleston, a crash on each bar, a kick on every beat
        L['od'].note(DR, bt, q, 49, 80)
        for beat in range(4):
            L['od'].note(DR, T(S.at(b, beat * 2)), q // 2, 36, 70)
        for e, dur in [(0, 2), (3, 1), (6, 2)]:
            for p in voicing(root, iv, 60, 74):
                L['od'].note(5, T(S.at(b, e)), q * dur * 0.5 * 0.9, p, S.hv(78, 5))
        # on the jetpack: a soft timpani heartbeat and the wind
        for beat in range(4):
            L['jet'].note(6, T(S.at(b, beat * 2)), q // 2, root - 24 if beat % 2 == 0 else root - 17, 46 if beat % 2 == 0 else 34)
        L['jet'].note(7, bt, q * 4, 60, 40)
    # the melody: every ring's note on its layer, and the notes the band plays between them
    ring = RING.get(S.c['lead'], 1.25)
    eighth = S.beat / 2.0
    for i, n in enumerate(S.c['notes']):
        d = max(0.32, n['len'] * eighth * ring)
        L['melA' if i % 2 == 0 else 'melB'].note(0, T(n['t']), T(d), n['note'], 100)
    for g in S.c['ghosts']:
        d = max(0.3, g['len'] * eighth * ring)
        L['ghost'].note(0, T(g['t']), T(d), g['note'], 84)
    # the duet: a second voice a third or so below each note, on a chord tone (it joins on an EXCELLENT streak)
    for k in ['harmA', 'harmB']:
        L[k].program(0, st['duet'])
        L[k].cc(0, 91, 80)
    for i, n in enumerate(S.c['notes']):
        p = harmony(S, n)
        if p is not None:
            d = max(0.4, n['len'] * eighth * 1.5)
            L['harmA' if i % 2 == 0 else 'harmB'].note(0, T(n['t']), T(d), p, 78)
    return L

def harmony(S, n):
    b = min(len(S.bars) - 1, max(0, int(n['t'] // S.bar)))
    root, iv = S.chord(b)
    tones = {(root + x) % 12 for x in iv}
    for down in range(3, 10):
        if (n['note'] - down) % 12 in tones:
            return n['note'] - down
    return n['note'] - 5

def render(name, track, bpm, out_dir, dur, gain):
    mid = os.path.join(out_dir, name + '.mid')
    wav = os.path.join(out_dir, name + '.wav')
    write_midi(mid, track, bpm)
    subprocess.run(['fluidsynth', '-ni', '-q', '-F', wav, '-r', str(SR), '-g', str(gain),
                    '-o', 'synth.reverb.active=1', '-o', 'synth.reverb.room-size=0.62', '-o', 'synth.reverb.damp=0.35',
                    '-o', 'synth.reverb.width=0.9', '-o', 'synth.reverb.level=0.55',
                    '-o', 'synth.chorus.active=0', SF2, mid], check=True, stderr=subprocess.DEVNULL, stdout=subprocess.DEVNULL)
    os.unlink(mid)
    return wav

def main():
    mp, ep = sys.argv[1], int(sys.argv[2])
    c = json.load(open(os.path.join(ROOT, f'godot/game/data/{mp}_{ep}.json')))
    S = Song(c)
    L = arrange_swing(S)
    out_dir = os.path.join(ROOT, f'godot/game/audio/{mp}_{ep}')
    os.makedirs(out_dir, exist_ok=True)
    dur = c['len'] * c['bar'] + 3
    for name, tr in L.items():
        # the melody sits on top of the band
        wav = render(name, tr, c['bpm'], out_dir, dur, 2.3 if name in ('ghost', 'melA', 'melB') else 1.5 if name.startswith('harm') else 0.8)
        ogg = os.path.join(out_dir, name + '.ogg')
        # trim to the song's length (every layer the same, so they stay locked together) and encode
        # the melody and the band at good quality; the layers that only add colour, lighter (they're quieter and sparse)
        q = '5' if name in ('core', 'full', 'ghost', 'melA', 'melB') else '2'
        subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', wav, '-af', f'apad=whole_dur={dur}', '-t', str(dur),
                        '-c:a', 'libvorbis', '-q:a', q, ogg], check=True)
        os.unlink(wav)
        print(' ', name)

if __name__ == '__main__':
    main()
