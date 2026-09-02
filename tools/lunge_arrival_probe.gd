## **DOES THE LUNGE AUTO-KILL LAND ON A REAL SERVER?** US-0070, reported from the
## controls on 2026-09-02 as *"the autokill on lunge does not work"*.
##
## **THE SEAM NOBODY TESTS.** `test_lunge_effect.gd` proves the effect queues an
## arrival on `MatchContext.auto_kill_arrivals`; `test_lunge_arrival.gd` appends to
## that queue **by hand** and proves `SYS-KILL` judges it. Neither runs the two
## together through a real tick, so the hop between the `abilities` stage and the
## `combat` stage is proven by nobody — which is exactly the shape that let
## `NET-C2S-ABILITY-REQUEST` ship with no caller.
##
## It boots `server_root.tscn`, joins two peers into a two-player cycle, stands the
## caster's own contract a chosen distance down the dash line, and presses.
##
## ```
## godot --headless --path . res://tools/lunge_arrival_probe.tscn
## ```
extends Node

const SERVER := "res://scenes/server_root.tscn"
const HUNTER := 4242
const PREY := 4343
const SETTLE := 40

## Metres from the caster to their contract when the dash begins. The dash covers
## about 5.85 m, so at 6.0 the pawn arrives 0.15 m short of the body — deep inside
## `TUN-KILL-RANGE` + `TUN-KILL-VALIDATION-GRACE` 2.85 m, and far enough inside
## that no rounding decides it.
const STAND_OFF := 6.0

var _root: Node = null
var _seq: int = 0

## **THE CONE IS READ FROM THE PAWN'S YAW, NOT FROM THE DASH DIRECTION**, so a
## probe that dashes one way while facing another measures a refusal it caused
## itself. The first version sent `InputCommand.empty()` — yaw 0, facing +Z —
## while dashing toward -X, and reported a whiff at a gap of 0.15 m.
var _yaw: float = 0.0


## Overridden with `-- --standoff <m>`, so the boundary can be swept without
## editing the file: the dash is a fixed length and unsteerable, so *too close* is
## a failure mode as real as too far.
func _stand_off() -> float:
	var args := OS.get_cmdline_user_args()
	for i: int in args.size():
		if args[i] == "--standoff" and i + 1 < args.size():
			return float(args[i + 1])
	return STAND_OFF


func _ready() -> void:
	_run()


func _run() -> void:
	_root = (load(SERVER) as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(_root)
	for _i: int in SETTLE:
		await get_tree().physics_frame
	var abilities: AbilitySystem = _root.get("abilities")
	var kills: KillSystem = _root.get("kills")
	var ctx: MatchContext = (_root.get("director") as MatchDirector).ctx
	if abilities == null or kills == null or ctx == null:
		print("REFUSING: the server has no combat or ability system to press.")
		get_tree().quit(1)
		return
	_root.call(&"_on_peer_joined", HUNTER)
	_root.call(&"_on_peer_joined", PREY)
	# Long enough for the repair debounce to announce and TUN-RESPAWN-INVULN to
	# expire — a protected contract is refused with TARGET_PROTECTED, which would
	# read exactly like an arrival that never happened.
	for _i: int in 150:
		await _drive()
	await _press(abilities, kills, ctx)
	get_tree().quit()


## **A PEER THAT NEVER SENDS INPUT IS NEVER STEPPED**, so both pawns are driven —
## the caster because `LungingState` runs at the `pawn` stage, the prey because a
## body nobody simulates is not recorded where it stands.
func _drive() -> void:
	var director := _root.get("director") as MatchDirector
	_seq += 1
	if director != null:
		director.enqueue_input(HUNTER, _look(_seq, _yaw))
		director.enqueue_input(PREY, _look(_seq, 0.0))
	await get_tree().physics_frame


## A command that holds nothing but a heading.
func _look(seq: int, yaw: float) -> InputCommand:
	var command := InputCommand.empty(seq)
	command.look_yaw = yaw
	return command


func _place(ctx: MatchContext, peer: int, at: Vector3) -> void:
	var body: CharacterBody3D = ctx.pawns.get(peer)
	var pawn: PawnContext = ctx.pawn_contexts.get(peer)
	if body != null:
		body.global_position = at
	if pawn != null:
		pawn.position = at


func _press(abilities: AbilitySystem, kills: KillSystem, ctx: MatchContext) -> void:
	var hunter: PawnContext = ctx.pawn_contexts.get(HUNTER)
	var contract := int(ctx.announced_contracts.get(HUNTER, ContractCycle.NOBODY))
	print("")
	print("--- THE LUNGE ARRIVAL, ON A REAL SERVER ---")
	print("hunter %d   announced contract %d   (prey is %d)" % [HUNTER, contract, PREY])
	if contract != PREY:
		print("REFUSING: the two-player cycle did not announce the prey as the contract.")
		return
	var from := hunter.position
	var toward := (Vector3(60.0, from.y, 60.0) - from).normalized()
	# `CameraArm.forward(yaw)` is `(sin yaw, 0, cos yaw)`, so this is its inverse.
	_yaw = atan2(toward.x, toward.z)
	_place(ctx, PREY, from + toward * _stand_off())
	# The lag-comp ring must hold the prey where it now stands, or the rewind
	# resolves against where the body was before it was moved.
	for _i: int in 20:
		await _drive()
	var prey: PawnContext = ctx.pawn_contexts.get(PREY)
	print(
		(
			"standing the prey %.2f m down the dash line at %s"
			% [from.distance_to(prey.position), str(prey.position)]
		)
	)
	var before := [kills.arrivals_judged, kills.arrivals_landed, kills.arrivals_whiffed]
	var data := Tuning.ability_data(Ids.ABIL_LUNGE)
	abilities.report_request(HUNTER, 1, from, toward * data.distance)
	await _watch(kills, ctx, from, int(before[0]))
	_report(kills, ctx, before)


## What the arrival was worth, said separately from producing it — the seam
## `ability_probe.gd` already draws between *press and watch* and *tell somebody*.
func _report(kills: KillSystem, ctx: MatchContext, before: Array) -> void:
	var hunter: PawnContext = ctx.pawn_contexts.get(HUNTER)
	print("")
	print(
		(
			"arrivals: judged %d -> %d   landed %d -> %d   whiffed %d -> %d"
			% [
				before[0],
				kills.arrivals_judged,
				before[1],
				kills.arrivals_landed,
				before[2],
				kills.arrivals_whiffed
			]
		)
	)
	if kills.arrivals_whiffed > int(before[2]):
		print("the whiff's reason: ", KillVerdict.V.keys()[kills.last_whiff])
	print("hunter ended in state ", hunter.state_id)
	print("prey is dead: ", CombatTargets.is_dead(ctx.pawn_contexts.get(PREY)))
	print("")
	print("EXPECT: one arrival judged, one landed, the prey dead or dying, and the")
	print("        hunter in KillAnim rather than Staggered.")


## Watches until the arrival is judged, and prints what the world looked like on
## the tick it was — **live and rewound**, because a kill is validated in the past
## and a dash is the fastest thing in this game.
func _watch(kills: KillSystem, ctx: MatchContext, from: Vector3, judged: int) -> void:
	var hunter: PawnContext = ctx.pawn_contexts.get(HUNTER)
	var prey: PawnContext = ctx.pawn_contexts.get(PREY)
	var dash_frames := 0
	for _step: int in 120:
		var before := kills.arrivals_judged
		await _drive()
		if hunter.state_id == PawnStateId.LUNGING:
			dash_frames += 1
		if kills.arrivals_judged > before or (kills.arrivals_judged > judged and dash_frames > 0):
			break
	print("  held Lunging %d step ticks of %d" % [dash_frames, LungingState.dash_ticks()])
	print("  travelled %.2f m of a tuned %.1f" % [from.distance_to(hunter.position), 6.0])
	print("  live gap hunter -> prey: %.2f m" % hunter.position.distance_to(prey.position))
	var at_tick := RewindClamp.tick_for(ctx.tick, Net.rtt_ms(HUNTER))
	var world := kills.rewind.world_for(ctx, HUNTER, at_tick)
	var here := world.position_of(HUNTER)
	var there := world.position_of(PREY)
	print("  rewound %d ticks (%.0f ms)" % [ctx.tick - at_tick, RewindClamp.milliseconds_for(0.0)])
	if here != Vector3.INF and there != Vector3.INF:
		print("  rewound gap hunter -> prey: %.2f m" % here.distance_to(there))
		print(
			"  the hunter was %.2f m behind their arrival point" % here.distance_to(hunter.position)
		)
	print(
		(
			"  reach is %.2f m (TUN-KILL-RANGE + TUN-KILL-VALIDATION-GRACE)"
			% (Tuning.combat.kill_range + Tuning.combat.kill_validation_grace)
		)
	)
