## **NO RELAXATION PATH EVER DROPS THE SELF FILTER.** US-0049, GDD-03 §7.2.
##
## Insertion prefers a position that is not self, not a recent contract and not
## adjacent to the killer, and drops those constraints in a fixed order when none
## satisfies all three. **Self-assignment is the only one that never relaxes**, and
## a self-contract is not a degraded outcome — it is a player told to hunt
## themselves, which no rule downstream is written to survive.
##
## Two guards, because either alone is weak. The behavioural one sweeps every small
## cycle exhaustively; the structural one refuses a `_candidates` whose self filter
## sits inside a stage branch, which is how it would come to relax by accident.
extends GutTest

const SEED := 20260821
const SOURCE := "res://scripts/core/contract/contract_cycle.gd"


func _rng(offset: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + offset
	return rng


func test_no_insertion_at_any_size_or_seed_produces_a_self_contract() -> void:
	# Exhaustive over the sizes a six-player match can present, every killer choice,
	# and enough seeds that the random pick inside each stage is not a single draw.
	var checked := 0
	for count: int in range(0, 7):
		for killer_slot: int in range(-1, count):
			for offset: int in 6:
				var cycle := ContractCycle.new(_rng(offset))
				var players := PackedInt32Array()
				for index: int in count:
					players.append(10 + index)
				cycle.open(players)
				var killer: int = (
					ContractCycle.NOBODY if killer_slot < 0 else int(cycle.living()[killer_slot])
				)
				cycle.insert(99, killer)
				checked += 1
				assert_ne(cycle.contract_of(99), 99, "peer 99 was told to hunt itself")
				assert_ne(cycle.pursuer_of(99), 99, "peer 99 is its own pursuer")
				assert_eq(cycle.assert_valid(), "", "invalid after inserting into %d" % count)
	gut.p("swept %d insertions across sizes 0-6" % checked)
	assert_gt(checked, 100, "the sweep was too small to mean anything")


func test_the_self_filter_holds_when_every_other_constraint_is_impossible() -> void:
	# **THE CASE THAT FORCES FULL RELAXATION.** A one-player cycle offers two
	# insertion points and both have the same neighbour on either side, so a killer
	# rule and an anti-repeat rule naming that neighbour cannot both be satisfied —
	# the pass must fall through to the last stage and still refuse self.
	var cycle := ContractCycle.new(_rng(0))
	cycle.open(PackedInt32Array([10, 11]))
	# 11 holds a contract on 10, then dies and comes back with 10 as its killer:
	# every remaining position is both a repeat and killer-adjacent.
	var repeat := cycle.contract_of(11)
	cycle.remove(11)
	assert_eq(cycle.size(), 1, "the cycle is not down to one")
	assert_true(cycle.insert(11, 10), "the insertion failed rather than relaxing")
	assert_eq(cycle.size(), 2, "the player did not come back")
	assert_ne(cycle.contract_of(11), 11, "full relaxation produced a self-contract")
	assert_eq(cycle.assert_valid(), "", "the cycle is invalid after full relaxation")
	gut.p(
		(
			"relaxed to the last stage and returned a contract on %d (repeat was %d)"
			% [cycle.contract_of(11), repeat]
		)
	)


func test_a_respawn_avoids_the_contract_it_just_held_where_it_can() -> void:
	# `TUN-CONTRACT-ANTI-REPEAT-DEPTH`, and the reason the history must OUTLIVE the
	# removal: the only reader of `_recent` is the insertion that happens when a
	# player comes back. The first version of `remove()` erased it, which made this
	# rule inert for the one case it exists for while every live-cycle test passed.
	var avoided := 0
	var attempts := 0
	for offset: int in 40:
		var cycle := ContractCycle.new(_rng(offset))
		cycle.open(PackedInt32Array([10, 11, 12, 13, 14]))
		var peer := 11
		var held := cycle.contract_of(peer)
		cycle.remove(peer)
		cycle.insert(peer, ContractCycle.NOBODY)
		attempts += 1
		if cycle.contract_of(peer) != held:
			avoided += 1
	gut.p("avoided the repeat in %d of %d respawns" % [avoided, attempts])
	assert_eq(
		avoided,
		attempts,
		(
			"a respawning player was handed the contract it just held, with four other "
			+ "positions available — TUN-CONTRACT-ANTI-REPEAT-DEPTH is inert"
		)
	)


func test_the_self_filter_is_not_inside_a_relaxation_branch() -> void:
	# **THE STRUCTURAL HALF.** The behavioural sweep above can only find a self
	# contract the constraints happen to produce; this refuses the shape that would
	# make one possible — a self filter guarded by the stage, so a future fourth
	# relaxation level silently drops it. Falsified by moving the filter below the
	# first `stage ==` comparison.
	var source := SourceScanner.read(SOURCE)
	assert_gt(source.length(), 500, "the source is missing or tiny — the scan is vacuous")
	var body := source.substr(source.find("func _candidates("))
	assert_gt(body.length(), 200, "_candidates was not found — this guard scans nothing")
	var self_filter := body.find("predecessor == peer or successor == peer")
	var first_stage := body.find("if stage ==")
	assert_gt(self_filter, -1, "the self filter is gone from _candidates")
	assert_gt(first_stage, -1, "no relaxation branch found — the scan is aimed at the wrong code")
	assert_lt(
		self_filter,
		first_stage,
		(
			"the self filter sits below the first relaxation branch in _candidates, so a "
			+ "stage that skipped it would assign a player to hunt themselves"
		)
	)
