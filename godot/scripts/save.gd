extends Node
## Everything kept on the device (autoload "Save"), as in the web game: stars and bests per episode, the coin wallet,
## the cars and pilots you own, missions, the daily gift, Endless high scores and settings.

const PATH := "user://tempo_drift.json"
## The cities with the new music are open: Berlin 2075 (the Future's sixth city), London 1890 (the Past's first) and
## Rio de Janeiro (the Present's second).
## The other cities stay on the map, locked, and open one by one as their new music is made (add them here).
const OPEN := {"rain": [5], "old": [0], "sunset": [1]}
const HOME_MAP := "rain"

var data := {
	"episodes": {},      # "old-0" -> {stars, score, acc, grade}
	"coins": 0,
	"cars": [], "car": "arrow",
	"pilots": [], "pilot": "astro",
	"missions": {},
	"daily": {"day": "", "streak": 0},
	"endless": {},       # map -> [{s, d}] top five
	"map": "rain",
	"tut": false,        # Flight School done
	"settings": {"sound": true, "haptics": true, "fx_low": false, "level": "normal", "dev": true, "cal": null},
}


func _ready() -> void:
	if FileAccess.file_exists(PATH):
		var d = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if d is Dictionary:
			for k in d:
				if data.has(k) and data[k] is Dictionary and d[k] is Dictionary:
					data[k].merge(d[k], true)
				else:
					data[k] = d[k]
	if not OPEN.has(str(data.map)):
		data.map = HOME_MAP


func write() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


func setting(k: String):
	return data.settings.get(k)


func set_setting(k: String, v) -> void:
	data.settings[k] = v
	write()


# ------------------------------------------------------------------ episodes and eras

func ep(map: String, i: int) -> Dictionary:
	return data.episodes.get("%s-%d" % [map, i], {"stars": 0, "score": 0, "acc": 0.0, "grade": ""})


func map_stars(map: String) -> int:
	var s := 0
	for i in 8:
		s += int(ep(map, i).stars)
	return s


func total_stars() -> int:
	var s := 0
	for m in Catalog.MAPS:
		s += map_stars(m)
	return s


func dev() -> bool:
	return bool(setting("dev"))


func era_open(map: String) -> bool:
	return OPEN.has(map)


func unlocked(map: String, i: int) -> bool:
	return OPEN.has(map) and i in OPEN[map]


func next_episode(map: String) -> int:
	## the first open episode not yet cleared (or the weakest open one, when all are)
	if not era_open(map):
		return -1
	var open: Array = OPEN[map]
	for i in open:
		if int(ep(map, i).stars) == 0:
			return i
	var best: int = open[0]
	for i in open:
		if int(ep(map, i).stars) < int(ep(map, best).stars):
			best = i
	return best


func record_ep(map: String, i: int, stars: int, score: int, acc: float, grade: String) -> Dictionary:
	var old := ep(map, i)
	var rank := "DCBAS"
	data.episodes["%s-%d" % [map, i]] = {
		"stars": maxi(stars, int(old.stars)), "score": maxi(score, int(old.score)), "acc": maxf(acc, float(old.acc)),
		"grade": grade if old.grade == "" or rank.find(grade) > rank.find(old.grade) else old.grade,
	}
	write()
	return {"best": score > int(old.score), "first_clear": int(old.stars) == 0, "new_stars": maxi(0, stars - int(old.stars))}


# ------------------------------------------------------------------ the wallet and the garage

func wallet() -> int:
	return int(data.coins)


func add_coins(n: int) -> void:
	data.coins = maxi(0, int(data.coins) + n)
	write()


func owns_car(k: String) -> bool:
	return int(Catalog.CARS[k].price) == 0 or k in data.cars


func owns_pilot(k: String) -> bool:
	return int(Catalog.PILOTS[k].price) == 0 or k in data.pilots


func buy(kind: String, k: String) -> bool:
	var price: int = (Catalog.CARS if kind == "car" else Catalog.PILOTS)[k].price
	if wallet() < price:
		return false
	add_coins(-price)
	(data.cars if kind == "car" else data.pilots).append(k)
	write()
	return true


# ------------------------------------------------------------------ missions

func missions() -> Dictionary:
	var m: Dictionary = data.missions
	if not m.has("active"):
		m.active = []
		for i in 3:
			m.active.append({"id": Catalog.MISSION_POOL[i].id, "tier": 0, "prog": 0})
		m.next = 3
		write()
	return m


func mission_goal(a: Dictionary) -> int:
	for p in Catalog.MISSION_POOL:
		if p.id == a.id:
			return int(p.goals[mini(int(a.tier), 2)])
	return 1


func mission_reward(a: Dictionary) -> int:
	return 100 + int(a.tier) * 100


func mission(id: String, n: int) -> Array:
	## counts progress; returns the missions finished by it as [{say, rw}] (their coins are paid at once)
	var m := missions()
	var done := []
	for a in m.active:
		if a.id != id:
			continue
		var pool: Dictionary = {}
		for p in Catalog.MISSION_POOL:
			if p.id == id:
				pool = p
		a.prog = maxi(int(a.prog), n) if pool.get("max", false) else int(a.prog) + n
		if int(a.prog) >= mission_goal(a):
			var rw := mission_reward(a)
			done.append({"say": Catalog.mission_text(id, mission_goal(a)), "rw": rw})
			data.coins = int(data.coins) + rw
			# the next mission: the next kind not already active, a tier harder each time round the list
			var k: int = m.next
			for i in Catalog.MISSION_POOL.size():
				var cand: Dictionary = Catalog.MISSION_POOL[(k + i) % Catalog.MISSION_POOL.size()]
				var taken := false
				for x in m.active:
					if x != a and x.id == cand.id:
						taken = true
				if not taken:
					a.id = cand.id
					m.next = k + i + 1
					break
			a.tier = mini(2, int(m.next / Catalog.MISSION_POOL.size()) + (1 if int(a.tier) > 0 else 0))
			a.prog = 0
	write()
	return done


# ------------------------------------------------------------------ the daily gift

func gift_today() -> Dictionary:
	## {day, streak, gift} if today's gift hasn't been claimed: 100, then 50 more a day in a row, up to 400
	var today := Time.get_date_string_from_system()
	var d: Dictionary = data.daily
	if d.day == today:
		return {}
	var yesterday := Time.get_date_string_from_unix_time(int(Time.get_unix_time_from_system()) - 86400)
	var streak: int = int(d.streak) + 1 if d.day == yesterday else 1
	return {"day": today, "streak": streak, "gift": mini(400, 50 + 50 * streak)}


func claim_gift() -> int:
	var g := gift_today()
	if g.is_empty():
		return 0
	add_coins(g.gift)
	data.daily = {"day": g.day, "streak": g.streak}
	write()
	return g.gift


# ------------------------------------------------------------------ Endless high scores

func record_endless(map: String, score: int) -> int:
	var list: Array = data.endless.get(map, [])
	list.append({"s": score, "d": Time.get_date_string_from_system()})
	list.sort_custom(func(a, b): return a.s > b.s)
	var rank := 1
	for e in list:
		if e.s == score:
			break
		rank += 1
	data.endless[map] = list.slice(0, 5)
	write()
	return rank
