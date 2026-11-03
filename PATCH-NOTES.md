# Patch notes

What changed in `main`, newest first. Every update to `main` adds an entry here. The game's own change log
(the ✦ pill on the main menu, `godot/data/changelog.json`) has the same versions in shorter words.

## v29 Brass & Swing · 2–3 Nov 2026

Two more cities open, London 1890 with acoustic jazz and Rio de Janeiro with a real samba band, and Berlin 2075 gets
new sounds. All picked from several rounds of tries. In London and Berlin the notes and rings are the same as
before; Rio has a new tune, so its rings were laid out again to follow it.

- **London 1890 is open** (the Past's first city), next to Berlin. Its music is a music-hall pub band played by real
  recorded instruments: the melody on a trumpet, with an old upright pub piano, trombone, tuba, a soft violin section,
  a strumstick and a harmonica in place of banjo and accordion, a rope-tension snare kit and tambourine, all in one
  warm hall. Each player is a few milliseconds off the beat, like real musicians; the melody stays on the rings and sits
  a little under the band. No techno.
- **Rio de Janeiro is open** (the Present's second city). Its band is real musicians: a samba-school percussion
  section (surdos, snares, tamborims, shakers) from recorded loops, with a carnival street crowd underneath. The
  melody is a new marchinha, a bouncy carnival march written for the game (original, in the spirit of the old Rio
  carnival songs), played by a tenor sax and a nylon-string classical guitar together, the sax tongued short like a
  carnival band. The guitar is a real Spanish classical guitar recorded note by note at three strengths.
- **Rio's rings follow the new tune:** 107 rings (one per melody note) and 23 vehicles, laid out by the web game's
  own rules; a perfect flight plays every note and never crashes.
- **Berlin's melody is an 80s synth brass** (Surge XT's "Synth Brass 1"), with its brightest overtones softened so
  it doesn't sound harsh. It replaces the breathy flute.
- **Warmer Berlin band:** the bass ("Deep End"), the pads ("MKS-70 Warm Pad") and the arpeggio ("Nice Pluck 1") are
  now played by Surge XT, a free synthesizer, instead of the game's own synths. The drums are unchanged.
- **Smooth bass that you can hear on a phone.** Phone speakers play almost nothing under ~150 Hz, so the deep bass
  alone sounded strained there. The lowest sub is now a little lower, and a soft octave above the bass line is added
  (kept under 450 Hz, so it doesn't buzz). In Berlin's intro, where only drums and bass play, the bass starts dark
  and opens up as the band comes in, so it never sounds bare or clipped.
- **Points instead of timing words.** Catching a ring no longer shows OK / GOOD / EXCELLENT. The points you got
  ("+300") pop up at the car, swoop along a curve into the score at the top and vanish; the score counts them in,
  swells and flashes their colour (gold for a perfect catch, cyan for good, pale for OK), with a little ✦ burst.
- **The main menu has its own music**, "Time Traveller": a new tune written for Tempo Drift, on a string section,
  a rippling upright piano, plucked bass and brushes, the tune first on violins and then on a soft trumpet (real
  recordings). A seamless 40-second loop, a little quieter than the episodes. The menus no longer reuse Berlin's song.
- **Unlocking:** the open cities are listed in `OPEN` in `godot/scripts/save.gd` (now `rain: [5]`, `old: [0]`, `sunset: [1]`).
- **Music tools:** `jazz.py` builds the Past's acoustic bands; `sampler.py` plays the free CC0 Versilian sample
  libraries (VCSL, VSCO 2 CE), the rest through FluidSynth; `menu.py` makes the menu theme (four arrangements); `listen.py` draws a song's spectrogram and flags clicks,
  clipping and harsh spots;
  `surge_render.py` plays parts on Surge XT sounds, `melodies.py` writes new melodies on a city's chords (for later
  tries), `audition.py` scores Surge sounds for harshness; `rio_real.py` builds Rio on recorded loops, `carnival.py` holds
  its tunes, `expr.py` plays a melody with phrasing; `tools/bake/bake_tune.mjs` lays out the rings for a new tune.
  See `godot/tools/music/README.md`.
- **The project is named "Tempo Drift v29 Brass & Swing".**

## v28 New Music · 1 Nov 2026

Murat's Godot version becomes `main`, with the first city of the new music.

- **Berlin 2075 is the only open city.** New melodic techno: a harder kick, deep rolling bass that pumps around it,
  wide pads, a plucked arpeggio, and the melody on a breathy flute, 6 dB above the band.
- **The other 23 cities stay on the map, locked.** Each opens when its new music is made
  (`TEST_MAP` / `TEST_EP` in `godot/scripts/save.gd`).
- **The menus play the new Berlin track.** The old menu theme and the intro jingle are gone.
- **All the old music is taken out** (the 23 other cities, Flight School, Endless): the music folder went from 276 MB
  to 11 MB.
- **The music tools are in `godot/tools/music/`.** Every sound is synthesized, the layers are mastered together, and
  the melody stands out most in the first city and blends in a little more in each city after it.
- **No Next button after Berlin**, since nothing else is open yet.
- **Only the current version is named.** The front page shows v28 at the top; the old mentions of the web game's
  version number are gone from the front page, the Godot guide and the code.
- **The ✦ version pill on the main menu reads the newest change-log entry**, so it always shows the current version.
- **The project is named with its version: "Tempo Drift v28 New Music"** (in Godot's project list and the window
  title). Saves stay in one place across versions.
- **`main` is now Murat's Godot version** (branch `murat-godot-remake`). Reha's earlier Godot version (`godot/game/`)
  and the Lane Runner draft leave `main`; both are still in the history.

## Earlier versions

From the game's change log.

### v27 Godot · 1 Nov 2026

- Rebuilt in Godot with real 3D scenes
- Cities, landmarks and cars you can open in the editor
- Same rules, music and menus as v26

### v26 Note Mode · 26 Oct 2026

- No coins: every note is a ring
- Swipe into each ring
- EXCELLENT, GOOD, OK timing
- Closing cue ring
- No tapping or glass
- New Flight School

### v25.1 Map Fix · 26 Oct 2026

- Cities sit on their real spots
- Smaller map markers
- Same world map for every era

### v25 Pilot Shop · 26 Oct 2026

- Astronaut pilot by default
- 5 pilots to buy
- Each pilot has its own music
- Rescue 25% easier, arrives on the beat
- Music stays on the beat
- Pulse and glass play in key

### v24 Eight Cities · 25 Oct 2026

- Two lives: car, then jetpack
- 3 new, harder cities per era
- More swipes every episode
- PLAY opens the map
- Intro music
- Dev mode on at start

### v23 Bail Out · 25 Oct 2026

- Crash: car explodes, pilot ejects
- Jetpack as a second life
- Rescue meter wins the car back
- Lives replace Sync

### v22 More Notes · 25 Oct 2026

- Busier melodies
- More coins and lane changes
- No guide line

### v21.2 Lane Ladder · 25 Oct 2026

- Lane changes rise each episode

### v21.1 Gold Rush · 25 Oct 2026

- Coins collapse into the counter
- Sparkle trail and burst

### v21 Magnet Catch · 25 Oct 2026

- Coins pulled to the car
- Coin counter
- Sparkles on catch

### v20 The Band · 24 Oct 2026

- Band builds with your Flow
- Overdrive ×8
- Grades D to S
- 3 stars per episode

### v18 Play Test · 24 Oct 2026

- Audio sync setting
- Revive for coins
- Car perks
- Daily gift card
- Bigger buttons

### v17.2 Change Log · 23 Oct 2026

- This change log

### v17.1 One Lane at a Time · 23 Oct 2026

- One swipe, one lane

### v17 World Map · 23 Oct 2026

- World map of cities
- Glass shatters
- Glass crash costs a life
- Upright up/down signs
- Coins colored by height

### v16 Tempo Drift · 23 Oct 2026

- New name
- Coins in glass
- Calmer coins
- iPhone version

### v15 Title Screen · 23 Oct 2026

- New main menu
- Settings panel
- Taps never change lane
- Auto quality on slow phones

### v14.1 One-Note Hops · 22 Oct 2026

- Hops last one note

### v14 Golden Hour · 22 Oct 2026

- Realistic look
- Past, Present, Future
- Three lanes
- Tap to break glass
- Power-ups, missions, daily gift

### v13 Slow-Motion School · 22 Oct 2026

- Flight School slows down
- Art-style demos

### v12 Five Lanes · 22 Oct 2026

- Five lanes
- Haptics
- Studio intro

### v11 Dev Mode · 22 Oct 2026

- Dev mode switch

### v10 Around the World · 22 Oct 2026

- Four eras
- Real cities
- Swing band

### v9 Garage · 21 Oct 2026

- Smaller car
- Five cars to buy
- Flight School

### v8 Five Stars · 21 Oct 2026

- A backdrop per episode
- 5-star system
- Menu music

### v7 Episodes · 21 Oct 2026

- Three heights
- Roadblocks
- 20 songs, Infinite mode
- High scores

### v6.1 In Sync · 21 Oct 2026

- Game follows the music clock

### v6 Feedback Round · 21 Oct 2026

- Pause and resume
- Crash tumble
- Techno style

### v5 Sunset City · 21 Oct 2026

- Sunset City
- Moving traffic
- Call-outs

### v4 Clear Path · 21 Oct 2026

- Path line
- Sound toggle
- iPhone silent-switch fix

### v3 Two Styles · 21 Oct 2026

- Cyberpunk and Arcade
- No camera shake
- Shields

### v2 Rain Canyon · 21 Oct 2026

- Flying-car rhythm game
- Coins play notes

### v1 First Draft · 20 Oct 2026

- Godot runner draft
