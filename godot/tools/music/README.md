# Music tools

Make an episode's soundtrack from its course: the melody and chords in `data/<map>_<i>.json`, so the rings still land on
the notes. All the sounds are synthesized here (no samples): kick, claps and hats, basses, pads, plucks and the melody's flute,
then sidechain pumping, echo, reverb and mastering.

| File | What it does |
|---|---|
| `engine.py` | The sound engine: oscillators, filters, envelopes, drums, effects, sidechain, mastering, file export |
| `arr.py` | What every style shares: the course, chords, placing the melody, and how much the melody stands out |
| `techno.py` | The Future's techno, flavours `melodic` (in the game) and `warehouse` |
| `leads.py` | Melody instruments modelled on real ones: breathy flute (in the game), marimba, glass keys, plucked string, analog pluck |
| `render.py` | Renders the layers the game plays, and a preview mp3 of a good run |
| `jazz.py`, `jazz_render.py` | The Past's acoustic jazz bands (ragtime, music hall, dixieland, gypsy, noir trio, big band, pub, vibes, parlour, smoky sax) on recorded instruments; London uses `pub` with `--mel=-4` |
| `sampler.py` | Plays real recorded instruments from the free CC0 Versilian libraries (VCSL, VSCO 2 CE): nearest sample, velocity layers, rotating takes, human timing. London uses `pub_full` |
| `listen.py` | Draws a song's spectrogram and reports loudness, peaks, clicks, squashed and harsh stretches |
| `menu.py` | The main-menu theme, one tune in four arrangements (traveller, lofi, neon, eras) as seamless loops; the game uses `traveller` (`audio/menu/theme.ogg`) |
| `gm.py` | Plays a part on a General MIDI instrument through FluidSynth and the MuseScore General sample library |
| `surge_render.py` | Plays the bass, pads, arpeggio and melody on Surge XT sounds; `game KEY OUT --stems` writes the game's layers (Berlin uses `mel_tron`) |
| `melodies.py` | Writes new melodies on a city's own chords (hook, heroic, dark); the rings would move with them |
| `audition.py` | Scores Surge sounds on a short phrase: how much harsh 2–6 kHz, how noisy, how bright |
| `rio_real.py`, `rio_render.py` | Rio de Janeiro on loops recorded by real players (escola de samba, bossa, baião, bloco, ijexá, eletrônico); the game uses `escola` |
| `flow_layers.py` | Flow music's extra layers for London, Rio and Berlin (grander parts, fills, the octave-up anthem), mastered with each song's own gain so they add up in the game |
| `carnival.py` | Original Rio melodies in the shape of famous carnival, samba and bossa songs (marchinha in the game) |
| `expr.py` | The expressive melody player: phrasing, dynamics, vibrato; `samba` (tongued sax) and `guitar` (plucked) styles |
| `tune_bars.py` | Writes a `carnival.py` tune as bar melodies for `tools/bake/bake_tune.mjs`, which lays the rings out for it |
| `split_iowa.py` | Cuts the University of Iowa guitar recordings into one file per note |

The melody stands out most in the first city (London 1890) and blends further into the band in each city after that,
up to Las Vegas 2099: louder and drier ring notes early, more echo and busier parts later (`ease_for` in `arr.py`).

## Make a song

Needs Python 3.12 with `numpy scipy numba pedalboard soundfile`, and `ffmpeg`.

```bash
uv venv -p 3.12 .venv && uv pip install -p .venv/bin/python numpy scipy numba pedalboard soundfile
.venv/bin/python render.py ../../data/rain_5.json techno melodic out --stems
```

This writes `out/rain_5_melodic.mp3` (a preview) and `out/rain_5_melodic/<layer>.ogg`. Copy the `.ogg` files into
`audio/rain_5/`.

The layers are the ones `scripts/music.gd` plays: `core` (drums and bass), `full` (the whole band), `arp`, `perc`, `od`
(Overdrive), `jet` (the jetpack), `ghost` (the melody's in-between notes), `melA` and `melB` (the ring notes). They are
mastered together: one compressor and limiter curve, measured on the whole band, is applied to every layer, so they
still add up to the mastered song in the game.

## Surge XT sounds (Berlin, from v29)

Berlin's bass, pads, arpeggio and melody are played by [Surge XT](https://surge-synthesizer.github.io/) 1.3.4, a free,
open-source synthesizer, loaded as a VST3 plugin through `pedalboard`. `surge_render.py` expects the plugin at
`surge/root/usr/lib/vst3/Surge XT.vst3` and its factory sounds at `surge/root/usr/share/surge-xt/patches_factory`
(the Linux `.deb`, unpacked next to the script), and the course at `courses/rain_5.json` (a copy of
`../../data/rain_5.json`).

```bash
.venv/bin/python surge_render.py game out mel_tron --stems   # out/mel_tron/<layer>.ogg -> audio/rain_5/
```

Sounds that measure harsh (lots of 2–6 kHz, or noisy) were left out on purpose: they sounded artificial. Every mix
also goes through `phone_bass` in `techno.py`, so the bass line still comes through on a phone speaker.

## Acoustic jazz (London 1890, from v29)

The Past's bands are played by recorded instruments: `gm.py` writes each part as MIDI and renders it with
[FluidSynth](https://www.fluidsynth.org/) and the MuseScore General sample library (`MuseScore_General_Full.sf2`,
the jazz and brush drum kits included). Saxes and the muted trumpet play the melody an octave down, in their warm
range, and horns, reeds and the violin get the 2-5 kHz bite eased; the rings don't move.

```bash
.venv/bin/python jazz_render.py out pub --mel=-4 --stems    # course: courses/old_0.json; out/pub/<layer>.ogg -> audio/old_0/
```

## Real instruments (London 1890, from v29)

London's band is played by real recordings from two free, public-domain (CC0) sample libraries by Versilian Studios:
[VCSL](https://github.com/sgossner/VCSL) (upright piano, strumstick, harmonica, rope-tension snare, bass drum, hi-hat,
tambourine, cymbal, woodblock) and [VSCO 2 CE](https://github.com/sgossner/VSCO-2-CE) (tuba, trumpet, trombone,
violins, double bass). The samples are not in this repo (about 2 GB): clone only the folders listed in `sampler.py`
(`git clone --filter=blob:none --sparse`) into `samples/vcsl` and `samples/vsco` next to the tools, and set `LIB`.

```bash
.venv/bin/python jazz_render.py out pub_full --mel=-4 --stems    # out/pub_full/<layer>.ogg -> audio/old_0/
```

## Rio de Janeiro (from v29)

Rio's band is real musicians: CC0 loops from [Freesound](https://freesound.org) (samba-school percussion, a
carnival street recording, bossa-nova guitar), stretched to 120 BPM and shifted onto Rio's chords. Who recorded
each loop: `loops/meta.json`; `loops/fs_get.py ID...` downloads them into `loops/raw` (not in the repo).

The melody is a new marchinha (`carnival.py`, `marcha`) played by a tenor saxophone (VCSL, CC0) and a nylon-string
classical guitar together. The guitar is the [University of Iowa](https://theremin.music.uiowa.edu/MIS.html)
Raimundo 118 recorded note by note at three strengths (free to use without restrictions), cut with `split_iowa.py`
into `samples/iowa_guitar`; it plays an octave below the written notes, a guitarist's natural range.

The rings follow the new tune: the course is baked by the web game's own generator with the tune in place of its
melody, then the level scene is rebuilt.

```bash
.venv/bin/python tune_bars.py marcha marcha_bars.json
node ../bake/bake_tune.mjs ../../../web/game.html sunset 1 marcha_bars.json ../../data/sunset_1.json
LEVEL="sunset 1" godot --headless --path ../.. res://tools/editor/runner.tscn -- build_one_level
.venv/bin/python rio_render.py out escola --stems --melody=sax_samba+guitar_low --course=../../data/sunset_1.json
# out/escola/<layer>.ogg -> audio/sunset_1/
```
