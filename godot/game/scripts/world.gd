class_name World
extends Node3D
## A city street of the Past, built from a "look": London 1890 in the rain (Victorian terraces, slate and chimneys,
## Big Ben), Istanbul 1910 at sunset (plaster houses with wooden bay windows, terracotta roofs, cypresses, a great
## mosque), Paris 1925 at dusk (limestone blocks with iron balconies and zinc mansard roofs, the Eiffel Tower).
## The whole route is laid out once at load: each kind of piece (walls, roofs, chimneys, lamps...) is one batched mesh,
## so the street is a few dozen draw calls however long it is.

# the skyway (the car's middle height) flies 3.4 above the cobbles
const ROAD_Y := -3.4
const WALK_Y := -3.22
const ROAD_HW := 4.6      # half the road's width
const FRONT := 6.8        # where the house fronts stand
const DEPTH := 9.0        # how deep a house is

var z_start := 40.0
var z_end := -1500.0
var far: Node3D           # the skyline at the end of the street, kept at the same distance ahead
var sun: DirectionalLight3D
var env: Environment
var rng := RandomNumberGenerator.new()
var big_halos: MultiMeshInstance3D
var look: Dictionary
var searchlights := []

# wall styles for the facade shader: brick 0, plaster 0.25, stucco ground floor 0.5, ashlar stone 0.75, brick with
# stone bands 1
const LOOKS := {
	"london": {
		"sky": [Color(0.3, 0.34, 0.43), Color(0.53, 0.52, 0.53), Color(0.86, 0.7, 0.52), Color(1.0, 0.78, 0.52)],
		"cloud": Color(0.4, 0.4, 0.44), "cover": 0.55, "sun": Color(1.0, 0.7, 0.44), "sun_e": 2.0, "sun_dir": Vector3(0.62, -0.24, 1.0),
		"fog": Color(0.66, 0.55, 0.45), "fog_d": 0.0062, "haze": Color(0.88, 0.75, 0.6),
		"walls": [Color(0.62, 0.53, 0.40), Color(0.55, 0.30, 0.22), Color(0.40, 0.34, 0.29), Color(0.66, 0.58, 0.45), Color(0.48, 0.27, 0.21)],
		"styles": [0.0, 0.5, 1.0, 0.5, 0.0, 1.0], "floors": [3, 5], "roof": "pitch", "roof_col": Color(0.29, 0.31, 0.35),
		"chimneys": true, "bays": "ground", "railings": true, "balconies": false, "trees": "plane", "landmark": "bigben",
		"rain": true, "smoke": true, "puddles": 0.42, "seed": 1890},
	"istanbul": {
		"sky": [Color(0.34, 0.34, 0.6), Color(0.78, 0.56, 0.66), Color(1.0, 0.68, 0.5), Color(1.0, 0.8, 0.56)],
		"cloud": Color(0.62, 0.48, 0.58), "cover": 0.68, "sun": Color(1.0, 0.64, 0.48), "sun_e": 2.2, "sun_dir": Vector3(-0.55, -0.2, 1.0),
		"fog": Color(0.78, 0.58, 0.5), "fog_d": 0.0058, "haze": Color(0.95, 0.7, 0.6),
		"walls": [Color(0.86, 0.66, 0.48), Color(0.8, 0.5, 0.36), Color(0.92, 0.84, 0.7), Color(0.62, 0.46, 0.36), Color(0.76, 0.62, 0.44), Color(0.7, 0.36, 0.3)],
		"styles": [0.25, 0.25, 0.25, 0.5, 0.0], "floors": [2, 4], "roof": "pitch", "roof_col": Color(0.6, 0.31, 0.21),
		"chimneys": false, "bays": "upper", "railings": false, "balconies": false, "trees": "cypress", "landmark": "mosque",
		"rain": false, "smoke": false, "puddles": 0.08, "seed": 1910},
	"paris": {
		"sky": [Color(0.28, 0.32, 0.56), Color(0.68, 0.56, 0.71), Color(0.94, 0.65, 0.63), Color(1.0, 0.78, 0.63)],
		"cloud": Color(0.55, 0.5, 0.62), "cover": 0.62, "sun": Color(1.0, 0.69, 0.6), "sun_e": 1.8, "sun_dir": Vector3(0.5, -0.16, 1.0),
		"fog": Color(0.66, 0.55, 0.62), "fog_d": 0.0052, "haze": Color(0.86, 0.72, 0.76),
		"walls": [Color(0.8, 0.72, 0.58), Color(0.74, 0.66, 0.53), Color(0.84, 0.77, 0.63), Color(0.7, 0.62, 0.5)],
		"styles": [0.75], "floors": [5, 6], "roof": "mansard", "roof_col": Color(0.4, 0.45, 0.53),
		"chimneys": true, "bays": "", "railings": false, "balconies": true, "trees": "chestnut", "landmark": "eiffel",
		"rain": false, "smoke": false, "puddles": 0.18, "seed": 1925},
	"newyork": {
		"sky": [Color(0.06, 0.08, 0.2), Color(0.2, 0.21, 0.38), Color(0.66, 0.44, 0.4), Color(1.0, 0.6, 0.42)],
		"cloud": Color(0.16, 0.16, 0.26), "cover": 0.6, "sun": Color(0.72, 0.62, 1.0), "sun_e": 0.55, "sun_dir": Vector3(0.3, -0.3, 1.0),
		"fog": Color(0.24, 0.23, 0.33), "fog_d": 0.0068, "haze": Color(0.4, 0.34, 0.46), "ambient": 0.3, "lit": 0.55,
		"walls": [Color(0.44, 0.34, 0.29), Color(0.58, 0.52, 0.45), Color(0.36, 0.3, 0.28), Color(0.64, 0.58, 0.5), Color(0.5, 0.28, 0.22)],
		"styles": [1.0, 0.75, 0.0, 1.0], "floors": [6, 12], "roof": "flat", "roof_col": Color(0.2, 0.2, 0.22),
		"chimneys": false, "bays": "", "railings": false, "balconies": false, "fire_escapes": true, "tanks": true,
		"trees": "none", "landmark": "deco", "rain": false, "smoke": false, "steam": true, "puddles": 0.3, "seed": 1935},
	"havana": {
		"sky": [Color(0.22, 0.4, 0.68), Color(0.76, 0.62, 0.74), Color(1.0, 0.63, 0.5), Color(1.0, 0.78, 0.53)],
		"cloud": Color(0.72, 0.6, 0.68), "cover": 0.7, "sun": Color(1.0, 0.72, 0.56), "sun_e": 2.2, "sun_dir": Vector3(-0.6, -0.22, 1.0),
		"fog": Color(0.84, 0.62, 0.6), "fog_d": 0.0052, "haze": Color(0.98, 0.76, 0.66),
		"walls": [Color(0.22, 0.7, 0.72), Color(0.92, 0.42, 0.52), Color(0.98, 0.8, 0.3), Color(0.58, 0.44, 0.82), Color(0.95, 0.92, 0.84), Color(1.0, 0.56, 0.32)],
		"styles": [0.25], "floors": [2, 3], "roof": "flat", "roof_col": Color(0.6, 0.31, 0.21),
		"chimneys": false, "bays": "", "railings": false, "balconies": true, "trees": "palm", "landmark": "capitolio",
		"rain": false, "smoke": false, "puddles": 0.05, "seed": 1955},
	"vienna": {
		"sky": [Color(0.28, 0.3, 0.55), Color(0.72, 0.6, 0.72), Color(1.0, 0.69, 0.63), Color(1.0, 0.82, 0.66)],
		"cloud": Color(0.6, 0.55, 0.66), "cover": 0.6, "sun": Color(1.0, 0.75, 0.62), "sun_e": 1.9, "sun_dir": Vector3(0.55, -0.2, 1.0),
		"fog": Color(0.74, 0.63, 0.66), "fog_d": 0.0062, "haze": Color(0.9, 0.76, 0.76),
		"walls": [Color(0.93, 0.8, 0.5), Color(0.9, 0.86, 0.76), Color(0.86, 0.74, 0.6), Color(0.84, 0.84, 0.78), Color(0.92, 0.76, 0.56)],
		"styles": [0.75, 0.5, 0.25], "floors": [4, 5], "roof": "mansard", "roof_col": Color(0.34, 0.52, 0.45),
		"chimneys": true, "bays": "", "railings": false, "balconies": true, "trees": "chestnut", "landmark": "stephansdom",
		"rain": false, "smoke": true, "puddles": 0.15, "seed": 1905},
	"cairo": {
		"sky": [Color(0.34, 0.4, 0.6), Color(0.8, 0.66, 0.58), Color(1.0, 0.72, 0.46), Color(1.0, 0.84, 0.6)],
		"cloud": Color(0.78, 0.66, 0.58), "cover": 0.78, "sun": Color(1.0, 0.74, 0.5), "sun_e": 2.3, "sun_dir": Vector3(-0.5, -0.24, 1.0),
		"fog": Color(0.82, 0.66, 0.5), "fog_d": 0.0056, "haze": Color(0.98, 0.82, 0.62),
		"walls": [Color(0.84, 0.68, 0.48), Color(0.76, 0.6, 0.42), Color(0.9, 0.8, 0.62), Color(0.68, 0.54, 0.4), Color(0.94, 0.88, 0.76)],
		"styles": [0.25, 0.25, 0.75], "floors": [2, 4], "roof": "flat", "roof_col": Color(0.6, 0.5, 0.4),
		"chimneys": false, "bays": "upper", "railings": false, "balconies": false, "trees": "palm", "landmark": "cairo",
		"rain": false, "smoke": false, "puddles": 0.0, "seed": 1926},
	"rome": {
		"sky": [Color(0.28, 0.38, 0.62), Color(0.74, 0.62, 0.66), Color(1.0, 0.7, 0.5), Color(1.0, 0.84, 0.6)],
		"cloud": Color(0.7, 0.6, 0.62), "cover": 0.72, "sun": Color(1.0, 0.72, 0.5), "sun_e": 2.1, "sun_dir": Vector3(0.6, -0.22, 1.0),
		"fog": Color(0.82, 0.66, 0.55), "fog_d": 0.0064, "haze": Color(0.96, 0.78, 0.64),
		"walls": [Color(0.84, 0.56, 0.32), Color(0.76, 0.42, 0.28), Color(0.9, 0.74, 0.5), Color(0.72, 0.5, 0.36), Color(0.88, 0.66, 0.44)],
		"styles": [0.25, 0.25, 0.5], "floors": [3, 5], "roof": "pitch", "roof_col": Color(0.62, 0.33, 0.22),
		"chimneys": false, "bays": "", "railings": false, "balconies": true, "trees": "pine", "landmark": "rome",
		"rain": false, "smoke": false, "puddles": 0.05, "seed": 1948},
	# ---- the Present
	"dubai": {"base": "present", "seed": 2001, "landmark": "burj", "trees": "palm",
		"sky": [Color(0.42, 0.52, 0.76), Color(0.78, 0.67, 0.69), Color(1.0, 0.75, 0.54), Color(1.0, 0.85, 0.63)],
		"sun": Color(1.0, 0.76, 0.55), "sun_e": 2.2, "sun_dir": Vector3(-0.55, -0.2, 1.0),
		"fog": Color(0.82, 0.7, 0.6), "fog_d": 0.0048, "haze": Color(0.96, 0.82, 0.7),
		"walls": [Color(0.86, 0.76, 0.6), Color(0.92, 0.86, 0.74), Color(0.8, 0.68, 0.52)], "tower_share": 0.7},
	"rio": {"base": "present", "seed": 2002, "landmark": "rio", "trees": "palm", "tower_share": 0.4, "tower_styles": [2.5, 2.5, 2.0],
		"sky": [Color(0.25, 0.45, 0.76), Color(0.56, 0.7, 0.86), Color(0.95, 0.8, 0.66), Color(1.0, 0.86, 0.68)],
		"sun": Color(1.0, 0.86, 0.66), "sun_e": 2.0, "sun_dir": Vector3(0.6, -0.3, 1.0),
		"fog": Color(0.7, 0.75, 0.8), "fog_d": 0.0045, "haze": Color(0.82, 0.86, 0.9),
		"walls": [Color(0.95, 0.85, 0.4), Color(0.4, 0.75, 0.6), Color(0.95, 0.55, 0.45), Color(0.95, 0.94, 0.9), Color(0.5, 0.6, 0.85)]},
	"singapore": {"base": "present", "seed": 2003, "landmark": "mbs", "trees": "plane", "tower_share": 0.78, "neon": 0.15,
		"sky": [Color(0.18, 0.2, 0.45), Color(0.55, 0.45, 0.7), Color(0.95, 0.6, 0.6), Color(1.0, 0.75, 0.6)],
		"sun": Color(1.0, 0.7, 0.65), "sun_e": 1.6, "sun_dir": Vector3(0.5, -0.18, 1.0),
		"fog": Color(0.55, 0.45, 0.6), "fog_d": 0.005, "haze": Color(0.8, 0.66, 0.78), "lit": 0.55,
		"walls": [Color(0.92, 0.9, 0.84), Color(0.85, 0.8, 0.7), Color(0.7, 0.8, 0.75)]},
	"sanfrancisco": {"base": "present", "seed": 2004, "landmark": "goldengate", "tower_share": 0.3, "bays": "ground", "floors": [3, 4], "styles": [0.25],
		"sky": [Color(0.45, 0.55, 0.7), Color(0.78, 0.74, 0.72), Color(1.0, 0.8, 0.6), Color(1.0, 0.88, 0.7)],
		"sun": Color(1.0, 0.82, 0.62), "sun_e": 1.8, "sun_dir": Vector3(0.55, -0.2, 1.0),
		"fog": Color(0.84, 0.8, 0.76), "fog_d": 0.0085, "haze": Color(0.92, 0.88, 0.84),
		"walls": [Color(0.86, 0.62, 0.7), Color(0.6, 0.74, 0.86), Color(0.95, 0.88, 0.6), Color(0.7, 0.85, 0.7), Color(0.95, 0.94, 0.9)]},
	"sydney": {"base": "present", "seed": 2005, "landmark": "opera", "trees": "plane", "tower_share": 0.6,
		"sky": [Color(0.3, 0.45, 0.75), Color(0.7, 0.7, 0.78), Color(1.0, 0.78, 0.55), Color(1.0, 0.85, 0.6)],
		"sun": Color(1.0, 0.78, 0.55), "sun_e": 2.1, "sun_dir": Vector3(-0.5, -0.22, 1.0),
		"fog": Color(0.75, 0.7, 0.66), "fog_d": 0.0048, "haze": Color(0.9, 0.84, 0.76),
		"walls": [Color(0.86, 0.6, 0.46), Color(0.9, 0.86, 0.78), Color(0.74, 0.5, 0.38)]},
	"capetown": {"base": "present", "seed": 2006, "landmark": "tablemountain", "trees": "palm", "tower_share": 0.25, "floors": [2, 3], "styles": [0.25],
		"sky": [Color(0.35, 0.42, 0.7), Color(0.85, 0.6, 0.55), Color(1.0, 0.62, 0.4), Color(1.0, 0.75, 0.5)],
		"sun": Color(1.0, 0.66, 0.42), "sun_e": 2.3, "sun_dir": Vector3(0.6, -0.18, 1.0),
		"fog": Color(0.85, 0.6, 0.5), "fog_d": 0.0048, "haze": Color(0.98, 0.72, 0.6),
		"walls": [Color(0.95, 0.4, 0.6), Color(0.35, 0.75, 0.5), Color(0.3, 0.55, 0.85), Color(0.98, 0.82, 0.3), Color(0.65, 0.4, 0.8), Color(0.98, 0.55, 0.3)]},
	"barcelona": {"base": "present", "seed": 2007, "landmark": "sagrada", "trees": "plane", "tower_share": 0.08, "floors": [5, 6], "styles": [0.75],
		"balconies": true, "roof": "flat",
		"sky": [Color(0.3, 0.35, 0.62), Color(0.78, 0.6, 0.72), Color(1.0, 0.68, 0.6), Color(1.0, 0.8, 0.66)],
		"sun": Color(1.0, 0.72, 0.6), "sun_e": 2.0, "sun_dir": Vector3(-0.55, -0.2, 1.0),
		"fog": Color(0.78, 0.62, 0.62), "fog_d": 0.0055, "haze": Color(0.95, 0.78, 0.76),
		"walls": [Color(0.86, 0.76, 0.62), Color(0.8, 0.66, 0.52), Color(0.9, 0.82, 0.7)]},
	"reykjavik": {"base": "present", "seed": 2008, "landmark": "hallgrims", "tower_share": 0.0, "floors": [2, 3], "styles": [0.25],
		"roof": "pitch", "roof_col": Color(0.55, 0.16, 0.14), "snow": true, "aurora": 1.3, "stars": 1.0, "lit": 0.62, "ambient": 0.32,
		"sky": [Color(0.03, 0.05, 0.13), Color(0.08, 0.13, 0.27), Color(0.24, 0.3, 0.46), Color(0.42, 0.48, 0.64)],
		"sun": Color(0.6, 0.7, 1.0), "sun_e": 0.6, "sun_dir": Vector3(0.3, -0.4, 1.0), "cloud": Color(0.12, 0.14, 0.22), "cover": 0.75,
		"fog": Color(0.25, 0.3, 0.4), "fog_d": 0.0065, "haze": Color(0.3, 0.36, 0.5), "walk": Color(0.85, 0.87, 0.9),
		"walls": [Color(0.75, 0.2, 0.18), Color(0.2, 0.35, 0.6), Color(0.92, 0.78, 0.3), Color(0.92, 0.92, 0.9), Color(0.3, 0.55, 0.45)]},
	# ---- the Future
	"hongkong": {"base": "future", "seed": 2049, "landmark": "hk",
		"sky": [Color(0.02, 0.024, 0.05), Color(0.08, 0.09, 0.15), Color(0.23, 0.16, 0.24), Color(0.5, 0.42, 0.54)],
		"neon_a": Color(1.0, 0.25, 0.7), "neon_b": Color(0.18, 0.95, 1.0)},
	"tokyo": {"base": "future", "seed": 2060, "landmark": "skytree",
		"sky": [Color(0.02, 0.02, 0.06), Color(0.07, 0.06, 0.16), Color(0.25, 0.1, 0.25), Color(0.55, 0.3, 0.45)],
		"neon_a": Color(1.0, 0.15, 0.2), "neon_b": Color(0.3, 0.5, 1.0), "city_glow": Color(0.55, 0.15, 0.3)},
	"losangeles": {"base": "future", "seed": 2070, "landmark": "ziggurat", "trees": "palm", "rain_amt": 0.6,
		"sky": [Color(0.04, 0.03, 0.04), Color(0.15, 0.08, 0.08), Color(0.45, 0.2, 0.12), Color(0.8, 0.45, 0.25)],
		"neon_a": Color(1.0, 0.5, 0.15), "neon_b": Color(0.2, 0.9, 0.8), "city_glow": Color(0.7, 0.3, 0.12),
		"fog": Color(0.2, 0.12, 0.1), "haze": Color(0.45, 0.25, 0.18)},
	"shanghai": {"base": "future", "seed": 2085, "landmark": "pearl",
		"sky": [Color(0.03, 0.03, 0.07), Color(0.1, 0.08, 0.2), Color(0.3, 0.15, 0.35), Color(0.6, 0.35, 0.55)],
		"neon_a": Color(1.0, 0.75, 0.2), "neon_b": Color(1.0, 0.25, 0.6)},
	"seoul": {"base": "future", "seed": 2099, "landmark": "seoul",
		"sky": [Color(0.02, 0.03, 0.08), Color(0.06, 0.1, 0.22), Color(0.2, 0.2, 0.4), Color(0.45, 0.45, 0.7)],
		"neon_a": Color(0.6, 0.35, 1.0), "neon_b": Color(0.2, 0.95, 1.0), "city_glow": Color(0.3, 0.25, 0.6)},
	"berlin": {"base": "future", "seed": 2075, "landmark": "fernsehturm", "neon": 0.35, "rain_amt": 0.6,
		"sky": [Color(0.03, 0.03, 0.04), Color(0.1, 0.1, 0.12), Color(0.25, 0.22, 0.28), Color(0.45, 0.4, 0.45)],
		"neon_a": Color(0.3, 1.0, 0.4), "neon_b": Color(0.95, 0.95, 1.0), "city_glow": Color(0.25, 0.25, 0.3)},
	"miami": {"base": "future", "seed": 2088, "landmark": "miami", "trees": "palm", "rain": false, "tower_share": 0.6, "styles": [0.25],
		"walls": [Color(0.95, 0.6, 0.75), Color(0.5, 0.85, 0.85), Color(0.98, 0.9, 0.7)],
		"sky": [Color(0.08, 0.03, 0.2), Color(0.4, 0.08, 0.4), Color(1.0, 0.3, 0.5), Color(1.0, 0.6, 0.4)],
		"sun": Color(1.0, 0.4, 0.6), "sun_e": 1.2, "sun_dir": Vector3(0.0, -0.08, 1.0), "fog": Color(0.35, 0.12, 0.3), "fog_d": 0.008,
		"haze": Color(0.7, 0.3, 0.5), "neon_a": Color(1.0, 0.3, 0.75), "neon_b": Color(0.25, 0.95, 1.0), "city_glow": Color(0.8, 0.25, 0.4), "wet": 0.3},
	"vegas": {"base": "future", "seed": 2099, "landmark": "vegas", "neon": 1.0, "rain": false, "wet": 0.2,
		"sky": [Color(0.03, 0.02, 0.06), Color(0.12, 0.05, 0.18), Color(0.4, 0.15, 0.3), Color(0.8, 0.4, 0.4)],
		"neon_a": Color(1.0, 0.8, 0.2), "neon_b": Color(1.0, 0.2, 0.6), "city_glow": Color(0.8, 0.4, 0.3)},
}

# shared settings of the modern eras; a look names its base and overrides what's different
const BASES := {
	"present": {
		"road": "asphalt", "wet": 0.05, "walk": Color(0.62, 0.6, 0.57), "floors": [3, 6], "styles": [0.25, 0.75],
		"tower_share": 0.55, "tower_floors": [8, 22], "tower_styles": [2.0, 2.0, 2.5],
		"tower_cols": [Color(0.3, 0.5, 0.56), Color(0.32, 0.42, 0.6), Color(0.56, 0.46, 0.36), Color(0.62, 0.64, 0.68), Color(0.74, 0.72, 0.68)],
		"roof": "flat", "roof_col": Color(0.3, 0.3, 0.32), "chimneys": false, "bays": "", "railings": false, "balconies": false,
		"lamps": "modern", "neon": 0.0, "antennas": true, "trees": "none", "rain": false, "smoke": false, "puddles": 0.0, "lit": 0.2,
		"cloud": Color(0.7, 0.66, 0.72), "cover": 0.5},
	"future": {
		"road": "asphalt", "wet": 0.85, "walk": Color(0.3, 0.3, 0.34), "floors": [4, 8], "styles": [0.75],
		"tower_share": 0.85, "tower_floors": [10, 32], "tower_styles": [3.0],
		"tower_cols": [Color(0.2, 0.21, 0.26), Color(0.16, 0.16, 0.2), Color(0.26, 0.24, 0.3)],
		"walls": [Color(0.3, 0.3, 0.34), Color(0.24, 0.24, 0.28)], "roof": "flat", "roof_col": Color(0.15, 0.15, 0.18),
		"chimneys": false, "bays": "", "railings": false, "balconies": false, "lamps": "neon", "neon": 0.6, "antennas": true,
		"trees": "none", "rain": true, "rain_amt": 1.0, "smoke": false, "steam": true, "puddles": 0.0, "lit": 0.5,
		"sun": Color(0.6, 0.5, 0.9), "sun_e": 0.5, "sun_dir": Vector3(0.2, -0.4, 1.0), "ambient": 0.32,
		"fog": Color(0.12, 0.1, 0.18), "fog_d": 0.011, "haze": Color(0.3, 0.2, 0.34), "cloud": Color(0.1, 0.09, 0.14), "cover": 0.7,
		"city_glow": Color(0.5, 0.2, 0.42), "office": Color(0.7, 0.85, 1.0)},
}

func _merge_look(name: String) -> Dictionary:
	var l: Dictionary = LOOKS[name]
	if not l.has("base"):
		return l
	var m: Dictionary = BASES[l.base].duplicate()
	m.merge(l, true)
	return m

func build(length_units: float, look_name := "london") -> void:
	look = _merge_look(look_name)
	rng.seed = look.seed
	z_end = -length_units - 260.0
	_environment()
	_street()
	_houses()
	_lamps_and_trees()
	_skyline()
	_weather()

func _mat(path: String, params := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(path)
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m

func _std(col: Color, rough := 0.8, metal := 0.0, emit := Color.BLACK, emit_e := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	if emit_e > 0.0:
		m.emission_enabled = true
		m.emission = emit
		m.emission_energy_multiplier = emit_e
	return m

## one batched mesh: transforms (and optional per-piece custom data) for every copy
func _multi(mesh: Mesh, mat: Material, xforms: Array, custom: Array = [], shadows := true) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = custom.size() > 0
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		if custom.size() > 0:
			mm.set_instance_custom_data(i, custom[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi

func _box_xf(center: Vector3, size: Vector3) -> Transform3D:
	return Transform3D(Basis.from_scale(size), center)

# ---------------------------------------------------------------- light, sky, fog

func _environment() -> void:
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load("res://shaders/sky.gdshader")
	for i in 4:
		sky_mat.set_shader_parameter(["top_col", "mid_col", "low_col", "hor_col"][i], look.sky[i])
	sky_mat.set_shader_parameter("sun_col", look.sun)
	sky_mat.set_shader_parameter("cloud_col", look.cloud)
	sky_mat.set_shader_parameter("cover", look.cover)
	sky_mat.set_shader_parameter("aurora", look.get("aurora", 0.0))
	sky_mat.set_shader_parameter("stars", look.get("stars", 0.0))
	sky_mat.set_shader_parameter("city_glow", look.get("city_glow", Color.BLACK))
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	sky.process_mode = Sky.PROCESS_MODE_QUALITY
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = look.get("ambient", 0.42)
	env.ambient_light_sky_contribution = 0.85
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 0.95
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_strength = 1.0
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 0.95
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.set_glow_level(0, 0.0)
	env.set_glow_level(1, 0.6)
	env.set_glow_level(2, 1.0)
	env.set_glow_level(3, 0.8)
	env.set_glow_level(4, 0.5)
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = look.fog
	env.fog_light_energy = 1.0
	env.fog_density = look.fog_d
	env.fog_sun_scatter = 0.45
	env.fog_sky_affect = 0.15
	env.fog_height = -1.2
	env.fog_height_density = 0.018
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.1
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	# the low sun ahead and to the left: long shadows toward the camera, warm light grazing the right-hand houses
	sun = DirectionalLight3D.new()
	sun.light_color = look.sun
	sun.light_energy = look.sun_e
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 70.0
	sun.directional_shadow_split_1 = 0.25
	sun.shadow_blur = 1.4
	sun.shadow_bias = 0.06
	sun.shadow_normal_bias = 1.2
	add_child(sun)
	sun.look_at_from_position(Vector3.ZERO, look.sun_dir, Vector3.UP)
	sun.light_angular_distance = 1.2

## the skyline stays the same distance ahead of the car
func follow(car_z: float) -> void:
	if far:
		far.position.z = car_z - 250.0
	var tt := Time.get_ticks_msec() / 1000.0
	for k in searchlights.size():
		searchlights[k].rotation.z = sin(tt * 0.35 + k * 1.7) * 0.5 + (k - 1.5) * 0.12

# ---------------------------------------------------------------- street, pavements, kerbs

func _street() -> void:
	var len := z_start - z_end
	var mid := (z_start + z_end) * 0.5
	# the road: one long plane (it is drawn in pieces so nothing far away is computed for nothing)
	var piece := 60.0
	var road_mat: ShaderMaterial
	if look.get("road", "cobble") == "asphalt":
		road_mat = _mat("res://shaders/asphalt.gdshader", {"half_w": ROAD_HW, "wet": look.get("wet", 0.0)})
	else:
		road_mat = _mat("res://shaders/cobble.gdshader", {"half_w": ROAD_HW, "puddles": look.puddles})
	var z := z_start
	while z > z_end:
		var pm := PlaneMesh.new()
		pm.size = Vector2(ROAD_HW * 2.0, piece)
		pm.subdivide_depth = 0
		var mi := MeshInstance3D.new()
		mi.mesh = pm
		mi.material_override = road_mat
		mi.position = Vector3(0, ROAD_Y, z - piece * 0.5)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		z -= piece
	# pavements and granite kerbs
	var walk_mat := _mat("res://shaders/flags.gdshader", {"stone": look.get("walk", Color(0.52, 0.49, 0.44))})
	var kerb_mat := _std(Color(0.5, 0.49, 0.47), 0.45)
	var walks := []
	var kerbs := []
	for s in [-1.0, 1.0]:
		walks.append(_box_xf(Vector3(s * (ROAD_HW + FRONT) * 0.5, WALK_Y - 0.1, mid), Vector3(FRONT - ROAD_HW, 0.2, len)))
		kerbs.append(_box_xf(Vector3(s * (ROAD_HW + 0.12), WALK_Y - 0.09, mid), Vector3(0.24, 0.22, len)))
	_multi(BoxMesh.new(), walk_mat, walks, [], false)
	_multi(BoxMesh.new(), kerb_mat, kerbs, [], false)

# ---------------------------------------------------------------- the terraces

func _prism() -> ArrayMesh:
	# a pitched roof: a triangle across the house, run along the street, with gable ends
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a := Vector3(-0.5, 0, -0.5); var b := Vector3(0.5, 0, -0.5); var c := Vector3(0, 1, -0.5)
	var a2 := Vector3(-0.5, 0, 0.5); var b2 := Vector3(0.5, 0, 0.5); var c2 := Vector3(0, 1, 0.5)
	for tri in [[a, c, c2], [a, c2, a2], [b, b2, c2], [b, c2, c], [a, b, c], [a2, c2, b2]]:
		var n: Vector3 = (tri[1] - tri[0]).cross(tri[2] - tri[0]).normalized()
		for v in tri:
			st.set_normal(n)
			st.add_vertex(v)
	return st.commit()

## a mansard roof (Paris): steep lower slopes and a low top, in zinc
func _mansard() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var prof := [Vector2(-0.5, 0), Vector2(-0.36, 0.82), Vector2(-0.2, 1.0), Vector2(0.2, 1.0), Vector2(0.36, 0.82), Vector2(0.5, 0)]
	for k in prof.size() - 1:
		var a: Vector2 = prof[k]
		var b: Vector2 = prof[k + 1]
		var q := [Vector3(a.x, a.y, -0.5), Vector3(b.x, b.y, -0.5), Vector3(b.x, b.y, 0.5), Vector3(a.x, a.y, 0.5)]
		for tri in [[q[0], q[1], q[2]], [q[0], q[2], q[3]]]:
			var n: Vector3 = (tri[1] - tri[0]).cross(tri[2] - tri[0]).normalized()
			for v in tri:
				st.set_normal(n)
				st.add_vertex(v)
	# the gable ends
	for zz in [-0.5, 0.5]:
		var n := Vector3(0, 0, signf(zz))
		for k in range(1, prof.size() - 1):
			var tri := [Vector3(prof[0].x, prof[0].y, zz), Vector3(prof[k].x, prof[k].y, zz), Vector3(prof[k + 1].x, prof[k + 1].y, zz)]
			if zz < 0.0:
				tri = [tri[0], tri[2], tri[1]]
			for v in tri:
				st.set_normal(n)
				st.add_vertex(v)
	return st.commit()

func _houses() -> void:
	var walls := []; var wall_cd := []
	var roofs := []
	var stacks := []; var stack_cd := []
	var pots := []
	var cornices := []
	var rails := []
	var balconies := []
	var tanks := []
	var ladders := []
	var masts := []; var beacons := []
	var signs := []; var sign_cd := []
	var palette: Array = look.walls
	var styles: Array = look.styles
	var fl: Array = look.floors
	for s in [-1.0, 1.0]:
		var z := z_start
		var since_gap := 0.0
		var col: Color = palette[0]
		while z > z_end:
			# now and then a side street opens between the terraces
			if since_gap > 70.0 and rng.randf() < 0.07:
				z -= 8.0 + rng.randf() * 4.0
				since_gap = 0.0
				continue
			var tower: bool = rng.randf() < look.get("tower_share", 0.0)
			var w: float = [4.5, 5.0, 5.0, 5.5, 6.0][rng.randi() % 5]
			if tower:
				w = [8.0, 10.0, 12.0, 14.0][rng.randi() % 4]
			if look.roof == "mansard":
				w *= 2.0
			var floors: int = fl[0] + rng.randi_range(0, fl[1] - fl[0])
			if tower:
				var tf: Array = look.tower_floors
				floors = tf[0] + rng.randi_range(0, tf[1] - tf[0])
			var h := floors * 2.7 + 0.7
			var cz := z - w * 0.5
			var cx: float = s * (FRONT + DEPTH * 0.5)
			var style: float = styles[rng.randi() % styles.size()]
			if tower:
				var ts: Array = look.tower_styles
				style = ts[rng.randi() % ts.size()]
			# neighbours are often built as a row and share their colour
			if rng.randf() < 0.65:
				col = palette[rng.randi() % palette.size()]
			if tower:
				# (towers: 3.3 a floor, their own colours, and a mast with a red light on some)
				h = floors * 3.3 + 0.6
				var tc: Array = look.tower_cols
				var tcol: Color = tc[rng.randi() % tc.size()]
				walls.append(_box_xf(Vector3(cx, WALK_Y + h * 0.5, cz), Vector3(DEPTH, h, w)))
				wall_cd.append(Color(tcol.r, tcol.g, tcol.b, style))
				if look.get("antennas", false) and rng.randf() < 0.35:
					masts.append(Transform3D(Basis.from_scale(Vector3(0.12, 5.0, 0.12)), Vector3(cx + s * 1.0, WALK_Y + h + 2.5, cz)))
					beacons.append(Transform3D(Basis.from_scale(Vector3.ONE * 1.6), Vector3(cx + s * 1.0, WALK_Y + h + 5.1, cz)))
			else:
				walls.append(_box_xf(Vector3(cx, WALK_Y + h * 0.5, cz), Vector3(DEPTH, h, w)))
				wall_cd.append(Color(col.r, col.g, col.b, style))
			# neon signs hung out over the street (the Future, and some modern cities)
			if rng.randf() < look.get("neon", 0.0):
				var nh := 2.5 + rng.randf() * 3.0
				var ny := WALK_Y + 3.5 + rng.randf() * minf(h - nh - 4.0, 10.0)
				var ncol: Color = look.get("neon_a", Color(1, 0.3, 0.7)) if rng.randf() < 0.5 else look.get("neon_b", Color(0.2, 0.9, 1.0))
				signs.append(Transform3D(Basis.from_scale(Vector3(1.1, nh, 1)), Vector3(s * (FRONT - 0.75), ny + nh * 0.5, cz + rng.randf_range(-w * 0.3, w * 0.3))))
				sign_cd.append(Color(ncol.r, ncol.g, ncol.b, rng.randf()))
			if look.bays == "ground" and rng.randf() < 0.3 and w >= 5.0:
				# a two-storey bay window in stucco (London)
				walls.append(_box_xf(Vector3(s * (FRONT - 0.35), WALK_Y + 2.7, cz), Vector3(0.7, 5.4, 2.6)))
				wall_cd.append(Color(0.84, 0.8, 0.72, 0.5))
			elif look.bays == "upper" and rng.randf() < 0.6 and floors >= 3:
				# a wooden bay jutting out over the street from the upper floors (Istanbul)
				var wood: Color = [Color(0.46, 0.3, 0.2), Color(0.62, 0.5, 0.36), Color(0.36, 0.3, 0.28)][rng.randi() % 3]
				var bh := (floors - 1) * 2.7
				walls.append(_box_xf(Vector3(s * (FRONT - 0.5), WALK_Y + 2.7 + bh * 0.5, cz), Vector3(1.0, bh, w * 0.7)))
				wall_cd.append(Color(wood.r, wood.g, wood.b, 0.25))
			if look.balconies:
				# wrought-iron balconies along the second and the top floor (Paris)
				for f in [2, floors - 1]:
					balconies.append(Transform3D(Basis.from_scale(Vector3(1, 0.95, w)), Vector3(s * (FRONT - 0.45), WALK_Y + f * 2.7 + 0.47, cz)))
					cornices.append(_box_xf(Vector3(s * (FRONT - 0.25), WALK_Y + f * 2.7 + 0.03, cz), Vector3(0.55, 0.08, w)))
			# the cornice along the top of the front
			cornices.append(_box_xf(Vector3(s * (FRONT - 0.12), WALK_Y + h - 0.12, cz), Vector3(0.36, 0.26, w + 0.02)))
			# the roof, its ridge along the street (flat roofs have only their parapet)
			var rh := (2.8 + rng.randf() * 0.6) if look.roof == "mansard" else (1.6 + rng.randf() * 0.9 if look.chimneys else 1.1 + rng.randf() * 0.6)
			if look.roof != "flat":
				roofs.append(Transform3D(Basis.from_scale(Vector3(DEPTH * 0.92, rh, w)), Vector3(cx + s * 0.2, WALK_Y + h, cz)))
			else:
				rh = 0.0
			if look.get("tanks", false) and rng.randf() < 0.45:
				# a wooden water tank on legs on the roof (New York)
				tanks.append(Transform3D(Basis.from_scale(Vector3(1.8, 1.8, 1.8)), Vector3(cx + rng.randf_range(-2.0, 2.0), WALK_Y + h + 2.0, cz)))
			if look.get("fire_escapes", false) and rng.randf() < 0.55 and floors > 3:
				# an iron fire escape zigzagging up the front
				for f in range(1, floors):
					balconies.append(Transform3D(Basis.from_scale(Vector3(1, 0.9, 3.0)), Vector3(s * (FRONT - 0.7), WALK_Y + f * 2.7 + 0.45, cz)))
					cornices.append(_box_xf(Vector3(s * (FRONT - 0.38), WALK_Y + f * 2.7 + 0.02, cz), Vector3(0.75, 0.06, 3.0)))
					ladders.append(Transform3D(Basis.from_scale(Vector3(1, 2.7, 0.5)).rotated(Vector3.RIGHT, 0.6 if f % 2 == 0 else -0.6), Vector3(s * (FRONT - 0.5), WALK_Y + f * 2.7 + 1.35, cz)))
			if look.chimneys:
				# chimney stacks on the party wall, with clay pots
				var sh := 1.4 + rng.randf() * 1.2
				for dx in [-2.2, 2.2]:
					var sc := Vector3(cx + dx, WALK_Y + h + rh * 0.45 + sh * 0.5, z)
					stacks.append(_box_xf(sc, Vector3(0.8, sh + rh * 0.9, 1.5)))
					stack_cd.append(Color(col.r * 0.9, col.g * 0.9, col.b * 0.9, -1.0))
					for k in 3:
						pots.append(Transform3D(Basis.from_scale(Vector3(0.22, 0.5, 0.22)), sc + Vector3(0, sh * 0.5 + rh * 0.45 + 0.25, -0.45 + k * 0.45)))
			if look.railings:
				# iron railings in front of the basement areas
				rails.append(Transform3D(Basis.from_scale(Vector3(1, 1.0, w)), Vector3(s * (FRONT - 0.9), WALK_Y + 0.5, cz)))
			z -= w
			since_gap += w
	var wall_mat := _mat("res://shaders/facade.gdshader", {"lit_share": look.get("lit", 0.34), "office_col": look.get("office", Color(0.92, 0.95, 1.0)),
		"neon_a": look.get("neon_a", Color(1.0, 0.25, 0.7)), "neon_b": look.get("neon_b", Color(0.2, 0.95, 1.0))})
	if masts.size() > 0:
		_multi(_cyl1(6), _std(Color(0.3, 0.3, 0.32), 0.4, 0.8), masts, [], false)
		_multi(QuadMesh.new(), _mat("res://shaders/halo.gdshader", {"tint": Color(1.0, 0.15, 0.1), "energy": 1.6, "fade": 0.004}), beacons, [], false)
	if signs.size() > 0:
		var sm := ShaderMaterial.new()
		sm.shader = load("res://shaders/neon.gdshader")
		_multi(QuadMesh.new(), sm, signs, sign_cd, false)
	_multi(BoxMesh.new(), wall_mat, walls, wall_cd)
	if stacks.size() > 0:
		_multi(BoxMesh.new(), wall_mat, stacks, stack_cd)
		var pot := CylinderMesh.new()
		pot.top_radius = 0.42; pot.bottom_radius = 0.5; pot.height = 1.0; pot.radial_segments = 8
		_multi(pot, _std(Color(0.62, 0.34, 0.24), 0.75), pots, [], false)
	_multi(_mansard() if look.roof == "mansard" else _prism(), _mat("res://shaders/roof.gdshader", {"slate": look.roof_col}), roofs)
	_multi(BoxMesh.new(), _std(Color(0.8, 0.77, 0.7), 0.6), cornices)
	var rail_mesh := QuadMesh.new()
	rail_mesh.orientation = PlaneMesh.FACE_X
	var rail_mat := ShaderMaterial.new()
	rail_mat.shader = _railing_shader()
	if rails.size() > 0:
		_multi(rail_mesh, rail_mat, rails, [], false)
	if balconies.size() > 0:
		_multi(rail_mesh, rail_mat, balconies, [], false)
	if ladders.size() > 0:
		_multi(rail_mesh, rail_mat, ladders, [], false)
	if tanks.size() > 0:
		var tank := CylinderMesh.new()
		tank.top_radius = 0.5; tank.bottom_radius = 0.5; tank.height = 1.0; tank.radial_segments = 14
		var wood := _std(Color(0.4, 0.3, 0.22), 0.8)
		_multi(tank, wood, tanks)
		var cone := CylinderMesh.new()
		cone.top_radius = 0.02; cone.bottom_radius = 0.55; cone.height = 0.4; cone.radial_segments = 14
		var tops := []
		var legs := []
		for xf in tanks:
			tops.append(Transform3D(xf.basis, xf.origin + Vector3(0, 1.1, 0)))
			for k in 4:
				var a := k * PI * 0.5 + PI * 0.25
				legs.append(Transform3D(Basis.from_scale(Vector3(0.1, 1.2, 0.1)), xf.origin + Vector3(cos(a) * 0.7, -1.5, sin(a) * 0.7)))
		_multi(cone, _std(Color(0.22, 0.2, 0.2), 0.6), tops)
		_multi(BoxMesh.new(), _std(Color(0.08, 0.08, 0.08), 0.5, 0.5), legs, [], false)

func _railing_shader() -> Shader:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode cull_disabled;
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float bar = step(fract(wp.z / 0.16), 0.22);
	float top = step(0.9, UV.y) * step(UV.y, 0.96) + step(0.08, UV.y) * step(UV.y, 0.12);
	if (max(bar, top) < 0.5) discard;
	ALBEDO = vec3(0.04, 0.05, 0.045);
	METALLIC = 0.6;
	ROUGHNESS = 0.35;
}
"""
	return sh

# ---------------------------------------------------------------- gas lamps and plane trees

func _lamps_and_trees() -> void:
	var gas: bool = look.get("lamps", "gas") == "gas"
	var lamp_col: Color = {"gas": Color(1.0, 0.7, 0.38), "modern": Color(0.95, 0.92, 0.85), "neon": look.get("neon_b", Color(0.3, 0.9, 1.0))}[look.get("lamps", "gas")]
	var bases := []; var poles := []; var bars := []; var lanterns := []; var caps := []
	var halos := []; var halos_big := []; var pools := []
	var trunks := []; var crowns := []
	for s in [-1.0, 1.0]:
		var z := z_start - (0.0 if s < 0 else 6.5)
		var n := 0
		while z > z_end:
			var x: float = s * (ROAD_HW + 0.75)
			if gas:
				bases.append(Transform3D(Basis.from_scale(Vector3(0.32, 0.6, 0.32)), Vector3(x, WALK_Y + 0.3, z)))
				poles.append(Transform3D(Basis.from_scale(Vector3(0.11, 3.7, 0.11)), Vector3(x, WALK_Y + 2.15, z)))
				bars.append(_box_xf(Vector3(x, WALK_Y + 3.45, z), Vector3(0.7, 0.05, 0.05)))
				var lp := Vector3(x, WALK_Y + 4.25, z)
				lanterns.append(_box_xf(lp, Vector3(0.38, 0.55, 0.38)))
				caps.append(Transform3D(Basis.from_scale(Vector3(0.6, 0.32, 0.6)), lp + Vector3(0, 0.42, 0)))
				halos.append(Transform3D(Basis.from_scale(Vector3.ONE * 1.5), lp))
				halos_big.append(Transform3D(Basis.from_scale(Vector3.ONE * 5.0), lp))
				pools.append(Transform3D(Basis.from_scale(Vector3(5.5, 1, 5.5)), Vector3(x - s * 0.6, WALK_Y + 0.02, z)))
			else:
				# a tall modern pole with an arm out over the road and a flat LED head
				var ph := 6.6
				bases.append(Transform3D(Basis.from_scale(Vector3(0.26, 0.4, 0.26)), Vector3(x, WALK_Y + 0.2, z)))
				poles.append(Transform3D(Basis.from_scale(Vector3(0.12, ph, 0.12)), Vector3(x, WALK_Y + ph * 0.5, z)))
				bars.append(_box_xf(Vector3(x - s * 0.8, WALK_Y + ph, z), Vector3(1.7, 0.09, 0.09)))
				var lp := Vector3(x - s * 1.55, WALK_Y + ph - 0.1, z)
				lanterns.append(_box_xf(lp, Vector3(0.65, 0.1, 0.32)))
				halos.append(Transform3D(Basis.from_scale(Vector3.ONE * 1.4), lp - Vector3(0, 0.15, 0)))
				halos_big.append(Transform3D(Basis.from_scale(Vector3.ONE * 6.0), lp))
				pools.append(Transform3D(Basis.from_scale(Vector3(6.5, 1, 6.5)), Vector3(lp.x, ROAD_Y + 0.02, z)))
			# a tree halfway between every other pair of lamps: London planes, Paris chestnuts, Istanbul's tall cypresses
			if n % 2 == 1:
				var tz := z + 6.5
				var tx: float = s * (ROAD_HW + 1.25)
				if look.trees == "none":
					pass
				elif look.trees == "palm":
					# a tall palm leaning a little toward the street, a crown of drooping fronds
					var ph := 6.5 + rng.randf() * 2.5
					var lean: float = -s * 0.06
					trunks.append(Transform3D(Basis.from_scale(Vector3(0.24, ph, 0.24)).rotated(Vector3.FORWARD, lean), Vector3(tx - s * ph * 0.03, WALK_Y + ph * 0.5, tz)))
					var top := Vector3(tx - s * ph * 0.06, WALK_Y + ph, tz)
					for k in 8:
						var a := k * TAU / 8.0 + rng.randf() * 0.3
						var d := Vector3(cos(a), 0, sin(a))
						# each frond: a long flat leaf reaching out and drooping (stretched along its own length)
						var fb := Basis.looking_at((d + Vector3(0, -0.45, 0)).normalized(), Vector3.UP).scaled_local(Vector3(0.75, 0.16, 2.6))
						crowns.append(Transform3D(fb, top + d * 1.15 - Vector3(0, 0.45, 0)))
					crowns.append(Transform3D(Basis.from_scale(Vector3(0.7, 0.6, 0.7)), top))
				elif look.trees == "pine":
					# a Roman umbrella pine: a tall bare trunk and a wide flat crown
					var ph := 6.0 + rng.randf() * 2.0
					trunks.append(Transform3D(Basis.from_scale(Vector3(0.3, ph, 0.3)), Vector3(tx, WALK_Y + ph * 0.5, tz)))
					crowns.append(Transform3D(Basis.from_scale(Vector3(3.4, 1.1, 3.0)), Vector3(tx + s * 0.3, WALK_Y + ph + 0.4, tz)))
					crowns.append(Transform3D(Basis.from_scale(Vector3(2.4, 0.9, 2.2)), Vector3(tx - s * 0.6, WALK_Y + ph + 0.8, tz + 0.8)))
				elif look.trees == "cypress":
					trunks.append(Transform3D(Basis.from_scale(Vector3(0.24, 1.6, 0.24)), Vector3(tx, WALK_Y + 0.8, tz)))
					var th := 6.5 + rng.randf() * 3.0
					crowns.append(Transform3D(Basis.from_scale(Vector3(0.85, th * 0.5, 0.85)), Vector3(tx, WALK_Y + 1.2 + th * 0.5, tz)))
					crowns.append(Transform3D(Basis.from_scale(Vector3(0.6, th * 0.32, 0.6)), Vector3(tx, WALK_Y + 1.2 + th * 0.82, tz)))
				else:
					trunks.append(Transform3D(Basis.from_scale(Vector3(0.36, 4.4, 0.36)), Vector3(tx, WALK_Y + 2.2, tz)))
					for k in 4:
						var r := 1.4 + rng.randf() * 0.7
						var off := Vector3((rng.randf() - 0.5) * 1.6 + s * 0.3, 4.4 + rng.randf() * 1.6 + k * 0.35, (rng.randf() - 0.5) * 2.2)
						crowns.append(Transform3D(Basis.from_scale(Vector3(r, r * 0.85, r)).rotated(Vector3.UP, rng.randf() * TAU), Vector3(tx, WALK_Y, tz) + off))
			z -= 13.0
			n += 1
	var iron := _std(Color(0.06, 0.08, 0.07), 0.4, 0.6)
	var cyl := CylinderMesh.new()
	cyl.radial_segments = 10; cyl.top_radius = 0.5; cyl.bottom_radius = 0.5; cyl.height = 1.0
	_multi(cyl, iron, bases)
	_multi(cyl, iron, poles)
	_multi(BoxMesh.new(), iron, bars, [], false)
	_multi(BoxMesh.new(), _std(lamp_col, 0.2, 0.0, lamp_col, 4.0), lanterns, [], false)
	var cap := CylinderMesh.new()
	cap.top_radius = 0.05; cap.bottom_radius = 0.5; cap.height = 1.0; cap.radial_segments = 4
	_multi(cap, iron, caps, [], false)
	var quad := QuadMesh.new()
	_multi(quad, _mat("res://shaders/halo.gdshader", {"tint": lamp_col, "energy": 1.1, "fade": 0.012}), halos, [], false)
	big_halos = _multi(quad, _mat("res://shaders/halo.gdshader", {"tint": lamp_col, "energy": 0.16, "fade": 0.01}), halos_big, [], false)
	var pool := _mat_pool()
	pool.set_shader_parameter("tint", lamp_col)
	_multi(_pool_mesh(), pool, pools, [], false)
	var bark := _std(Color(0.42, 0.4, 0.33), 0.85)
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.35; trunk.bottom_radius = 0.5; trunk.height = 1.0; trunk.radial_segments = 8
	if trunks.is_empty() or look.trees == "none":
		return
	if look.trees == "palm":
		bark = _std(Color(0.5, 0.42, 0.32), 0.9)
	_multi(trunk, bark, trunks)
	var crown := SphereMesh.new()
	crown.radial_segments = 14; crown.rings = 8
	var leaves := ShaderMaterial.new()
	leaves.shader = _leaves_shader()
	var greens: Array = {"plane": [Color(0.16, 0.22, 0.09), Color(0.36, 0.42, 0.16)], "chestnut": [Color(0.2, 0.3, 0.1), Color(0.44, 0.52, 0.2)],
		"cypress": [Color(0.06, 0.12, 0.07), Color(0.16, 0.24, 0.12)], "palm": [Color(0.14, 0.24, 0.08), Color(0.42, 0.52, 0.18)],
		"pine": [Color(0.1, 0.16, 0.07), Color(0.26, 0.34, 0.14)], "none": [Color.BLACK, Color.BLACK]}[look.trees]
	leaves.set_shader_parameter("dark", greens[0])
	leaves.set_shader_parameter("light", greens[1])
	_multi(crown, leaves, crowns)

func _pool_mesh() -> PlaneMesh:
	var p := PlaneMesh.new()
	p.size = Vector2(1, 1)
	return p

## the pool of lamplight on the wet pavement and road
func _mat_pool() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, shadows_disabled, fog_disabled;
uniform vec3 tint : source_color = vec3(1.0, 0.62, 0.3);
void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float f = exp(-length(VERTEX) * 0.02);
	ALBEDO = tint * pow(clamp(1.0 - d, 0.0, 1.0), 2.2) * 0.32 * f;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m

func _leaves_shader() -> Shader:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
uniform vec3 dark : source_color = vec3(0.16, 0.22, 0.09);
uniform vec3 light : source_color = vec3(0.36, 0.42, 0.16);
varying vec3 wp;
// a hash without sine (stable on every GPU, phones included)
float h21(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
float vn(vec3 p) {
	vec3 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(h21(i.xy + i.z * 7.1), h21(i.xy + vec2(1, 0) + i.z * 7.1), f.x);
	float b = mix(h21(i.xy + vec2(0, 1) + i.z * 7.1), h21(i.xy + vec2(1, 1) + i.z * 7.1), f.x);
	return mix(a, b, f.y);
}
void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// lumpy, leafy silhouettes instead of smooth balls
	VERTEX += NORMAL * (vn(w * 1.3) - 0.5) * 0.5;
	wp = w;
}
void fragment() {
	float n = vn(wp * 3.0) * 0.6 + vn(wp * 7.0) * 0.4;
	ALBEDO = mix(dark, light, n);
	ROUGHNESS = 0.7;
	SPECULAR = 0.3;
	BACKLIGHT = vec3(0.35, 0.4, 0.12);
}
"""
	return sh

# ---------------------------------------------------------------- the skyline at the end of the street

func _sil(depth: float, ribs := 0.6) -> ShaderMaterial:
	return _mat("res://shaders/silhouette.gdshader", {"depth": depth, "ribs": ribs})

func _skyline() -> void:
	far = Node3D.new()
	add_child(far)
	match look.landmark:
		"mosque":
			_mosque()
		"eiffel":
			_eiffel()
		"deco":
			_deco()
		"capitolio":
			_capitolio()
		"stephansdom":
			_stephansdom()
		"cairo":
			_pyramids()
			_mosque()
		"rome":
			_rome()
		"burj", "rio", "mbs", "goldengate", "opera", "tablemountain", "sagrada", "hallgrims":
			call("_lm_" + look.landmark)
			_roofscape()
			return
		"hk", "skytree", "ziggurat", "pearl", "seoul", "fernsehturm", "miami", "vegas":
			_future_skyline()
			call("_lm_" + look.landmark)
			return
		_:
			_bigben()
	_roofscape()

func _sil_h(depth: float, ribs := 0.6) -> ShaderMaterial:
	var m := _sil(depth, ribs)
	m.set_shader_parameter("haze_col", look.haze)
	return m

## a great mosque on the skyline: a square hall, a big dome on semidomes, and four slender minarets
func _mosque() -> void:
	var mos := Node3D.new()
	mos.position = Vector3(-4.0, ROAD_Y, 0.0)
	far.add_child(mos)
	var m := _sil_h(0.34, 0.0)
	var dome := SphereMesh.new()
	dome.radial_segments = 32; dome.rings = 16; dome.is_hemisphere = true
	_part(mos, BoxMesh.new(), m, Vector3(0, 9, 0), Vector3(40, 18, 34))
	_part(mos, _cyl1(), m, Vector3(0, 21, 0), Vector3(22, 6, 22))
	_part(mos, dome, m, Vector3(0, 24, 0), Vector3(14, 13, 14))
	for d in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
		_part(mos, dome, m, Vector3(0, 18, 0) + d * 12.0, Vector3(9, 7, 9))
	for c in [Vector3(-14, 0, -12), Vector3(14, 0, -12), Vector3(-14, 0, 12), Vector3(14, 0, 12)]:
		_part(mos, dome, m, Vector3(c.x, 18, c.z), Vector3(4, 4, 4))
	var spire := CylinderMesh.new()
	spire.top_radius = 0.02; spire.bottom_radius = 0.5; spire.height = 1.0; spire.radial_segments = 10
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.5; shaft.bottom_radius = 0.5; shaft.height = 1.0; shaft.radial_segments = 12
	for c in [Vector3(-27, 0, -20), Vector3(27, 0, -20), Vector3(-27, 0, 20), Vector3(27, 0, 20)]:
		_part(mos, shaft, m, c + Vector3(0, 30, 0), Vector3(2.2, 60, 2.2))
		for by in [36.0, 48.0]:
			_part(mos, shaft, m, c + Vector3(0, by, 0), Vector3(3.4, 1.0, 3.4))
		_part(mos, spire, m, c + Vector3(0, 66, 0), Vector3(2.4, 12, 2.4))
	# the lamps of the courtyard and the gallery of each minaret, warm in the dusk
	var glow_mat := _mat("res://shaders/halo.gdshader", {"tint": Color(1.0, 0.72, 0.45), "energy": 0.9, "fade": 0.0})
	for c in [Vector3(-27, 0, -20), Vector3(27, 0, -20)]:
		var h := MeshInstance3D.new()
		h.mesh = QuadMesh.new()
		h.material_override = glow_mat
		h.position = c + Vector3(0, 48, 2)
		h.scale = Vector3.ONE * 5.0
		mos.add_child(h)
	# a second mosque further off, and the Galata tower on the left
	var m2 := _sil_h(0.6, 0.0)
	_part(far, dome, m2, Vector3(95, ROAD_Y + 16, 110), Vector3(16, 14, 16))
	_part(far, BoxMesh.new(), m2, Vector3(95, ROAD_Y + 8, 110), Vector3(34, 16, 30))
	for sx in [-1.0, 1.0]:
		_part(far, shaft, m2, Vector3(95 + sx * 22, ROAD_Y + 26, 110), Vector3(1.8, 52, 1.8))
		_part(far, spire, m2, Vector3(95 + sx * 22, ROAD_Y + 57, 110), Vector3(2.0, 10, 2.0))
	var gal := _sil_h(0.5, 0.0)
	_part(far, shaft, gal, Vector3(-80, ROAD_Y + 22, 60), Vector3(9, 44, 9))
	_part(far, spire, gal, Vector3(-80, ROAD_Y + 50, 60), Vector3(11, 12, 11))

## the Eiffel Tower at the end of the street: four legs in iron lattice meeting in a spire, its platforms lit
func _eiffel() -> void:
	var tw := Node3D.new()
	tw.position = Vector3(2.0, ROAD_Y, -90.0)
	tw.scale = Vector3.ONE * 0.72
	far.add_child(tw)
	var iron := _sil_h(0.3, 0.0)
	iron.set_shader_parameter("lattice", 1.0)
	iron.set_shader_parameter("near_col", Color(0.24, 0.2, 0.22))
	var solid := _sil_h(0.3, 0.0)
	solid.set_shader_parameter("near_col", Color(0.24, 0.2, 0.22))
	# each leg: a tapering box leaning in toward the middle
	var leg := CylinderMesh.new()
	leg.top_radius = 0.35; leg.bottom_radius = 0.5; leg.height = 1.0; leg.radial_segments = 4
	var hgt := [0.0, 40.0, 80.0, 150.0]
	var half := [34.0, 17.0, 7.0, 0.6]
	var thick := [11.0, 6.0, 4.0, 2.5]
	for k in 3:
		for c in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			var a := Vector3(c.x * half[k], hgt[k], c.y * half[k])
			var b := Vector3(c.x * half[k + 1], hgt[k + 1], c.y * half[k + 1])
			if k == 2:
				b = Vector3(c.x * half[3] * 2.0, hgt[3] - 10.0, c.y * half[3] * 2.0)
			var p := MeshInstance3D.new()
			p.mesh = leg
			p.material_override = iron
			var dir := (b - a)
			p.position = (a + b) * 0.5
			p.basis = Basis.looking_at(dir.normalized(), Vector3.FORWARD if absf(dir.normalized().y) > 0.99 else Vector3.UP) * Basis(Vector3.RIGHT, PI * 0.5)
			p.basis = p.basis.scaled_local(Vector3(thick[k], dir.length(), thick[k]))
			p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			tw.add_child(p)
	# the arches under the first platform, and the platforms
	_part(tw, BoxMesh.new(), iron, Vector3(0, 40, 0), Vector3(38, 2.2, 38))
	_part(tw, BoxMesh.new(), iron, Vector3(0, 80, 0), Vector3(19, 1.6, 19))
	_part(tw, BoxMesh.new(), solid, Vector3(0, 140, 0), Vector3(5, 3, 5))
	var spire := CylinderMesh.new()
	spire.top_radius = 0.05; spire.bottom_radius = 0.5; spire.height = 1.0; spire.radial_segments = 6
	_part(tw, spire, solid, Vector3(0, 152, 0), Vector3(2.6, 20, 2.6))
	var arch := TorusMesh.new()
	arch.inner_radius = 0.86; arch.outer_radius = 1.0; arch.rings = 32; arch.ring_segments = 4
	for r in [0.0, PI * 0.5]:
		var a := MeshInstance3D.new()
		a.mesh = arch
		a.material_override = solid
		a.position = Vector3(0, 22, 0)
		a.basis = Basis(Vector3.UP, r) * Basis(Vector3.RIGHT, PI * 0.5) * Basis.from_scale(Vector3(26, 1, 20))
		tw.add_child(a)
	# lights on the platforms and the beacon at the top
	var glow_mat := _mat("res://shaders/halo.gdshader", {"tint": Color(1.0, 0.78, 0.48), "energy": 0.7, "fade": 0.0})
	for y in [40.0, 80.0, 140.0]:
		var h := MeshInstance3D.new()
		h.mesh = QuadMesh.new()
		h.material_override = glow_mat
		h.position = Vector3(0, y, 14)
		h.scale = Vector3(40, 6, 1) if y < 100 else Vector3(10, 10, 1)
		tw.add_child(h)
	var bm := _mat("res://shaders/halo.gdshader", {"tint": Color(1.0, 0.9, 0.7), "energy": 1.6, "fade": 0.0})
	var beacon := MeshInstance3D.new()
	beacon.mesh = QuadMesh.new()
	beacon.material_override = bm
	beacon.position = Vector3(0, 162, 4)
	beacon.scale = Vector3.ONE * 9.0
	tw.add_child(beacon)
	# the dome of the Invalides on the right
	var dome := SphereMesh.new()
	dome.radial_segments = 24; dome.rings = 12; dome.is_hemisphere = true
	var gold := _sil_h(0.5, 0.0)
	_part(far, _cyl1(), gold, Vector3(90, ROAD_Y + 18, 90), Vector3(20, 14, 20))
	_part(far, dome, gold, Vector3(90, ROAD_Y + 25, 90), Vector3(11, 14, 11))
	_part(far, spire, gold, Vector3(90, ROAD_Y + 44, 90), Vector3(1.6, 10, 1.6))

func _glow_at(parent: Node3D, pos: Vector3, size: Vector3, col: Color, e: float) -> void:
	var h := MeshInstance3D.new()
	h.mesh = QuadMesh.new()
	h.material_override = _mat("res://shaders/halo.gdshader", {"tint": col, "energy": e, "fade": 0.0})
	h.position = pos
	h.scale = size
	parent.add_child(h)

## a cylinder one unit tall (Godot's default is two), so a part's scale is its size
func _cyl1(seg := 24) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = 0.5; c.bottom_radius = 0.5; c.height = 1.0; c.radial_segments = seg
	return c

func _spire_mesh(seg := 4) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = 0.02; c.bottom_radius = 0.5; c.height = 1.0; c.radial_segments = seg
	return c

# ---------------------------------------------------------------- landmarks of the Present

func _lm_burj() -> void:
	# the Burj Khalifa: a needle of stepped wings, and the sail of the Burj Al Arab off to the left
	var m := _sil_h(0.3, 1.0)
	m.set_shader_parameter("lights", 0.25)
	var c := Node3D.new()
	c.position = Vector3(6.0, ROAD_Y, -60.0)
	far.add_child(c)
	var h := 0.0
	for k in 7:
		var w := 22.0 - k * 2.8
		var hh := 26.0 - k * 1.5
		_part(c, BoxMesh.new(), m, Vector3(0, h + hh * 0.5, 0), Vector3(w, hh, w * 0.7))
		h += hh
	_part(c, _spire_mesh(6), m, Vector3(0, h + 22, 0), Vector3(3.5, 44, 3.5))
	_glow_at(c, Vector3(0, h + 44, 2), Vector3.ONE * 6.0, Color(1.0, 0.85, 0.6), 1.0)
	var sail := _sil_h(0.45, 0.0)
	var arab := MeshInstance3D.new()
	arab.mesh = SphereMesh.new()
	arab.material_override = sail
	arab.position = Vector3(-70, ROAD_Y + 40, 40)
	arab.scale = Vector3(14, 80, 26)
	far.add_child(arab)

func _lm_rio() -> void:
	# Sugarloaf and Corcovado with the statue of Christ, its arms out, lit
	var m := _sil_h(0.42, 0.0)
	for p in [[Vector3(-50, 0, 0), Vector3(40, 90, 40)], [Vector3(-80, 0, 30), Vector3(30, 50, 30)], [Vector3(60, 0, -20), Vector3(70, 130, 60)]]:
		var mi := MeshInstance3D.new()
		mi.mesh = SphereMesh.new()
		mi.material_override = m
		mi.position = p[0] + Vector3(0, ROAD_Y, 0)
		mi.scale = p[1]
		far.add_child(mi)
	var st := _sil_h(0.25, 0.0)
	st.set_shader_parameter("near_col", Color(0.95, 0.92, 0.85))
	_part(far, BoxMesh.new(), st, Vector3(60, ROAD_Y + 71, -20), Vector3(2.0, 10, 2.0))
	_part(far, BoxMesh.new(), st, Vector3(60, ROAD_Y + 74, -20), Vector3(11, 1.6, 1.6))
	_glow_at(far, Vector3(60, ROAD_Y + 72, -16), Vector3.ONE * 16.0, Color(1.0, 0.9, 0.7), 0.5)

func _lm_mbs() -> void:
	# Marina Bay Sands: three towers carrying a long deck, and the glowing Supertrees beside them
	var m := _sil_h(0.32, 0.0)
	m.set_shader_parameter("lights", 0.6)
	var c := Node3D.new()
	c.position = Vector3(0, ROAD_Y, 0)
	far.add_child(c)
	for k in 3:
		_part(c, BoxMesh.new(), m, Vector3(-24 + k * 24, 36, 0), Vector3(12, 72, 14), (k - 1) * 0.08)
	_part(c, BoxMesh.new(), m, Vector3(6, 74, 0), Vector3(78, 4, 16))
	for k in 6:
		var x := -70.0 + k * 9.0
		var tr := _sil_h(0.4, 0.0)
		var tree_m := CylinderMesh.new()
		tree_m.top_radius = 0.5; tree_m.bottom_radius = 0.12; tree_m.height = 1.0; tree_m.radial_segments = 10
		_part(far, tree_m, tr, Vector3(x, ROAD_Y + 16, 50), Vector3(8, 32, 8))
		_glow_at(far, Vector3(x, ROAD_Y + 32, 53), Vector3(14, 4, 1), Color(0.6, 0.4, 1.0) if k % 2 else Color(0.3, 1.0, 0.7), 0.8)

func _lm_goldengate() -> void:
	# the Golden Gate's two red towers and its cables, rising out of the fog
	var red := _sil_h(0.4, 0.0)
	red.set_shader_parameter("near_col", Color(0.7, 0.18, 0.1))
	var c := Node3D.new()
	c.position = Vector3(0, ROAD_Y, 0)
	far.add_child(c)
	for tx in [-45.0, 45.0]:
		for sx in [-4.0, 4.0]:
			_part(c, BoxMesh.new(), red, Vector3(tx + sx, 45, 0), Vector3(3, 90, 3))
		for y in [30.0, 55.0, 80.0]:
			_part(c, BoxMesh.new(), red, Vector3(tx, y, 0), Vector3(10, 3, 3))
	_part(c, BoxMesh.new(), red, Vector3(0, 22, 0), Vector3(200, 3, 6))
	# the main cables as long sagging arcs
	for k in 40:
		var x := -90.0 + k * 4.5
		var d := absf(x) - 45.0
		var y := 88.0 - 60.0 * (1.0 - pow(clampf(absf(x) / 45.0, 0.0, 1.0) * 1.0, 2.0)) if absf(x) <= 45.0 else 88.0 - d * 1.2
		_part(c, BoxMesh.new(), red, Vector3(x, y, 0), Vector3(4.6, 0.8, 0.8))
	var tp := _sil_h(0.55, 0.0)
	_part(far, _spire_mesh(4), tp, Vector3(90, ROAD_Y + 50, 70), Vector3(18, 100, 18), PI * 0.25)

func _lm_opera() -> void:
	# the Opera House's white shells on the water, and the Harbour Bridge's arch behind
	var white := _sil_h(0.28, 0.0)
	white.set_shader_parameter("near_col", Color(0.95, 0.93, 0.88))
	var c := Node3D.new()
	c.position = Vector3(-10, ROAD_Y, 0)
	far.add_child(c)
	_part(c, BoxMesh.new(), white, Vector3(0, 4, 0), Vector3(70, 8, 30))
	var shell := SphereMesh.new()
	shell.is_hemisphere = true; shell.radial_segments = 24; shell.rings = 10
	for k in 5:
		var sh := MeshInstance3D.new()
		sh.mesh = shell
		sh.material_override = white
		sh.position = Vector3(-22 + k * 11, 8, 0)
		sh.basis = Basis(Vector3.FORWARD, -0.5).scaled(Vector3(9 - k * 0.8, 28 - k * 3, 12))
		c.add_child(sh)
	var steel := _sil_h(0.5, 0.0)
	var arch := TorusMesh.new()
	arch.inner_radius = 0.92; arch.outer_radius = 1.0; arch.rings = 40; arch.ring_segments = 4
	var a := MeshInstance3D.new()
	a.mesh = arch
	a.material_override = steel
	a.position = Vector3(60, ROAD_Y, 60)
	a.basis = Basis(Vector3.RIGHT, PI * 0.5).scaled(Vector3(70, 1, 50))
	far.add_child(a)
	_part(far, BoxMesh.new(), steel, Vector3(60, ROAD_Y + 25, 60), Vector3(140, 3, 8))

func _lm_tablemountain() -> void:
	# Table Mountain's long flat top, Devil's Peak and Lion's Head on either side
	var m := _sil_h(0.4, 0.0)
	var top := MeshInstance3D.new()
	top.mesh = _mansard()
	top.material_override = m
	top.position = Vector3(0, ROAD_Y, 10)
	top.basis = Basis(Vector3.UP, PI * 0.5).scaled(Vector3(60, 90, 220))
	far.add_child(top)
	_part(far, _spire_mesh(8), m, Vector3(110, ROAD_Y + 45, 0), Vector3(60, 90, 60))
	_part(far, _spire_mesh(8), m, Vector3(-120, ROAD_Y + 35, 30), Vector3(50, 70, 50))

func _lm_sagrada() -> void:
	# the Sagrada Familia: clusters of tall rounded spires, the tallest in the middle, cranes still at work
	var m := _sil_h(0.34, 2.2)
	var c := Node3D.new()
	c.position = Vector3(2, ROAD_Y, 0)
	far.add_child(c)
	_part(c, BoxMesh.new(), m, Vector3(0, 20, 0), Vector3(70, 40, 40))
	var sp := CylinderMesh.new()
	sp.top_radius = 0.08; sp.bottom_radius = 0.5; sp.height = 1.0; sp.radial_segments = 12
	for k in 4:
		for side in [-1.0, 1.0]:
			_part(c, sp, m, Vector3(side * (12 + k * 5), 40 + 25 - k * 2, -10), Vector3(6, 50 - k * 4, 6))
	_part(c, sp, m, Vector3(0, 80, 5), Vector3(14, 90, 14))
	_glow_at(c, Vector3(0, 126, 8), Vector3.ONE * 6, Color(1.0, 0.9, 0.7), 0.9)
	var crane := _sil_h(0.5, 0.0)
	_part(c, BoxMesh.new(), crane, Vector3(40, 60, 10), Vector3(1.5, 120, 1.5))
	_part(c, BoxMesh.new(), crane, Vector3(30, 118, 10), Vector3(40, 1.5, 1.5))

func _lm_hallgrims() -> void:
	# Hallgrimskirkja's stepped concrete tower, and snowy mountains across the bay
	var m := _sil_h(0.3, 2.6)
	m.set_shader_parameter("near_col", Color(0.55, 0.58, 0.66))
	var c := Node3D.new()
	c.position = Vector3(3, ROAD_Y, 0)
	far.add_child(c)
	for k in 6:
		_part(c, BoxMesh.new(), m, Vector3(-12 + k * 2.0 + 0.0, 12 + k * 7, 0), Vector3(4, 24 + k * 14, 14))
		_part(c, BoxMesh.new(), m, Vector3(12 - k * 2.0, 12 + k * 7, 0), Vector3(4, 24 + k * 14, 14))
	_part(c, BoxMesh.new(), m, Vector3(0, 50, 0), Vector3(9, 100, 12))
	_part(c, _spire_mesh(4), m, Vector3(0, 108, 0), Vector3(9, 16, 12), PI * 0.25)
	_glow_at(c, Vector3(0, 80, 7), Vector3(5, 5, 1), Color(1.0, 0.85, 0.6), 0.8)
	var snow := _sil_h(0.6, 0.0)
	snow.set_shader_parameter("near_col", Color(0.8, 0.85, 0.95))
	for p in [Vector3(-110, 0, 60), Vector3(-40, 0, 90), Vector3(80, 0, 80)]:
		_part(far, _spire_mesh(8), snow, p + Vector3(0, ROAD_Y + 30, 0), Vector3(110, 60, 60))

# ---------------------------------------------------------------- the Future: megacities and their towers

func _future_skyline() -> void:
	# a forest of lit towers behind every Future city
	var lit := _sil_h(0.35, 0.0)
	lit.set_shader_parameter("lights", 1.0)
	lit.set_shader_parameter("near_col", Color(0.06, 0.06, 0.1))
	var far_lit := _sil_h(0.55, 0.0)
	far_lit.set_shader_parameter("lights", 0.7)
	far_lit.set_shader_parameter("near_col", Color(0.06, 0.06, 0.1))
	for layer in 2:
		for i in 22:
			var x := -120.0 + i * 11.0 + rng.randf() * 6.0
			if absf(x) < 14.0:
				continue
			var h := 50.0 + rng.randf() * 90.0
			_part(far, BoxMesh.new(), lit if layer == 0 else far_lit, Vector3(x, ROAD_Y + h * 0.5, 40.0 + layer * 60.0 + rng.randf() * 30.0), Vector3(9 + rng.randf() * 8, h, 10))
	var beam_mat := _mat("res://shaders/beam.gdshader")
	for k in 3:
		var b := MeshInstance3D.new()
		b.mesh = QuadMesh.new()
		b.material_override = beam_mat
		b.position = Vector3(-50.0 + k * 50.0, ROAD_Y, 90.0)
		b.scale = Vector3(6.0, 260.0, 1.0)
		far.add_child(b)
		searchlights.append(b)

func _neon_mat(col: Color, e := 2.4) -> StandardMaterial3D:
	var m := _std(col, 0.3, 0.0, col, e)
	m.disable_fog = true
	return m

func _lm_hk() -> void:
	# a Bank of China-like tower of stacked triangles, outlined in neon
	var m := _sil_h(0.28, 0.0)
	m.set_shader_parameter("lights", 0.8)
	m.set_shader_parameter("near_col", Color(0.08, 0.08, 0.12))
	var c := Node3D.new()
	c.position = Vector3(4, ROAD_Y, -40)
	far.add_child(c)
	var h := 0.0
	for k in 4:
		var hh := 40.0 - k * 4.0
		_part(c, _spire_mesh(3), m, Vector3(0, h + hh * 0.5, 0), Vector3(30 - k * 6, hh, 30 - k * 6), k * 0.6)
		h += hh * 0.8
	_part(c, _spire_mesh(4), m, Vector3(0, h + 20, 0), Vector3(2, 40, 2))
	for k in 6:
		_part(c, BoxMesh.new(), _neon_mat(look.neon_a), Vector3(0, 10 + k * 22, 8 - k), Vector3(26 - k * 3.5, 0.4, 0.4))
	_glow_at(c, Vector3(0, h + 40, 3), Vector3.ONE * 8, look.neon_b, 1.2)

func _lm_skytree() -> void:
	# the Tokyo Skytree: a tall tapering lattice with two observation rings, lit blue and violet
	var m := _sil_h(0.3, 0.0)
	m.set_shader_parameter("lattice", 1.0)
	m.set_shader_parameter("near_col", Color(0.3, 0.32, 0.4))
	var c := Node3D.new()
	c.position = Vector3(3, ROAD_Y, -60)
	far.add_child(c)
	var tw := CylinderMesh.new()
	tw.top_radius = 0.12; tw.bottom_radius = 0.5; tw.height = 1.0; tw.radial_segments = 12
	_part(c, tw, m, Vector3(0, 90, 0), Vector3(24, 180, 24))
	var ring := TorusMesh.new()
	ring.inner_radius = 0.7; ring.outer_radius = 1.0; ring.rings = 24; ring.ring_segments = 6
	for y in [110.0, 150.0]:
		_part(c, ring, _neon_mat(look.neon_b, 2.0), Vector3(0, y, 0), Vector3(9, 4, 9))
	_part(c, _spire_mesh(6), m, Vector3(0, 200, 0), Vector3(2, 40, 2))
	_glow_at(c, Vector3(0, 220, 2), Vector3.ONE * 7, look.neon_a, 1.2)

func _lm_ziggurat() -> void:
	# a vast stepped pyramid with fire on its flanks, the old corporate temple of the city
	var m := _sil_h(0.28, 0.0)
	m.set_shader_parameter("lights", 0.9)
	m.set_shader_parameter("near_col", Color(0.1, 0.07, 0.06))
	var c := Node3D.new()
	c.position = Vector3(0, ROAD_Y, -40)
	far.add_child(c)
	for k in 6:
		_part(c, BoxMesh.new(), m, Vector3(0, 10 + k * 18, 0), Vector3(140 - k * 22, 20, 90 - k * 13))
	for sx in [-1.0, 1.0]:
		_glow_at(c, Vector3(sx * 62, 30, 46), Vector3(8, 16, 1), Color(1.0, 0.5, 0.15), 1.4)

func _lm_pearl() -> void:
	# the Oriental Pearl Tower: lit spheres strung on columns, and the twisting Shanghai Tower beside it
	var m := _sil_h(0.3, 0.0)
	m.set_shader_parameter("near_col", Color(0.12, 0.1, 0.16))
	var c := Node3D.new()
	c.position = Vector3(-6, ROAD_Y, -40)
	far.add_child(c)
	for sx in [-4.0, 0.0, 4.0]:
		_part(c, _cyl1(), m, Vector3(sx, 50, 0), Vector3(2.6, 100, 2.6))
	var ball := SphereMesh.new()
	ball.radial_segments = 24; ball.rings = 12
	_part(c, ball, _neon_mat(look.neon_b, 1.6), Vector3(0, 30, 0), Vector3.ONE * 26)
	_part(c, ball, _neon_mat(look.neon_a, 1.8), Vector3(0, 100, 0), Vector3.ONE * 18)
	_part(c, ball, _neon_mat(look.neon_b, 1.6), Vector3(0, 130, 0), Vector3.ONE * 8)
	_part(c, _spire_mesh(6), m, Vector3(0, 160, 0), Vector3(2, 50, 2))
	var st := _sil_h(0.4, 0.0)
	st.set_shader_parameter("lights", 0.8)
	st.set_shader_parameter("near_col", Color(0.08, 0.08, 0.12))
	for k in 8:
		_part(far, _cyl1(), st, Vector3(70, ROAD_Y + 12 + k * 22, 30), Vector3(26 - k * 2, 22, 22 - k * 1.5), k * 0.2)

func _lm_seoul() -> void:
	# N Seoul Tower on its hill, and a tall tapering supertower lit to the top
	var hill := _sil_h(0.4, 0.0)
	hill.set_shader_parameter("near_col", Color(0.05, 0.06, 0.1))
	var hm := MeshInstance3D.new()
	hm.mesh = SphereMesh.new()
	hm.material_override = hill
	hm.position = Vector3(-50, ROAD_Y, -10)
	hm.scale = Vector3(140, 70, 80)
	far.add_child(hm)
	var m := _sil_h(0.3, 0.0)
	m.set_shader_parameter("near_col", Color(0.4, 0.42, 0.5))
	_part(far, _cyl1(), m, Vector3(-50, ROAD_Y + 55, -10), Vector3(4, 40, 4))
	_part(far, _cyl1(), _neon_mat(look.neon_a, 1.6), Vector3(-50, ROAD_Y + 78, -10), Vector3(12, 6, 12))
	_part(far, _spire_mesh(6), m, Vector3(-50, ROAD_Y + 96, -10), Vector3(1.5, 30, 1.5))
	var t := _sil_h(0.32, 0.0)
	t.set_shader_parameter("lights", 1.0)
	t.set_shader_parameter("near_col", Color(0.06, 0.07, 0.12))
	_part(far, _spire_mesh(4), t, Vector3(40, ROAD_Y + 100, -30), Vector3(30, 200, 30), PI * 0.25)
	_glow_at(far, Vector3(40, ROAD_Y + 196, -26), Vector3.ONE * 7, look.neon_b, 1.2)

func _lm_fernsehturm() -> void:
	# Berlin's TV tower: a sphere on a thin column, its antenna blinking
	var m := _sil_h(0.3, 0.0)
	m.set_shader_parameter("near_col", Color(0.35, 0.36, 0.4))
	var c := Node3D.new()
	c.position = Vector3(4, ROAD_Y, -50)
	far.add_child(c)
	var col := CylinderMesh.new()
	col.top_radius = 0.3; col.bottom_radius = 0.5; col.height = 1.0; col.radial_segments = 16
	_part(c, col, m, Vector3(0, 55, 0), Vector3(9, 110, 9))
	var ball := SphereMesh.new()
	ball.radial_segments = 28; ball.rings = 14
	_part(c, ball, m, Vector3(0, 120, 0), Vector3.ONE * 26)
	_part(c, _cyl1(), _neon_mat(look.neon_a, 2.0), Vector3(0, 120, 0), Vector3(26.5, 1.2, 26.5))
	_part(c, _cyl1(), m, Vector3(0, 150, 0), Vector3(2.4, 40, 2.4))
	_glow_at(c, Vector3(0, 172, 2), Vector3.ONE * 6, Color(1.0, 0.2, 0.15), 1.4)

func _lm_miami() -> void:
	# a synthwave sun sinking into the sea, striped, with palms against it and pastel Deco towers
	var sun_m := ShaderMaterial.new()
	sun_m.shader = load("res://shaders/synthsun.gdshader")
	var sun := MeshInstance3D.new()
	sun.mesh = QuadMesh.new()
	sun.material_override = sun_m
	sun.position = Vector3(0, ROAD_Y + 40, -60)
	sun.scale = Vector3(120, 120, 1)
	far.add_child(sun)
	var m := _sil_h(0.35, 0.0)
	m.set_shader_parameter("lights", 0.5)
	m.set_shader_parameter("near_col", Color(0.25, 0.08, 0.25))
	for i in 10:
		var x := -100.0 + i * 22.0
		if absf(x) < 30.0:
			continue
		_part(far, BoxMesh.new(), m, Vector3(x, ROAD_Y + 25, 10), Vector3(16, 50 + (i % 3) * 20, 14))

func _lm_vegas() -> void:
	# the Stratosphere's pod on its column, and the Luxor's black pyramid sending its beam into the sky
	var m := _sil_h(0.3, 0.0)
	m.set_shader_parameter("near_col", Color(0.1, 0.08, 0.12))
	var c := Node3D.new()
	c.position = Vector3(-30, ROAD_Y, -30)
	far.add_child(c)
	_part(c, _cyl1(), m, Vector3(0, 70, 0), Vector3(8, 140, 8))
	_part(c, _cyl1(16), _neon_mat(look.neon_a, 2.0), Vector3(0, 142, 0), Vector3(22, 8, 22))
	_part(c, _spire_mesh(6), m, Vector3(0, 165, 0), Vector3(2, 40, 2))
	var pyr := _sil_h(0.3, 0.0)
	pyr.set_shader_parameter("near_col", Color(0.03, 0.03, 0.04))
	_part(far, _spire_mesh(4), pyr, Vector3(40, ROAD_Y + 35, -20), Vector3(100, 70, 100), PI * 0.25)
	var beam := MeshInstance3D.new()
	beam.mesh = QuadMesh.new()
	var bm := _mat("res://shaders/beam.gdshader")
	beam.material_override = bm
	beam.position = Vector3(40, ROAD_Y + 70, -20)
	beam.scale = Vector3(5, 400, 1)
	far.add_child(beam)

## Manhattan at night: stepped Art Deco towers with lit windows, a crowned spire, and searchlights sweeping the sky
func _deco() -> void:
	var lit := _sil_h(0.3, 0.0)
	lit.set_shader_parameter("lights", 1.0)
	lit.set_shader_parameter("near_col", Color(0.12, 0.12, 0.18))
	var far_lit := _sil_h(0.55, 0.0)
	far_lit.set_shader_parameter("lights", 0.7)
	far_lit.set_shader_parameter("near_col", Color(0.12, 0.12, 0.18))
	# the Empire State: setbacks and a mast
	var es := Node3D.new()
	es.position = Vector3(4.0, ROAD_Y, 0)
	far.add_child(es)
	# the shaft, then four setbacks, each narrower
	_part(es, BoxMesh.new(), lit, Vector3(0, 30, 0), Vector3(26, 60, 21))
	for k in range(1, 5):
		var w := 26.0 - k * 4.5
		_part(es, BoxMesh.new(), lit, Vector3(0, 60 + (k - 1) * 18 + 9, 0), Vector3(w, 18, w * 0.8))
	_part(es, _cyl1(), lit, Vector3(0, 142, 0), Vector3(4, 14, 4))
	_part(es, _spire_mesh(8), lit, Vector3(0, 162, 0), Vector3(2, 26, 2))
	_glow_at(es, Vector3(0, 176, 3), Vector3.ONE * 8.0, Color(1.0, 0.35, 0.3), 1.2)
	# the Chrysler crown on the left: stacked arches narrowing to a needle, lit
	var ch := Node3D.new()
	ch.position = Vector3(-46, ROAD_Y, 40)
	far.add_child(ch)
	_part(ch, BoxMesh.new(), lit, Vector3(0, 50, 0), Vector3(18, 100, 18))
	for k in 5:
		_part(ch, SphereMesh.new(), lit, Vector3(0, 100 + k * 6, 0), Vector3(16 - k * 3, 12, 16 - k * 3))
	_part(ch, _spire_mesh(8), lit, Vector3(0, 140, 0), Vector3(1.5, 30, 1.5))
	_glow_at(ch, Vector3(0, 112, 9), Vector3(14, 22, 1), Color(1.0, 0.86, 0.6), 0.5)
	# a forest of towers behind
	for i in 22:
		var x := -110.0 + i * 10.0 + rng.randf() * 5.0
		if absf(x - 4.0) < 16.0:
			continue
		var h := 40.0 + rng.randf() * 70.0
		_part(far, BoxMesh.new(), far_lit, Vector3(x, ROAD_Y + h * 0.5, 60.0 + rng.randf() * 60.0), Vector3(10 + rng.randf() * 8, h, 10))
	# searchlights: long pale beams fanning up from behind the skyline (they sweep in follow())
	var beam_mat := _mat("res://shaders/beam.gdshader")
	for k in 4:
		var b := MeshInstance3D.new()
		b.mesh = QuadMesh.new()
		b.material_override = beam_mat
		b.position = Vector3(-60.0 + k * 40.0, ROAD_Y, 80.0)
		b.scale = Vector3(7.0, 260.0, 1.0)
		far.add_child(b)
		searchlights.append(b)

## Havana: the Capitolio's dome on its drum above a long colonnaded front
func _capitolio() -> void:
	var m := _sil_h(0.36, 1.2)
	var c := Node3D.new()
	c.position = Vector3(-2.0, ROAD_Y, 0)
	far.add_child(c)
	_part(c, BoxMesh.new(), m, Vector3(0, 12, 0), Vector3(120, 24, 30))
	_part(c, BoxMesh.new(), m, Vector3(0, 28, 0), Vector3(36, 10, 26))
	_part(c, _cyl1(), m, Vector3(0, 40, 0), Vector3(22, 16, 22))
	var dome := SphereMesh.new()
	dome.radial_segments = 28; dome.rings = 14; dome.is_hemisphere = true
	_part(c, dome, m, Vector3(0, 47, 0), Vector3(13, 22, 13))
	_part(c, _cyl1(), m, Vector3(0, 72, 0), Vector3(3, 6, 3))
	_part(c, _spire_mesh(8), m, Vector3(0, 78, 0), Vector3(1.5, 6, 1.5))
	_glow_at(c, Vector3(0, 74, 4), Vector3.ONE * 7.0, Color(1.0, 0.8, 0.5), 0.8)
	# the sea wall and the lighthouse of El Morro off to the left
	var m2 := _sil_h(0.6, 0.0)
	_part(far, _cyl1(), m2, Vector3(-110, ROAD_Y + 18, 60), Vector3(6, 36, 6))
	_glow_at(far, Vector3(-110, ROAD_Y + 38, 64), Vector3.ONE * 10.0, Color(1.0, 0.85, 0.6), 1.0)

## Vienna: St. Stephen's, its steep patterned roof and the great south spire, and a green dome beside it
func _stephansdom() -> void:
	var m := _sil_h(0.34, 1.6)
	var c := Node3D.new()
	c.position = Vector3(2.0, ROAD_Y, 0)
	far.add_child(c)
	_part(c, BoxMesh.new(), m, Vector3(-8, 14, 0), Vector3(30, 28, 60))
	var roof := _prism()
	var rm := MeshInstance3D.new()
	rm.mesh = roof
	rm.material_override = m
	rm.position = Vector3(-8, 28, 0)
	rm.scale = Vector3(30, 26, 60)
	c.add_child(rm)
	_part(c, BoxMesh.new(), m, Vector3(14, 30, -10), Vector3(12, 60, 12))
	_part(c, _spire_mesh(8), m, Vector3(14, 92, -10), Vector3(12, 64, 12))
	_part(c, _spire_mesh(8), m, Vector3(14, 130, -10), Vector3(2.5, 14, 2.5))
	for sx in [-1.0, 1.0]:
		_part(c, _spire_mesh(6), m, Vector3(14 + sx * 6.5, 64, -10 + sx * 6.5), Vector3(2.2, 14, 2.2))
	var green := _sil_h(0.5, 0.0)
	green.set_shader_parameter("near_col", Color(0.24, 0.36, 0.32))
	var dome := SphereMesh.new()
	dome.radial_segments = 24; dome.rings = 12; dome.is_hemisphere = true
	_part(far, _cyl1(), green, Vector3(80, ROAD_Y + 22, 80), Vector3(22, 14, 22))
	_part(far, dome, green, Vector3(80, ROAD_Y + 29, 80), Vector3(12, 18, 12))
	for sx in [-1.0, 1.0]:
		_part(far, _cyl1(), green, Vector3(80 + sx * 20, ROAD_Y + 20, 72), Vector3(4, 40, 4))

## Cairo: the pyramids of Giza far off in the dust
func _pyramids() -> void:
	var m := _sil_h(0.62, 0.0)
	var pyr := _spire_mesh(4)
	for p in [[Vector3(-120, 0, -180), 110.0], [Vector3(-40, 0, -150), 90.0], [Vector3(-190, 0, -120), 60.0]]:
		_part(far, pyr, m, p[0] + Vector3(0, ROAD_Y + p[1] * 0.5, 0), Vector3(p[1] * 1.6, p[1], p[1] * 1.6), PI * 0.25)

## Rome: St. Peter's dome with its lantern, and the Colosseum's broken ring to one side
func _rome() -> void:
	var m := _sil_h(0.36, 1.4)
	var c := Node3D.new()
	c.position = Vector3(3.0, ROAD_Y, 0)
	far.add_child(c)
	# a long low front, a short drum ringed with columns, and the great ribbed dome with its lantern
	_part(c, BoxMesh.new(), m, Vector3(0, 11, 14), Vector3(100, 22, 24))
	_part(c, _cyl1(32), m, Vector3(0, 28, -6), Vector3(40, 12, 40))
	var dome := SphereMesh.new()
	dome.radial_segments = 32; dome.rings = 16; dome.is_hemisphere = true
	_part(c, dome, m, Vector3(0, 34, -6), Vector3(21, 30, 21))
	_part(c, _cyl1(), m, Vector3(0, 66, -6), Vector3(6, 8, 6))
	_part(c, _spire_mesh(8), m, Vector3(0, 74, -6), Vector3(3, 8, 3))
	_glow_at(c, Vector3(0, 68, 0), Vector3.ONE * 8.0, Color(1.0, 0.8, 0.5), 0.7)
	var col := _sil_h(0.5, 3.0)
	col.set_shader_parameter("arches", 1.0)
	var ring := CylinderMesh.new()
	ring.top_radius = 0.5; ring.bottom_radius = 0.5; ring.height = 1.0; ring.radial_segments = 40
	_part(far, ring, col, Vector3(-85, ROAD_Y + 16, 70), Vector3(60, 32, 50))

func _bigben() -> void:
	# the Elizabeth Tower: the shaft, the belfry with its four lit clock faces, and the spire
	var tower := Node3D.new()
	tower.position = Vector3(3.0, ROAD_Y, 0.0)
	far.add_child(tower)
	var tw := _sil_h(0.34, 1.4)
	_part(tower, BoxMesh.new(), tw, Vector3(0, 26, 0), Vector3(7.5, 52, 7.5))
	_part(tower, BoxMesh.new(), tw, Vector3(0, 56.5, 0), Vector3(9.0, 9.0, 9.0))
	var face_mat := _std(Color(1.0, 0.9, 0.7), 0.3, 0.0, Color(1.0, 0.8, 0.5), 2.6)
	face_mat.disable_fog = true
	var disc := CylinderMesh.new()
	disc.top_radius = 3.1; disc.bottom_radius = 3.1; disc.height = 0.2; disc.radial_segments = 24
	for k in 4:
		var a := k * PI * 0.5
		var d := Vector3(sin(a), 0, cos(a))
		var p := MeshInstance3D.new()
		p.mesh = disc
		p.material_override = face_mat
		p.position = Vector3(0, 56.5, 0) + d * 4.55
		p.basis = Basis.looking_at(d, Vector3.UP) * Basis(Vector3.RIGHT, PI * 0.5)
		tower.add_child(p)
	var glow_q := QuadMesh.new()
	var halo := MeshInstance3D.new()
	halo.mesh = glow_q
	halo.material_override = _mat("res://shaders/halo.gdshader", {"tint": Color(1.0, 0.75, 0.45), "energy": 0.5, "fade": 0.0})
	halo.position = Vector3(0, 56.5, 6.0)
	halo.scale = Vector3.ONE * 16.0
	tower.add_child(halo)
	_part(tower, BoxMesh.new(), tw, Vector3(0, 63, 0), Vector3(8.0, 4.0, 8.0))
	var spire := CylinderMesh.new()
	spire.top_radius = 0.1; spire.bottom_radius = 0.5; spire.height = 1.0; spire.radial_segments = 4
	_part(tower, spire, tw, Vector3(0, 74, 0), Vector3(10.5, 18, 10.5), PI * 0.25)
	_part(tower, spire, tw, Vector3(0, 86, 0), Vector3(1.8, 7, 1.8), PI * 0.25)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_part(tower, spire, tw, Vector3(sx * 4.2, 69, sz * 4.2), Vector3(1.4, 6, 1.4), PI * 0.25)
	# the Palace of Westminster beside it, with its row of pinnacles, and the Victoria Tower further off
	var pal := _sil_h(0.46, 1.8)
	_part(far, BoxMesh.new(), pal, Vector3(-30, ROAD_Y + 11, 12), Vector3(48, 22, 14))
	for i in 10:
		_part(far, spire, pal, Vector3(-52 + i * 5.0, ROAD_Y + 25, 12), Vector3(1.6, 6, 1.6), PI * 0.25)
	var vic := _sil_h(0.6, 1.2)
	_part(far, BoxMesh.new(), vic, Vector3(-70, ROAD_Y + 30, 40), Vector3(12, 60, 12))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_part(far, spire, vic, Vector3(-70 + sx * 5.2, ROAD_Y + 63, 40 + sz * 5.2), Vector3(1.8, 8, 1.8), PI * 0.25)
	# St Paul's dome far to the right
	var sp := _sil_h(0.68, 0.0)
	var dome := SphereMesh.new()
	dome.radial_segments = 24; dome.rings = 12; dome.is_hemisphere = true
	_part(far, _cyl1(), sp, Vector3(110, ROAD_Y + 26, 120), Vector3(30, 18, 30))
	_part(far, dome, sp, Vector3(110, ROAD_Y + 35, 120), Vector3(17, 17, 17))
	_part(far, _cyl1(), sp, Vector3(110, ROAD_Y + 54, 120), Vector3(3, 6, 3))

func _roofscape() -> void:
	# the roofs of the rest of the city, layer behind layer
	for layer in 3:
		var m := _sil_h(0.5 + layer * 0.14, 0.0)
		for i in 26:
			var x := -90.0 + i * 7.0 + rng.randf() * 4.0
			if absf(x - 3.0) < 6.0:
				continue
			var h := 8.0 + rng.randf() * 12.0 + layer * 3.0
			_part(far, BoxMesh.new(), m, Vector3(x, ROAD_Y + h * 0.5, 30.0 + layer * 40.0), Vector3(6.0 + rng.randf() * 4.0, h, 8.0))

func _part(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, scl: Vector3, rot_y := 0.0) -> MeshInstance3D:
	var p := MeshInstance3D.new()
	p.mesh = mesh
	p.material_override = mat
	p.position = pos
	p.basis = Basis(Vector3.UP, rot_y).scaled(scl)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	return p

# ---------------------------------------------------------------- drizzle, chimney smoke and street mist

var rain: GPUParticles3D
var snow: GPUParticles3D
var smoke: GPUParticles3D
var mist: GPUParticles3D

func _weather() -> void:
	if look.get("snow", false):
		# soft flakes drifting down past the camera
		snow = GPUParticles3D.new()
		snow.amount = 900
		snow.lifetime = 4.0
		snow.preprocess = 4.0
		snow.visibility_aabb = AABB(Vector3(-40, -20, -80), Vector3(80, 40, 160))
		var spm := ParticleProcessMaterial.new()
		spm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		spm.emission_box_extents = Vector3(10, 6, 24)
		spm.direction = Vector3(0.2, -1, 0.1)
		spm.spread = 25.0
		spm.initial_velocity_min = 1.0
		spm.initial_velocity_max = 2.2
		spm.gravity = Vector3(0, -0.6, 0)
		spm.turbulence_enabled = true
		spm.turbulence_noise_strength = 0.6
		snow.process_material = spm
		var fq := QuadMesh.new()
		fq.size = Vector2(0.07, 0.07)
		var fm := StandardMaterial3D.new()
		fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		fm.albedo_color = Color(0.95, 0.97, 1.0)
		fq.material = fm
		snow.draw_pass_1 = fq
		add_child(snow)
	rain = GPUParticles3D.new()
	rain.visible = look.rain
	rain.amount = 1600
	rain.lifetime = 0.9
	rain.preprocess = 1.0
	rain.visibility_aabb = AABB(Vector3(-40, -20, -80), Vector3(80, 40, 160))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(9, 5, 22)
	pm.direction = Vector3(0.06, -1, 0.12)
	pm.spread = 2.0
	pm.initial_velocity_min = 14.0
	pm.initial_velocity_max = 18.0
	pm.gravity = Vector3(0, -4, 0)
	pm.particle_flag_align_y = true
	rain.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.018, 0.7)
	var rm := ShaderMaterial.new()
	rm.shader = load("res://shaders/rain.gdshader")
	q.material = rm
	rain.draw_pass_1 = q
	add_child(rain)
	smoke = _puffs(70, 7.0, Vector3(13, 1.2, 70), Vector3(0.6, 0.35, 0), Vector2(3.0, 7.0), Color(0.6, 0.58, 0.56), 0.16)
	smoke.visible = look.smoke
	if look.get("steam", false):
		# steam rising from the manholes
		mist = _puffs(40, 4.0, Vector3(4, 0.2, 70), Vector3(0.1, 1.4, 0), Vector2(2.0, 5.0), Color(0.75, 0.72, 0.8), 0.16)
	else:
		mist = _puffs(36, 8.0, Vector3(5, 0.4, 70), Vector3(0.3, 0.02, 0), Vector2(7.0, 12.0), look.haze, 0.07)

func _puffs(amount: int, life: float, box: Vector3, vel: Vector3, size: Vector2, col: Color, alpha: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.preprocess = life
	p.visibility_aabb = AABB(Vector3(-60, -30, -160), Vector3(120, 60, 320))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = box
	pm.direction = vel.normalized() if vel.length() > 0.0 else Vector3.UP
	pm.spread = 25.0
	pm.initial_velocity_min = vel.length() * 0.6
	pm.initial_velocity_max = vel.length() * 1.4
	pm.gravity = Vector3.ZERO
	pm.scale_min = size.x
	pm.scale_max = size.y
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0))
	curve.add_point(Vector2(0.25, 1))
	curve.add_point(Vector2(0.8, 0.7))
	curve.add_point(Vector2(1, 0))
	var ct := CurveTexture.new()
	ct.curve = curve
	pm.alpha_curve = ct
	# each puff gets its own random number in its colour's red channel (the shader turns it into its shape)
	var g := Gradient.new()
	g.set_color(0, Color(0, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 1))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_initial_ramp = gt
	p.process_material = pm
	var q := QuadMesh.new()
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/smoke.gdshader")
	m.set_shader_parameter("tint", col)
	m.set_shader_parameter("alpha", alpha)
	m.render_priority = -1
	q.material = m
	p.draw_pass_1 = q
	p.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD
	add_child(p)
	return p

## the weather moves with the camera: rain falls around it, smoke rises from the roofs ahead, mist hangs over the road
func weather_follow(cam_pos: Vector3) -> void:
	if snow:
		snow.global_position = cam_pos + Vector3(0, 2.0, -18)
	if rain:
		rain.global_position = cam_pos + Vector3(0, 1.5, -16)
		smoke.global_position = Vector3(0, WALK_Y + 15.0, cam_pos.z - 60.0)
		mist.global_position = Vector3(0, ROAD_Y + 0.6, cam_pos.z - 55.0)
