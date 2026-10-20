class_name GameConfig
extends RefCounted

## All the gameplay tuning numbers in one place.
## The player stays at z = 0 and the world scrolls toward +Z (toward the camera).

const LANE_WIDTH := 2.5

const START_SPEED := 14.0        # metres per second
const MAX_SPEED := 32.0
const SPEED_RAMP_TIME := 110.0   # seconds to get ~63% of the way to MAX_SPEED

const GRAVITY := 34.0
const JUMP_VELOCITY := 12.0      # ~2.1 m high, ~0.7 s in the air
const FAST_FALL_VELOCITY := -26.0
const SLIDE_TIME := 0.75
const LANE_CHANGE_TIME := 0.14

const PLAYER_HALF_WIDTH := 0.32
const PLAYER_HALF_DEPTH := 0.3
const PLAYER_HEIGHT := 1.75
const PLAYER_SLIDE_HEIGHT := 0.75
const STEP_UP := 0.45            # how far below a surface you can be and still snap on top

const STUMBLE_WINDOW := 4.0      # two side-bumps within this many seconds = game over

const SPAWN_Z := -160.0          # new things appear this far ahead
const DESPAWN_Z := 14.0          # and are removed once they are this far behind

const MAGNET_TIME := 10.0
const MAGNET_RANGE := 22.0
const DOUBLE_TIME := 12.0

const TRAIN_HEIGHT := 2.5
const TRAIN_WIDTH := 2.1
const RAMP_LENGTH := 7.0


static func lane_x(lane: int) -> float:
	return (lane - 1) * LANE_WIDTH


static func speed_at(run_time: float) -> float:
	return START_SPEED + (MAX_SPEED - START_SPEED) * (1.0 - exp(-run_time / SPEED_RAMP_TIME))
