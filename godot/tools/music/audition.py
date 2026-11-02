"""score Surge patches on a short B-minor phrase: how much harsh 2-6 kHz, how noisy (spectral flatness), sustain"""
import sys, os, numpy as np
from scipy.signal import welch
import surge_render as sr
def phrase(lo):
    ns_ = [lo, lo+3, lo+7, lo+10, lo+12, lo+7, lo+5, lo+3]
    return [(i*0.28, 0.25 if i < 6 else 0.6, n, 100) for i, n in enumerate(ns_)]
for spec in sys.argv[1:]:
    folder, name = spec.split('/', 1)
    lo = {'Basses': 35, 'Pads': 59, 'Polysynths': 59}.get(folder, 71)
    try:
        p = sr.load(os.path.join(sr.PATCHES, spec + '.fxp'))
        if folder in ('Pads', 'Polysynths', 'Chords'):
            notes = [(0, 2.0, n, 90) for n in (59, 62, 66)]
        else:
            notes = phrase(lo)
        y = sr.render_notes(p, notes, 3.5).mean(0)
    except Exception as e:
        print(spec, 'ERR', e); continue
    f, P = welch(y, 44100, nperseg=4096); tot = P.sum() + 1e-20
    harsh = 10*np.log10(P[(f>2000)&(f<6000)].sum()/tot); air = 10*np.log10(P[f>8000].sum()/tot)
    band = P[(f>200)&(f<8000)]; flat = np.exp(np.mean(np.log(band+1e-20)))/np.mean(band)
    cen = (f*P).sum()/tot
    print(f'{spec:34s} {sr.patch_name(p)[:18]:18s} 2-6k {harsh:6.1f}  >8k {air:6.1f}  flat {flat:.3f}  centroid {cen:6.0f}  peak {np.abs(y).max():.2f}', flush=True)
