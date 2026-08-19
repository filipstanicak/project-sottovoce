## The wire-and-budget half of TUNABLES.md §17's cross-field invariants:
## replication, lag compensation and the client frame budget.
##
## **SPLIT OUT OF `TuningInvariants` WHEN THAT FILE REACHED 400 LINES**, at the two
## rate-LOD invariants US-0031 added. The division is by subject rather than by
## size: these are rules about how the game is *transmitted*, and the ones left
## behind are rules about how it *plays*. `TuningInvariants.check()` calls this, so
## there is still exactly one entry point and no caller has to know about the split.
class_name TuningInvariantsTech
extends RefCounted


static func check(p: TuningProfile) -> Array[String]:
	var e: Array[String] = []
	e.append_array(_net(p))
	e.append_array(_npc_replication(p))
	e.append_array(_perf(p))
	return e


static func _net(p: TuningProfile) -> Array[String]:
	var e: Array[String] = []
	# 16. The history buffer is never the binding constraint.
	if p.net.lagcomp_max > p.net.lagcomp_history / 2.0:
		e.append(
			(
				"16. net.lagcomp_max (%.1f) must be <= net.lagcomp_history / 2 (%.1f)"
				% [p.net.lagcomp_max, p.net.lagcomp_history / 2.0]
			)
		)
	return e


## **THE THREE RADII AND THE TWO RATES THAT DECIDE WHAT REACHES A CLIENT.** Split
## out of `_net` when it passed 40 lines — and it reads better for it, because
## these four are one rule seen from four sides: full detail near, reduced detail
## in a band, nothing beyond, and every gameplay radius inside the lot.
static func _npc_replication(p: TuningProfile) -> Array[String]:
	var e: Array[String] = []
	# 17. A culled NPC can never affect anything the client can perceive.
	if p.net.npc_cull_radius < p.compass.range_max:
		e.append(
			(
				"17. net.npc_cull_radius (%.1f) must be >= compass.range_max (%.1f)"
				% [p.net.npc_cull_radius, p.compass.range_max]
			)
		)
	# 29. A clone kept near a player must be one that player can see.
	if p.crowd.clone_local_radius > p.net.npc_cull_radius:
		e.append(
			(
				"29. crowd.clone_local_radius (%.1f) must be <= net.npc_cull_radius (%.1f)"
				% [p.crowd.clone_local_radius, p.net.npc_cull_radius]
			)
		)
	# 30. A rate-LOD radius past the cull radius describes a band that cannot
	# exist, and the symptom is nothing at all: the branch is never reached.
	if p.net.npc_rate_lod_radius > p.net.npc_cull_radius:
		e.append(
			(
				"30. net.npc_rate_lod_radius (%.1f) must be <= net.npc_cull_radius (%.1f)"
				% [p.net.npc_rate_lod_radius, p.net.npc_cull_radius]
			)
		)
	# 31. A "reduced" rate above the snapshot rate is not one: the stride rounds to
	# one and every far NPC is sent every tick, while the tunable claims a saving.
	if p.net.npc_rate_lod_hz > p.net.snapshot_rate:
		e.append(
			(
				"31. net.npc_rate_lod_hz (%.1f) must be <= net.snapshot_rate (%.1f)"
				% [p.net.npc_rate_lod_hz, p.net.snapshot_rate]
			)
		)
	return e


static func _perf(p: TuningProfile) -> Array[String]:
	var e: Array[String] = []
	var spent := (
		p.perf.crowd_budget
		+ p.perf.net_budget
		+ p.perf.gameplay_budget
		+ p.perf.ui_budget
		+ p.perf.render_budget
	)
	if spent > p.perf.frame_budget:
		e.append(
			(
				"20. client budgets sum to %.2f ms, over frame_budget %.2f ms"
				% [spent, p.perf.frame_budget]
			)
		)
	return e
