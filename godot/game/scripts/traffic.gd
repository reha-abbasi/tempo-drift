class_name Traffic
extends Node3D
## The traffic and the barriers: one model per vehicle in the course, shown while it's near.
## Road traffic drives forward at its own speed; airships fly the upper lanes.

const VIEW := 130.0
const CAR_COLS := [Color("141414"), Color("3a1418"), Color("1a2232"), Color("2a2a20")]
const TAXI_COLS := [Color(0.98, 0.78, 0.1), Color(0.95, 0.95, 0.95), Color(0.1, 0.1, 0.12), Color(0.2, 0.45, 0.8)]
const TRUCK_COLS := [Color(0.8, 0.15, 0.1), Color(0.15, 0.4, 0.75), Color(0.95, 0.95, 0.95), Color(0.2, 0.6, 0.3)]
const FUTURE_COLS := [Color(0.12, 0.12, 0.15), Color(0.25, 0.1, 0.3), Color(0.08, 0.2, 0.28), Color(0.6, 0.6, 0.65)]
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
		var future: bool = game.course.map == "rain"
		match h.kind:
			"taxi":
				m = Models.taxi(TAXI_COLS[rng.randi() % TAXI_COLS.size()] if not future else FUTURE_COLS[rng.randi() % FUTURE_COLS.size()], future)
			"truck":
				m = Models.truck(TRUCK_COLS[rng.randi() % TRUCK_COLS.size()], future)
			"bus":
				m = Models.city_bus(Color(0.85, 0.2, 0.15) if not future else Color(0.15, 0.16, 0.2), future)
			"hovercab":
				m = Models.hovercab(TAXI_COLS[rng.randi() % TAXI_COLS.size()])
			"drone":
				m = Models.drone(FUTURE_COLS[rng.randi() % FUTURE_COLS.size()])
			"barrier" when game.course.map != "old":
				m = Models.barrier_modern(future)
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
		if h.kind in ["oldcar", "dbus", "taxi", "truck", "bus"]:
			y = World.ROAD_Y
		m.position = Vector3(game.LX[h.col], y, car_z + z)
		if h.kind == "drone" or h.kind == "hovercab":
			m.position.y += sin(game.t * 2.4 + i) * 0.08
			if m.has_meta("rotors"):
				for r in m.get_meta("rotors"):
					r.rotation.y += dt * 45.0
		if h.kind == "biplane":
			m.position.y += sin(game.t * 2.0 + i) * 0.06
			m.rotation.z = sin(game.t * 1.3 + i) * 0.06
			var prop: Node3D = m.get_meta("prop")
			prop.rotation.z += dt * 40.0
