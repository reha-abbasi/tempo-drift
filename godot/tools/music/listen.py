"""Look at a song instead of hearing it: a spectrogram picture plus the problems numbers can catch.

usage: listen.py OUT.png FILE [FILE ...]   (mp3, ogg or wav; several files are stacked to compare)
         --from=S --to=S   only that stretch (seconds)

The picture: time left to right, pitch bottom (20 Hz) to top (16 kHz, log scale), brightness = loudness. Under it,
the loudness over time. Red ticks mark clicks (digital jumps in the waveform), orange ticks mark peaks within 0.3 dB of
full scale (clipping risk). The report lists, per file: loudness, peak, clicks, clipped samples, how much energy sits
in each band (sub, bass, low-mid, harsh 2-6 kHz, air), and the stretches where the harsh band jumps up.
"""
import os, subprocess, sys, tempfile
import numpy as np
import soundfile as sf
from scipy.signal import stft, butter, sosfilt
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

BANDS = [('sub', 20, 60), ('bass', 60, 200), ('low-mid', 200, 800), ('mid', 800, 2000), ('harsh', 2000, 6000), ('air', 6000, 16000)]


def load(path, a=None, z=None):
    d = tempfile.mkdtemp()
    w = os.path.join(d, 'x.wav')
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', path, '-ar', '44100', w], check=True)
    x, sr = sf.read(w, always_2d=True)
    os.unlink(w); os.rmdir(d)
    a = int((a or 0) * sr)
    z = int(z * sr) if z else len(x)
    return x[a:z], sr


def lufs_ish(m, sr):
    # K-weighting is close to a high-pass at 60 Hz plus a +4 dB shelf above 2 kHz; good enough to compare files
    y = sosfilt(butter(2, 60, 'hp', fs=sr, output='sos'), m)
    return 10 * np.log10(np.mean(y ** 2) + 1e-12) - 0.691


def analyse(x, sr, t0=0.0):
    m = x.mean(axis=1)
    peak = 20 * np.log10(np.abs(x).max() + 1e-12)
    clipped = int((np.abs(x) > 10 ** (-0.3 / 20)).sum())
    f, t, Z = stft(m, sr, nperseg=2048, noverlap=1536)
    P = np.abs(Z) ** 2 + 1e-14
    tot = P.sum()
    bands = {n: 10 * np.log10(P[(f >= lo) & (f < hi)].sum() / tot) for n, lo, hi in BANDS}
    # clicks: digital jumps in the waveform itself (a sample far from its neighbours), not drum hits
    dx = np.abs(np.diff(m))
    med = np.convolve(dx, np.ones(441) / 441, mode='same') + 1e-6
    idx = np.nonzero((dx > 0.25) & (dx > 25 * med))[0]
    clicks = np.array(sorted({round(i / sr, 2) for i in idx})) + t0
    # squashed stretches: the sound pressed flat (peak hardly above the average) for half a second
    win = int(0.5 * sr)
    squash = []
    for j in range(0, len(m) - win, win):
        seg = m[j:j + win]
        rms = np.sqrt(np.mean(seg ** 2)) + 1e-9
        crest = 20 * np.log10(np.abs(seg).max() / rms)
        if rms > 0.05 and crest < 7.0:
            squash.append((round(t0 + j / sr, 1), round(float(crest), 1)))
    # harsh stretches: 2-6 kHz share per half second, flagged when 6 dB above the file's median share
    harsh = P[(f >= 2000) & (f < 6000)].sum(axis=0) / P.sum(axis=0)
    hop = t[1] - t[0]
    w = max(1, int(0.5 / hop))
    hs = np.array([harsh[i:i + w].mean() for i in range(0, len(harsh), w)])
    hs_db = 10 * np.log10(hs + 1e-12)
    flag = [(round(t0 + i * w * hop, 1), round(float(v - np.median(hs_db)), 1)) for i, v in enumerate(hs_db) if v - np.median(hs_db) > 6]
    peaks_t = t0 + np.nonzero(np.abs(x).max(axis=1) > 10 ** (-0.3 / 20))[0] / sr
    return dict(f=f, t=t + t0, P=P, lufs=lufs_ish(m, sr), peak=peak, clipped=clipped, bands=bands,
                clicks=clicks, harsh=flag, peaks_t=peaks_t, squash=squash)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    opt = dict(a.lstrip('-').split('=') for a in sys.argv[1:] if a.startswith('--') and '=' in a)
    a = float(opt['from']) if 'from' in opt else None
    z = float(opt['to']) if 'to' in opt else None
    out, files = args[0], args[1:]
    fig, axes = plt.subplots(2 * len(files), 1, figsize=(16, 4.2 * len(files)),
                             gridspec_kw={'height_ratios': [4, 1] * len(files)}, squeeze=False)
    for i, path in enumerate(files):
        x, sr = load(path, a, z)
        r = analyse(x, sr, a or 0.0)
        ax, lx = axes[2 * i][0], axes[2 * i + 1][0]
        sel = (r['f'] >= 20) & (r['f'] <= 16000)
        S = 10 * np.log10(r['P'][sel])
        ax.pcolormesh(r['t'], r['f'][sel], S, shading='auto', cmap='magma', vmin=S.max() - 80, vmax=S.max())
        ax.set_yscale('log'); ax.set_ylim(20, 16000)
        ax.set_yticks([30, 60, 120, 250, 500, 1000, 2000, 4000, 8000, 16000])
        ax.set_yticklabels(['30', '60', '120', '250', '500', '1k', '2k', '4k', '8k', '16k'])
        for y0, y1 in ((2000, 6000),):
            ax.axhspan(y0, y1, color='white', alpha=0.05)
        ax.set_title(f"{os.path.basename(path)}   loudness {r['lufs']:.1f} dB   peak {r['peak']:.1f} dBFS   "
                     f"clicks {len(r['clicks'])}   clipped samples {r['clipped']}", fontsize=10, loc='left')
        for c in r['clicks']:
            ax.axvline(c, color='red', alpha=0.6, lw=0.8)
        for c in r['peaks_t'][::max(1, len(r['peaks_t']) // 200 + 1)]:
            ax.axvline(c, color='orange', alpha=0.4, lw=0.6)
        m = x.mean(axis=1)
        hop = int(0.05 * sr)
        env = [20 * np.log10(np.sqrt(np.mean(m[j:j + hop] ** 2)) + 1e-9) for j in range(0, len(m) - hop, hop)]
        lx.plot((a or 0) + np.arange(len(env)) * 0.05, env, lw=0.8, color='#444')
        lx.set_ylim(-60, 0); lx.set_xlim(r['t'][0], r['t'][-1]); lx.set_ylabel('dB', fontsize=8)
        print(f"== {path}")
        print(f"   loudness {r['lufs']:.1f} dB, peak {r['peak']:.1f} dBFS, clipped samples {r['clipped']}, clicks {len(r['clicks'])}"
              + (f" at {', '.join(f'{c:.1f}s' for c in r['clicks'][:12])}" if len(r['clicks']) else ''))
        print('   bands: ' + '  '.join(f"{n} {v:.1f}" for n, v in r['bands'].items()))
        if r['squash']:
            print('   squashed (s, peak over average dB; under 7 sounds pressed flat): ' + ', '.join(f'{t}s {v}' for t, v in r['squash'][:15]))
        if r['harsh']:
            print('   harsh jumps (s, dB over the usual): ' + ', '.join(f'{t}s +{v}' for t, v in r['harsh'][:15]))
    plt.tight_layout()
    plt.savefig(out, dpi=80)
    print('picture:', out)


if __name__ == '__main__':
    main()
