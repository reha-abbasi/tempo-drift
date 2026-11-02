"""Recorded instruments: a part is written as MIDI and played by FluidSynth through the MuseScore General sample
library, dry (no built-in reverb or chorus), so the mix adds its own effects."""
import os, struct, subprocess, tempfile
import numpy as np
import soundfile as sf
from engine import SR

SF2 = '/usr/share/sounds/sf2/MuseScore_General_Full.sf2'
PPQ = 480


def _vlq(n):
    out = [n & 0x7F]
    n >>= 7
    while n:
        out.insert(0, (n & 0x7F) | 0x80)
        n >>= 7
    return bytes(out)


class Part:
    def __init__(self, program, drums=False, bank=0):
        self.program = program
        self.bank = bank
        self.ch = 9 if drums else 0
        self.ev = []   # (seconds, duration, pitch, velocity 0..127)

    def note(self, t, dur, pitch, vel):
        self.ev.append((t, dur, int(pitch), int(max(1, min(127, vel)))))

    def render(self, bpm, seconds, gain=0.5):
        if not self.ev:
            return np.zeros((2, int(seconds * SR)))
        tps = PPQ * bpm / 60.0
        evs = [(0, 0, bytes([0xB0 | self.ch, 91, 0])), (0, 0, bytes([0xB0 | self.ch, 93, 0])),
               (0, 0, bytes([0xB0 | self.ch, 0, self.bank])), (0, 0, bytes([0xC0 | self.ch, self.program]))]
        for t, d, p, v in self.ev:
            a = max(0, int(round(t * tps)))
            evs.append((a, 2, bytes([0x90 | self.ch, p, v])))
            evs.append((a + max(1, int(round(d * tps))), 1, bytes([0x80 | self.ch, p, 0])))
        evs.sort(key=lambda e: (e[0], e[1]))
        data = b'\x00\xFF\x51\x03' + struct.pack('>I', int(60_000_000 / bpm))[1:]
        last = 0
        for tick, _, b in evs:
            data += _vlq(tick - last) + b
            last = tick
        data += b'\x00\xFF\x2F\x00'
        mid = b'MThd' + struct.pack('>IHHH', 6, 0, 1, PPQ) + b'MTrk' + struct.pack('>I', len(data)) + data
        d = tempfile.mkdtemp()
        mp, wp = os.path.join(d, 'p.mid'), os.path.join(d, 'p.wav')
        open(mp, 'wb').write(mid)
        subprocess.run(['fluidsynth', '-ni', '-q', '-F', wp, '-r', str(SR), '-g', str(gain), '-o', 'synth.reverb.active=0',
                        '-o', 'synth.chorus.active=0', SF2, mp], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        x, _ = sf.read(wp, always_2d=True)
        os.unlink(mp)
        os.unlink(wp)
        os.rmdir(d)
        n = int(seconds * SR)
        out = np.zeros((2, n))
        m = min(n, x.shape[0])
        out[:, :m] = x[:m].T
        return out
