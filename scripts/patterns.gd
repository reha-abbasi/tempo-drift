class_name Patterns
extends RefCounted

## Hand-made obstacle layouts. The track strings these together at random
## (sometimes mirrored left/right). Add new ones here - no other code needed.
##
## "d" = metres ahead of the pattern start. Distances get stretched as the game
##        speeds up so reaction time stays fair; train lengths do not.
## Lanes: 0 = left, 1 = middle, 2 = right.
##
## Items:
##   ["hurdle", lane, d]                    low barrier   -> jump over it
##   ["bar", lane, d]                       overhead sign -> slide under it
##   ["train", lane, d, length, ramp]       wagon, front at d. ramp = true adds a
##                                          ramp in front so you can run on the roof
##   ["coins", lane, d, count, style]       style: "line" (follows the ground, ramps
##                                          and roofs) or "jump" (arc centred on d)
##   ["power", lane, d, kind]               "magnet" or "double"
##
## level = minimum difficulty level (level goes up every LEVEL_DISTANCE metres).
## Rules of thumb: every row must leave at least one way through, and don't put
## two trains back to back in the same lane (the gap grows with speed and you
## would fall off the first roof into the second).

const LEVEL_DISTANCE := 350.0

const LIST := [
	{"name": "warmup_coins", "level": 0, "weight": 1.0, "len": 30, "items": [
		["coins", 1, 0, 10, "line"],
	]},
	{"name": "hurdle_middle", "level": 0, "weight": 1.0, "len": 22, "items": [
		["hurdle", 1, 14],
		["coins", 0, 2, 8, "line"],
		["coins", 1, 14, 5, "jump"],
	]},
	{"name": "bar_side", "level": 0, "weight": 1.0, "len": 22, "items": [
		["bar", 0, 12],
		["hurdle", 2, 12],
		["coins", 1, 4, 8, "line"],
	]},
	{"name": "hurdle_wall", "level": 0, "weight": 1.0, "len": 20, "items": [
		["hurdle", 0, 12], ["hurdle", 1, 12], ["hurdle", 2, 12],
		["coins", 1, 12, 5, "jump"],
	]},
	{"name": "bar_wall", "level": 0, "weight": 1.0, "len": 20, "items": [
		["bar", 0, 12], ["bar", 1, 12], ["bar", 2, 12],
		["coins", 1, 6, 6, "line"],
	]},
	{"name": "trains_sides", "level": 0, "weight": 1.2, "len": 30, "items": [
		["train", 0, 6, 24, false],
		["train", 2, 6, 24, false],
		["coins", 1, 4, 12, "line"],
	]},
	{"name": "single_train", "level": 0, "weight": 1.0, "len": 26, "items": [
		["train", 1, 6, 20, false],
		["coins", 0, 4, 9, "line"],
	]},
	{"name": "ramp_middle", "level": 0, "weight": 1.2, "len": 34, "items": [
		["train", 1, 12, 26, true],
		["coins", 1, 5, 16, "line"],
	]},
	{"name": "slalom", "level": 1, "weight": 1.0, "len": 40, "items": [
		["train", 0, 6, 14, false],
		["hurdle", 1, 10], ["bar", 2, 10],
		["train", 2, 30, 14, false],
		["hurdle", 0, 34], ["bar", 1, 34],
		["coins", 1, 10, 5, "jump"],
	]},
	{"name": "mixed_rows", "level": 1, "weight": 1.0, "len": 30, "items": [
		["hurdle", 0, 8], ["bar", 1, 8], ["hurdle", 2, 8],
		["bar", 0, 24], ["hurdle", 1, 24], ["bar", 2, 24],
		["coins", 1, 24, 5, "jump"],
	]},
	{"name": "train_pair_jump", "level": 1, "weight": 1.0, "len": 36, "items": [
		["train", 0, 6, 30, false],
		["train", 1, 6, 30, false],
		["hurdle", 2, 14],
		["bar", 2, 28],
		["coins", 2, 4, 6, "line"],
		["coins", 2, 14, 5, "jump"],
	]},
	{"name": "ramp_forced", "level": 1, "weight": 1.0, "len": 40, "items": [
		["train", 0, 14, 22, false],
		["train", 1, 14, 30, true],
		["train", 2, 14, 22, false],
		["coins", 1, 7, 18, "line"],
		["power", 1, 38, "magnet"],
	]},
	{"name": "zigzag_trains", "level": 1, "weight": 1.0, "len": 54, "items": [
		["train", 0, 6, 14, false],
		["train", 1, 6, 14, false],
		["train", 1, 32, 14, false],
		["train", 2, 32, 14, false],
		["coins", 2, 4, 8, "line"],
		["coins", 0, 30, 8, "line"],
	]},
	{"name": "double_slide", "level": 2, "weight": 0.8, "len": 26, "items": [
		["bar", 0, 8], ["bar", 1, 8], ["bar", 2, 8],
		["bar", 0, 20], ["bar", 1, 20], ["bar", 2, 20],
		["coins", 1, 6, 10, "line"],
	]},
	{"name": "roof_run", "level": 2, "weight": 1.0, "len": 50, "items": [
		["train", 1, 12, 34, true],
		["train", 0, 20, 24, false],
		["hurdle", 2, 22],
		["bar", 2, 40],
		["coins", 1, 5, 20, "line"],
		["power", 1, 24, "double"],
	]},
	{"name": "gauntlet", "level": 3, "weight": 0.9, "len": 44, "items": [
		["train", 0, 6, 36, false],
		["hurdle", 1, 10], ["bar", 1, 22], ["hurdle", 1, 34],
		["train", 2, 6, 16, false],
		["train", 2, 30, 14, false],
		["coins", 1, 10, 5, "jump"],
	]},
	{"name": "magnet_gift", "level": 0, "weight": 0.35, "len": 24, "items": [
		["power", 1, 10, "magnet"],
		["coins", 0, 14, 6, "line"], ["coins", 2, 14, 6, "line"],
	]},
	{"name": "double_gift", "level": 1, "weight": 0.3, "len": 24, "items": [
		["hurdle", 0, 10], ["hurdle", 2, 10],
		["power", 1, 10, "double"],
	]},
]


static func level_for(distance: float) -> int:
	return int(distance / LEVEL_DISTANCE)


## Weighted random pick among the patterns unlocked at `level`, avoiding an
## immediate repeat of `last`.
static func pick(rng: RandomNumberGenerator, level: int, last: String) -> Dictionary:
	var pool: Array[Dictionary] = []
	var total := 0.0
	for p: Dictionary in LIST:
		if p["level"] <= level and p["name"] != last:
			pool.append(p)
			total += float(p["weight"])
	var roll := rng.randf() * total
	for p in pool:
		roll -= float(p["weight"])
		if roll <= 0.0:
			return p
	return pool.back()


static func by_name(pattern_name: String) -> Dictionary:
	for p: Dictionary in LIST:
		if p["name"] == pattern_name:
			return p
	return {}
