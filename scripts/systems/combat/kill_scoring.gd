## **WHAT WAS TRUE WHEN THE PLAYER PRESSED, GATHERED FROM THE WORLD.** TDD-10 §2,
## US-0065. SERVER ONLY.
##
## The thin half of scoring: it reads `MatchContext` and fills a `KillScoreFacts`.
## Every judgement about what those facts are *worth* is `ScoreBonuses`, which is
## pure and knows nothing about a context — so the part that can be wrong in an
## interesting way is the part a unit test can drive.
##
## **CAPTURED AT INITIATION AND PAID AT THE CONTACT FRAME.** `KillSystem` holds the
## facts on its pending row for the 0.9 s between the two, because GDD-07 §3 judges
## every bonus at the moment the player committed. A hunter who was Anonymous when
## they pressed does not lose Silent to the animation they cannot cancel.
class_name KillScoring
extends RefCounted

var _blend: BlendSystem = null


## `SYS-BLEND` is owned by `SYS-SUSPICION`, so it is handed over rather than
## reached for. Null is legal and means no blend bonus — which is what a test
## fixture with no suspicion system gets, and it is the safe direction.
func _init(blend: BlendSystem = null) -> void:
	_blend = blend


## Everything GDD-07 §3 judges, read once, at the tick of the press.
func facts_at(ctx: MatchContext, killer: int, victim: int) -> KillScoreFacts:
	var facts := KillScoreFacts.new()
	facts.tick = ctx.tick
	facts.killer = killer
	facts.victim = victim
	var here: PawnContext = ctx.pawn_contexts.get(killer)
	var there: PawnContext = ctx.pawn_contexts.get(victim)
	if here == null or there == null:
		return facts
	var windows := ctx.score_windows
	facts.tier = here.tier
	facts.patient = windows.peak_speed(killer) <= Tuning.scoring.patient_speed
	facts.focus_ticks = windows.focus_ticks(killer)
	facts.height = here.position.y - there.position.y
	facts.blended = _blend != null and _blend.grace_ticks_remaining(killer) > 0
	facts.hunt_ticks = windows.hunt_ticks(killer, ctx.tick)
	facts.vendetta = windows.avenges(killer, victim)
	# **MASKED AND POISONED ARE BOTH DORMANT, FOR DIFFERENT REASONS.**
	# `ABIL-SECONDFACE` is US-0069 and there is no `AbilitySystem` to ask; a
	# delayed-kill ability is post-MVP entirely (ASM-0016). Both stay false here
	# rather than absent from `KillScoreFacts`, so the day either arrives it is one
	# assignment and not a rule to re-derive.
	return facts


## **EVERY SCORING CONSEQUENCE OF A KILL, IN ONE PLACE AND ONE FEED GROUP.** The
## bonuses, `SCORE-VARIETY`, the victim's `SCORE-DEATH` marker, and the two windows
## a death resets.
##
## **THE AWARDS CARRY THE INITIATION TICK AND THE DEATH MARKER CARRIES NOW.** They
## are different moments 0.9 s apart and the multiplier is frozen from whichever is
## on the event — the bonuses were earned when the player pressed, and the death
## happened when the body fell.
func pay_for_kill(ctx: MatchContext, facts: KillScoreFacts) -> int:
	var awards := ScoreBonuses.for_kill(facts, Tuning.scoring)
	var group := ctx.score.append_kill(awards, Tuning.match_rules, Tuning.scoring)
	ctx.score.mark_death(ctx.tick, facts.victim, facts.killer, Tuning.match_rules, group)
	# **THE DEBT IS RECORDED AND THE VICTIM'S WINDOWS END.** `note_killed_by` is
	# what `SCORE-VENDETTA` reads, and the overwrite is what makes "and has not
	# died since" true without a second field.
	ctx.score_windows.note_killed_by(facts.victim, facts.killer)
	ctx.score_windows.report_death(facts.victim)
	return group


## **PAY THE PREY FOR SURVIVING A HUNT.** US-0097, ADR-0014.
##
## Beside `pay_for_stun` rather than in `server_root`, because these are the prey's
## **two non-death outcomes** — stun the hunter, or lose them — and invariants 19
## and 37 price both against the same base kill. Splitting them across two files
## would put one under a rule the other could drift from.
##
## **THE ACTOR IS THE PREY AND THE SUBJECT IS THE HUNTER.** `NET-S2C-SCORE-EVENT`
## reaches `ScoreEvent.actor_id` alone, so the hunter is never told they were
## escaped from; they find out because their Compass stops pointing.
func pay_for_escape(ctx: MatchContext, prey: int, hunter: int, close_call: bool) -> void:
	var group := ctx.score.open_group()
	for award: ScoreAward in ScoreBonuses.for_escape(
		ctx.tick, prey, hunter, close_call, Tuning.scoring
	):
		ctx.score.append(award, Tuning.match_rules, group)


## Pay for a landed stun. **One base kill, and no variety group** — a stun is one
## award, so a group would be a feed line with nothing to group.
func pay_for_stun(ctx: MatchContext, stunner: int, target: int) -> void:
	for award: ScoreAward in ScoreBonuses.for_stun(ctx.tick, stunner, target, Tuning.scoring):
		ctx.score.append(award, Tuning.match_rules, ctx.score.open_group())
