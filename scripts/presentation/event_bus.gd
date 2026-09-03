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
## **EVERY PLAYER-SHAPED PARAMETER HERE IS A WIRE SLOT, NEVER A PEER ID.** A
## client has no peer ids at all — `SlotTable` exists because Godot hands out
## random 32-bit ids and `NETWORK_PROTOCOL` §4 declares a byte. Three of these
## signals were declared taking `peer`, `killer`, `victim`, which reads as
## something a client could never supply; renamed 2026-09-02 when the bridge was
## finally wired to them.
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

## Both sides of a pursuit, `[0, 1]` each: the chase YOU are running and the chase
## run AGAINST you. Two values because a Hamiltonian cycle makes every player both
## at once. Names nobody — a bar, never a finger on it.
## EVT-PURSUIT-CHANGED
signal pursuit_changed(hunting: float, hunted: float)

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

## THE PREY WARNING. A world bearing in radians and a Quantise.BUCKET_STEP
## distance bucket — and nothing else, ever.
##
## AMENDED 2026-08-26 (ADR-0013, US-0059). This signal took zero parameters until
## then, as the middle layer of a three-layer directionlessness rule. The
## reference marks a revealed pursuer with bearing and range, so this does too.
## The old argument is preserved in GDD-01 Law 5 rather than deleted, because the
## cost it names — the panicked scan of a crowd — is real and was knowingly paid.
##
## WHAT SURVIVES IS THE HALF THAT MATTERS MORE: it says WHERE, never WHO. A
## persona, a slot, a name or a colour here would collapse the crowd from
## seventy-eight candidates to one, permanently and for free, and ASM-0030's
## Compass lock would have nothing left to earn. test_prey_warning_signal_arity.gd
## refuses an identifying parameter on this line.
##
## The bearing is WORLD. A widget rotates it by the local yaw every rendered
## frame, the same decision SYS-COMPASS made in US-0057.
## EVT-PREY-WARNING-TRIGGERED
signal prey_warning_triggered(bearing: float, bucket: int)

## Any ability started within its tell radius. This is the tell channel that
## reaches a victim who was not looking at the caster (design law 3).
## EVT-ABILITY-STARTED
signal ability_started(caster_slot: int, ability: StringName, origin: Vector3, at: Vector3)

## Own ability request was refused, with a DenyReason.
## EVT-ABILITY-DENIED
signal ability_denied(slot: int, reason: int)

## A Compass pulse period elapsed. Audio only — the pulse IS the Compass.
## EVT-COMPASS-PULSED
signal compass_pulsed

## You killed, or you died. Never anyone else's kill: there is no global feed.
## EVT-KILL-RESOLVED
signal kill_resolved(killer_slot: int, victim_slot: int)

## You stunned, or were stunned. valid distinguishes a landed stun from a refused
## one, because a stun is worth as much as a kill (design law 5).
## EVT-STUN-RESOLVED
signal stun_resolved(stunner_slot: int, target_slot: int, valid: bool)

## An audio event flagged captionable fired. direction of zero means
## non-positional. The key indexes data/strings/en.csv — never a literal.
## EVT-CAPTION
signal caption(key: StringName, direction: Vector2)

## Connect, disconnect or timeout.
## EVT-CONNECTION-CHANGED
signal connection_changed(state: int, reason: int)
