"""New melodies for a course, written on its own chords (B minor in Berlin). Each returns a course copy whose
'notes' are the new melody (the rings would move with it) and whose 'ghosts' are empty or new in-between notes."""
import copy

SCALE = [0, 2, 3, 5, 7, 8, 10]          # natural minor, from the key's tonic


def _tonic(c):
    return c['bars'][1]['root'] % 12      # Berlin: B


def _chord_tones(root, iv, lo, hi):
    pcs = {(root + i) % 12 for i in iv}
    return [m for m in range(lo, hi + 1) if m % 12 in pcs]


def _scale_tones(c, lo, hi, extra=()):
    t = _tonic(c)
    pcs = {(t + s) % 12 for s in SCALE} | {(t + e) % 12 for e in extra}
    return [m for m in range(lo, hi + 1) if m % 12 in pcs]


def _near(cands, target):
    return min(cands, key=lambda m: (abs(m - target), m))


def _write(c, events, ghosts=()):
    """events: (time s, MIDI note, length in eighths)"""
    cc = copy.deepcopy(c)
    cc['notes'] = [{'t': round(t, 4), 'note': int(n), 'len': l, 'col': 1, 'row': 1, 'dir': '', 'mv': False, 'pu': ''}
                   for t, n, l in events]
    cc['ghosts'] = [{'t': round(t, 4), 'note': int(n), 'len': l} for t, n, l in ghosts]
    return cc


def _bars(c):
    for b, B in enumerate(c['bars']):
        if B['sec'] in ('I', 'E'):
            continue
        yield b, B


def hook(c):
    """a syncopated melodic-techno hook: dotted-quarter pushes (eighths 0, 3, 6), climbing over each 4-bar phrase,
    answering itself an octave higher in the big sections"""
    e = c['beat'] / 2
    ev, gh = [], []
    shape = [0, 2, 1, -1]                  # where each bar of a 4-bar phrase sits, in chord tones above the base
    for b, B in _bars(c):
        tones = _chord_tones(B['root'], B['iv'], 62, 79)
        base = _near(tones, 66 + (5 if B['sec'] in ('B', 'C') else 0))
        i0 = tones.index(base) + shape[b % 4]
        pat = [(0, 0, 3), (3, 1, 3), (6, -1, 2)]
        for pos, step, ln in pat:
            k = max(0, min(len(tones) - 1, i0 + step))
            ev.append((c['bar'] * b + pos * e, tones[k], ln))
        if B['sec'] in ('B', 'C'):
            st = _scale_tones(c, 62, 81)
            top = tones[max(0, min(len(tones) - 1, i0 + 1))]
            gh.append((c['bar'] * b + 5 * e, _near([s for s in st if s != top], top + 2), 1))
    return _write(c, ev, gh)


def heroic(c):
    """a big, open, film-score line: long notes that leap by fifths and octaves, with a run of eighths into the
    loud sections"""
    e = c['beat'] / 2
    ev = []
    for b, B in _bars(c):
        r = B['root']
        tones = _chord_tones(r, B['iv'], 59, 81)
        if B['sec'] == 'A':
            ev.append((c['bar'] * b, _near(tones, 66), 4))
            ev.append((c['bar'] * b + 4 * e, _near(tones, 71 if b % 2 else 69), 4))
        elif B['sec'] == 'B':
            ev.append((c['bar'] * b, _near(tones, 71), 3))
            ev.append((c['bar'] * b + 3 * e, _near(tones, 74), 3))
            ev.append((c['bar'] * b + 6 * e, _near(tones, 78 if b % 2 else 73), 2))
        else:   # C / O: the climax, an octave leap then steps down
            hi = _near(tones, 78)
            st = _scale_tones(c, 59, 83)
            ev.append((c['bar'] * b, hi - 12, 2))
            ev.append((c['bar'] * b + 2 * e, hi, 3))
            j = st.index(_near(st, hi))
            ev.append((c['bar'] * b + 5 * e, st[max(0, j - 1)], 1))
            ev.append((c['bar'] * b + 6 * e, st[max(0, j - 2)], 2))
    return _write(c, ev)


def dark(c):
    """a low, tense, minor line: short repeated notes that fall, a flat second (C over B) for a darker colour,
    and stabs on the off-beats"""
    e = c['beat'] / 2
    ev, gh = [], []
    for b, B in _bars(c):
        tones = _chord_tones(B['root'], B['iv'], 57, 74)
        st = _scale_tones(c, 55, 76, extra=(1,))          # + C natural: the phrygian half-step above B
        top = _near(tones, 69 if B['sec'] == 'A' else 71)
        j = st.index(top)
        line = [(0, top, 1), (1.5 * 2 / 2 * 1, top, 1), (3, st[max(0, j - 1)], 1), (4, st[max(0, j - 2)], 2), (7, st[max(0, j - 1)], 1)]
        if b % 4 == 3:
            line = [(0, top, 1), (2, st[min(len(st) - 1, j + 1)], 1), (3, top, 2), (6, st[max(0, j - 3)], 2)]
        for pos, n, ln in line:
            ev.append((c['bar'] * b + pos * e, n, ln))
        if B['sec'] in ('B', 'C'):
            gh.append((c['bar'] * b + 5 * e, top - 12, 1))
            gh.append((c['bar'] * b + 6 * e, top - 12, 1))
    return _write(c, ev, gh)


MELODIES = {'hook': hook, 'heroic': heroic, 'dark': dark}
