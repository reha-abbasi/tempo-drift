"""A sample player: real recorded instruments (the free CC0 Versilian libraries, VCSL and VSCO 2 CE) played from note
lists, with the same interface as gm.Part (note(), render()), so the jazz bands can swap their General MIDI sounds
for these.

For each note it takes the recording nearest in pitch (shifted the last semitone or two by resampling) and in
loudness, rotates through the takes of that note so repeats never sound copied, and fades the note out naturally when
it ends (each instrument has its own release). Drum kits map General MIDI drum numbers to recordings.
"""
import glob, os, re
import numpy as np
import soundfile as sf
from scipy.signal import resample_poly
from engine import SR

LIB = '/tmp/claude-1000/-workspaces-Claude-sandbox/cf9a3551-fa16-4fcd-9ea5-d1354809ee47/scratchpad/samples'
PC = {'C': 0, 'C#': 1, 'Db': 1, 'D': 2, 'D#': 3, 'Eb': 3, 'E': 4, 'F': 5, 'F#': 6, 'Gb': 6, 'G': 7, 'G#': 8, 'Ab': 8,
      'A': 9, 'A#': 10, 'Bb': 10, 'B': 11}
_cache = {}


def _load(path):
    if path not in _cache:
        x, sr = sf.read(path, always_2d=True, dtype='float32')
        x = x.T.astype(np.float64)
        if x.shape[0] == 1:
            x = np.vstack([x, x])
        x = x[:2]
        if sr != SR:
            x = resample_poly(x, SR, sr, axis=1)
        # trim the silence before the attack
        a = np.abs(x).max(axis=0)
        on = int(np.argmax(a > a.max() * 0.02))
        x = x[:, max(0, on - 64):]
        _cache[path] = x
    return _cache[path]


def _pitch(x, a=0.03, b=0.4):
    """the fundamental of a recording (harmonic product spectrum: robust for bright or short sounds)"""
    m = x.mean(0)[int(a * SR):int(b * SR)]
    m = m * np.hanning(len(m))
    F = np.abs(np.fft.rfft(m, 1 << 18))
    f = np.fft.rfftfreq(1 << 18, 1 / SR)
    H = F.copy()
    for k in (2, 3, 4):
        H[:len(F) // k] *= F[::k][:len(F) // k]
    sel = (f > 25) & (f < 2500)
    return f[sel][np.argmax(H[sel])]


def _note(name, octave_shift):
    m = re.match(r'([A-G][#b]?)(-?\d)$', name)
    return PC[m.group(1)] + 12 * (int(m.group(2)) + 1 + octave_shift)


class Instrument:
    """files: glob under LIB; rx: regex with named groups note, vel (optional), rr (optional)"""

    def __init__(self, pattern, rx, octave_shift=1, release=0.25, gain=1.0, vel_names=None, max_len=None, honky=0.0,
                 auto_octave=False):
        self.release, self.gain, self.max_len, self.honky = release, gain, max_len, honky
        self.zones = []          # (midi, vel_rank, path)
        for p in sorted(glob.glob(os.path.join(LIB, pattern), recursive=True)):
            m = re.search(rx, os.path.basename(p))
            if not m:
                continue
            d = m.groupdict()
            v = d.get('vel')
            v = (vel_names.index(v) if vel_names else int(re.sub(r'\D', '', v) or 1)) if v else 1
            self.zones.append((_note(d['note'], octave_shift), v, p))
        if not self.zones:
            raise ValueError('no samples for ' + pattern)
        if auto_octave:
            # measure a middle recording's pitch and fix the library's octave numbering
            mid = sorted(self.zones)[len(self.zones) // 2]
            f = _pitch(_load(mid[2]))
            want = 440 * 2 ** ((mid[0] - 69) / 12)
            k = int(round(np.log2(f / want)))
            if k:
                self.zones = [(n + 12 * k, v, p) for n, v, p in self.zones]
        self.vels = sorted({z[1] for z in self.zones})
        self._rr = {}

    def pick(self, note, vel):
        notes = sorted({z[0] for z in self.zones}, key=lambda n: (abs(n - note), n < note))
        base = notes[0]
        layer = self.vels[min(len(self.vels) - 1, int(vel / 128 * len(self.vels)))]
        cands = [z for z in self.zones if z[0] == base]
        best = min(abs(z[1] - layer) for z in cands)
        cands = [z for z in cands if abs(z[1] - layer) == best]
        k = self._rr.get((base, layer), 0)
        self._rr[(base, layer)] = k + 1
        return base, cands[k % len(cands)][2]

    def voice(self, note, vel, dur):
        x = self._voice(note, vel, dur)
        if self.honky:
            # an old pub upright: each note's strings are a little out of tune with each other
            r = 2 ** (self.honky / 1200)
            y = resample_poly(x, 10000, int(round(10000 * r)), axis=1)[:, :x.shape[1]]
            z = np.zeros_like(x); z[:, :y.shape[1]] = y
            x = 0.62 * x + 0.48 * z
        return x

    def _voice(self, note, vel, dur):
        base, path = self.pick(note, vel)
        x = _load(path)
        shift = note - base
        if shift:
            r = 2 ** (shift / 12)
            # resample: play faster (higher) or slower (lower)
            up, down = int(round(1000 / r)), 1000
            x = resample_poly(x, up, down, axis=1)
        n = int((dur + self.release) * SR)
        if self.max_len:
            n = min(n, int(self.max_len * SR))
        x = x[:, :n].copy()
        hold = int(dur * SR)
        if x.shape[1] > hold:
            tail = x.shape[1] - hold
            x[:, hold:] *= np.exp(-np.arange(tail) / (self.release * SR / 4))
        x[:, -min(256, x.shape[1]):] *= np.linspace(1, 0, min(256, x.shape[1]))
        # louder notes from a softer layer: scale gently by velocity inside the layer
        return x * self.gain * (0.55 + 0.45 * vel / 127)


class Kit:
    """drum kit: {gm_note: (Instrument-like list of (vel_rank, path)), ...}"""

    def __init__(self, pieces):
        self.pieces = {}
        for gm, (pattern, gain, choke) in pieces.items():
            files = sorted(glob.glob(os.path.join(LIB, pattern), recursive=True))
            if not files:
                raise ValueError('no samples for ' + pattern)
            self.pieces[gm] = (files, gain, choke)
        self._rr = {}

    def voice(self, note, vel, dur):
        if note not in self.pieces:
            return None
        files, gain, choke = self.pieces[note]
        # files are sorted soft to loud where names carry a level; pick by velocity, rotate the takes
        k = self._rr.get(note, 0)
        self._rr[note] = k + 1
        groups = {}
        for f in files:
            m = re.search(r'(?:_v|_vl|vl)(\d)', os.path.basename(f))
            groups.setdefault(int(m.group(1)) if m else 1, []).append(f)
        levels = sorted(groups)
        lv = levels[min(len(levels) - 1, int(vel / 128 * len(levels)))]
        g = groups[lv]
        x = _load(g[k % len(g)])
        if choke:
            x = x[:, :int(choke * SR)].copy()
            x[:, -256:] *= np.linspace(1, 0, 256)
        return x * gain * (0.5 + 0.5 * vel / 127)


class RPart:
    """drop-in for gm.Part: note(t, dur, pitch, vel) then render(bpm, seconds) -> stereo array"""

    def __init__(self, inst, jitter=0.0, lag=0.0, seed=1):
        """jitter: random timing spread in seconds (a human player is never exactly on the grid); lag: lay back"""
        self.inst = inst
        self.ev = []
        self.jitter, self.lag = jitter, lag
        self.rng = np.random.default_rng(seed)

    def note(self, t, dur, pitch, vel):
        self.ev.append((t, dur, int(pitch), int(max(1, min(127, vel)))))

    def render(self, bpm, seconds, gain=0.5):
        n = int(seconds * SR)
        out = np.zeros((2, n))
        for t, d, p, v in sorted(self.ev):
            x = self.inst.voice(p, v, d)
            if x is None:
                continue
            if self.jitter or self.lag:
                t = t + self.lag + float(self.rng.normal(0, self.jitter))
            a = int(max(0, t) * SR)
            if a >= n:
                continue
            m = min(n - a, x.shape[1])
            out[:, a:a + m] += x[:, :m]
        return out


V = 'vcsl/'
INSTRUMENTS = {
    'upright_piano': lambda: Instrument(V + 'Chordophones/Zithers/Upright Piano, Knight/Sustains/*.wav',
                                        r'vl(?P<vel>\d)_rr\d_(?P<note>[A-G]#?-?\d)\.wav', release=0.35, max_len=4.0),
    'pub_piano': lambda: Instrument(V + 'Chordophones/Zithers/Upright Piano, Knight/Sustains/*.wav',
                                    r'vl(?P<vel>\d)_rr\d_(?P<note>[A-G]#?-?\d)\.wav', release=0.35, max_len=4.0, honky=14),
    'strumstick': lambda: Instrument(V + 'Chordophones/Composite Chordophones/Strumstick/Finger/*.wav',
                                     r'Main_(?P<note>[A-G]#?\d)_vl(?P<vel>\d)', release=0.4, max_len=2.5),
    'harmonica': lambda: Instrument(V + 'Aerophones/Free Aerophones/Harmonica-Hohner-Super64/Sustains/Normal/*.wav',
                                    r'_(?P<note>[A-G]#?\d)\.wav', release=0.12),
    'tuba': lambda: Instrument('vsco/Brass/Tuba/stac/*.wav', r'stac_(?P<note>[A-G]#?\d)_v(?P<vel>\d)_rr\d', release=0.15),
    'tuba_sus': lambda: Instrument('vsco/Brass/Tuba/sus/*.wav', r'sus_(?P<note>[A-G]#?\d)_v(?P<vel>\d)', release=0.2),
    'trumpet': lambda: Instrument('vsco/Brass/Trumpet/sus/*.wav', r'sus_(?P<note>[A-G]#?\d)_v(?P<vel>\d)', release=0.18),
    'trumpet_vib': lambda: Instrument('vsco/Brass/Trumpet/susvib/*.wav', r'susvib_(?P<note>[A-G]#?\d)_v(?P<vel>\d)', release=0.2),
    'tenor_sax': lambda: Instrument(V + 'Aerophones/Reed Aerophones/Tenor Saxophone/Non-Vibrato/*.wav',
                                    r'NV_Main_(?P<note>[A-G]#?\d)_vl(?P<vel>\d)', release=0.15, auto_octave=True),
    'tenor_vib': lambda: Instrument(V + 'Aerophones/Reed Aerophones/Tenor Saxophone/Vibrato/*.wav',
                                    r'Vib_Main_(?P<note>[A-G]#?\d)_var', release=0.18, auto_octave=True),
    'muted_trumpet': lambda: Instrument('vsco/Brass/Trumpet/harmonM-sus/*.wav', r'harmonM-sus_(?P<note>[A-G]#?\d)_v(?P<vel>\d)', release=0.18),
    'trumpet_stac': lambda: Instrument('vsco/Brass/Trumpet/stac/*.wav', r'stac_(?P<note>[A-G]#?\d)_v(?P<vel>\d)', release=0.12),
    'trombone': lambda: Instrument('vsco/Brass/OldTrombone/Sustain/*.wav', r'Sustain_(?P<note>[A-G]#?\d)_v(?P<vel>\d)_\d', release=0.25),
    'trombone_short': lambda: Instrument('vsco/Brass/OldTrombone/Short/*.wav', r'Short_(?P<note>[A-G]#?\d)_v(?P<vel>\d)_\d', release=0.15),
    'violins': lambda: Instrument('vsco/Strings/Violin Section/susVib/*.wav', r'susVib_(?P<note>[A-G]#?\d)_v(?P<vel>\d)', release=0.5),
    'solo_violin': lambda: Instrument('vsco/Strings/Solo Violin/Arco Vib/*.wav', r'ArcoVib_(?P<note>[A-G]#?\d)_(?P<vel>p|f)', octave_shift=0,
                                      release=0.25, vel_names=['p', 'f']),
    'bass_pizz': lambda: Instrument('vsco/Strings/Solo Contrabass/Pizz/*.wav', r'Pizz_(?P<note>[A-G]#?\d)_v(?P<vel>\d)_rr\d', release=0.3),
    # Rio
    # University of Iowa MIS: a Raimundo 118 Spanish classical guitar, every note pp/mf/ff (free, no restrictions),
    # cut from its chromatic scales by split_iowa.py, the chamber's rumble filtered out
    'iowa_guitar': lambda: Instrument('iowa_guitar/*.wav', r'(?P<note>[A-G]#?\d)_(?P<vel>pp|mf|ff)\.wav', octave_shift=0,
                                      release=0.25, vel_names=['pp', 'mf', 'ff'], max_len=4.0),
    'nylon_guitar': lambda: Instrument('freepats/x_g_SFZ+FLAC.7z/*/samples/*.flac', r'^(?P<note>[A-G]#?\d)\.flac$', release=0.3,
                                       max_len=3.0, auto_octave=True),
    'marimba': lambda: Instrument(V + 'Idiophones/Struck Idiophones/Marimba/*.wav', r'Outrigger_(?P<note>[A-G]#?\d)_(?P<vel>soft|med|loud)',
                                  release=0.3, vel_names=['soft', 'med', 'loud']),   # pitch check fooled by the bars' overtones
    'vibes': lambda: Instrument(V + 'Idiophones/Struck Idiophones/Vibraphone/Soft Mallets/*.wav', r'soft_(?P<note>[A-G]#?\d)_',
                                release=0.5, max_len=3.0, auto_octave=True),
    'tenor_sax': lambda: Instrument(V + 'Aerophones/Reed Aerophones/Tenor Saxophone/Non-Vibrato/*.wav',
                                    r'NV_Main_(?P<note>[A-G]#?\d)_vl(?P<vel>\d)', release=0.15, auto_octave=True),
    'tenor_stac': lambda: Instrument(V + 'Aerophones/Reed Aerophones/Tenor Saxophone/Staccato/*.wav',
                                     r'Staccato_Main_(?P<note>[A-G]#?\d)_vl(?P<vel>\d)', release=0.1, auto_octave=True),
    'recorder': lambda: Instrument(V + 'Aerophones/Edge-blown Aerophones/Baroque Alto Recorder/Sustain/*.wav',
                                   r'Sus_(?P<note>[A-G]#?\d)_', release=0.12, auto_octave=True),
    'harp': lambda: Instrument(V + 'Chordophones/Composite Chordophones/Concert Harp/*.wav', r'KSHarp_(?P<note>[A-G]#?\d)_(?P<vel>mf|f)',
                               release=0.8, vel_names=['mf', 'f'], max_len=3.0, auto_octave=True),
    'epiano': lambda: Instrument(V + 'Electrophones/TX81Z/FM Piano/*.wav', r'FMPiano_(?P<note>[A-G]#?\d)_vl(?P<vel>\d)', release=0.4,
                                 max_len=3.0, auto_octave=True),
}
DR = V + 'Membranophones/Struck Membranophones/'
ID = V + 'Idiophones/Struck Idiophones/'
KITS = {
    # General MIDI drum numbers -> (recordings, gain, cut-off seconds or None)
    # Latin percussion, General MIDI numbers: 35 big bass drum (surdo), 36 kick, 38 snare, 40 snare without snares (caixa
    # body), 37 stick, 39 claps, 42/46 hi-hat, 49 cymbal, 54 tambourine (pandeiro), 56 cowbell, 60/61 bongos, 62 quinto,
    # 63 conga, 64 tumba, 65 muted conga, 66 muted bongo (tamborim), 67/68 agogo, 69 cabasa, 70 shaker, 71/72 whistle,
    # 73/74 guiro, 75 claves, 80/81 triangle, 43 frame drum (zabumba body), 92 ocean drum
    'latin_kit': lambda: Kit({
        35: (DR + 'Bass Drum 2/bassdrum_hit_[mf]*.wav', 1.0, 1.2),
        36: (DR + 'Bass Drum 1/*.wav', 1.0, None),
        38: (DR + 'Snare Drum, Modern 1/Snare2_HitSN_*.wav', 0.7, None),
        40: (DR + 'Snare Drum, Modern 1/Snare2_HitNS_*.wav', 0.7, None),
        37: (DR + 'Snare Drum, Modern 1/Snare2_stick_*.wav', 0.8, None),
        39: (ID + 'Claps/Clap_rr*.wav', 0.8, None),
        42: (ID + 'Hi-Hat Cymbal/HiHat_HitC_*.wav', 0.6, 0.4),
        46: (ID + 'Hi-Hat Cymbal/HiHat_HitO_*.wav', 0.5, None),
        49: (ID + 'Suspended Cymbal 1/susCymb1_hit_[fm]*1.wav', 0.5, None),
        54: (ID + 'Tambourine 2/*Hit*.wav', 0.7, None),
        56: (ID + 'Cowbells/Cowbell1_Hit_*.wav', 0.6, None),
        60: (DR + 'Bongos/BongoH_Hit1_*.wav', 0.8, None),
        61: (DR + 'Bongos/BongoL_Hit1_*.wav', 0.8, None),
        62: (DR + 'Conga/Quinto_HitN_*.wav', 0.8, None),
        63: (DR + 'Conga/Conga_HitN_*.wav', 0.8, None),
        64: (DR + 'Conga/Tumba_HitN_*.wav', 0.8, None),
        65: (DR + 'Conga/Conga_HitFM_*.wav', 0.8, None),
        66: (DR + 'Bongos/BongoH_HitMuted1_*.wav', 0.8, None),
        67: (ID + 'Agogo Bells/Agogo_High_*.wav', 0.6, None),
        68: (ID + 'Agogo Bells/Agogo_Low_*.wav', 0.6, None),
        69: (ID + 'Cabasa/Cabasa1_Hit_*.wav', 0.6, None),
        70: (ID + 'Shaker, Small/*_Down_*.wav', 0.5, 0.25),
        71: ('vcsl/Aerophones/Edge-blown Aerophones/Ball Whistle/*Short*.wav', 0.4, None),
        72: ('vcsl/Aerophones/Edge-blown Aerophones/Ball Whistle/*Long*.wav', 0.4, None),
        73: (ID + 'Guiro/Guiro_Hit_*.wav', 0.6, None),
        74: (ID + 'Guiro/Guiro_Med_*.wav', 0.6, None),
        75: (ID + 'Claves/Claves1_Hit_*.wav', 0.6, None),
        80: (ID + 'Triangles/Triangle1_HitM_*.wav', 0.5, 0.12),     # damped by the hand between hits, as players do
        81: (ID + 'Triangles/Triangle1_Hit_*.wav', 0.5, 0.45),
        43: (DR + 'Bass Drum 1/*.wav', 0.9, 0.5),
        92: ('vcsl/Membranophones/Other Membranophones/Ocean Drum/*.wav', 0.5, None),
    }),
    'parlour_kit': lambda: Kit({
        36: (DR + 'Bass Drum 1/*.wav', 1.0, None),
        38: (DR + 'Snare Drum, Rope Tension/Hi/*_sn_*.wav', 0.8, None),
        40: (DR + 'Snare Drum, Rope Tension/Low/*_sn_*.wav', 0.8, None),
        37: (DR + 'Snare Drum, Rope Tension/RopeSnare_sidestick*.wav', 0.9, None),
        42: (ID + 'Hi-Hat Cymbal/HiHat_HitC_*.wav', 0.7, 0.4),
        44: (ID + 'Hi-Hat Cymbal/HiHat_Close_*.wav', 0.7, 0.3),
        46: (ID + 'Hi-Hat Cymbal/HiHat_HitO_*.wav', 0.6, None),
        49: (ID + 'Suspended Cymbal 1/susCymb1_hit_[fm]*1.wav', 0.6, None),
        51: (ID + 'Suspended Cymbal 1/susCymb1_hit_stick_*.wav', 0.5, 1.5),
        54: (ID + 'Tambourine 1/Tamb1_Hit_*.wav', 0.8, None),
        70: (ID + 'Tambourine 1/Tamb1_Shake_*.wav', 0.5, 0.4),
        76: (ID + 'Woodblock/wood_click_*.wav', 0.6, None),
        77: (ID + 'Woodblock/wood_click3_*.wav', 0.6, None),
        41: (DR + 'Snare Drum, Rope Tension/Low/*_tsn_*.wav', 0.6, None),
    }),
}


_made = {}


def get(name):
    """an instrument or kit by name, made once"""
    if name not in _made:
        _made[name] = (INSTRUMENTS.get(name) or KITS[name])()
    return _made[name]
