"""Render parts of a song with the Surge XT synthesizer (its factory sounds), through Spotify's pedalboard.

usage:
  surge_render.py probe                     load Surge, load a factory patch, render a test note
  surge_render.py list [FOLDER]             list factory patches (optionally in one folder, e.g. Pads)
  surge_render.py berlin OUT_DIR PATCHES... render Berlin with Surge sounds for bass / pads / arp (see berlin())
"""
import os, sys, glob
import numpy as np
import mido
import pedalboard as pb

HERE = os.path.dirname(os.path.abspath(__file__))
VST = os.path.join(HERE, 'surge/root/usr/lib/vst3/Surge XT.vst3')
PATCHES = os.path.join(HERE, 'surge/root/usr/share/surge-xt/patches_factory')
SR = 44100
FXP_HEADER = 60   # 'CcnK' ... 'FPCh' ... program name, chunk size; Surge's own patch data follows


JUCE64 = ".ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+"


def juce_b64_decode(s):
    """JUCE's MemoryBlock base64: "<size>.<chars>", 6 bits per char, least significant bits first"""
    size, chars = s.split('.', 1)
    size = int(size)
    vals = np.array([JUCE64.index(c) for c in chars], dtype=np.uint8)
    bits = np.unpackbits(vals[:, None], axis=1, bitorder='little')[:, :6].reshape(-1)
    bits = bits[:size * 8]
    return np.packbits(bits, bitorder='little').tobytes()[:size]


def juce_b64_encode(b):
    bits = np.unpackbits(np.frombuffer(b, dtype=np.uint8), bitorder='little')
    pad = (-len(bits)) % 6
    bits = np.concatenate([bits, np.zeros(pad, dtype=np.uint8)]).reshape(-1, 6)
    vals = (bits * (1 << np.arange(6))).sum(axis=1)
    return str(len(b)) + '.' + ''.join(JUCE64[v] for v in vals)


def _split_state(st):
    """the plugin state: 'VC2!', a 4-byte length, then XML holding the component state in JUCE base64"""
    import re
    xml = st[8:8 + int.from_bytes(st[4:8], 'little')].decode('utf-8')
    m = re.search(r'<IComponent>([^<]*)</IComponent>', xml)
    return xml, m


def load(patch=None):
    p = pb.load_plugin(VST)
    if patch:
        chunk = open(patch, 'rb').read()[FXP_HEADER:]
        xml, m = _split_state(p.raw_state)
        xml = xml[:m.start(1)] + juce_b64_encode(chunk) + xml[m.end(1):]
        body = xml.encode('utf-8')
        p.raw_state = b'VC2!' + len(body).to_bytes(4, 'little') + body
        # Surge swaps the patch in on its audio thread: run some silent audio so the swap happens before any note
        p([], duration=1.0, sample_rate=SR, num_channels=2, buffer_size=512, reset=False)
    return p


def patch_name(p):
    xml, m = _split_state(p.raw_state)
    raw = juce_b64_decode(m.group(1))
    import re
    n = re.search(rb'<meta name="([^"]*)"', raw)
    return n.group(1).decode() if n else '?'


def find(name):
    hits = [f for f in glob.glob(os.path.join(PATCHES, '**', '*.fxp'), recursive=True) if name.lower() in os.path.basename(f).lower()]
    return sorted(hits)


def render_notes(p, notes, seconds):
    """notes: list of (start s, length s, MIDI note, velocity 1-127) -> stereo float array (2, n)"""
    msgs = []
    for t, d, n, v in notes:
        msgs.append(mido.Message('note_on', note=int(n), velocity=int(v), time=float(t)))
        msgs.append(mido.Message('note_off', note=int(n), velocity=0, time=float(t + d)))
    msgs.sort(key=lambda m: m.time)
    out = p(msgs, duration=seconds, sample_rate=SR, num_channels=2, buffer_size=512, reset=False)
    return np.asarray(out, dtype=np.float64)


def probe():
    p = load()
    st = p.raw_state
    print('plugin', p.name, 'instrument', p.is_instrument, 'params', len(p.parameters))
    print('default state', len(st), st[:16])
    a = render_notes(p, [(0.0, 0.5, 60, 100)], 1.0)
    print('default note peak', float(np.abs(a).max()))
    for name in ('Pads/', 'Basses/', 'Plucks/'):
        f = sorted(glob.glob(os.path.join(PATCHES, name, '*.fxp')))[0]
        raw = open(f, 'rb').read()
        print(os.path.relpath(f, PATCHES), 'fxp', len(raw), raw[:4], raw[8:12], raw[16:20])
        q = load(f)
        b = render_notes(q, [(0.0, 0.5, 48, 100)], 1.5)
        diff = float(np.abs(b[:, :a.shape[1]] - a[:, :b.shape[1]]).mean()) if b.size else -1
        print('   loaded: peak', round(float(np.abs(b).max()), 3), 'differs from default by', round(diff, 4))


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else 'probe'
    if cmd == 'probe':
        probe()
    elif cmd == 'list':
        folder = sys.argv[2] if len(sys.argv) > 2 else ''
        for f in sorted(glob.glob(os.path.join(PATCHES, folder, '**', '*.fxp'), recursive=True)):
            print(os.path.relpath(f, PATCHES))


if __name__ == '__main__':
    main()



VERSIONS = {
    'warm':   ('Warm',   {'bass': 'Basses/Deep End', 'chords': 'Pads/MKS-70 Warm Pad', 'arp': 'Plucks/Nice Pluck 1'}),
    'dark':   ('Dark',   {'bass': 'Basses/Wide Bassline', 'chords': 'Pads/Moody Statement', 'arp': 'Plucks/Sync Pluck'}),
    'bright': ('Bright', {'bass': 'Basses/Rubber Bass', 'chords': 'Pads/Super', 'arp': 'Plucks/Trancy'}),
    'dreamy': ('Dreamy', {'bass': 'Basses/Smoothie', 'chords': 'Pads/Ghost Pad', 'arp': 'Plucks/Magic Music Box'}),
}


def berlin(out, keys):
    import json, techno
    from engine import loudness, master_gain, to_mp3, active_rms_db
    from render import preview_gains
    c = json.load(open(os.path.join(HERE, 'courses/rain_5.json')))
    os.makedirs(out, exist_ok=True)
    for key in keys:
        title, parts = VERSIONS[key]
        def ext(part, notes, seconds):
            p = load(os.path.join(PATCHES, parts[part] + '.fxp'))
            print(f'  {key}: {part} on "{patch_name(p)}"', flush=True)
            return render_notes(p, notes, seconds + 1.0)
        L, S = techno.build(c, 'melodic', ext=ext)
        n = L['core'].n
        gains = preview_gains(S, n)
        loudest = sum(L[k].x for k in ('full', 'arp', 'perc', 'od', 'ghost', 'melA', 'melB'))
        G = 10 ** ((-11.0 - loudness(loudest)[0]) / 20)
        for _ in range(3):
            mg = master_gain(loudest * G, ceiling_db=-1.5, glue_db=-6.0, glue_ratio=2.0)
            prev = sum(L[k].x * G * mg * gains[k] for k in gains)
            prev = prev * master_gain(prev, ceiling_db=-1.5, glue_db=40.0)
            lufs, peak = loudness(prev)
            if abs(lufs + 11.0) < 0.4:
                break
            G *= 10 ** ((-11.0 - lufs) / 20 * 0.9)
        to_mp3(prev, os.path.join(out, f'berlin_surge_{key}.mp3'))
        print(f'{key}: {lufs:.1f} LUFS, peak {peak:.1f} dBFS', flush=True)


if __name__ == '__main__' and len(sys.argv) > 2 and sys.argv[1] == 'berlin':
    berlin(sys.argv[2], sys.argv[3:] or list(VERSIONS))


def check():
    d = load()
    xml, m = _split_state(d.raw_state)
    raw = juce_b64_decode(m.group(1))
    print('default component state', len(raw), raw[:4], '| round trip ok:', juce_b64_encode(raw) == m.group(1), '| patch:', patch_name(d))
    a = render_notes(d, [(0.0, 0.5, 48, 100)], 1.2)
    for f in [find('Attacky')[0], sorted(glob.glob(os.path.join(PATCHES, 'Pads', '*.fxp')))[3]]:
        q = load(f)
        b = render_notes(q, [(0.0, 0.5, 48, 100)], 1.2)
        print(os.path.basename(f), '-> loaded patch:', patch_name(q), '| audio diff', round(float(np.abs(a - b).mean()), 4), '| peak', round(float(np.abs(b).max()), 3))


if __name__ == '__main__' and len(sys.argv) > 1 and sys.argv[1] == 'check':
    check()


# round 2: everything built on "Warm" (the user's pick), some with a new melody sound or phrasing
W = {'bass': 'Basses/Deep End', 'chords': 'Pads/MKS-70 Warm Pad', 'arp': 'Plucks/Nice Pluck 1'}
VERSIONS2 = {
    'w_dreamyflute': ('Warm + Dreamy Flute melody', dict(W, lead='Winds/Dreamy Flute'), {'lead': 'lead'}),
    'w_clarinet':    ('Warm + Clarinet melody', dict(W, lead='Winds/Clarinet'), {'lead': 'lead'}),
    'w_epiano':      ('Warm + Electric piano melody', dict(W, lead='Keys/Soft Suitcase'), {'lead': 'lead'}),
    'w_butter':      ('Warm + Smooth synth melody', dict(W, lead='Leads/Butter'), {'lead': 'lead'}),
    'w_high':        ('Warm + Melody an octave up (flute + soft sine)', dict(W, lead='Leads/Sine Lead'), {'lead': 'lead', 'double': True, 'octave': 12}),
    'w_legato':      ('Warm + Long, held melody (Surge flute)', dict(W, lead='Winds/Flute 2'), {'lead': 'lead', 'ring_len': 1.7, 'ghosts': False}),
    'w_strings':     ('Warm Strings (Juno strings pad)', dict(W, chords='Polysynths/Juno-60 Strings', arp='Plucks/Nice Pluck 2'), {}),
    'w_soft':        ('Warm Soft (rounder bass, wooden arp)', dict(W, bass='Basses/Mellow', chords='Pads/Winter Warmer', arp='Plucks/Woody'), {}),
}


def berlin2(out, keys):
    import json, techno
    from engine import loudness, master_gain, to_mp3
    from render import preview_gains
    c = json.load(open(os.path.join(HERE, 'courses/rain_5.json')))
    os.makedirs(out, exist_ok=True)
    for key in keys:
        title, parts, mel = VERSIONS2[key]
        def ext(part, notes, seconds):
            p = load(os.path.join(PATCHES, parts[part] + '.fxp'))
            print(f'  {key}: {part} on "{patch_name(p)}"', flush=True)
            y = render_notes(p, notes, seconds + 1.0)
            if part == 'lead':
                # the melody chain adds +3 dB of air for the soft flute: take the edge off Surge's brighter leads first
                y = pb.Pedalboard([pb.HighShelfFilter(2500, -5.0), pb.LowpassFilter(9000)])(y.astype(np.float32), SR).astype(np.float64)
            return y
        L, S = techno.build(c, 'melodic', ext=ext, mel=mel)
        n = L['core'].n
        gains = preview_gains(S, n)
        loudest = sum(L[k].x for k in ('full', 'arp', 'perc', 'od', 'ghost', 'melA', 'melB'))
        G = 10 ** ((-11.0 - loudness(loudest)[0]) / 20)
        for _ in range(4):
            mg = master_gain(loudest * G, ceiling_db=-1.5, glue_db=-6.0, glue_ratio=2.0)
            prev = sum(L[k].x * G * mg * gains[k] for k in gains)
            prev = prev * master_gain(prev, ceiling_db=-1.5, glue_db=40.0)
            lufs, peak = loudness(prev)
            if abs(lufs + 11.0) < 0.3:
                break
            G *= 10 ** ((-11.0 - lufs) / 20)
        to_mp3(prev, os.path.join(out, f'{key}.mp3'))
        print(f'{key}: {lufs:.1f} LUFS, peak {peak:.1f} dBFS', flush=True)


if __name__ == '__main__' and len(sys.argv) > 2 and sys.argv[1] == 'berlin2':
    berlin2(sys.argv[2], sys.argv[3:] or list(VERSIONS2))


# round 3: like "Smooth synth", Tron / Cyberpunk melodies, Tron / Cyberpunk bands, and new melody notes
TRON = {'bass': 'Basses/Lord Sawtooth', 'chords': 'Polysynths/Super Jupiter', 'arp': 'Plucks/The 1980s', 'lead': 'Brass/Synth Brass 1'}
CYBER = {'bass': 'Basses/Dist Bass 1', 'chords': 'Polysynths/PPG Dreams', 'arp': 'Plucks/Delay Pops 1', 'lead': 'Leads/Moogy Saw'}
L1 = {'lead': 'lead'}
VERSIONS3 = {
    'smooth_ref':   ('Smooth synth (last round)', dict(W, lead='Leads/Butter'), L1, None, None),
    'smooth_world': ('Smooth: "Smoothness World Cup"', dict(W, lead='Leads/Smoothness World Cup'), L1, None, None),
    'smooth_generic': ('Smooth: "Generic" (warm analog)', dict(W, lead='Leads/Generic'), L1, None, None),
    'smooth_playnice': ('Smooth: "Play Nice"', dict(W, lead='Leads/Play Nice'), L1, None, None),
    'mel_tron':     ('Tron melody, Warm band', dict(W, lead=TRON['lead']), L1, None, None),
    'mel_cyber':    ('Cyberpunk melody, Warm band', dict(W, lead=CYBER['lead']), L1, None, None),
    'mel_pwm':      ('Retro PWM melody, Warm band', dict(W, lead='Leads/Crisp PWM'), L1, None, None),
    'band_tron':    ('Tron band', TRON, L1, 'tron', None),
    'band_cyber':   ('Cyberpunk band', CYBER, L1, 'cyber', None),
    'new_hook':     ('New melody: hook (Smooth synth, Warm band)', dict(W, lead='Leads/Butter'), L1, None, 'hook'),
    'new_heroic':   ('New melody: heroic (Tron band)', TRON, L1, 'tron', 'heroic'),
    'new_dark':     ('New melody: dark (Cyberpunk band)', CYBER, L1, 'cyber', 'dark'),
}


def berlin3(out, keys):
    import json, techno, melodies
    from engine import loudness, master_gain, to_mp3
    from render import preview_gains
    c0 = json.load(open(os.path.join(HERE, 'courses/rain_5.json')))
    os.makedirs(out, exist_ok=True)
    for key in keys:
        title, parts, mel, style, newmel = VERSIONS3[key]
        c = melodies.MELODIES[newmel](c0) if newmel else c0
        def ext(part, notes, seconds):
            p = load(os.path.join(PATCHES, parts[part] + '.fxp'))
            print(f'  {key}: {part} on "{patch_name(p)}"', flush=True)
            y = render_notes(p, notes, seconds + 1.0)
            if part == 'lead':
                soft = -10.0 if 'Brass' in parts['lead'] else -5.0     # brass leads are full of upper harmonics
                y = pb.Pedalboard([pb.HighShelfFilter(2500, soft), pb.LowpassFilter(7000 if soft < -5 else 9000)])(y.astype(np.float32), SR).astype(np.float64)
            return y
        L, S = techno.build(c, 'melodic', ext=ext, mel=mel, style=style)
        gains = preview_gains(S, L['core'].n)
        loudest = sum(L[k].x for k in ('full', 'arp', 'perc', 'od', 'ghost', 'melA', 'melB'))
        G = 10 ** ((-11.0 - loudness(loudest)[0]) / 20)
        for _ in range(4):
            mg = master_gain(loudest * G, ceiling_db=-1.5, glue_db=-6.0, glue_ratio=2.0)
            prev = sum(L[k].x * G * mg * gains[k] for k in gains)
            prev = prev * master_gain(prev, ceiling_db=-1.5, glue_db=40.0)
            lufs, peak = loudness(prev)
            if abs(lufs + 11.0) < 0.3:
                break
            G *= 10 ** ((-11.0 - lufs) / 20)
        to_mp3(prev, os.path.join(out, f'{key}.mp3'))
        print(f'{key}: {lufs:.1f} LUFS, peak {peak:.1f} dBFS', flush=True)


if __name__ == '__main__' and len(sys.argv) > 2 and sys.argv[1] == 'berlin3':
    berlin3(sys.argv[2], sys.argv[3:] or list(VERSIONS3))


def game(key, out, phone=True):
    """the song as the game uses it: the preview mp3 and the nine layers as ogg, mastered together like render.py"""
    import json, techno, melodies
    from engine import loudness, master_gain, to_mp3, to_ogg
    from render import preview_gains
    title, parts, mel, style, newmel = VERSIONS3[key]
    c0 = json.load(open(os.path.join(HERE, 'courses/rain_5.json')))
    c = melodies.MELODIES[newmel](c0) if newmel else c0
    def ext(part, notes, seconds):
        p = load(os.path.join(PATCHES, parts[part] + '.fxp'))
        print(f'  {key}: {part} on "{patch_name(p)}"', flush=True)
        y = render_notes(p, notes, seconds + 1.0)
        if part == 'lead':
            soft = -10.0 if 'Brass' in parts['lead'] else -5.0
            y = pb.Pedalboard([pb.HighShelfFilter(2500, soft), pb.LowpassFilter(7000 if soft < -5 else 9000)])(y.astype(np.float32), SR).astype(np.float64)
        return y
    L, S = techno.build(c, 'melodic', ext=ext, mel=dict(mel, phone=phone), style=style)
    gains = preview_gains(S, L['core'].n)
    loudest = sum(L[k].x for k in ('full', 'arp', 'perc', 'od', 'ghost', 'melA', 'melB'))
    G = 10 ** ((-11.0 - loudness(loudest)[0]) / 20)
    for _ in range(4):
        mg = master_gain(loudest * G, ceiling_db=-1.5, glue_db=-6.0, glue_ratio=2.0)
        prev = sum(L[k].x * G * mg * gains[k] for k in gains)
        prev = prev * master_gain(prev, ceiling_db=-1.5, glue_db=40.0)
        lufs, peak = loudness(prev)
        if abs(lufs + 11.0) < 0.3:
            break
        G *= 10 ** ((-11.0 - lufs) / 20)
    os.makedirs(out, exist_ok=True)
    to_mp3(prev, os.path.join(out, key + '.mp3'))
    if out.endswith('stems') or '--stems' in sys.argv:
        d = os.path.join(out, key)
        os.makedirs(d, exist_ok=True)
        for k, l in L.items():
            to_ogg(l.x * G * mg, os.path.join(d, k + '.ogg'), 5 if k in ('core', 'full', 'ghost', 'melA', 'melB') else 3)
    print(f'{key}: {lufs:.1f} LUFS, peak {peak:.1f} dBFS', flush=True)


if __name__ == '__main__' and len(sys.argv) > 2 and sys.argv[1] == 'game':
    for k in sys.argv[3:]:
        if not k.startswith('--'):
            game(k, sys.argv[2])
