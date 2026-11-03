"""Rio carnival melodies for the Rio course (G major, 120 BPM, 2 s bars; A = G Em C D, B = C G D Em).
Original tunes written in the forms of the famous carnival songs (no tune is copied):
- enredo:  the samba-school parade anthem (in the spirit of "É Hoje", "Aquarela Brasileira", "Liberdade, Liberdade"):
           a story-telling verse full of anticipations (notes landing a sixteenth early), then the big refrão the whole
           avenue sings, leaping up to held high notes.
- marcha:  the street-carnival marchinha ("Cidade Maravilhosa", "Ô Abre Alas", "Mamãe Eu Quero"): bouncy two-beat,
           repeated notes, dotted rhythms, question and answer, chord arpeggios.
- partido: a partido-alto riff ("Mas Que Nada", "Bum Bum Paticumbum"): a short off-beat riff the drums answer, a
           held call and quick stabs in the chorus.
Bars are written as tokens 'pos note len' on a sixteenth grid (pos 0-15, len in sixteenths); a 'g' before the pos
makes an in-between ghost note instead of a ring."""
import copy

NAMES = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}


def midi(s):
    n = NAMES[s[0]]
    i = 1
    if s[i] == '#':
        n += 1; i += 1
    elif s[i] == 'b':
        n -= 1; i += 1
    return n + 12 * (int(s[i:]) + 1)


ENREDO = {
    'A1': ['0 D5 2, g2 D5 1, 3 B4 3, 7 D5 3, g10 E5 1, 11 D5 3, g14 C5 2',
           '0 B4 6, g6 A4 1, 7 G4 3, g10 A4 2, 12 B4 4',
           '0 C5 2, g2 C5 1, 3 E5 3, 7 G5 3, g10 A5 1, 11 G5 3, g14 E5 2',
           '0 F#5 8, g10 E5 1, 11 D5 3, 15 G5 5'],
    'A2': ['g6 F#5 1, 7 E5 3, g10 D5 1, 11 B4 3, g14 D5 2',
           '0 E5 4, g4 D5 2, 6 B4 3, g9 A4 1, 10 G4 2, 13 E4 3',
           '0 G4 2, g2 A4 1, 3 C5 3, 7 E5 3, g10 D5 1, 11 C5 3, g14 B4 2',
           '0 A4 8, g8 B4 2, 10 C5 2, g12 B4 2, 14 A4 2'],
    'B1': ['3 E5 2, 6 G5 2, 9 A5 3, 12 G5 4',
           '0 B5 6, g6 A5 1, 7 G5 3, g10 E5 1, 11 D5 5',
           '0 F#5 2, g2 G5 1, 3 A5 3, 7 F#5 3, g10 E5 1, 11 D5 3, g14 E5 2',
           '0 B4 8, g10 D5 1, 11 E5 3, g14 G5 2'],
    'B2': ['0 A5 3, 3 G5 3, g6 E5 1, 7 G5 3, g10 A5 1, 11 G5 3, g14 E5 2',
           '0 D5 6, g6 E5 1, 7 D5 3, g10 B4 1, 11 G4 5',
           '0 A4 2, g2 B4 1, 3 C5 3, 7 D5 3, g10 E5 1, 11 F#5 5',
           '0 G5 8, g8 F#5 2, 10 E5 2, 13 D5 3'],
    'O': ['0 G5 12'],
}

MARCHA = {
    'A1': ['0 G4 2, g2 G4 2, 4 B4 2, g6 B4 2, 8 D5 4, 12 B4 4',
           '0 E5 3, g3 D5 1, 4 B4 4, 8 G4 4, g12 A4 2, g14 B4 2',
           '0 C5 2, g2 C5 2, 4 E5 2, g6 E5 2, 8 G5 4, 12 E5 4',
           '0 F#5 3, g3 E5 1, 4 D5 4, 8 A4 6, g14 D5 2'],
    'A2': ['0 G5 3, g3 F#5 1, 4 E5 2, g6 D5 2, 8 B4 4, 12 D5 4',
           '0 E5 3, g3 F#5 1, 4 G5 4, 8 E5 4, 12 B4 4',
           '0 C5 3, g3 D5 1, 4 E5 2, g6 C5 2, 8 A4 3, g11 B4 1, 12 C5 4',
           '0 B4 3, g3 A4 1, 4 F#4 4, 8 A4 3, g11 B4 1, 12 C5 2, g14 D5 2'],
    'B1': ['0 E5 2, g2 E5 2, 4 E5 2, g6 D5 2, 8 E5 3, g11 F#5 1, 12 G5 4',
           '0 G5 2, g2 G5 2, 4 G5 2, g6 F#5 2, 8 G5 3, g11 A5 1, 12 B5 4',
           '0 A5 3, g3 G5 1, 4 F#5 2, g6 E5 2, 8 D5 3, g11 E5 1, 12 F#5 4',
           '0 G5 6, g6 F#5 2, 8 E5 4, 12 B4 4'],
    'B2': ['0 C5 2, g2 D5 2, 4 E5 2, g6 G5 2, 8 A5 4, 12 G5 4',
           '0 D5 2, g2 E5 2, 4 D5 2, g6 B4 2, 8 G4 4, 12 B4 4',
           '0 A4 3, g3 B4 1, 4 C5 2, g6 D5 2, 8 E5 3, g11 F#5 1, 12 A5 4',
           '0 G5 4, 4 F#5 4, 8 E5 6, g14 D5 2'],
    'O': ['0 G5 3, g3 G5 1, 4 D5 2, 8 G5 8'],
}

PARTIDO = {
    'A1': ['g0 D5 1, 3 B4 2, 6 D5 3, g9 E5 1, 10 D5 2, 13 B4 3',
           '0 E5 5, g6 D5 1, 7 B4 3, 11 G4 5',
           'g0 E5 1, 3 C5 2, 6 E5 3, g9 A5 1, 10 G5 2, 13 E5 3',
           '0 F#5 5, g6 E5 1, 7 D5 3, 11 A4 5'],
    'A2': ['g0 G5 1, 3 D5 2, 6 G5 3, g9 A5 1, 10 G5 2, 13 D5 3',
           '0 E5 5, g6 F#5 1, 7 G5 3, 11 B4 5',
           'g0 C5 1, 3 E5 2, 6 G5 3, g9 E5 1, 10 C5 2, 13 A4 3',
           '0 D5 3, g3 E5 1, 4 F#5 3, 8 A5 4, g12 G5 2, 14 F#5 2'],
    'B1': ['3 E5 3, 6 G5 4, g10 A5 1, 11 G5 2, 14 E5 2',
           '1 D5 5, g6 B4 1, 7 D5 2, 10 G5 6',
           'g0 F#5 1, 3 A5 2, 6 F#5 3, g9 E5 1, 10 D5 2, 13 A4 3',
           '0 B4 6, g7 D5 1, 8 E5 3, 12 G5 4'],
    'B2': ['0 G5 2, 3 E5 3, 6 G5 4, g10 A5 1, 11 G5 2, 14 E5 2',
           '1 D5 3, 4 B4 2, 7 D5 3, 10 B4 2, 13 G4 3',
           '0 A4 2, 3 C5 3, g6 D5 1, 7 E5 3, 10 F#5 2, 13 A5 3',
           '0 G5 8, g8 F#5 2, 10 E5 3, 13 D5 3'],
    'O': ['0 G5 2, 3 D5 2, 6 G5 10'],
}

# bossa nova (in the spirit of "Garota de Ipanema", "Corcovado", "Wave"): long floating notes that start a little
# early, a motif repeated over each new chord, colour notes (the major 7th, the 9th, the #11) where they glow
BOSSA = {
    'A1': ['0 D5 5, 6 B4 2, 9 F#5 6, g15 E5 1',
           '0 E5 5, 6 D5 2, 9 B4 6, g15 A4 1',
           '0 G5 5, 6 E5 2, 9 B4 6, g15 C5 1',
           '0 A4 6, g6 B4 1, 7 C5 3, 10 E5 6'],
    'A2': ['0 D5 6, g6 C5 1, 7 B4 3, 10 F#4 6',
           '0 G4 5, 6 B4 2, 9 D5 6, g15 E5 1',
           '0 E5 6, g6 F#5 1, 7 E5 3, 10 B4 6',
           '0 A4 8, 9 F#4 3, 12 A4 4'],
    'B1': ['0 E5 2, 3 G5 3, 6 B5 4, 10 A5 2, 13 G5 3',
           '0 F#5 6, g6 E5 1, 7 D5 3, 11 B4 5',
           '0 A4 2, 3 C#5 3, 6 E5 4, 10 F#5 2, 13 A5 3',
           '0 G5 6, g6 F#5 1, 7 E5 3, 11 B4 5'],
    'B2': ['0 C5 3, 3 E5 3, 6 G5 4, 10 B5 6',
           '0 A5 6, g6 G5 1, 7 F#5 3, 11 D5 5',
           '0 E5 3, 3 F#5 3, 6 A5 4, 10 F#5 2, 13 E5 3',
           '0 D5 4, 4 B4 4, 8 G4 8'],
    'O': ['0 B4 3, 3 D5 3, 6 F#5 10'],
}

# the one-note samba (in the spirit of "Samba de Uma Nota Só", "Desafinado"): one note repeated in a samba rhythm
# while the chords move under it, so it changes colour (D is the 5th of G, the 7th of Em, the 9th of C, the root of
# D); then the same on G; the bridge runs up and down the scale
UMANOTA = {
    'A1': ['0 D5 2, 3 D5 2, 6 D5 3, 10 D5 2, 13 D5 3',
           '0 D5 6, 7 D5 3, 10 D5 2, 13 D5 3',
           '0 D5 2, 3 D5 2, 6 D5 3, 10 D5 2, 13 D5 3',
           '0 D5 6, 7 D5 3, 10 E5 2, 13 F#5 3'],
    'A2': ['0 G5 2, 3 G5 2, 6 G5 3, 10 G5 2, 13 G5 3',
           '0 G5 6, 7 G5 3, 10 G5 2, 13 G5 3',
           '0 G5 2, 3 G5 2, 6 G5 3, 10 G5 2, 13 G5 3',
           '0 F#5 6, 7 F#5 3, 10 E5 2, 13 D5 3'],
    'B1': ['0 C5 2, 3 D5 2, 6 E5 2, 9 F#5 2, 12 G5 4',
           '0 A5 2, 3 G5 2, 6 F#5 2, 9 E5 2, 12 D5 4',
           '0 E5 2, 3 F#5 2, 6 G5 2, 9 A5 2, 12 B5 4',
           '0 B5 6, 7 G5 3, 10 E5 2, 13 B4 3'],
    'B2': ['0 G5 2, 3 E5 2, 6 C5 2, 9 E5 2, 12 G5 4',
           '0 B5 4, 4 A5 2, 7 G5 3, 10 D5 6',
           '0 F#5 2, 3 E5 2, 6 D5 2, 9 C5 2, 12 A4 4',
           '0 B4 6, 7 D5 3, 10 E5 3, 13 D5 3'],
    'O': ['0 D5 2, 3 D5 2, 6 G5 10'],
}

# samba-exaltação (in the spirit of "Aquarela do Brasil"): grand and proud, chord arpeggios leaping up to long held
# notes that land a sixteenth early, then tumbling back down
EXALTA = {
    'A1': ['0 B4 3, 3 D5 3, 7 G5 9',
           '3 E5 3, 6 D5 2, 9 B4 3, 12 G4 4',
           '0 E4 3, 3 G4 3, 7 C5 9',
           '3 D5 3, 6 C5 2, 9 B4 3, 12 A4 4'],
    'A2': ['0 B4 3, 3 D5 3, 7 B5 9',
           '3 A5 3, 6 G5 2, 9 E5 3, 12 B4 4',
           '0 C5 3, 3 E5 3, 7 G5 5, g12 A5 1, 13 G5 3',
           '0 F#5 6, g6 E5 1, 7 D5 3, 10 E5 2, 13 F#5 3'],
    'B1': ['0 G5 3, 3 E5 3, 6 G5 2, 9 A5 7',
           '1 G5 3, 4 D5 2, 7 G5 3, 10 B5 6',
           '0 A5 6, g6 G5 1, 7 F#5 3, 10 E5 2, 13 D5 3',
           '0 E5 3, 3 G5 3, 7 B5 9'],
    'B2': ['3 A5 3, 6 G5 2, 9 E5 3, 12 C5 4',
           '0 D5 3, 3 G5 3, 7 B5 5, g12 A5 1, 13 G5 3',
           '0 F#5 3, 3 A5 3, 6 F#5 2, 9 D5 3, 12 A4 4',
           '0 B4 3, 3 E5 3, 7 G5 9'],
    'O': ['3 B4 3, 6 D5 2, 9 G5 7'],
}

TUNES = {'enredo': ENREDO, 'marcha': MARCHA, 'partido': PARTIDO, 'bossa': BOSSA, 'umanota': UMANOTA, 'exalta': EXALTA}
TITLES = {'enredo': 'Samba-enredo', 'marcha': 'Marchinha', 'partido': 'Partido-alto', 'bossa': 'Bossa nova',
          'umanota': 'One-note samba', 'exalta': 'Samba-exaltação'}
# which part each bar of the course plays (bars 0-1 intro, 31 end)
ORDER = [(2, 'A1'), (6, 'A2'), (10, 'B1'), (14, 'B2'), (18, 'A1'), (22, 'B1'), (26, 'B2'), (30, 'O')]
MIN_GAP = 0.375          # rings closer than this would be a scramble; the later one becomes a ghost


def course(c, name):
    tune = TUNES[name]
    s16 = c['bar'] / 16
    ev = []
    for b0, part in ORDER:
        for k, bar in enumerate(tune[part]):
            for tok in bar.split(','):
                f = tok.split()
                ghost = f[0].startswith('g')
                pos = int(f[0].lstrip('g'))
                ev.append(((b0 + k) * c['bar'] + pos * s16, midi(f[1]), int(f[2]) / 2, ghost))
    ev.sort()
    notes, ghosts, demoted, last = [], [], 0, -9.0
    for t, n, l, g in ev:
        if not g and t - last < MIN_GAP - 1e-6:
            g, demoted = True, demoted + 1
        if g:
            ghosts.append({'t': round(t, 4), 'note': n, 'len': l})
        else:
            notes.append({'t': round(t, 4), 'note': n, 'len': l, 'col': 1, 'row': 1, 'dir': '', 'mv': False, 'pu': ''})
            last = t
    cc = copy.deepcopy(c)
    cc['notes'], cc['ghosts'] = notes, ghosts
    return cc, demoted
