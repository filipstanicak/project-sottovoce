## **WHEN GDD-03 §6.3 RULE 3 BINDS, AND WHY IT DOES NOT BIND AT THE INSTANT A
## PLAYER IS PLACED.** GDD-03 §6.3 rule 3, GDD-05 §2.7 rule 8, TDD-08 §5.1.5.
## PURE — `Tuning` only, which ADR-0005 permits in Core.
##
## Rule 3 asks for `TUN-CROWD-CLONE-LOCAL-MIN` clones of each in-use persona
## within `TUN-CROWD-CLONE-LOCAL-RADIUS` of every player. It said **at all times**
## until 2026-08-21, and "all times" includes the tick a player is placed — which
## no arrangement of the crowd can honour on a map whose thinnest spawn point can
## see one NPC. **A release blocker nothing can satisfy is one nobody can act on**,
## and this one was reported rather than acted on for two milestones.
##
## **THE SCOPE IS THE RULE'S OWN PURPOSE, NOT A DISCOUNT ON IT.** Rule 3 protects a
## player from being the only instance of their persona *where they are standing*.
## At the instant of placement they have not chosen where they are standing — the
## match chose — so what the rule can fairly require is that they are covered from
## the moment they could have moved.
##
## **AND THE GRACE IS THAT MOVE, DERIVED RATHER THAN CHOSEN.** One director pass,
## the soonest the crowd can notice, plus one crossing of the local radius at
## stroll. That is both how long a fetched clone takes to reach the player and how
## long the player takes to reach the crowd, **and it is one number for one
## reason**: invariant 1 forces `TUN-CROWD-NPC-SPEED-STROLL` to equal
## `TUN-SPEED-BLENDWALK`, so the two walks are the same walk. The player is never
## asked to spend speed — design law 1 — to buy back their anonymity.
##
## **WHAT THE SCOPE DOES NOT DO IS EXCUSE THE OPENING ARRANGEMENT.** That is
## GDD-05 §2.7 rule 8's now, and three of `MAP-VETRAIO`'s six spawn points fail it.
## Moving the obligation is the whole of the change: it turns a design law no map
## could satisfy into a level pass somebody can run.
class_name CloneParity


## Seconds after a player is placed before rule 3 binds on them.
##
## **NOT A TUNABLE, BECAUSE IT IS NOT A CHOICE.** Every term is already tuned, and
## a fourth number here could be set to a value the first three contradict — a
## grace shorter than the walk would bind the rule before anybody could satisfy it,
## and a longer one would be an exemption nothing earns. Retune any of the three
## and this follows. Same reasoning as `CloneBalance._anchors_for`'s margin.
static func grace_seconds() -> float:
	return Tuning.crowd.director_interval + walk_seconds()


## One crossing of the local radius at stroll — the journey at both ends of the
## rule. About eighteen seconds at the shipped values.
static func walk_seconds() -> float:
	return Tuning.crowd.clone_local_radius / maxf(Tuning.crowd.npc_speed_stroll, 0.01)


## The same window at the 30 Hz net tick, which is what every caller counts in.
## Rounded **up**: binding the rule on the tick the walk is still finishing would
## report a breach that the next tick resolves.
static func grace_ticks() -> int:
	return int(ceil(grace_seconds() * Tuning.net.snapshot_rate))


## How many clone seats one position must offer for rule 3 to be satisfiable
## there at all — `TUN-CROWD-CLONE-LOCAL-MIN` for each persona that could be in
## use. **A permutation cannot conjure a seat that is not there**, so this is what
## separates a level-data defect from a scheduling one, and it is GDD-05 §2.7
## rule 8's threshold.
static func seats_required() -> int:
	return int(Tuning.crowd.clone_local_min) * CrowdRoster.PLAYABLE.size()
