// Bakes an episode's course (rings + traffic) with the web game's own generator and autopilot check, but with a new
// melody in place of the generated one (the course only; the music is rendered separately, e.g. tools/music/rio_render.py)
//   node tools/bake/bake_tune.mjs <game.html> <map> <ep> <bars.json> <out.json>    (bars.json: tools/music/tune_bars.py)
import { chromium } from '../node_modules/playwright/index.mjs';
import fs from 'fs';
const [html, map, epArg, barsPath, outPath] = process.argv.slice(2);
const ep = +epArg, mel = JSON.parse(fs.readFileSync(barsPath, 'utf8'));
const HOOK = String.raw`
window.__tdBakeTune=(map,ep,mel)=>{
  LEVEL='normal';MODE='ep';EP=ep;inMenu=false;over=false;paused=false;audioOn=false;userAt=-99;lastJudged=-9;
  sim={stats:{glass:0,shatters:0,perfects:0,power:0,coins:0,hits:0,misses:0,skipped:0,crashes:0,nearMiss:0,swipes:0,swipesNeeded:0,tooFast:0,mistakes:0,hops:0,overs:0,offRuns:0,air:0,airMax:0,missLog:[]},result:null,prevCoin:null,bot:null};
  const S=buildSong(map,ep);
  for(let k=0;k<S.bars.length;k++)S.bars[k].mel=(mel[k]||[]).map(m=>m.slice());
  const ps=S.bars.flatMap(b=>b.mel.filter(m=>!m[4]).map(m=>m[1]));
  S.row=rowCut(ps,S.diff.hi,S.diff.lo);S.lane=laneMap(ps,S.diff.spread);
  applyTheme(map,false);setSong(S);resetRun();shields=999;
  const T0=songBar0*BAR,N=new Map(),H=new Map(),end=gateT+BAR+0.5;
  for(let i=0;i<400*60&&t<end&&!over;i++){update(1/60);
    for(const n of nodes)if(!N.has(n.id))N.set(n.id,{t:+(n.time-T0).toFixed(4),col:n.col,row:n.row,note:n.note,len:n.len,dir:n.dir||'',mv:!!n.mv,pu:n.pu||''});
    for(const h of hazards)if(!H.has(h.id))H.set(h.id,{t:+(h.time-T0).toFixed(4),col:h.col,row:h.row,kind:h.kind,over:!!h.over,under:!!h.under});}
  const bars=[];for(let k=0;k<S.len;k++){const B=S.bar(k);bars.push({sec:B.sec,root:B.chord[0],iv:B.chord[1],lvl:B.lvl||0});}
  const kinds={};for(const k of TH.kindList)kinds[k]={len:KINDS[k].len,rel:KINDS[k].rel};
  const res={map,ep,name:S.name,bpm:S.bpm,swing:S.swing,lead:S.V.lead,bar:BAR,beat:BEAT,eighth:EIGHTH,speed:SPEED,hang:HANG,
    intro:S.intro,len:S.len,gate:+(gateT-T0).toFixed(4),diff:{react:S.diff.react,swipe:S.diff.swipe,L:S.diff.L},rescueK:1.6-0.1*ep,
    lanes:LX,rows:LY,home:HOME,roadY:ROAD_Y,kinds,bars,
    notes:[...N.values()].sort((a,b)=>a.t-b.t),hazards:[...H.values()].sort((a,b)=>a.t-b.t),
    ghosts:ghosts.map(g=>({t:+(g.time-T0).toFixed(4),note:g.note,len:g.len})).sort((a,b)=>a.t-b.t),ended:t>=gateT+BAR,crashes:sim.stats.crashes,stats:sim.stats};
  sim=null;openMenu();return res;};
`;
const src = fs.readFileSync(html, 'utf8');
const page = outPath + '.page.html';
fs.writeFileSync(page, src.replace('window.__lrDebug={', HOOK + 'window.__lrDebug={'));
const b = await chromium.launch({ executablePath: process.env.HOME + '/.cache/ms-playwright/chromium_headless_shell-1248/chrome-headless-shell-linux64/chrome-headless-shell', args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const p = await b.newPage({ viewport: { width: 400, height: 700 } });
const errs = []; p.on('pageerror', e => errs.push(e.message));
await p.addInitScript(() => { try { localStorage.setItem('td-nointro', '1'); } catch (e) {} });
await p.goto('file://' + page); await p.waitForTimeout(5000);
await p.evaluate(() => window.__lrDebug.freeze && window.__lrDebug.freeze());
const course = await p.evaluate(([m, e, mm]) => window.__tdBakeTune(m, e, mm), [map, ep, mel]);
fs.unlinkSync(page);
const st = course.stats; delete course.stats;
fs.writeFileSync(outPath, JSON.stringify(course));
console.log(course.name + ': ' + course.notes.length + ' rings, ' + course.hazards.length + ' hazards, ' + course.ghosts.length + ' band notes, ended ' + course.ended + ', crashes ' + course.crashes);
console.log('stats', JSON.stringify(st));
console.log('errors:', errs);
await b.close();
