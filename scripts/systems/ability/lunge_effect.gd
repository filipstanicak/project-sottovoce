## **`ABIL-LUNGE` — THE PANIC BUTTON.** GDD-04 §3.4, US-0070. SERVER ONLY.
##
## Press it and 0.25 s later you dash `TUN-LUNGE-DISTANCE` 6.0 m at
## `TUN-LUNGE-SPEED` 9.0 m/s in the direction you were aiming, steering none of
## it. If you arrive within reach of your contract the kill **auto-initiates**;
## if you do not, you stand in the open for `TUN-LUNGE-WHIFF-STAGGER` 1.2 s,
## Noticed, unable to act.
##
## **THE DASH IS NOT HERE.** `LungingState` owns the movement, because this file
## is in `scripts/systems/` and is stripped from every client export — 6 m driven
## from here would be 6 m the client never predicted. What this does is put the
## pawn into that state with the clamped aim as its velocity, and read the state
## back afterwards to decide what the dash was worth.
##
## **ONE CLOCK, WHICH IS US-0067's LESSON APPLIED BEFORE IT COST ANYTHING.** The
## Cinderfall effect and its volume kept two clocks and the defect lived in the
## gap. Here `tick()` returns *"is the pawn still Lunging"* rather than counting
## down a copy of the duration — so the state and the effect cannot disagree about
## when the dash ended, however either is retuned.
##
## **AND IT DOES NOT DECIDE WHETHER THE KILL LANDS.** It queues an arrival and
## `SYS-KILL` judges it with the rules it already owns — range, cone, the
## announced contract, the cloud, the contest. An effect that pre-checked would be
## `KillRules` written a second time, and the second copy is the one that drifts.
class_name LungeEffect
extends AbilityEffect

var _caster: int = ContractCycle.NOBODY

## `end()` **must be idempotent** — the base says so, and a caster who dies
## mid-dash triggers both the death sweep and the expiry already scheduled for the
## same tick. Queueing the arrival twice would ask `SYS-KILL` for two kills.
var _resolved: bool = false


## **THE BURST.** `AbilitySystem` has already spent the cooldown, charged
## `TUN-LUNGE-SUSPICION` +40 and broadcast the tell — 0.25 s ago, which is what
## makes the tell a warning rather than a notification.
func begin(ctx: MatchContext, caster: int, aim: AimData) -> void:
	_caster = caster
	var pawn: PawnContext = ctx.pawn_contexts.get(caster)
	var machine: PawnStateMachine = ctx.pawn_machines.get(caster)
	if pawn == null or machine == null:
		return
	# **HORIZONTAL, BECAUSE THERE IS NO AIM PITCH IN THIS GAME.** A client sends a
	# direction and `AbilityRules.aim` has already clamped its length; what it
	# cannot do is stop somebody aiming at the sky, and a dash with a vertical
	# component would be a jump nobody tuned.
	var flat := Vector3(aim.direction.x, 0.0, aim.direction.z)
	if flat.length() < 0.001:
		return
	var speed := LungingState.dash_speed()
	var held := flat.normalized() * speed
	# **THE VELOCITY IS THE LOCKED DIRECTION**, which is the whole reason this
	# needs no field on `PawnContext` and no row on the wire: `own_velocity` is
	# already full floats in the own-pawn block, so a client forced into the state
	# by a snapshot can predict the rest of the dash from what it was sent.
	pawn.velocity = Vector3(held.x, pawn.velocity.y, held.z)
	if not machine.is_valid_edge(pawn.state_id, PawnStateId.LUNGING):
		Log.warn("no %s -> Lunging edge in GDD-02 §3" % pawn.state_id, &"pawn")
		return
	machine.transition(pawn, PawnStateId.LUNGING, PawnState.PRIORITY_COMBAT)


## **THE STATE IS THE CLOCK.** Not a countdown of its own — see the class
## docstring. `AbilityEffect.tick` returning false ends the effect on the same
## tick, so the resolution below happens the moment the dash does.
func tick(ctx: MatchContext, _dt: float) -> bool:
	var pawn: PawnContext = ctx.pawn_contexts.get(_caster)
	return pawn != null and pawn.state_id == PawnStateId.LUNGING


## **WHAT THE DASH WAS WORTH, AND ONLY IF IT RAN ITS COURSE.**
##
## A dash that ended because its owner was **stunned, killed or despawned** is one
## whose outcome has already been decided by the thing that interrupted it —
## stunning a lunger is GDD-04 §3.4's named counterplay, and charging them a whiff
## stagger on top would punish the prey's read twice. So the arrival is queued
## only when the pawn came back to locomotion, which is the one exit
## `LungingState` takes on its own.
func end(ctx: MatchContext) -> void:
	if _resolved:
		return
	_resolved = true
	var pawn: PawnContext = ctx.pawn_contexts.get(_caster)
	if pawn == null or not PawnStateId.is_locomotion(pawn.state_id):
		return
	ctx.auto_kill_arrivals.append(_caster)
