## The one-way systems-to-presentation channel (ADR-0006).
##
## SIGNAL DECLARATIONS AND COMMENTS ONLY. No var. No func. A stateful event bus
## is a global variable in disguise, and test_eventbus_is_stateless.gd exists to
## keep it that way.
##
## Signals are past-tense FACTS: the bus reports what has happened, never what
## should happen.
extends Node

# --- Facts -------------------------------------------------------------------

## Own suspicion tier crossed a hysteresis boundary. active_sources is a
## bitfield so the HUD can say WHY, not just how much.
signal suspicion_tier_changed(tier: int, active_sources: int)

## A new contract was issued. Carries a reason, never an identity hint.
signal contract_assigned(reason: int)

## A Compass lock completed; the portrait fills permanently for this contract.
signal contract_portrait_revealed(persona: StringName)

signal compass_updated(bearing: float, distance_bucket: int, lock: float)
signal match_phase_changed(phase: int, multiplier: float)
signal ability_cooldown_changed(slot: int, remaining_ticks: int)
signal blend_state_changed(blend_type: int)
signal kill_ready_changed(kill: bool, stun: bool)
signal tuning_reloaded

# --- Moments -----------------------------------------------------------------

signal score_event_appended(event: RefCounted)

## THE PREY WARNING. Takes ZERO parameters, deliberately.
##
## Directionlessness is enforced at three layers: the protocol carries only a
## tick, this signal has no parameter, and no widget has anything to render.
## A rule enforced in one place does not survive refactoring.
signal prey_warning_triggered

signal ability_started(peer: int, ability: StringName, origin: Vector3)
signal ability_denied(slot: int, reason: int)
signal compass_pulsed
signal kill_resolved(killer: int, victim: int)
signal stun_resolved(stunner: int, target: int, valid: bool)
signal caption(key: StringName, direction: Vector2)
signal connection_changed(state: int, reason: int)
