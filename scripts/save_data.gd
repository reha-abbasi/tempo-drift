extends Node

## Saved progress (autoload "SaveData"). Stored in user://save.cfg on the device.

const PATH := "user://save.cfg"

var best_score := 0
var total_coins := 0
var games_played := 0
var sound_on := true


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	best_score = cfg.get_value("stats", "best_score", 0)
	total_coins = cfg.get_value("stats", "total_coins", 0)
	games_played = cfg.get_value("stats", "games_played", 0)
	sound_on = cfg.get_value("settings", "sound_on", true)


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("stats", "best_score", best_score)
	cfg.set_value("stats", "total_coins", total_coins)
	cfg.set_value("stats", "games_played", games_played)
	cfg.set_value("settings", "sound_on", sound_on)
	cfg.save(PATH)


## Returns true if this run is a new best score.
func record_run(score: int, coins: int) -> bool:
	games_played += 1
	total_coins += coins
	var is_best := score > best_score
	if is_best:
		best_score = score
	save()
	return is_best
