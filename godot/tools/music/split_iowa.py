"""cut the Iowa guitar chromatic-scale recordings into one file per note: split_iowa.py SRC DST"""
import os, re, sys, glob
import numpy as np, soundfile as sf
NAMES = {'C': 0, 'Db': 1, 'D': 2, 'Eb': 3, 'E': 4, 'F': 5, 'Gb': 6, 'G': 7, 'Ab': 8, 'A': 9, 'Bb': 10, 'B': 11}
SHARP = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B']
def m(s):
    n, o = re.match(r'([A-G]b?)(\d)', s).groups(); return NAMES[n] + 12 * (int(o) + 1)
src, dst = sys.argv[1], sys.argv[2]
os.makedirs(dst, exist_ok=True)
STR = {'sul_E': 0, 'sulB': 1, 'sulG': 2, 'sulD': 3, 'sulA': 4, 'sulE': 5}   # preference: highest string first
best = {}
for f in sorted(glob.glob(os.path.join(src, 'Guitar.*.aif'))):
    dyn, string, rng = re.match(r'.*Guitar\.(pp|mf|ff)\.(\w+?)\.([A-G]b?\d(?:[A-G]b?\d)?)\.aif', f).groups()
    ns = re.findall(r'[A-G]b?\d', rng)
    lo, hi = m(ns[0]), m(ns[-1])
    want = hi - lo + 1
    x, sr = sf.read(f, always_2d=True)
    if lo < 50:
        continue                     # the low strings share their range with the room's rumble; the melody never goes there
    # the chamber has a loud low rumble (~75 Hz) between notes: take it out below the lowest note
    from scipy.signal import butter, sosfiltfilt
    x = sosfiltfilt(butter(4, 0.8 * 440 * 2 ** ((lo - 69) / 12), 'highpass', fs=sr, output='sos'), x, axis=0)
    env = np.sqrt(np.convolve((x ** 2).mean(1), np.ones(441) / 441, 'same'))[::441]   # 10 ms
    db = 20 * np.log10(env + 1e-9); db -= db.max()
    # notes are separated by quiet: split where the level stays below -40 dB for at least 0.3 s
    loud = db > -40
    on, quiet = [], 99
    for i, v in enumerate(loud):
        if v and quiet >= 30:
            on.append(max(0, i - 2))
        quiet = 0 if v else quiet + 1
    while len(on) > want:
        # an extra sound (a knock, a stray pluck): drop the quietest piece
        pk = [db[a:(on[k + 1] if k + 1 < len(on) else len(db))].max() for k, a in enumerate(on)]
        on.pop(int(np.argmin(pk)))
    status = 'ok' if len(on) == want else f'GOT {len(on)} WANT {want}'
    print(os.path.basename(f), status)
    if len(on) != want:
        continue
    for k, a in enumerate(on):
        b = on[k + 1] - 2 if k + 1 < len(on) else len(db)
        seg = x[a * 441: b * 441]
        # trim the tail once it has died away (-60 dB below the note's peak)
        e = env[a:b]; tail = np.where(20 * np.log10(e / e.max() + 1e-9) > -60)[0]
        seg = seg[: (tail[-1] + 1) * 441] if len(tail) else seg
        p = lo + k
        key = (p, dyn)
        if key not in best or STR[string] < best[key][0]:
            best[key] = (STR[string], seg, sr)
for (p, dyn), (_, seg, sr) in best.items():
    f = int(0.004 * sr); seg = seg.copy(); seg[-f:] *= np.linspace(1, 0, f)[:, None]
    sf.write(os.path.join(dst, f'{SHARP[p % 12]}{p // 12 - 1}_{dyn}.wav'), seg.astype(np.float32), sr)
print(len(best), 'notes written')
