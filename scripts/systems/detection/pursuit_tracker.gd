## **HOW LONG A HUNTER KEEPS A CONTRACT ONCE THEY HAVE BEEN SEEN.** ADR-0014,
## US-0097. SERVER ONLY.
##
## `PursuitBoard` is the pure rule — refresh, drain, empty. This is the thin half
## that reads the world: it decides what counts as *sight*, remembers how near the
## prey was at the last one, and raises `escaped` when a bar empties.
##
## **IT IS NOT A `GameSystem`, FOR THE FIFTH TIME AND A FIFTH REASON.**
## `MatchDirector` permits one system per stage, and every question a chase asks —
## the cone, the range, the line of sight — is one `SYS-DETECTION` has already
## answered for the Compass lock in the same pass. A `pursuit` stage would ask them
## all a second time, one tick later.
class_name PursuitTracker
extends RefCounted

## Fired when a bar empties. `server_root` wires it to
## `ContractSystem.report_escape` and to the prey's two score awards.
signal escaped(hunter: int, prey: int, close_call: bool)

## Hunters whose chase was refreshed this tick. Cleared at the top of every pass,
## so a hunter absent from it is one who did not see their prey.
var _refreshed: Dictionary = {}

## Hunter -> how far their prey was at the last sighting. `SCORE-CLOSECALL` reads
## it, because the distance when a bar empties is one nobody observed.
var _chase_range: Dictionary = {}


func begin_pass() -> void:
	_refreshed.clear()


## Cone and range only — the half of the pursuit sight test that costs nothing.
static func geometry(angle: float, metres: float) -> bool:
	var c := Tuning.contract
	return metres <= c.pursuit_sight_range and angle <= deg_to_rad(c.pursuit_sight_cone) * 0.5


## **ONE TICK OF A CHASE, FROM THE HUNTER'S SIDE.** US-0097 §2 and §3.
##
## `seen` is geometry and line of sight. What this adds is the blend clause, which
## is GDD-03 §9.2's own rule applied to a new consumer: *the crowd hides you by
## being confusing, never by being solid.* A hunter with a clear line to a player
## in a blend cannot pick them out of it — **unless they had unbroken sight at the
## instant the blend began**, in which case they watched it happen.
##
## **SO THE PREY'S CORRECT PLAY IS: BREAK THE CORNER FIRST, THEN BLEND.** Blending
## in front of somebody looking straight at you buys nothing, and that is the whole
## reason this clause is worth its complexity.
func advance(
	hunter: int, contract: int, there: PawnContext, metres: float, seen: bool, ctx: MatchContext
) -> void:
	if not ctx.pursuit.is_chasing(hunter) or ctx.pursuit.prey_of(hunter) != contract:
		return
	var blended := there.blend_state != BlendKind.Kind.NONE
	if not blended:
		# While the prey is in the open the flag simply tracks live sight, so at the
		# instant they blend it already holds the right answer. That is what makes
		# `note_blend_began` a fact about **one moment** rather than a poll.
		ctx.pursuit.note_blend_began(hunter, seen)
	elif not seen:
		ctx.pursuit.note_sight_broken(hunter)
	if not seen or (blended and not ctx.pursuit.watched_the_blend(hunter)):
		return
	ctx.pursuit.refresh(hunter, contract, Tuning.ticks(&"TUN-PURSUIT-DURATION"))
	_refreshed[hunter] = true
	_chase_range[hunter] = metres


## **EVERY CHASE NOBODY REFRESHED, AND THE ESCAPES THAT FALL OUT OF IT.** Run after
## the pair pass, because a chase is refreshed from the hunter's side and drained
## from nobody's — so the drain can only be correct once every pair has been seen.
func drain(ctx: MatchContext) -> void:
	var idle := PackedInt32Array()
	for hunter: int in ctx.pursuit.hunters():
		if not _refreshed.has(hunter):
			idle.append(hunter)
	for hunter: int in ctx.pursuit.drain(idle):
		var prey := ctx.pursuit.prey_of(hunter)
		# **THE CLOSE CALL IS MEASURED AT THE LAST SIGHTING, NOT AT THE EMPTY BAR.**
		# By definition the hunter has not seen their prey for the whole window, so
		# "how near were they when it emptied" is a distance nobody observed. What
		# the bonus prices is escaping **under pressure**, and the last moment the
		# two were known to be together is the only honest reading of that.
		var last := float(_chase_range.get(hunter, INF))
		ctx.pursuit.escaped(hunter)
		_chase_range.erase(hunter)
		escaped.emit(hunter, prey, last <= Tuning.contract.pursuit_closecall_radius)


## The hunter's own yaw to `at`, in radians, absolute. **Their yaw and never the
## Compass bearing**: the bearing carries `TUN-COMPASS-CONE-WOBBLE`'s lie, and
## gating a rule on it would mean a hunter aiming at the drifted cone fails against
## somebody standing exactly where they are pointing.
static func angle_to(here: PawnContext, at: Vector3) -> float:
	return absf(CompassMath.angle_between(here.yaw, CompassMath.bearing_to(here.position, at)))
