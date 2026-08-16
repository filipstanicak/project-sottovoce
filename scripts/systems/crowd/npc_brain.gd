## **FIVE STATES, ONE GLOBAL INTERRUPT.** ADR-0003, TDD-08 §3, GDD-03 §6.1,
## US-0040. SERVER ONLY.
##
## A flat HFSM, not a behaviour tree. Per-tick tree traversal across ninety
## agents in GDScript is thousands of virtual calls for five behaviours — and
## **the crowd is not required to be intelligent, only legible.** A player has to
## be able to read a startle wave; nobody has to be fooled into thinking an NPC
## has plans.
##
## **THE HOT PATH IS THREE OPERATIONS**, and TDD-08 §3 says so in a comment
## because it is what makes 2.0 ms plausible: one integer compare (the
## interrupt), one timer decrement, and one small call when the timer runs out.
## The transition table is consulted on *events*, which are rare. `step()`
## constructs no Array and no Dictionary, ever — `test_npc_brain_no_alloc.gd`
## measures it rather than trusting the comment.
##
## **STARTLE ALWAYS WINS.** It is enterable from every other state and cannot be
## refused. That is deliberate and it costs something real: an NPC gawking at a
## corpse who is then startled abandons the corpse, destroying a standing
## information object. Accepted, because a startle wave is an information channel
## players read as *direction*, and an unreliable information channel is worse
## than none. The corpse itself persists for `TUN-CORPSE-LIFETIME` regardless.
class_name NpcBrain
extends RefCounted

## **EXACTLY FIVE. A SIXTH REQUIRES AN ADR** — ADR-0003 chose a flat machine over
## a tree on the strength of there being few behaviours, and that argument stops
## holding somewhere. `test_npc_brain_transitions.gd` fails if this grows.
enum State { STROLL, IDLE, WALKING_GROUP, STARTLE, GAWK }

## Everything that can move an NPC between states. `TIMER_EXPIRED` is internal;
## the rest are set on `CrowdContext` by the director or by whatever detected
## violence.
enum Event {
	TIMER_EXPIRED, REACHED_ANCHOR, SLOT_ASSIGNED, SLOT_REVOKED, GAWK_GRANTED, CORPSE_GONE, STARTLED
}

## A state-event pair that is deliberately nothing. **Not the same as an absent
## entry**, which is the classic FSM bug: a silent no-op transition looks exactly
## like a handled one until somebody wonders why an NPC never left Idle.
## `test_npc_brain_transitions.gd` requires every one of the 35 pairs to appear.
const IGNORED := -1

## **THE WHOLE MACHINE, AS DATA.** `const`, so it is built once at parse time and
## `step()` allocates nothing by construction rather than by discipline.
##
## Read as: from this state, this event leads there. Every pair is present —
## that completeness is a criterion, and the table is the only place it can be
## checked at a glance.
const TRANSITIONS: Dictionary = {
	State.STROLL:
	{
		Event.TIMER_EXPIRED: IGNORED,  # a strolling NPC has nowhere to be
		Event.REACHED_ANCHOR: State.IDLE,
		Event.SLOT_ASSIGNED: State.WALKING_GROUP,
		Event.SLOT_REVOKED: IGNORED,  # it had no slot
		Event.GAWK_GRANTED: State.GAWK,
		Event.CORPSE_GONE: IGNORED,  # it was not gawking
		Event.STARTLED: State.STARTLE,
	},
	State.IDLE:
	{
		Event.TIMER_EXPIRED: State.STROLL,
		Event.REACHED_ANCHOR: IGNORED,  # already at one
		Event.SLOT_ASSIGNED: State.WALKING_GROUP,
		Event.SLOT_REVOKED: IGNORED,
		Event.GAWK_GRANTED: State.GAWK,
		Event.CORPSE_GONE: IGNORED,
		Event.STARTLED: State.STARTLE,
	},
	State.WALKING_GROUP:
	{
		Event.TIMER_EXPIRED: IGNORED,  # the circuit ends by revocation, not by clock
		Event.REACHED_ANCHOR: IGNORED,  # anchors are for NPCs not in formation
		Event.SLOT_ASSIGNED: IGNORED,  # it has one
		Event.SLOT_REVOKED: State.STROLL,
		Event.GAWK_GRANTED: State.GAWK,  # leaves the formation, GDD-03 §6.1
		Event.CORPSE_GONE: IGNORED,
		Event.STARTLED: State.STARTLE,
	},
	State.STARTLE:
	{
		Event.TIMER_EXPIRED: State.STROLL,
		Event.REACHED_ANCHOR: IGNORED,  # fleeing, not arriving
		Event.SLOT_ASSIGNED: IGNORED,  # a formation cannot recruit a fleeing NPC
		Event.SLOT_REVOKED: IGNORED,
		Event.GAWK_GRANTED: IGNORED,  # **FLEEING BEATS GAWKING**, TDD-08 §3.3
		Event.CORPSE_GONE: IGNORED,
		Event.STARTLED: State.STARTLE,  # re-startled: the timer restarts
	},
	State.GAWK:
	{
		Event.TIMER_EXPIRED: State.STROLL,
		Event.REACHED_ANCHOR: IGNORED,
		Event.SLOT_ASSIGNED: IGNORED,  # a gawker is busy
		Event.SLOT_REVOKED: IGNORED,
		Event.GAWK_GRANTED: IGNORED,  # already gawking
		Event.CORPSE_GONE: State.STROLL,
		Event.STARTLED: State.STARTLE,  # abandons the corpse — see the class note
	},
}

var state: State = State.STROLL

## Ticks remaining in the current state, at the **30 Hz net tick**. Trap 9: a
## brain ticked by a system runs at the net rate, so `Tuning.ticks()` is the
## right converter and `Tuning.step_ticks()` — the 60 Hz one — would halve every
## duration silently, because both produce plausible integers.
var timer_ticks: int = 0

## **STARTLE PROPAGATES AT MOST ONCE PER AGENT**, which is what caps the cascade
## at two hops. Without it a startle in a dense market would cross the district
## and the wave would stop carrying direction — it would just mean "something,
## somewhere".
var has_propagated: bool = false


## One step. **Three operations on the hot path**; everything else happens on an
## event, and events are rare.
##
## **`stride` IS HOW MANY TICKS THIS STEP STANDS FOR**, US-0045. Under LOD a Far
## brain is stepped every fifteenth tick, and a timer decremented by one each time
## would make an 8–25 s idle pause last 120–375 s. That is not a rate change; it
## is a *behaviour* change wearing a rate change's name, and ADR-0003's whole
## claim is that LOD changes the rate and never the logic. Defaulting to 1 keeps
## every existing caller correct.
func step(ctx: CrowdContext, _dt: float, stride: int = 1) -> void:
	if ctx.startle_flag:
		handle(Event.STARTLED, ctx)
		return
	if timer_ticks > 0:
		timer_ticks = maxi(timer_ticks - maxi(stride, 1), 0)
		if timer_ticks == 0:
			handle(Event.TIMER_EXPIRED, ctx)


## Apply one event through the table. Returns true if the state changed.
##
## **AN UNKNOWN PAIR IS A LOUD FAILURE, NOT A SHRUG.** Every state-event pair is
## in `TRANSITIONS`; if one is ever missing, the machine says so rather than
## silently doing nothing, because a silent no-op is indistinguishable from a
## handled event and is the reason this table exists.
func handle(event: Event, ctx: CrowdContext) -> bool:
	var row: Dictionary = TRANSITIONS[state]
	if not row.has(event):
		Log.error("NpcBrain: no rule for %s in %s" % [event, state], &"crowd")
		return false
	var next: int = row[event]
	if next == IGNORED:
		return false
	_enter(next as State, ctx)
	return true


## Enter `next`, setting its timer. **Re-entering STARTLE restarts the timer**,
## which is why this does not early-out on `next == state`: an NPC startled again
## while already fleeing should flee for the full duration from the second
## scare, not finish the first one.
func _enter(next: State, ctx: CrowdContext) -> void:
	# **THE PROPAGATION FLAG CLEARS WHEN THE FLEEING STOPS, NOT WHEN IT STARTS.**
	# US-0044. Set once per wave so an NPC cannot scare its neighbours twice; kept
	# while it is still running, so a re-startle does not buy a second round; and
	# cleared on the way out, or an NPC would propagate exactly once per **match**
	# and every wave after the first would die at its first hop.
	if next != State.STARTLE:
		has_propagated = false
	state = next
	timer_ticks = _duration_ticks(next, ctx)


## How long the new state lasts, in net ticks. Zero means "until an event says
## otherwise" — Stroll and WalkingGroup both end on something happening rather
## than on a clock.
func _duration_ticks(next: State, ctx: CrowdContext) -> int:
	match next:
		State.IDLE:
			return _idle_ticks(ctx)
		State.STARTLE:
			return Tuning.ticks(&"TUN-CROWD-STARTLE-DURATION")
		State.GAWK:
			return Tuning.ticks(&"TUN-CROWD-GAWK-DURATION")
		_:
			return 0


## A pause between `TUN-CROWD-IDLE-DURATION-MIN` and `-MAX`, drawn from the
## **seeded** generator.
##
## Drawn rather than fixed because a crowd whose pauses are all the same length
## reads as a mechanism: ninety NPCs moving off together is the single most
## legible tell a city can have. Falls back to the minimum when there is no
## generator, so a brain stepped without one is still deterministic — an NPC that
## paused for a random length in a test would make every other assertion flaky.
func _idle_ticks(ctx: CrowdContext) -> int:
	if ctx.rng == null:
		return Tuning.ticks(&"TUN-CROWD-IDLE-DURATION-MIN")
	var seconds := ctx.rng.randf_range(
		Tuning.crowd.idle_duration_min, Tuning.crowd.idle_duration_max
	)
	return maxi(int(round(seconds * Tuning.net.server_tick)), 1)


## Reset to a freshly-spawned NPC. Used when the pool activates one; **not** a
## constructor, because the pool reuses brains along with the bodies.
func reset() -> void:
	state = State.STROLL
	timer_ticks = 0
	has_propagated = false
