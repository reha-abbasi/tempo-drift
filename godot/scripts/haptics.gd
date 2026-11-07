extends Node
## Haptic beats: the phone taps along with the run, as the web game did: a soft tick on every
## played note, a dull knock on a miss, and short patterns for the big moments (crash, a new car, OVERDRIVE, a
## shield save, a power-up, a new band level, the finish). Only when Haptics is on in Settings.
## A pattern is like the web game's navigator.vibrate: buzz, pause, buzz, ... in milliseconds.

const TICK := [10, 0.35]                    # a played note: [ms, strength 0-1]
const KNOCK := [28, 0.7]                    # a missed note
const PATTERNS := {
	"crash": [70, 50, 110],
	"win": [30, 60, 30, 60, 80],            # a new car, OVERDRIVE, the finish
	"bump": [22, 40, 22],                   # the shield saves you
	"buy": [20, 40, 40],                    # a power-up
	"level": [14, 50, 14],                  # the band steps up
}

var _busy_until := 0                        # (ms) no ticks over a pattern, so the big moments stay clear


func setup(run: Node) -> void:
	var r: Rules = run.rules
	r.judged.connect(func(_g, _n): _tap(TICK))
	r.missed.connect(func(_n): _tap(KNOCK))
	r.crashed.connect(func(_h): play("crash"))
	r.delivered.connect(func(_f): play("win"))
	r.overdrive.connect(func(on): if on: play("win"))
	r.shield_saved.connect(func(_h): play("bump"))
	r.power_up.connect(func(_k): play("buy"))
	r.tier_up.connect(func(_t): play("level"))
	r.finish_line.connect(func(): play("win"))


func _on() -> bool:
	return bool(Save.data.settings.get("haptics", true))


func _tap(p: Array) -> void:
	if _on() and Time.get_ticks_msec() >= _busy_until:
		Input.vibrate_handheld(p[0], p[1])


func play(k: String) -> void:
	if not _on():
		return
	var p: Array = PATTERNS[k]
	var at := 0
	for i in p.size():
		if i % 2 == 0:
			if at == 0:
				Input.vibrate_handheld(p[i])
			else:
				get_tree().create_timer(at / 1000.0).timeout.connect(Input.vibrate_handheld.bind(p[i]))
		at += p[i]
	_busy_until = Time.get_ticks_msec() + at
