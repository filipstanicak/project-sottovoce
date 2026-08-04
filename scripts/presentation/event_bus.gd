## The one-way systems-to-presentation channel (ADR-0006).
##
## SIGNAL DECLARATIONS AND COMMENTS ONLY. No var. No func. A stateful event bus
## is a global variable in disguise, and test_eventbus_is_stateless.gd exists to
## keep it that way — the moment the bus can be *read*, two widgets disagree
## about when to read it and the ordering becomes invisible.
##
## Signals are past-tense FACTS: the bus reports what has happened, never what
## should happen. `contract_assigned`, never `assign_contract` or `on_contract`.
##
## SYSTEMS NEVER LISTEN TO THIS. It carries information downhill only — systems
## to presentation. System-to-system communication is a direct typed call,
## because gameplay ordering matters and a bus makes ordering invisible
## (ADR-0006 rule 5, asserted by test_layer_dependencies).
##
## Each signal's docstring ends with its EVT- ID, the documentation identity in
## SIGNAL_AND_EVENT_BUS.md §3.
extends Node

# --- Facts -------------------------------------------------------------------
# State that has changed. A late listener has missed nothing it cannot re-read
# from a mirror.

## Own suspicion tier crossed a hysteresis boundary. active_sources is a bitfield
## (SPRINT ROOF CLIMB OPEN JOG RUN) so the HUD can say WHY, not just how much.
## EVT-SUSPICION-TIER-CHANGED
signal suspicion_tier_changed(tier: int, active_sources: int)

## Own suspicion value changed by at least 1.0. DEBUG OVERLAY ONLY — the number
## is never shown in the shipping HUD, because a legible number turns an authored
## uncertainty into arithmetic.
## EVT-SUSPICION-VALUE-CHANGED
signal suspicion_value_changed(value: float)

## A new contract was issued. Carries a REASON (START, KILL, RESPAWN, REPAIR),
## never an identity hint.
## EVT-CONTRACT-ASSIGNED
signal contract_assigned(reason: int)

## A Compass lock completed; the portrait fills permanently for this contract.
## The only way a hunter ever learns their contract's persona (ASM-0030).
## EVT-CONTRACT-PORTRAIT-REVEALED
signal contract_portrait_revealed(persona: StringName)

## Compass state for this snapshot. distance_bucket is an index, never metres —
## the imprecision is authored (design law 6).
## EVT-COMPASS-UPDATED
signal compass_updated(bearing: float, distance_bucket: int, lock: float)

## Match phase transition. multiplier is 1.0 or 2.0.
## EVT-MATCH-PHASE-CHANGED
signal match_phase_changed(phase: int, multiplier: float)

## A cooldown started, expired, or was corrected by the server. Remaining time is
## in TICKS, never seconds, because the server counts in ticks.
## EVT-ABILITY-COOLDOWN-CHANGED
signal ability_cooldown_changed(slot: int, remaining_ticks: int)

## Own blend began or ended: NONE, POCKET, GROUP, PROP_STATIC, PROP_CONCEAL.
## EVT-BLEND-STATE-CHANGED
signal blend_state_changed(blend_type: int)

## Server-computed validity of the kill and stun buttons changed. The client is
## told WHETHER, never allowed to decide.
## EVT-KILL-READY-CHANGED
signal kill_ready_changed(kill: bool, stun: bool)

## A hot reload or server profile sync landed. ANYTHING HOLDING A DERIVED TUNING
## VALUE MUST LISTEN, or it silently keeps the old one.
## EVT-TUNING-RELOADED
signal tuning_reloaded

# --- Moments -----------------------------------------------------------------
# Things that happened at an instant. A listener that misses one has missed it;
# there is no state to re-read.

## An immutable ScoreEvent was appended to the server's log. Typed as RefCounted
## until ScoreEvent lands in US-0030; the parameter is the event itself.
## EVT-SCORE-EVENT-APPENDED
signal score_event_appended(event: RefCounted)

## THE PREY WARNING. Takes ZERO parameters, deliberately.
##
## Directionlessness is enforced at three layers: NET-S2C-PREY-WARNING carries
## only a tick, this signal has no parameter, and the widget's flash is
## non-directional with a mono sting. There is nothing a widget COULD render.
##
## The panicked scan of a crowd is the best moment in the game, and a rule
## enforced in one widget does not survive refactoring.
## EVT-PREY-WARNING-TRIGGERED
signal prey_warning_triggered

## Any ability started within its tell radius. This is the tell channel that
## reaches a victim who was not looking at the caster (design law 3).
## EVT-ABILITY-STARTED
signal ability_started(peer: int, ability: StringName, origin: Vector3)

## Own ability request was refused, with a DenyReason.
## EVT-ABILITY-DENIED
signal ability_denied(slot: int, reason: int)

## A Compass pulse period elapsed. Audio only — the pulse IS the Compass.
## EVT-COMPASS-PULSED
signal compass_pulsed

## You killed, or you died. Never anyone else's kill: there is no global feed.
## EVT-KILL-RESOLVED
signal kill_resolved(killer: int, victim: int)

## You stunned, or were stunned. valid distinguishes a landed stun from a refused
## one, because a stun is worth as much as a kill (design law 5).
## EVT-STUN-RESOLVED
signal stun_resolved(stunner: int, target: int, valid: bool)

## An audio event flagged captionable fired. direction of zero means
## non-positional. The key indexes data/strings/en.csv — never a literal.
## EVT-CAPTION
signal caption(key: StringName, direction: Vector2)

## Connect, disconnect or timeout.
## EVT-CONNECTION-CHANGED
signal connection_changed(state: int, reason: int)
