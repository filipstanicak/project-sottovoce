extends RefCounted
## **THE HUNTING BRAIN: WHAT KEYS A PURSUING BOT HOLDS THIS INSTANT.** Split out of
## `bot_client.gd` on 2026-09-04, when the wall handling below took that file to 402
## lines. The seam is honest rather than mechanical: everything here decides *where
## to walk* from the one fact a client is told about its contract, and nothing here
## knows how a key is pressed, how long a frame is, or that a wire exists.
##
## **IT STEERS ON THE COMPASS AND NOTHING ELSE**, which is the only thing a client
## is given about where its contract is (GDD-03 §8.5). It cannot cheat because
## there is nothing to cheat with: the bearing carries `TUN-COMPASS-CONE-WOBBLE`'s
## lie exactly as a human's does.
##
## **AND IT SWEEPS RATHER THAN AIMS.** A bot has no mouse; `input_look_*` is the
## only heading control it has, which is why it circles its contract instead of
## walking a clean line. Said rather than tuned away: it is a moving, findable,
## stunnable pursuer, not an opponent.

## How far off the Compass bearing a hunting bot tolerates before it turns. Wide,
## because a bot sweeps with the pad rather than aiming with a mouse, and a tight
## tolerance makes it oscillate on the spot.
const AIM_TOLERANCE := 0.20

## **HOW A BOT NOTICES IT HAS WALKED INTO A WALL.** Steering on a bearing means no
## path query and no probe, so a hunter whose contract sits beyond a corner presses
## forward into masonry for the rest of the match. Reported from the controls on
## 2026-09-04: the bot was stuck in a corner and had to be walked away from.
##
## **IT IS MEASURED, NOT PREDICTED.** A forward probe is the wrong instrument — a
## bot wedged in a corner has clear ground ahead of it and still cannot travel,
## which is exactly the arrangement that was reported. What is unarguable is its
## own displacement over time, so that is what is read.
const STUCK_STEP := 0.05
const STUCK_SAMPLES := 15
const SHOVE_SAMPLES := 25

## How long the caller should hold the decided keys before asking again.
const BEAT := 0.1
const IDLE_BEAT := 0.2

var bearing := 0.0
var has_contract := false

var _rng := RandomNumberGenerator.new()
var _last_at := Vector3.INF
var _still_for: int = 0
var _shove_left: int = 0
var _shove_turn := "input_look_left"


func _init(seed_from: int) -> void:
	_rng.seed = hash("sottovoce-bot-hunt-%d" % seed_from)


## `EVT-COMPASS-UPDATED`. **`bucket` is the contract's distance and 255 means there
## is nobody to point at** — during `TUN-CONTRACT-REASSIGN-DELAY` a hunter has no
## announced contract at all, so this is how the bot learns to stop steering.
func on_compass(new_bearing: float, bucket: int, _lock: float) -> void:
	bearing = new_bearing
	has_contract = bucket != CompassBoard.NO_CONTRACT


## The keys to hold and how long to hold them, as `[actions, seconds]`.
##
## **BLEND-WALK, NOT RUN, AND THAT IS A MEASURED LIMIT RATHER THAN A CHOICE.**
## `input_run` held through `Input.action_press` produces **0.0 m of travel** —
## measured against the same bot walking 15 m with `input_slow`, with and without a
## clean press edge. Something in the run path does not accept a synthetic hold; it
## is reported in CLAUDE.md rather than worked around in silence, because a player
## holding Shift through a match start would meet whatever it is.
##
## **SO A HUNTING BOT IS ANONYMOUS UNLESS `--reckless`**, which is correct game
## behaviour rather than a gap: `TUN-STUN-MIN-TIER` makes a careful hunter
## unstunnable on purpose.
func decide(pawn: PawnContext) -> Array:
	var actions: Array = ["input_move_forward", "input_slow"]
	if _shoving(pawn, actions):
		return [actions, BEAT]
	if not has_contract:
		return [actions, IDLE_BEAT]
	var off := CompassMath.angle_between(pawn.yaw if pawn != null else 0.0, bearing)
	if absf(off) > AIM_TOLERANCE:
		# This game's yaw increases toward a turn to the LEFT — `InputSampler`
		# subtracts the mouse's x. So a positive offset is closed by looking left.
		actions.append("input_look_left" if off > 0.0 else "input_look_right")
	return [actions, BEAT]


## True while the bot is shoving off something it has walked into, in which case the
## caller's bearing is deliberately ignored for the duration — **the bearing is what
## walked it into the wall**, so obeying it again immediately walks it straight back.
##
## **THE TURN DIRECTION IS HELD FOR THE WHOLE SHOVE**, because re-deciding it every
## beat is how a bot rocks in place against the corner it is already in.
func _shoving(pawn: PawnContext, actions: Array) -> bool:
	if pawn == null:
		return false
	if _shove_left > 0:
		_shove_left -= 1
		actions.append(_shove_turn)
		return true
	var moved := _last_at == Vector3.INF or _last_at.distance_to(pawn.position) > STUCK_STEP
	_last_at = pawn.position
	_still_for = 0 if moved else _still_for + 1
	if _still_for < STUCK_SAMPLES:
		return false
	_still_for = 0
	_shove_left = SHOVE_SAMPLES
	_shove_turn = "input_look_left" if _rng.randf() < 0.5 else "input_look_right"
	return true


## How long the bot has failed to move, in decide() beats. Read by the probe.
func still_for() -> int:
	return _still_for
