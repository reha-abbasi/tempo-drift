class_name Catalog
extends RefCounted
## What the game is made of, as in the web game: the three eras and their 24 cities, the cars and pilots in the
## garage, and the missions. Names, prices and words are the web game's.

const MAPS := ["old", "sunset", "rain"]
const ERAS := {
	"old": {"name": "Past", "years": "1890–1955", "music": "swing", "color": Color("ff8a2a")},
	"sunset": {"name": "Present", "years": "today", "music": "pop", "color": Color("ff3f8f")},
	"rain": {"name": "Future", "years": "2049–2099", "music": "industrial", "color": Color("ff3fb4")},
}
## a later era opens with this many stars in the one before it
const ERA_NEED := 10
const STAR_PAY := 40
const REVIVE_COST := 200

const LEAD_NAMES := {
	"violin": "violin", "mandolin": "mandolin", "piano": "saloon piano", "oud": "oud", "accordion": "accordion",
	"clarinet": "clarinet", "trumpet": "trumpet", "pluck": "pluck", "bell": "bells", "square": "square lead", "acid": "acid",
	"brass": "synth brass", "glass": "glass bells", "koto": "koto", "sax": "night sax", "flute": "flute", "chip": "chiptune",
	"saw": "supersaw", "hero": "hero lead", "stab": "rave stab",
}

## each car plays a little differently: one small perk each, none of them needed to finish an episode
const CARS := {
	"arrow": {"name": "Arrow", "price": 0, "about": "Anti-gravity racer · twin engines and a rear wing", "perk": {}, "say": "No perk · the all-rounder"},
	"bubble": {"name": "Bubble", "price": 250, "about": "City pod · glass dome and a ring thruster", "perk": {"mag": 1.6}, "say": "Perk: magnets last 60% longer"},
	"retro": {"name": "Retro", "price": 600, "about": "80s supercar · neon edges and hover pads", "perk": {"reach": 0.78}, "say": "Perk: rings are easier to reach"},
	"spinner": {"name": "Spinner", "price": 1200, "about": "Police-style flyer · four turbo fans", "perk": {"startShield": true}, "say": "Perk: starts every run with a shield"},
	"manta": {"name": "Manta", "price": 2000, "about": "Flying wing · low, wide and fast", "perk": {"coin": 1.25}, "say": "Perk: +25% coins from every run"},
}
const PILOTS := {
	"astro": {"name": "Astronaut", "price": 0, "about": "Soft white suit, gold mirror visor, life-support pack", "lead": "bell"},
	"testpilot": {"name": "Test Pilot", "price": 0, "about": "Orange flight suit, black harness, twin rocket tanks", "lead": "saw"},
	"racer": {"name": "Racer", "price": 300, "about": "Red and white race suit, long aero helmet", "lead": "saw"},
	"robot": {"name": "Robot", "price": 600, "about": "Steel panels, LED eyes, one big thruster", "lead": "chip"},
	"fox": {"name": "Fox Pilot", "price": 900, "about": "Bomber jacket, goggles, a big bushy tail", "lead": "flute"},
	"ninja": {"name": "Cyber Ninja", "price": 1200, "about": "Layered black armour, lines of cyan light", "lead": "koto"},
	"mech": {"name": "Mech Suit", "price": 2000, "about": "Heavy crimson armour, chest light, boot thrusters", "lead": "hero"},
}

## missions ask for something on purpose (timing, clean runs, stars), not just for playing
const MISSION_POOL := [
	{"id": "nomiss", "goals": [1, 2, 4], "one": "Play every note in an episode", "many": "Play every note in %d episodes"},
	{"id": "clean", "goals": [1, 2, 4], "one": "Finish an episode without crashing", "many": "Finish %d episodes without crashing"},
	{"id": "combo", "goals": [30, 60, 100], "one": "Reach a %d-note combo", "many": "Reach a %d-note combo", "max": true},
	{"id": "od", "goals": [1, 4, 10], "one": "Go into OVERDRIVE", "many": "Go into OVERDRIVE %d times"},
	{"id": "agrade", "goals": [1, 3, 6], "one": "Get an A or better in an episode", "many": "Get an A or better in %d episodes"},
	{"id": "sgrade", "goals": [1, 2, 4], "one": "Get an S in an episode", "many": "Get an S in %d episodes"},
	{"id": "over", "goals": [4, 12, 30], "one": "Hop over %d roadblocks", "many": "Hop over %d roadblocks"},
	{"id": "excellent", "goals": [25, 80, 200], "one": "Make %d EXCELLENT moves", "many": "Make %d EXCELLENT moves"},
	{"id": "coins", "goals": [300, 800, 1800], "one": "Play %d notes", "many": "Play %d notes"},
	{"id": "rescue", "goals": [1, 3, 8], "one": "Fill the rescue meter and get your car back", "many": "Get rescued %d times"},
	{"id": "power", "goals": [3, 8, 15], "one": "Collect %d power-ups", "many": "Collect %d power-ups"},
]

static var _episodes := {}
static var _looks := {}


static func episodes(map: String) -> Array:
	## the era's eight cities in order: {map, i, name, bpm, lead, look, course path}
	if _episodes.is_empty():
		_looks = JSON.parse_string(FileAccess.get_file_as_string("res://data/looks.json"))
		for m in MAPS:
			var list := []
			for i in 8:
				var e: Dictionary = _looks[m].episodes[i]
				list.append({"map": m, "i": i, "name": e.name, "bpm": int(e.bpm), "lead": e.lead, "look": e.look,
					"course": "res://data/%s_%d.json" % [m, i], "audio": "res://audio/%s_%d" % [m, i]})
			_episodes[m] = list
	return _episodes[map]


static func theme(map: String) -> Dictionary:
	episodes(map)
	return _looks[map].theme


static func city_of(name: String) -> String:
	## "London 1890" -> "London"
	var parts := name.split(" ")
	if parts.size() > 1 and parts[-1].is_valid_int():
		parts.remove_at(parts.size() - 1)
	return " ".join(parts)


static func perk(car: String) -> Dictionary:
	var p := {"coin": 1.0, "mag": 1.0, "reach": 0.62, "startShield": false}
	p.merge(CARS[car].perk, true)
	return p


static func mission_text(id: String, goal: int) -> String:
	for p in MISSION_POOL:
		if p.id == id:
			var s: String = p.one if goal <= 1 else p.many
			return s % goal if s.contains("%d") else s
	return id
