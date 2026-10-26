class_name Traffic
extends Node3D
## The traffic and the barriers: one model per vehicle in the course, shown while it's near.
## Road traffic drives forward at its own speed; airships fly the upper lanes.

const VIEW := 130.0
const CAR_COLS := [Color("141414"), Color("3a1418"), Color("1a2232"), Color("2a2a20")]
const PLANE_COLS := [Color(0.55, 0.14, 0.12), Color(0.72, 0.58, 0.32), Color(0.22, 0.32, 0.48), Color(0.3, 0.4, 0.26)]

var game: Game
var models := {}

func setup(g: Game) -> void:
	game = g
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in game.hazards.size():
		var h: Dictionary = game.hazards[i]
		var m: Node3D
		match h.kind:
			"dbus":
				m = Models.dbus()
			"biplane":
				# (the web game flies biplanes here; in 1890 London it's little airships)
				m = Models.airship(PLANE_COLS[rng.randi() % PLANE_COLS.size()])
			"barrier":
				m = Models.barrier()
			_:
				m = Models.oldcar(CAR_COLS[rng.randi() % CAR_COLS.size()])
		m.visible = false
		add_child(m)
		models[i] = m

func update_traffic(car_z: float, dt: float) -> void:
	for i in game.hazards.size():
		var h: Dictionary = game.hazards[i]
		var m: Node3D = models[i]
		var z := game.hazard_z(h)
		var on: bool = h.state != 1 and z > -VIEW and z < 14.0
		m.visible = on
		if not on:
			continue
		var y: float = game.LY[h.row]
		if h.kind == "oldcar" or h.kind == "dbus":
			y = World.ROAD_Y
		m.position = Vector3(game.LX[h.col], y, car_z + z)
		if h.kind == "biplane":
			m.position.y += sin(game.t * 2.0 + i) * 0.06
			m.rotation.z = sin(game.t * 1.3 + i) * 0.06
			var prop: Node3D = m.get_meta("prop")
			prop.rotation.z += dt * 40.0
