// Bakes an episode of the web game (web/game.html) for the Godot version: the course (every note ring and every
// vehicle, exactly as the web game lays them out) and the soundtrack as layers, rendered by the web game's own synth.
// usage: node godot/tools/bake.mjs old 0 [--synth]       (map, episode index)
import { chromium } from 'playwright';
import fs from 'fs';
import path from 'path';
import { execFileSync } from 'child_process';

const [map = 'old', epArg = '0'] = process.argv.slice(2).filter(a => !a.startsWith('--'));
const ep = +epArg;
const root = path.resolve(path.dirname(new URL(import.meta.url).pathname), '../..');
const outData = path.join(root, 'godot/game/data');
const outAudio = path.join(root, `godot/game/audio/${map}_${ep}`);
fs.mkdirSync(outData, { recursive: true });
fs.mkdirSync(outAudio, { recursive: true });

// the bake hook runs inside the game's module, where it can reach the song builder, the course and the synth
const HOOK = String.raw`
window.__tdBake=async(map,ep,which)=>{
  if(which==='course'){
    LEVEL='normal';MODE='ep';EP=ep;inMenu=false;over=false;paused=false;audioOn=false;userAt=-99;lastJudged=-9;
    sim={stats:{glass:0,shatters:0,perfects:0,power:0,coins:0,hits:0,misses:0,skipped:0,crashes:0,nearMiss:0,swipes:0,swipesNeeded:0,tooFast:0,mistakes:0,hops:0,overs:0,offRuns:0,air:0,airMax:0,missLog:[]},result:null,prevCoin:null,bot:null};
    applyTheme(map,false);setSong(buildSong(map,ep));resetRun();shields=999;
    const T0=songBar0*BAR,N=new Map(),H=new Map(),end=gateT+BAR+0.5;
    for(let i=0;i<400*60&&t<end&&!over;i++){update(1/60);
      for(const n of nodes)if(!N.has(n.id))N.set(n.id,{t:+(n.time-T0).toFixed(4),col:n.col,row:n.row,note:n.note,len:n.len,dir:n.dir||'',mv:!!n.mv,pu:n.pu||''});
      for(const h of hazards)if(!H.has(h.id))H.set(h.id,{t:+(h.time-T0).toFixed(4),col:h.col,row:h.row,kind:h.kind,over:!!h.over,under:!!h.under});}
    const S=SONG,bars=[];for(let k=0;k<S.len;k++){const B=S.bar(k);bars.push({sec:B.sec,root:B.chord[0],iv:B.chord[1],lvl:B.lvl||0});}
    const kinds={};for(const k of TH.kindList)kinds[k]={len:KINDS[k].len,rel:KINDS[k].rel};
    const res={map,ep,name:S.name,bpm:S.bpm,swing:S.swing,lead:S.V.lead,V:S.V,scale:EPISODES[map][ep].scale,bar:BAR,beat:BEAT,eighth:EIGHTH,speed:SPEED,hang:HANG,
      intro:S.intro,len:S.len,gate:+(gateT-T0).toFixed(4),diff:{react:S.diff.react,swipe:S.diff.swipe,L:S.diff.L},rescueK:1.6-0.1*ep,
      lanes:LX,rows:LY,home:HOME,roadY:ROAD_Y,kinds,bars,
      notes:[...N.values()].sort((a,b)=>a.t-b.t),hazards:[...H.values()].sort((a,b)=>a.t-b.t),
      ghosts:ghosts.map(g=>({t:+(g.time-T0).toFixed(4),note:g.note,len:g.len})).sort((a,b)=>a.t-b.t),ended:t>=gateT+BAR,crashes:sim.stats.crashes};
    sim=null;openMenu();return res;}
  // one layer of the soundtrack, rendered offline from time 0 = the first intro bar
  const S=buildSong(map,ep),keep={...A},kTH=TH,kS=SONG,sr=44100;TH=THEMES[S.th];SONG=S;timing();
  const dur=S.len*BAR+3,c=new OfflineAudioContext(2,Math.ceil(sr*dur),sr);buildGraph(c);A.master.gain.value=0.8;A.mel.gain.value=1;
  form=2;odT=0;inMenu=false;
  const notes=which.course?which.course:null;
  const kind=which.kind;
  for(let n=0;n<S.len*16;n++){const st=n%16,sb=Math.floor(n/16),B=S.bar(sb),at=n*S16;if(!B)continue;
    if(kind==='core'||kind==='full'){
      if(B.sec==='E'){if(st===0){const[r,tri]=B.chord;kick(at,1.1);nz(at,{type:'highpass',freq:5000,dur:1.8,g:0.2,verb:0.6});
        tri.forEach(iv=>tone(at,midi(r+12+iv),{dur:BAR*1.2,g:0.045,cut:1800,attack:0.01,detune:10}));tone(at,midi(r-12),{type:'sine',dur:BAR,g:0.3,cut:400});}continue;}
      TH.backing(st,at,S16,B,S.V,B.sec==='I'?B.lvl:(kind==='core'?2:0),sb);continue;}
    if(B.sec==='I'||B.sec==='E')continue;const[r,iv]=B.chord;
    if(kind==='arp'&&st%2===0)tone(at,midi(r+24+iv[(st/2)%iv.length]+(st>=8?12:0)),{type:'triangle',dur:S16*1.8,g:0.03,cut:5000,attack:0.003});
    if(kind==='perc'){if(st===4||st===12)nz(at,{type:'bandpass',freq:1400,q:1.2,dur:0.12,g:0.16,verb:0.3});nz(at,{type:'highpass',freq:7000,dur:0.035,g:st%2?0.025:0.04});}
    if(kind==='od'){if(st%4===0)kick(at,0.75);if(st===0)nz(at,{type:'highpass',freq:5000,dur:1.4,g:0.12,verb:0.6});}
    if(kind==='jet'){if(st%4===0)kick(at,0.28,A.master);if(st===0)nz(at,{type:'bandpass',freq:700+Math.random()*500,q:0.7,dur:BAR*0.9,g:0.045,out:A.master});}}
  if(kind==='ghost'||kind==='melA'||kind==='melB'){
    const list=kind==='ghost'?which.ghosts:which.notes.filter((n,i)=>i%2===(kind==='melA'?0:1));
    for(const n of list)playLead(n.t,n.note,n.len);}
  const buf=await c.startRendering();Object.assign(A,keep);TH=kTH;SONG=kS;timing();
  // 16-bit WAV, base64
  const L=buf.getChannelData(0),R=buf.getChannelData(1),n=L.length,b=new ArrayBuffer(44+n*4),dv=new DataView(b),w=(o,s)=>{for(let i=0;i<s.length;i++)dv.setUint8(o+i,s.charCodeAt(i));};
  w(0,'RIFF');dv.setUint32(4,36+n*4,true);w(8,'WAVE');w(12,'fmt ');dv.setUint32(16,16,true);dv.setUint16(20,1,true);dv.setUint16(22,2,true);dv.setUint32(24,sr,true);
  dv.setUint32(28,sr*4,true);dv.setUint16(32,4,true);dv.setUint16(34,16,true);w(36,'data');dv.setUint32(40,n*4,true);
  let peak=0;for(let i=0;i<n;i++){const a=Math.max(-1,Math.min(1,L[i])),z=Math.max(-1,Math.min(1,R[i]));peak=Math.max(peak,Math.abs(a),Math.abs(z));dv.setInt16(44+i*4,a*32767,true);dv.setInt16(46+i*4,z*32767,true);}
  const u=new Uint8Array(b);let s='';for(let i=0;i<u.length;i+=0x8000)s+=String.fromCharCode.apply(null,u.subarray(i,i+0x8000));
  return{wav:btoa(s),peak};};
`;

const src = fs.readFileSync(path.join(root, 'web/game.html'), 'utf8');
if (!src.includes('window.__lrDebug={')) throw new Error('hook point not found');
const page = path.join(root, 'godot/tools/.bake.html');
fs.writeFileSync(page, src.replace('window.__lrDebug={', HOOK + 'window.__lrDebug={'));

const b = await chromium.launch({ executablePath: process.env.HOME + '/.cache/ms-playwright/chromium_headless_shell-1248/chrome-headless-shell-linux64/chrome-headless-shell', args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const p = await b.newPage({ viewport: { width: 400, height: 700 } });
const errs = []; p.on('pageerror', e => errs.push(e.message));
await p.addInitScript(() => { try { localStorage.setItem('td-nointro', '1'); } catch (e) {} });
await p.goto('file://' + page); await p.waitForTimeout(5000);
await p.evaluate(() => window.__lrDebug.freeze());
const course = await p.evaluate(([m, e]) => window.__tdBake(m, e, 'course'), [map, ep]);
if (!course.ended || course.crashes) throw new Error('course bake did not reach the end');
fs.writeFileSync(path.join(outData, `${map}_${ep}.json`), JSON.stringify(course));
console.log(`${course.name}: ${course.notes.length} notes, ${course.hazards.length} hazards, ${course.ghosts.length} band notes, ${course.len} bars`);
// (the Godot version renders its own soundtrack with real instruments, godot/tools/arrange.py; --synth also renders the
// web game's synth layers)
const synth = process.argv.includes('--synth');
for (const kind of synth ? ['core', 'full', 'arp', 'perc', 'od', 'jet', 'ghost', 'melA', 'melB'] : []) {
  const r = await p.evaluate(([m, e, k, c]) => window.__tdBake(m, e, { kind: k, notes: c.notes, ghosts: c.ghosts }), [map, ep, kind, { notes: course.notes, ghosts: course.ghosts }]);
  const wav = path.join(outAudio, kind + '.wav');
  fs.writeFileSync(wav, Buffer.from(r.wav, 'base64'));
  execFileSync('ffmpeg', ['-y', '-loglevel', 'error', '-i', wav, '-c:a', 'libvorbis', '-q:a', '6', path.join(outAudio, kind + '.ogg')]);
  fs.unlinkSync(wav);
  console.log(`  ${kind}.ogg peak ${r.peak.toFixed(2)}`);
}
fs.unlinkSync(page);
console.log('errors:', errs);
await b.close();
