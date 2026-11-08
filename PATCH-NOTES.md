# Patch notes

What changed in `main`, newest first. Every update to `main` adds an entry here. The game's own change log
(the ✦ pill on the main menu, `godot/data/changelog.json`) has the same versions in shorter words.

## v31 New Pilots · 8 Nov 2026

Every pilot is new, the game opens on the main menu, and the Future map's buildings are clean. The rules, the music
and the levels are unchanged.

- **All the pilots were sculpted again.** They used to be plain capsules joined at the joints. Each is now one
  smooth, detailed body that bends at the joints, with its own suit, gloves, boots and jetpack: the Astronaut (soft
  white suit, gold visor, life-support pack), the Racer (red and white suit, long aero helmet), the Robot (steel panels on
  ball joints, one big thruster), the Fox Pilot (bomber jacket, goggles, a bushy tail, a copper rocket), the Cyber Ninja
  (layered black armour, lines of cyan light) and the Mech Suit (crimson armour, boot thrusters). They show on the rooftop,
  in the garage, on the jetpack and in the rescue.
- **New pilot: the Test Pilot,** free in the garage: orange flight suit, black harness, white helmet, twin rocket tanks.
- **Arms out when flying.** The pilots' arms used to bend inward through the body; they now hold them out for balance.
- **The game opens on the main menu.** The studio intro (the door and the TV) is gone.
- **No more points flying from the car.** The score at the top still counts up.
- **Future map: the black specks are gone.** A rounding error gave every pixel of the lit walls and signs its own random
  pattern. The walls are clean, the signs read properly (HOTEL, TAXI, 2075), and their glow is balanced to match.

## v30 Rooftops & Banners · 8 Nov 2026

A new main menu and garage, street banners in place of the floating roadblocks, and a few fixes from playing.
The rules, the music and the levels' rings are unchanged.

- **The main menu is a rooftop.** Behind the menus you now stand on a roof high over the chosen era's open city,
  in its light: London 1890 at gaslight dusk with Big Ben down the street, Rio at golden hour with Sugarloaf over
  the sea, Berlin 2075 at neon night with the TV tower. Your car is parked on the landing pad; the pilot has
  climbed out and leans on the parapet with a drink (tea in London, a coconut in Rio, a glowing can in Berlin),
  taking a sip now and then. Traffic streams along the street below, and the city's own streets and buildings
  run out on every side, so it looks whole on a wide screen too. Choosing another era fades over to its roof.
  It is built from the levels' own art (street sections, Reha's city detail and light, the levels' materials and
  lamps) plus a few Poly Haven props (CC0).
- **The garage is on the same roof.** The camera glides in to the car; changing cars eases in to the new one. On
  the pilots' tab the pilot stands up from the parapet and turns round to face you. IN-GAME VIEW still shows the
  old turn round the car in the street; the street now carries on behind the car as far as ahead, and a second
  landmark stands behind it: the Monument in London, Dois Irmãos and Pedra da Gávea in Rio, the Victory Column
  over the Brandenburg Gate in Berlin.
- **Street banners instead of floating roadblocks.** A roadblock is now a banner on a cable strung between two
  masts at the kerbs, hanging over its lane at skyway height: fly under it on the road or hop over it, as before.
  Each era has its own design (a gilt-framed music-hall bill in the Past, a samba-school flag in the Present, an
  LED mesh panel in the Future) and each city its own words and colours, three per city. Fly into one and the
  cable snaps, the banner wraps round your car, and the pilot is thrown out to the jetpack.
- **NEXT goes to the next open city** after an episode (London, Rio, Berlin, round again), and after Flight
  School START goes to the era's open city instead of a locked one.
- **A street section behind the start line**, so the car no longer starts beside an empty plot.
- **Rio's hills**: their edges now meet the ground and the sea instead of floating, at twice the detail, with
  real granite on the bare rock; Christ the Redeemer stands on Corcovado's summit.
- **New in the project:** banner fonts (Abril Fatface, Playfair Display, Lobster, Bungee; SIL Open Font
  License), the banner artwork (`data/banners.json`, drawn by `tools/editor/build_banners.gd`), and checks
  (`tests/next_check`, `replay_check`, `hit_shot`, `garage_shot`).

## v29 Brass & Swing · 2–7 Nov 2026

Two more cities open, London 1890 with acoustic jazz and Rio de Janeiro with a real samba band, and Berlin 2075 gets
new sounds. All picked from several rounds of tries. In London and Berlin the notes and rings are the same as
before; Rio has a new tune, so its rings were laid out again to follow it. Five new things to play with, each
built and reviewed over three rounds and then picked: Flow music, the rescue plane, the edge bounce, surer swipes
and haptic beats. And the three open cities look much better: new light and sky, richer streets, new cars and
note rings, picked from two rounds of graphics tries.

- **New light and sky.** London 1890 is a warm gaslight dusk: a low golden sun rakes the facades, Big Ben stands
  against a sunset band, the windows are lit and the gas lamps throw pools of light on the cobbles. Rio is a real
  golden hour instead of the pink haze: violet-blue above, gold at the horizon, the sun low beside Sugarloaf, palms
  and hills in silhouette. Berlin 2075 is a blue-violet neon night with wide glow and a wet road that mirrors the
  neon further down the street while staying calm near the car. The garage shows your car under a spotlight.
- **Richer streets.** London: wet cobbles with puddles and tram rails, lit shop windows, gilt signs on iron
  brackets, fruit barrows, post boxes, flower baskets on the lamps, houses of different colours and heights, and
  St Paul's, spires and chimneys behind Big Ben. Rio: Copacabana's black-and-white wave pavement, the beach with
  surf alongside, parasols, a lifeguard post, proper palms, curved promenade lamps, striped awnings, café tables,
  lit signs, and Sugarloaf and Corcovado in the distance. Berlin: towers lit floor by floor, signs with real words,
  skybridges, a maglev line, holograms and the TV tower against the night sky. Baked ahead of time
  (`scripts/gfx_world_bake.gd`), so a run starts as fast as before.
- **New cars and note rings.** All five cars are real flying machines now, each with its own look (a red racer, a
  teal pod with a glowing halo, a black 80s wedge with neon edges, a police flyer with flashing lights, an indigo
  flying wing), with glowing engines and an underglow. The rings are glowing hoops in their height colour (blue
  low, gold middle, pink high) with a clear arrow; a thin ring closes in for the timing, a played note bursts
  white, a missed one breaks up grey. Short engine trails, catch sparkles, a crash fireball, gold streaks in
  Overdrive, a longer jetpack flame, and traffic that fits each era (1930s cars, double-deckers and biplanes in
  London; taxis, trucks, buses and hover-cabs in Rio; hovering taxis, freighters, buses and cargo drones in
  Berlin). A phone does no more work than before; most frames draw fewer objects.

- **Flow music.** The longer you keep playing notes without missing, the grander the band gets: eight steps, each on
  the first beat of a bar after a short drum fill, ending with an "anthem" where the tune is doubled an octave up.
  New parts per city: London bigger drums, a violin counter-melody and a brass section (anthem on violins); Rio
  extra surdos, repiniques, horn riffs and violins with the crowd (anthem on trumpet); Berlin a wide synth pad, big
  drums and bells (anthem on a soft lead). A miss makes the music lose its spark on the next beat (duller, a little
  quieter, the newest part drops out), and it comes back as you catch notes again. Seven marks under the Flow bar
  show the step: gold for the grand ones, flashing red when one is lost. The songs themselves are unchanged; the
  new parts are extra layers (`tools/music/flow_layers.py`).
- **The rescue plane.** After a crash the car comes back sooner: 15 played notes in London and Rio (was 23 and 25),
  17 in Berlin (was 34), and a miss costs only a quarter of a note. When the meter is full, your own car rises up
  behind you with a friend (the Fox Pilot) at the wheel, who grabs your hand and pulls you into the seat on the
  beat, then hops out on a jetpack, waves and flies off. You keep steering, and nothing can hit you meanwhile.
- **Edge bounce.** Swipe past the far-left or far-right lane and the car squishes against a soft wall at the road's
  edge and springs back with a wobble, a few gold stars, a shimmer on the edge and a "boing" (higher with each
  bump in a row); on the jetpack the pilot twirls. Only the drawing moves: catches and crashes are unchanged.
- **Surer swipes on phones.** Each finger has its own swipe, so a resting thumb no longer sends the car the wrong way;
  after a left/right swipe you can keep steering without lifting your finger; and a swipe made a moment before the
  car is back after a crash is no longer lost. Ordinary flicks move exactly as before (`tests/swipe_check.tscn`).
- **Haptic beats.** The phone taps softly on every note you play, knocks on a miss, and buzzes for the big moments
  (crash, new car, Overdrive, shield save, power-up, the band stepping up, the finish), with the web game's own
  patterns. Follows the Haptics setting.
- **An iPhone test build.** On every update to `main`, GitHub's Mac machines build the game as an iPhone app and
  attach it to the [iphone-test release](https://github.com/reha-abbasi/tempo-drift/releases/tag/iphone-test)
  (`.github/workflows/iphone.yml`), so the haptics and touch controls can be tried on a real phone. The game now has
  its icon (the sunset road and coin of the iPhone web version).
- **No more melody clicks.** Catching a note right after a miss made a small click (the melody switched back on in
  one jump); each melody line now plays on its own player and glides in and out.

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
