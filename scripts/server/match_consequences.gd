## **WHAT HAPPENS TO THE REST OF THE WORLD WHEN A SYSTEM DECIDES AN OUTCOME.**
## SERVER ONLY. Split out of `server_root.gd` on 2026-09-04, when ADR-0019's two
## lines took that file to 417 against never-do #6's 400.
##
## **THE SEAM IS THE ONE `MatchAnnouncer` LEFT BEHIND.** That split took *who is
## told what*; this one takes *what else changes*, and what remains in `ServerRoot`
## is boot, registration and wiring. A death is the clearest case: `SYS-KILL`
## decides it and announces it, and nothing about the cycle, the crowd, the blend
## or suspicion is decided anywhere in that system.
##
## **EVERY METHOD HERE IS A SIGNAL HANDLER AND NONE OF THEM DECIDES ANYTHING.**
## The rule has already been applied by the time one is called; what these do is
## carry the consequence to the systems that own the state it changes. Anything in
## here that started making a judgement would be a rule implemented in the wiring.
class_name MatchConsequences
extends RefCounted

## **THE COLLABORATORS ARE FIELDS RATHER THAN CONSTRUCTOR ARGUMENTS**, and that is
## `.gdlintrc`'s six-argument cap being read as the design signal it says it is: a
## seven-argument constructor whose arguments are all systems is a call site where
## transposing two of them is invisible. Named assignment cannot be transposed.
var contracts: ContractSystem = null
var suspicion: SuspicionSystem = null
var abilities: AbilitySystem = null
var kills: KillSystem = null
var detection: DetectionSystem = null
var crowd: CrowdDirector = null
var announcer: MatchAnnouncer = null

var _ctx: MatchContext


func _init(ctx: MatchContext) -> void:
	_ctx = ctx


## **EVERY CONSEQUENCE OF A DEATH, IN THE TICK IT RESOLVES.** The contract repair
## runs first because `SystemOrder` puts the `contract` stage immediately after
## `combat`, and the invariant is that nobody is contractless at a tick boundary.
func killed(killer: int, victim: int, at: Vector3) -> void:
	contracts.report_death(victim, killer, _ctx)
	# **THE SAME SIGNAL THAT REGISTERS THE CORPSE**, two lines below, which is what
	# makes GDD-02 §3's `Dead --> Respawning: corpse spawned` edge true rather than
	# approximately true. `SYS-SPAWN` is `SYS-CONTRACT`'s, so the placement and the
	# cycle insertion land in one tick.
	contracts.spawn.report_death(victim, killer, _ctx)
	suspicion.blend.report_damage(victim, _ctx)
	crowd.register_corpse(at, _ctx.tick, victim)
	crowd.startle_at(at)
	_charge_for_witnesses(killer, at)
	abilities.on_death(victim)
	announcer.kill_landed(killer, victim)


## **THE PREY FOUGHT BACK, AND IT COSTS THE PURSUER THE CONTRACT.** ADR-0019. Being
## stunned in the reference loses you the target rather than four seconds of it, so
## the pursuer fails the contract and is dealt a new one.
##
## **STAGE 7 TO STAGE 8, THE ORDERING A KILL ALREADY RELIES ON.** `SYS-STUN` is
## judged inside `SYS-KILL` at `combat` and `SYS-CONTRACT` repairs at `contract`,
## so the freeze and the reassignment land in the same tick — the stunned player
## learns they have lost their prey while they are still on the ground, rather than
## a tick later as though it were a second event.
##
## **`target` IS THE PURSUER**, and the payment is `paid_for_stun`'s: paying the
## prey an escape award here as well would price one read twice.
func stunned(_stunner: int, target: int, _lockout_ticks: int) -> void:
	contracts.report_stun(target, _ctx)


func paid_for_stun(stunner: int, target: int, _lockout_ticks: int) -> void:
	if kills.scoring != null:
		kills.scoring.pay_for_stun(_ctx, stunner, target)


## **THE PREY GOT AWAY.** US-0097. `SYS-DETECTION` is stage 5 and `SYS-CONTRACT`
## stage 8, so the bar empties and the cycle repairs in one tick — the guarantee
## `combat` before `contract` already buys for a kill. The payment lives on
## `KillScoring` beside the stun's, which is where its reasoning is.
func escaped(hunter: int, prey: int, close_call: bool) -> void:
	contracts.report_escape(hunter, _ctx)
	kills.scoring.pay_for_escape(_ctx, prey, hunter, close_call)


## **THE CLOUD HIDES YOU AND PAINTS AN ARROW AT YOUR POSITION, AND THAT IS THE
## ABILITY'S HONEST COST.** GDD-04 §3.1: *"every NPC within 9 m runs"* — so
## Cinderfall buys line of sight at the price of telling everybody within 30 m
## roughly where you are. The radius is the caster's, not the violence default.
func ability_startled(at: Vector3, radius: float) -> void:
	crowd.startle_at(at, radius)


## US-0052's last criterion: `TUN-SUSPICION-GAIN-WITNESSED-KILL` applies only if
## another PLAYER had line of sight.
##
## **PRESENT-TENSE, NOT REWOUND.** A witness did not *act*, so there is nothing of
## theirs to compensate for — what they see is the animation and the corpse, now —
## and rewinding their position would charge the killer for somebody who has since
## walked away. The victim is not a witness to their own death and the killer is
## not a witness to their own act.
func _charge_for_witnesses(killer: int, at: Vector3) -> void:
	for peer: int in _ctx.pawn_contexts.keys():
		if peer == killer:
			continue
		var pawn := _ctx.pawn_contexts[peer] as PawnContext
		if pawn.state_id == PawnStateId.DEAD:
			continue
		if not detection.clear_line(pawn.position, at):
			continue
		_ctx.impulses.queue(killer, Tuning.suspicion.gain_witnessed_kill)
		return
