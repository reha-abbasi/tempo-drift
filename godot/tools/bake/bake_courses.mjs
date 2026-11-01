// Bakes the Flight School and Endless courses with the web game's own generator (web/game.html), so they follow
// exactly the same rules as the episodes (whose courses were baked the same way):
//   data/school_<map>.json            the guided lesson song for each era
//   data/endless_<map>_<level>_<k>.json   Endless runs: the era's loop with the course and traffic drawn from a seed
//                                         (the web game draws a new seed each run; the game picks one of these)
// The generator's code is read from game.html and run unchanged; only the browser parts are stubbed.
//   node tools/bake/bake_courses.mjs <path to game.html> <out dir>
import fs from 'fs';

const [html, outDir] = process.argv.slice(2);
const L = fs.readFileSync(html, 'utf8').split('\n');
const lineOf = (start) => L.findIndex(l => l.startsWith(start));
const take = (start, endPred) => {
  const a = lineOf(start); if (a < 0) throw new Error('not found: ' + start);
  let b = a; while (!endPred(L[b], b - a)) b++;
  return L.slice(a, b + 1).join('\n');
};
const until = (start, nextStart) => { const a = lineOf(start), b = lineOf(nextStart); return L.slice(a, b).join('\n'); };

const src = [
  'const LX=[-1.6,0,1.6], CW=1.6, NL=LX.length, MID=1, AHEAD=12;',
  'const LY=[-1.7,0,1.7], HOME=1, ROAD_Y=-2.3;',
  'const HOLD_TAIL=0.12, MAX_RUN=1.7, PAD_LEAD=0.3, ONE_NOTE=0.32, DROP_TAIL=0.22;',
  take('const LEVELS=', () => true),
  'let LEVEL="normal";',
  take('const need=', () => true),
  take('const clamp=', () => true), take('const hsh=', () => true), take('const mkRng=', () => true),
  'let grand=mkRng(7);',
  until('const MINOR=', 'const SCALES='),
  take('const MAPINFO=', () => true),
  until('function laneMap', 'let key='),
  until('const KINDS={', 'const hobj='),
  'const NOTE_MODE=true;',
  until('const ACCENT=', 'let hudForm='),
].join('\n');

const driver = `
let SONG, TH, BEAT, EIGHTH, S16, BAR, SPEED, HANG, MODE='inf', sim=null, inMenu=false, run={coins:0};
let nodes=[], hazards=[], nid=0, bar=0, songBar0=0, runBar=0, t=0, lastGlassT=-99;
function bake(song, map, seed, level, bars){
  SONG=song; TH=THEMES[MAPINFO[map].th]; MODE=song.tut?'ep':'inf'; LEVEL=level;
  BEAT=60/SONG.bpm;EIGHTH=BEAT/2;S16=BEAT/4;BAR=BEAT*4;SPEED=TH.speed*SONG.bpm/TH.bpm;HANG=clamp(BEAT,0.45,0.6);
  nodes=[];hazards=[];ghosts=[];nid=0;songBar0=0;runBar=SONG.intro;bar=runBar;laneN=0;hopN=0;laneT0=runBar*BAR;lastGlassT=-99;
  grand=mkRng(seed);
  const end=(bars===Infinity?SONG.len:bars)*BAR;
  for(t=0;t<end-AHEAD-BAR;t+=0.05)spawn();
  return {nodes,hazards,ghosts,BAR,BEAT,EIGHTH,SPEED,HANG};
}
return {bake, loopSong, tutSong, THEMES, KINDS, LEVELS};`;

const api = new Function('document', 'localStorage', src + driver)({ getElementById: () => null }, null);

function layerOf(song, map, n) {
  const b = Math.floor(n.step / 8), e = n.step - b * 8, B = song.bar(b);
  const j = B ? B.mel.findIndex(m => m[0] === e) : 0;
  return Math.max(0, j) % 2;
}
const kindsOf = th => Object.fromEntries(th.kindList.map(k => [k, { len: api.KINDS[k].len, rel: api.KINDS[k].rel }]));
function course(map, song, r, extra) {
  const th = api.THEMES[map];
  const len = song.len === Infinity ? extra.bars : song.len;
  return {
    map, ep: -1, name: song.name, bpm: song.bpm, swing: song.swing || 0, lead: th.V0.lead, V: th.V0,
    bar: r.BAR, beat: r.BEAT, eighth: r.EIGHTH, speed: r.SPEED, hang: r.HANG, intro: song.intro, len,
    gate: song.len === Infinity ? 1e9 : +((len - 2) * r.BAR).toFixed(4),
    diff: { ...(api.LEVELS[extra.level] || api.LEVELS.normal), L: 0 }, rescueK: 1.6,
    lanes: [-1.6, 0, 1.6], rows: [-1.7, 0, 1.7], home: 1, roadY: -2.3, kinds: kindsOf(th),
    loop: song.len === Infinity ? { from: +(song.intro * r.BAR).toFixed(4), bars: 8 } : null,
    // the lessons: what each bar says, and the notes that wait for their move
    say: song.tut ? song.bars.map((b, k) => b.say ? { t: +(k * r.BAR).toFixed(4), say: b.say } : null).filter(Boolean) : [],
    // layer: which of the two lead recordings plays the note (every other note of its bar, as render_audio.mjs splits them)
    notes: r.nodes.map(n => ({ t: +n.time.toFixed(4), col: n.col, row: n.row, note: n.note, len: n.len, dir: n.dir, mv: n.mv, pu: n.pu || '', wait: n.wait || '', layer: layerOf(song, map, n) })),
    hazards: r.hazards.map(h => ({ t: +h.time.toFixed(4), col: h.col, row: h.row, kind: h.kind, over: !!h.over, under: !!h.under })),
    ghosts: r.ghosts.map(g => ({ t: +g.time.toFixed(4), note: g.note, len: g.len })),
  };
}

fs.mkdirSync(outDir, { recursive: true });
for (const map of ['old', 'sunset', 'rain']) {
  const s = api.tutSong(map);
  const c = course(map, s, api.bake(s, map, 7, 'normal', Infinity), { level: 'normal' });
  fs.writeFileSync(`${outDir}/school_${map}.json`, JSON.stringify(c));
  console.log('school', map, c.notes.length, 'notes', c.hazards.length, 'hazards', c.notes.filter(n => n.wait).length, 'lessons');
  for (const level of ['normal', 'hard']) for (let k = 0; k < 6; k++) {
    const ls = api.loopSong(map), bars = 2 + 8 * 40;
    const seed = (20261021 + k * 7919 + (level === 'hard' ? 104729 : 0)) >>> 0;
    const ec = course(map, ls, api.bake(ls, map, seed, level, bars), { level, bars });
    fs.writeFileSync(`${outDir}/endless_${map}_${level}_${k}.json`, JSON.stringify(ec));
    if (k === 0) console.log('endless', map, level, ec.notes.length, 'notes', ec.hazards.length, 'hazards over', bars, 'bars');
  }
}
