// Renders the music the web game plays live but has no recording of yet: the eras' loop songs (Endless and Flight
// School, as layers like the episodes'), the main-menu theme, the studio intro's music and the sound effects.
// The web game's own code makes the notes (its band per era, its lead instruments, menu theme, intro and effects,
// read from game.html and run unchanged); this file only stands in for the browser's audio engine: the same three
// voices (an oscillator through a low-pass filter, the kick, filtered noise), the same envelopes and filters, the
// reverb, and the master gain, rendered offline to WAV.
//   node tools/bake/render_audio.mjs <path to game.html> <out dir>
import fs from 'fs';

const [html, outDir] = process.argv.slice(2);
const SR = 44100;
// the files are written 6 dB down so the drums never clip; the game plays these songs 6 dB up (Music.gain_db)
const HEADROOM = 0.5;
const H = fs.readFileSync(html, 'utf8').split('\n');
const lineOf = s => H.findIndex(l => l.startsWith(s));
const take = s => H[lineOf(s)];
const until = (a, b) => H.slice(lineOf(a), lineOf(b)).join('\n');

// ------------------------------------------------------------------ the voices, rendered offline
let rngS = 12345;
const rnd = () => ((rngS = (rngS * 1664525 + 1013904223) >>> 0) / 4294967296);
const NOISE = Float32Array.from({ length: SR }, () => rnd() * 2 - 1);

class Bus { constructor(name, verb = 0) { this.name = name; this.verb = verb; this.L = null; this.R = null; } }
let LEN = 0, buses = {};
function bus(name, verb) { const b = new Bus(name, verb); b.L = new Float32Array(LEN); b.R = new Float32Array(LEN); b.vL = new Float32Array(LEN); buses[name] = b; return b; }

function biquad(type, f, q) {
  // the Web Audio filters (RBJ cookbook; low/high-pass Q in dB, band-pass Q as is)
  const w = 2 * Math.PI * Math.min(f, SR * 0.49) / SR, cs = Math.cos(w), sn = Math.sin(w);
  let a, b0, b1, b2, a0, a1, a2;
  if (type === 'bandpass') { a = sn / (2 * Math.max(q, 1e-4)); b0 = a; b1 = 0; b2 = -a; }
  else { a = sn / (2 * Math.pow(10, q / 20)); if (type === 'lowpass') { b0 = (1 - cs) / 2; b1 = 1 - cs; b2 = b0; } else { b0 = (1 + cs) / 2; b1 = -(1 + cs); b2 = b0; } }
  a0 = 1 + a; a1 = -2 * cs; a2 = 1 - a;
  return [b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0];
}
function mix(out, i0, buf, verbSend) {
  const b = out;
  for (let i = 0; i < buf.length; i++) { const k = i0 + i; if (k < 0 || k >= LEN) continue; b.L[k] += buf[i]; b.R[k] += buf[i]; if (verbSend) b.vL[k] += buf[i] * verbSend; }
}
function envAt(tt, t0, attack, g, dur) {
  // setValueAtTime(0.0001,t) · linearRamp to g at t+attack · exponentialRamp to 0.001 at t+dur
  if (tt < t0) return 0;
  if (tt < t0 + attack) return 0.0001 + (g - 0.0001) * (tt - t0) / attack;
  const e = Math.max(dur - attack, 1e-4), u = Math.min(1, (tt - t0 - attack) / e);
  return tt > t0 + dur ? 0.001 : g * Math.pow(0.001 / g, u);
}
function osc(type, ph) {
  const x = ph - Math.floor(ph);
  if (type === 'sine') return Math.sin(2 * Math.PI * x);
  if (type === 'triangle') return 1 - 4 * Math.abs(x - 0.5);
  if (type === 'square') return x < 0.5 ? 1 : -1;
  return 2 * x - 1;
}
function blep(t, dt) { if (t < dt) { t /= dt; return t + t - t * t - 1; } if (t > 1 - dt) { t = (t - 1) / dt; return t * t + t + t + 1; } return 0; }
function oscBL(type, ph, dt) {
  const x = ph - Math.floor(ph);
  if (type === 'sawtooth') return 2 * x - 1 - blep(x, dt);
  if (type === 'square') { let v = x < 0.5 ? 1 : -1; v += blep(x, dt); v -= blep((x + 0.5) % 1, dt); return v; }
  return osc(type, ph);
}
function tone(t, freq, { type = 'sawtooth', dur = 0.2, g = 0.2, cut = 2000, cutEnd = null, q = 1, attack = 0.005, detune = 0, out = A.back } = {}) {
  const n = Math.ceil((dur + 0.05) * SR), buf = new Float32Array(n);
  const fs = detune ? [freq * Math.pow(2, -detune / 1200), freq * Math.pow(2, detune / 1200)] : [freq];
  let z1 = 0, z2 = 0, coef = null;
  const phs = fs.map(() => 0);
  for (let i = 0; i < n; i++) {
    if (i % 32 === 0) { const u = Math.min(1, i / SR / dur), f = cutEnd ? cut * Math.pow(cutEnd / cut, u) : cut; coef = biquad('lowpass', f, q); }
    let s = 0;
    for (let k = 0; k < fs.length; k++) { const dt = fs[k] / SR; s += oscBL(type, phs[k], dt); phs[k] += dt; }
    const [b0, b1, b2, a1, a2] = coef, y = b0 * s + z1; z1 = b1 * s - a1 * y + z2; z2 = b2 * s - a2 * y;
    buf[i] = y * envAt(i / SR, 0, attack, g, dur);
  }
  mix(out, Math.round(t * SR), buf, out.verb);
}
function kick(t, g = 1, out = A.back) {
  const n = Math.ceil(0.45 * SR), buf = new Float32Array(n); let ph = 0;
  for (let i = 0; i < n; i++) { const tt = i / SR, f = tt < 0.14 ? 150 * Math.pow(40 / 150, tt / 0.14) : 40; ph += f / SR;
    buf[i] = Math.sin(2 * Math.PI * ph) * (tt < 0.42 ? 0.95 * g * Math.pow(0.001 / (0.95 * g), tt / 0.42) : 0); }
  mix(out, Math.round(t * SR), buf, out.verb);
}
function nz(t, { type = 'highpass', freq = 8000, q = 1, dur = 0.05, g = 0.3, verb = 0, out = A.back } = {}) {
  const n = Math.ceil((dur + 0.02) * SR), buf = new Float32Array(n), [b0, b1, b2, a1, a2] = biquad(type, freq, q);
  let z1 = 0, z2 = 0, p = Math.floor(rnd() * 0.5 * SR);
  for (let i = 0; i < n; i++) { const s = NOISE[(p + i) % SR], y = b0 * s + z1; z1 = b1 * s - a1 * y + z2; z2 = b2 * s - a2 * y;
    buf[i] = y * g * Math.pow(0.001 / g, Math.min(1, i / SR / dur)); }
  mix(out, Math.round(t * SR), buf, out.verb + verb);
}
const midi = n => 440 * Math.pow(2, (n - 69) / 12);
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
const hsh = (i, s) => { const v = Math.sin(i * 127.1 + s * 311.7) * 43758.5453; return v - Math.floor(v); };
const A = { ctx: { createGain: () => ({ gain: {}, connect() {} }) } };

// the reverb: 2.6 s of decaying noise, convolved (FFT, overlap-add), returned at 0.4
function fft(re, im, inv) {
  const n = re.length;
  for (let i = 1, j = 0; i < n; i++) { let bit = n >> 1; for (; j & bit; bit >>= 1) j ^= bit; j ^= bit; if (i < j) { [re[i], re[j]] = [re[j], re[i]]; [im[i], im[j]] = [im[j], im[i]]; } }
  for (let len = 2; len <= n; len <<= 1) { const ang = 2 * Math.PI / len * (inv ? -1 : 1), wr = Math.cos(ang), wi = Math.sin(ang);
    for (let i = 0; i < n; i += len) { let cr = 1, ci = 0; for (let j = 0; j < len / 2; j++) { const ar = re[i + j], ai = im[i + j], br = re[i + j + len / 2] * cr - im[i + j + len / 2] * ci, bi = re[i + j + len / 2] * ci + im[i + j + len / 2] * cr;
      re[i + j] = ar + br; im[i + j] = ai + bi; re[i + j + len / 2] = ar - br; im[i + j + len / 2] = ai - bi; const nr = cr * wr - ci * wi; ci = cr * wi + ci * wr; cr = nr; } } }
  if (inv) for (let i = 0; i < n; i++) { re[i] /= n; im[i] /= n; }
}
function reverb(src, seed) {
  const irLen = Math.floor(SR * 2.6); let s = seed;
  const ir = Float32Array.from({ length: irLen }, (_, i) => (((s = (s * 1664525 + 1013904223) >>> 0) / 4294967296) * 2 - 1) * Math.pow(1 - i / irLen, 3));
  // the browser normalises a convolver's impulse (normalize = true): 0.00125 / its RMS
  let ms = 0; for (const v of ir) ms += v * v; const norm = 0.00125 / Math.sqrt(ms / irLen); for (let i = 0; i < irLen; i++) ir[i] *= norm;
  const B = 8192, N = 1 << Math.ceil(Math.log2(B + irLen)), out = new Float32Array(src.length + irLen);
  const hr = new Float64Array(N), hi = new Float64Array(N); hr.set(ir); fft(hr, hi, false);
  for (let o = 0; o < src.length; o += B) {
    const xr = new Float64Array(N), xi = new Float64Array(N); let any = false;
    for (let i = 0; i < B && o + i < src.length; i++) { xr[i] = src[o + i]; if (src[o + i]) any = true; }
    if (!any) continue;
    fft(xr, xi, false);
    for (let i = 0; i < N; i++) { const r = xr[i] * hr[i] - xi[i] * hi[i]; xi[i] = xr[i] * hi[i] + xi[i] * hr[i]; xr[i] = r; }
    fft(xr, xi, true);
    for (let i = 0; i < N && o + i < out.length; i++) out[o + i] += xr[i];
  }
  return out;
}
function writeWav(path, L, R, gain = 0.8 * HEADROOM) {
  // (with a loop, the reverb tail that rings past the end is folded back onto the start of the loop)
  const n = L.length, buf = Buffer.alloc(44 + n * 4);
  buf.write('RIFF', 0); buf.writeUInt32LE(36 + n * 4, 4); buf.write('WAVEfmt ', 8); buf.writeUInt32LE(16, 16); buf.writeUInt16LE(1, 20); buf.writeUInt16LE(2, 22);
  buf.writeUInt32LE(SR, 24); buf.writeUInt32LE(SR * 4, 28); buf.writeUInt16LE(4, 32); buf.writeUInt16LE(16, 34); buf.write('data', 36); buf.writeUInt32LE(n * 4, 40);
  for (let i = 0; i < n; i++) { buf.writeInt16LE(Math.round(clamp(L[i] * gain, -1, 1) * 32767), 44 + i * 4); buf.writeInt16LE(Math.round(clamp(R[i] * gain, -1, 1) * 32767), 46 + i * 4); }
  fs.writeFileSync(path, buf);
}
function render(name, seconds, fn, loop) {
  // fn draws into the buses; each bus becomes a stem (dry + its reverb send), written as <name>/<bus>.wav
  LEN = Math.ceil(seconds * SR); buses = {}; rngS = 12345;
  fn();
  fs.mkdirSync(`${outDir}/${name}`, { recursive: true });
  for (const b of Object.values(buses)) {
    const v = reverb(b.vL, 99);
    let L = new Float32Array(LEN), R = new Float32Array(LEN);
    for (let i = 0; i < LEN; i++) { L[i] = b.L[i] + v[i] * 0.4; R[i] = b.R[i] + (v[i + 37] || 0) * 0.4; }
    if (loop) {
      // a seamless loop: what rings past the loop's end is added onto the start of the loop
      const a = Math.round(loop.from * SR), e = Math.round(loop.to * SR);
      for (let i = e; i < LEN; i++) { const k = a + ((i - e) % (e - a)); L[k] += L[i]; R[k] += R[i]; }
      L = L.slice(0, e); R = R.slice(0, e);
    }
    writeWav(`${outDir}/${name}/${b.name}.wav`, L, R);
  }
  console.log(name, Object.keys(buses).join(' '), seconds.toFixed(1) + ' s');
}

// ------------------------------------------------------------------ the web game's music, unchanged
const game = new Function('A', 'tone', 'kick', 'nz', 'midi', 'clamp', 'hsh', 'ROAD_Y', [
  take('const MINOR='), until('const THEMES=', 'const SCALES='), until('const LEADS=', 'const MM='),
  'return {THEMES, LEADS, MENU_BPM, menuStep};',
].join('\n'))(A, tone, kick, nz, midi, clamp, hsh, -2.3);
const intro = new Function('A', 'tone', 'kick', 'nz', 'midi', 'soundOn', 'intro', H.slice(lineOf('function introMusic'), lineOf('function introMusic') + 9).join('\n') + '\nreturn introMusic;');

function themeLoop(map, course, name) {
  // a course's music in layers: core (drums and bass), full (the whole band), arp, perc, od, jet, and the lead split in two
  const th = game.THEMES[map], BEAT = 60 / course.bpm, S16 = BEAT / 4, BAR = BEAT * 4, sw = course.swing || 0;
  const loop = course.loop, bars = loop ? course.intro + 8 : course.len, seconds = bars * BAR + 3.2;
  const barOf = k => {
    if (loop) return k < course.intro ? { sec: 'I', chord: th.chords[0], mel: [], lvl: k + 1 } : { sec: (k - 2) % 8 < 4 ? 'A' : 'B', chord: th.chords[(k - 2) % 4], mel: th.mel[(k - 2) % 8], lvl: 0 };
    return course.barsInfo[k];
  };
  render(name, seconds, () => {
    const L = {};
    for (const s of ['core', 'full', 'arp', 'perc', 'od', 'jet', 'ghost']) L[s] = bus(s, 0);
    const melA = bus('melA', 0.55), melB = bus('melB', 0.55);
    for (let b = 0; b < bars + (loop ? 1 : 0); b++) {
      const B = barOf(loop && b >= bars ? course.intro : b);
      if (!B) continue;
      for (let st = 0; st < 16; st++) {
        const at = (b * 16 + st) * S16;
        for (const [lvl, out] of [[2, L.core], [0, L.full]]) { A.back = out; th.backing(st, at, S16, B, course.V, B.sec === 'I' ? B.lvl : lvl, b); }
        if (B.sec === 'I') continue;
        const [r, iv] = B.chord;
        A.back = L.arp; if (st % 2 === 0) tone(at, midi(r + 24 + iv[(st / 2) % iv.length] + (st >= 8 ? 12 : 0)), { type: 'triangle', dur: S16 * 1.8, g: 0.03, cut: 5000, attack: 0.003 });
        A.back = L.perc; if (st === 4 || st === 12) nz(at, { type: 'bandpass', freq: 1400, q: 1.2, dur: 0.12, g: 0.16, verb: 0.3 }); nz(at, { type: 'highpass', freq: 7000, dur: 0.035, g: st % 2 ? 0.025 : 0.04 });
        A.back = L.jet; if (st % 4 === 0) kick(at, 0.28, L.jet); if (st === 0) nz(at, { type: 'bandpass', freq: 700 + rnd() * 500, q: 0.7, dur: BAR * 0.9, g: 0.045, out: L.jet });
        A.back = L.od; if (st % 4 === 0) kick(at, 0.75); if (st === 0) nz(at, { type: 'highpass', freq: 5000, dur: 1.4, g: 0.12, verb: 0.6 });
      }
      // the lead: each bar's notes alternate between the two layers
      const lead = game.LEADS[course.V.lead] || game.LEADS.pluck;
      B.mel.forEach(([e, note, len], j) => {
        const at = (b * 8 + e + (e % 2 ? sw : 0)) * BEAT / 2, d = Math.max(lead.min, len * BEAT / 2 * lead.k);
        A.mel = j % 2 ? melB : melA; lead.f(at, midi(note), d);
      });
    }
  }, loop ? { from: course.intro * BAR, to: bars * BAR } : null);
}

for (const map of ['old', 'sunset', 'rain']) {
  const th = game.THEMES[map];
  const school = JSON.parse(fs.readFileSync(`data/school_${map}.json`, 'utf8'));
  // Flight School's bars: two of intro, a lesson per bar (its notes on the loop's melody), then the end
  const tutBars = [];
  for (let k = 0; k < 2; k++) tutBars.push({ sec: 'I', chord: th.chords[0], mel: [], lvl: k + 1 });
  const TUT = JSON.parse(fs.readFileSync('data/themes.json', 'utf8')).tut;
  TUT.forEach((b, k) => { const m = th.mel[k % 8]; tutBars.push({ sec: 'A', chord: th.chords[k % 4], lvl: 0, mel: b.c.map(([e], j) => [e, m[Math.min(j, m.length - 1)][1], 2]) }); });
  tutBars.push({ sec: 'O', chord: th.chords[0], mel: [], lvl: 0 }, { sec: 'O', chord: th.chords[0], mel: [], lvl: 0 });
  themeLoop(map, { ...school, barsInfo: tutBars, len: tutBars.length }, `school_${map}`);
  const endless = JSON.parse(fs.readFileSync(`data/endless_${map}_normal_0.json`, 'utf8'));
  themeLoop(map, endless, `loop_${map}`);
}

// the main-menu theme: two bars of pads, then sixteen that loop
{
  const S = 15 / game.MENU_BPM, bars = 18;
  render('menu', bars * 16 * S + 3, () => { A.menu = bus('menu', 0.35); A.back = A.menu; A.master = A.menu;
    for (let n = 0; n < (bars + 1) * 16; n++) game.menuStep(n % 16, Math.floor(n / 16) >= bars ? 2 : Math.floor(n / 16), n * S); }, { from: 2 * 16 * S, to: bars * 16 * S });
}
// the studio intro's music
render('intro', 6.2, () => { A.master = bus('intro', 0); A.back = A.master; A.verb = A.master;
  const fake = { currentTime: -0.02 }; const prev = A.ctx; A.ctx = fake; intro(A, tone, kick, nz, midi, true, { on: true })(); A.ctx = prev; });

// the sound effects, as the web game makes them (one file each)
render('sfx', 2.4, () => {
  const at = 0.02;
  A.back = A.master = bus('crash', 0); kick(at, 1.3); nz(at, { type: 'lowpass', freq: 900, q: 0.7, dur: 0.7, g: 0.6, verb: 0.5 }); tone(at, 90, { type: 'sawtooth', dur: 0.5, g: 0.25, cut: 1200, cutEnd: 80 });
  A.back = A.master = bus('explode', 0); kick(at, 2.0); nz(at, { type: 'lowpass', freq: 520, q: 0.8, dur: 1.4, g: 0.95, verb: 0.6 });
  A.back = A.master = bus('whoosh', 0); nz(at, { type: 'bandpass', freq: 900, q: 0.8, dur: 0.16, g: 0.06 });
  A.back = A.master = bus('chime', 0); [76, 79, 84].forEach((n, i) => tone(at + i * 0.09, midi(n), { type: 'triangle', dur: 0.5, g: 0.1, cut: 5000 }));
  A.back = A.master = bus('deliver', 0); kick(at, 0.9); nz(at, { type: 'highpass', freq: 4000, dur: 1.0, g: 0.16, verb: 0.6 }); [0, 4, 7, 12].forEach((x, i) => tone(at + i * 0.045, midi(72 + x), { type: 'triangle', dur: 0.5, g: 0.05, cut: 7000 }));
  A.back = A.master = bus('click', 0); tone(at, midi(88), { type: 'square', dur: 0.05, g: 0.12, cut: 6000, attack: 0.001 }); kick(at, 0.35);
});
