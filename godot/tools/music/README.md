# Music tools

Make an episode's soundtrack from its course: the melody and chords in `data/<map>_<i>.json`, so the rings still land on
the notes. All the sounds are synthesized here (no samples): kick, claps and hats, basses, pads, plucks and leads,
then sidechain pumping, echo, reverb and mastering.

| File | What it does |
|---|---|
| `engine.py` | The sound engine: oscillators, filters, envelopes, drums, effects, sidechain, mastering, file export |
| `arr.py` | What every style shares: the course, chords, placing the melody, and how much the melody stands out |
| `techno.py` | The Future's techno, flavours `melodic` (in the game) and `warehouse` |
| `render.py` | Renders the layers the game plays, and a preview mp3 of a good run |

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
