## **WHO IS EVERYBODY WEARING?** GDD-03 §6, US-0100, owner decision 13. PURE.
##
## A persona per player, dealt from the match's own seeded generator at the
## countdown — the same breath as `ContractCycle.open`'s Fisher-Yates deal, and for
## the same reason: a live server grew both by join order until somebody looked.
##
## **DUPLICATES ARE PERMITTED AND THAT IS THE RULE RATHER THAN A SHORTCUT.**
## US-0078: *"duplicate personas are GOOD: they add a candidate to each other's
## crowd."* Two Lucerna players are two more figures each has to be told apart from,
## which is the whole protection ADR-0021 leans on. A deal that dealt each persona
## at most once would be a second, unasked rule — and with six players and four
## personas it could not even hold.
##
## **IT IS A DEAL, NOT A CHOICE, AND IT IS TEMPORARY.** US-0078's
## `NET-C2S-LOADOUT` replaces this when the lobby exists; the lobby does not
## *enable* the persona, it overrides a value that is already there. Until then
## a dealt persona is what makes the portrait, the clone floor and the results
## table possible at all.
class_name PersonaDeal
extends RefCounted


## One persona per peer, in `CrowdRoster.PLAYABLE`'s order of names.
##
## **THE RNG IS THE MATCH'S OWN**, never `randi` — never-do #8, and the reason is
## reproducibility rather than fairness: a recorded seed must deal the same
## district twice or no playtest can be re-run against a tuning change.
##
## A null generator deals the first persona to everybody. That is the *safe*
## direction for a caller that forgot to seed: `CrowdRoster` already argues that
## clones of a persona nobody plays are harmless, while a player with no clones is
## GDD-03 §6.3 rule 5's marked man.
static func deal(peers: PackedInt32Array, rng: RandomNumberGenerator) -> Dictionary:
	var dealt: Dictionary = {}
	for peer: int in peers:
		dealt[peer] = one(rng)
	return dealt


## The single draw, so the countdown and the late joiner cannot disagree about
## what a deal is. A late joiner draws from the same generator, which keeps the
## whole match reproducible from its seed — a second source of randomness for
## "the same thing, later" is how a replay stops replaying.
static func one(rng: RandomNumberGenerator) -> StringName:
	var playable := CrowdRoster.PLAYABLE
	if rng == null:
		return playable[0]
	return playable[rng.randi_range(0, playable.size() - 1)]
