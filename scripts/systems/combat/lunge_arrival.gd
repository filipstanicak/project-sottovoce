## **WHAT `ABIL-LUNGE`'s ARRIVAL IS WORTH, AND WHAT IT COSTS WHEN IT IS WORTH
## NOTHING.** US-0070, ADR-0018. SERVER ONLY.
##
## Split out of `KillSystem` when the pursuer stun took that file past its 400
## lines for the third time, and the seam mirrors `KillGates`': everything here is
## about the **arrival** — where the dash began, what it connected with, what a
## miss costs and how often each happens — and nothing here judges a press.
##
## **AN ARRIVAL IS A PRESS THE PLAYER DID NOT HAVE TO MAKE**, so `KillSystem` still
## judges it with the same rules and the same queue. What is different is only the
## two ends: it carries a dash origin in, and a refusal costs a stagger rather than
## suspicion on the way out.
class_name LungeArrival
extends RefCounted

## Counted apart from presses (US-0070). GDD-04 §3.4's failure mode is Lunge above
## ~15 % of kills, and a rate nobody can read is a rate nobody will check.
var judged: int = 0
var landed: int = 0
var whiffed: int = 0

## **WHY THE LAST ONE MISSED.** A whiff reaches nobody by design — GDD-04 §3.4
## prices a miss at `TUN-LUNGE-WHIFF-STAGGER` and nothing else — which is right for
## the player and leaves a developer unable to tell *overshot* from *behind you*.
var last_whiff: KillVerdict.V = KillVerdict.V.ALLOWED

## peer -> where their dash began, for this tick only. **Recorded by `LungeEffect`
## at the burst rather than derived from the final yaw**, because `LungingState`
## keeps the camera and a player who turned mid-dash would have their corridor
## drawn along a heading they never travelled.
var _from: Dictionary = {}


func remember(peer: int, from: Vector3) -> void:
	_from[peer] = from


## **THE FALLBACK IS THE ARRIVAL POINT, WHICH DEGENERATES THE CORRIDOR TO A
## POINT.** That is exactly the endpoint rule this ability had before ADR-0018, so
## a press with no recorded dash is judged the way a press should be.
func origin_of(peer: int, fallback := Vector3.INF) -> Vector3:
	return _from.get(peer, fallback) as Vector3


func clear() -> void:
	_from.clear()


## **A DASH THAT DID NOT KILL MAY STILL HAVE CONNECTED WITH A PURSUER**
## (ADR-0018). The kill is asked first and this second, which is the reference's
## own ordering — *a kill is always prioritised over a stun* — and it is the whole
## of what makes `ABIL-LUNGE` a defensive verb as well as an opener.
##
## **A CONNECTION IS NOT A MISS**, so a dash that stuns pays no whiff stagger: the
## player read an approach and spent a 30 s cooldown on it, and the stagger is
## priced for arriving at *nothing*.
## **THE LOCKOUT AND THE STATE ARE ARMED TOGETHER, ON ADJACENT LINES** (ADR-0017).
## The lockout answers *may this player initiate*, which both combat systems must
## ask with no state machine in reach; the state is the tell and the tempo. Moving
## this function here dropped the lockout line and
## `test_the_whiff_is_a_state_and_a_lockout_together` went red on the same run —
## which is exactly why that test asserts both rather than either.
func missed(
	ctx: MatchContext, peer: int, why: KillVerdict.V, stun: StunSystem, lockouts: CombatLockouts
) -> void:
	if stun != null and stun.stun_from_arrival(ctx, peer, origin_of(peer)):
		return
	whiffed += 1
	last_whiff = why
	if lockouts != null:
		lockouts.stagger(peer, ctx.tick + maxi(Tuning.ticks(&"TUN-LUNGE-WHIFF-STAGGER"), 1))
	CombatEntry.stagger(ctx, peer, &"TUN-LUNGE-WHIFF-STAGGER")
