"""Generate the placeholder chiptune sound effects and music loop.

Usage:  python3 tools/make_audio.py
Writes 16-bit mono WAV files into assets/audio/. Only uses the standard library.
Replace any of the files with real sounds later (keep the same file names).
"""

import math
import random
import struct
from pathlib import Path

RATE = 22050
OUT = Path(__file__).resolve().parent.parent / "assets" / "audio"


def square(f, t, duty=0.5):
    return 1.0 if (f * t) % 1.0 < duty else -1.0


def triangle(f, t):
    p = (f * t) % 1.0
    return 4.0 * abs(p - 0.5) - 1.0


def silence(seconds):
    return [0.0] * int(seconds * RATE)


def tone(f0, f1, seconds, wave_fn=square, vol=0.5, attack=0.005, release=None):
    n = int(seconds * RATE)
    out = []
    phase = 0.0
    release = seconds if release is None else release
    for i in range(n):
        t = i / RATE
        f = f0 + (f1 - f0) * (i / n)
        phase += f / RATE
        env = min(1.0, t / attack) if attack > 0 else 1.0
        env *= max(0.0, 1.0 - t / release)
        if wave_fn is square:
            s = 1.0 if phase % 1.0 < 0.5 else -1.0
        elif wave_fn is triangle:
            s = 4.0 * abs(phase % 1.0 - 0.5) - 1.0
        else:
            s = math.sin(2 * math.pi * phase)
        out.append(s * env * vol)
    return out


def noise(seconds, vol=0.5, smooth=0.0, decay=True, seed=1):
    rng = random.Random(seed)
    n = int(seconds * RATE)
    out = []
    last = 0.0
    for i in range(n):
        v = rng.uniform(-1, 1)
        last = last * smooth + v * (1 - smooth)
        env = (1.0 - i / n) if decay else math.sin(math.pi * i / n)
        out.append(last * env * vol)
    return out


def mix(*tracks):
    n = max(len(t) for t in tracks)
    out = [0.0] * n
    for t in tracks:
        for i, v in enumerate(t):
            out[i] += v
    return out


def concat(*parts):
    out = []
    for p in parts:
        out.extend(p)
    return out


def write(name, samples):
    OUT.mkdir(parents=True, exist_ok=True)
    peak = max(1e-6, max(abs(s) for s in samples))
    scale = 0.9 / peak if peak > 0.9 else 1.0
    data = b"".join(struct.pack("<h", int(max(-1, min(1, s * scale)) * 32767)) for s in samples)
    header = struct.pack("<4sI4s4sIHHIIHH4sI", b"RIFF", 36 + len(data), b"WAVE", b"fmt ", 16,
                         1, 1, RATE, RATE * 2, 2, 16, b"data", len(data))
    (OUT / f"{name}.wav").write_bytes(header + data)
    print(f"wrote {name}.wav ({len(samples) / RATE:.2f}s)")


def sfx():
    write("coin", concat(tone(988, 988, 0.05, vol=0.35), tone(1319, 1319, 0.14, vol=0.35)))
    write("jump", tone(320, 760, 0.18, vol=0.35))
    write("land", noise(0.08, vol=0.5, smooth=0.85))
    write("slide", noise(0.35, vol=0.5, smooth=0.7, decay=False, seed=3))
    write("swipe", noise(0.12, vol=0.4, smooth=0.5, decay=False, seed=4))
    write("bump", mix(tone(160, 90, 0.18, vol=0.5), noise(0.12, vol=0.4, smooth=0.8, seed=5)))
    write("crash", mix(tone(240, 50, 0.6, vol=0.45), noise(0.7, vol=0.6, smooth=0.6, seed=6)))
    write("power", concat(*[tone(f, f, 0.08, wave_fn=triangle, vol=0.5) for f in (523, 659, 784, 1047, 1319)]))
    write("click", tone(1500, 1200, 0.03, vol=0.3))


NOTE = {n: i for i, n in enumerate(["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"])}


def freq(name):
    """'A4' -> 440 Hz."""
    pitch, octave = name[:-1], int(name[-1])
    semis = NOTE[pitch] + (octave - 4) * 12 - 9
    return 440.0 * 2 ** (semis / 12)


def music():
    bpm = 150
    beat = 60.0 / bpm
    bars = 8
    total = int(bars * 4 * beat * RATE)
    out = [0.0] * total

    def put(start_s, samples):
        i0 = int(start_s * RATE)
        for i, v in enumerate(samples):
            if i0 + i < total:
                out[i0 + i] += v

    chords = [("C", ["C", "E", "G"]), ("A", ["A", "C", "E"]), ("F", ["F", "A", "C"]), ("G", ["G", "B", "D"])]
    melody = [
        "E5 G5 A5 G5 E5 D5 C5 D5", "E5 E5 G5 A5 C6 A5 G5 E5",
        "F5 A5 C6 A5 G5 F5 E5 D5", "D5 G5 B5 G5 D5 E5 F5 G5",
        "E5 G5 A5 G5 E5 D5 C5 D5", "E5 E5 G5 A5 C6 A5 G5 E5",
        "F5 A5 C6 A5 G5 F5 E5 F5", "G5 - B5 - D6 - G5 -",
    ]
    for bar in range(bars):
        root, triad = chords[bar % 4]
        t0 = bar * 4 * beat
        # bass: root eighths, octave jumps
        for e in range(8):
            octave = 2 if e % 2 == 0 else 3
            f = freq(f"{root}{octave}")
            put(t0 + e * beat / 2, tone(f, f, beat / 2 * 0.9, wave_fn=triangle, vol=0.55, release=beat / 2))
        # lead melody (square, eighths)
        for e, n in enumerate(melody[bar].split()):
            if n == "-":
                continue
            f = freq(n)
            put(t0 + e * beat / 2, tone(f, f, beat / 2 * 0.85, vol=0.16, release=beat * 0.6))
        # arpeggio pad
        for e in range(16):
            n = triad[e % 3]
            f = freq(f"{n}4")
            put(t0 + e * beat / 4, tone(f, f, beat / 4 * 0.8, vol=0.06, release=beat / 4))
        # drums
        for b in range(4):
            tb = t0 + b * beat
            if b % 2 == 0:
                put(tb, tone(150, 40, 0.12, wave_fn=None, vol=0.8))  # kick
            else:
                put(tb, noise(0.12, vol=0.35, smooth=0.3, seed=bar * 4 + b))  # snare
            put(tb + beat / 2, noise(0.04, vol=0.15, smooth=0.0, seed=100 + bar * 4 + b))  # hat
    write("music", out)


if __name__ == "__main__":
    sfx()
    music()
