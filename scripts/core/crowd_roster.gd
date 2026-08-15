## **WHO EVERY NPC IS, DERIVED FROM THE SEED.** GDD-03 §6.3, TDD-08 §2, US-0039.
##
## PURE and Core: a seed and a count in, a list of persona and archetype IDs out.
## No nodes, no world, no autoload but `Tuning` — so "do three peers agree?" is a
## question a test can ask directly rather than by standing three peers up.
##
## **DERIVED, NEVER REPLICATED.** GDD-03 §6.3 rule 4: clone personas come from
## `match_seed`, identically on every peer. Sending the roster would cost 90
## bytes a match and would be the *cheap* failure; the expensive one is that if
## two players ever saw different clone distributions, **"I saw a Lucerna by the
## furnace" becomes a lie** and the entire social layer stops working.
##
## **THE WHOLE ROSTER IS DERIVED AT ONCE**, not per index. TDD-08 §2 sketches
## `persona_for(index, seed, in_use)`, but the quota it has to satisfy — 8 to 12
## clones *per persona* — is a property of the whole list, and a per-index
## function could only honour it by deriving the whole list on every call. The
## signature moved; the guarantee did not.
class_name CrowdRoster
extends RefCounted

## The four playable personas. **Every one of them is a clone roster**, and the
## order is part of the derivation for the same reason `ARCHETYPES`' is.
##
## Used as "everybody is in use" wherever the real loadouts are not known yet —
## there is no lobby until M4. That is the safe direction: GDD-03 §6.3 rule 5
## makes a player with no clones a marked man, while clones of a persona nobody
## plays are explicitly harmless.
const PLAYABLE: Array[StringName] = [
	Ids.PERSONA_CANTATRICE,
	Ids.PERSONA_LUCERNA,
	Ids.PERSONA_PESATORE,
	Ids.PERSONA_VETRAIO,
]

## Filler archetypes, in a fixed order. **The order is part of the derivation** —
## reordering this array changes every roster every seed produces, which would
## not break anything and would silently invalidate every recorded playtest.
const ARCHETYPES: Array[StringName] = [
	Ids.ARCH_CHILD,
	Ids.ARCH_FISHWIFE,
	Ids.ARCH_MENDICANT,
	Ids.ARCH_PORTER,
	Ids.ARCH_WATERCARRIER,
]


## Clones of each in-use persona, for a lobby of `players`.
##
## **REPRODUCES TUNABLES' THREE DOCUMENTED DEFAULTS FROM EXISTING TUNABLES**, and
## that is why it is written this way rather than as a ratio: 6 players → 12 each
## (48 clones + 30 filler = 78), 5 → 11 (44 + 28 = 72), 4 → 10 (40 + 26 = 66).
## Every one of those is TUNABLES §-crowd's own number.
##
## The rule is the one TUNABLES states in prose — *"fewer players need fewer
## clones for the same per-player anonymity"* — so each seat below a full lobby
## costs one clone per persona. Clamped into
## `TUN-CROWD-CLONES-PER-PERSONA-MIN..MAX` regardless, because rule 3 is a
## release blocker in both directions: below 8 a persona can be locally depleted
## and the player wearing it becomes unique; above 12 the crowd reads as a police
## lineup of repeats rather than a city.
static func clones_per_persona(players: int) -> int:
	var ceiling: int = Tuning.crowd.clones_per_persona_max
	var seats: int = Tuning.match_rules.max_players
	return clampi(ceiling - (seats - players), Tuning.crowd.clones_per_persona_min, ceiling)


## The roster: one persona or archetype ID per NPC index.
##
## Clones first — **every persona a player is wearing gets its full quota before
## a single filler is placed**, because GDD-03 §6.3 rule 5 makes that a release
## blocker: a player with zero clones is a marked man. Filler takes whatever
## remains, and the whole list is then shuffled by the seed so clones are not
## clustered at low indices, which would put them all at whichever spawn points
## the pool assigns first.
static func derive(count: int, match_seed: int, personas_in_use: Array, players: int) -> Array:
	var roster: Array[StringName] = []
	var quota := clones_per_persona(players)
	for persona: StringName in personas_in_use:
		for _i: int in quota:
			if roster.size() < count:
				roster.append(persona)

	var rng := RandomNumberGenerator.new()
	rng.seed = _seed_for(match_seed)
	while roster.size() < count:
		roster.append(ARCHETYPES[rng.randi_range(0, ARCHETYPES.size() - 1)])

	_shuffle(roster, rng)
	return roster


## **THE SEED IS MIXED, NOT USED RAW.** Two matches whose seeds differ by one
## would otherwise produce rosters that differ in one draw — a pattern nobody
## would notice and every replay would inherit.
static func _seed_for(match_seed: int) -> int:
	return hash(match_seed) ^ 2654435761


## Fisher–Yates against the seeded generator. **Not `Array.shuffle()`**, which
## draws from the global RNG — banned outside `scripts/presentation/` by CLAUDE.md
## rule 8, and non-deterministic, which is the one thing this file exists to
## avoid.
static func _shuffle(roster: Array, rng: RandomNumberGenerator) -> void:
	for i: int in range(roster.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var held: StringName = roster[i]
		roster[i] = roster[j]
		roster[j] = held


## A stable summary of a roster, for the parity assertion. Two peers agree if and
## only if these match.
static func fingerprint(roster: Array) -> String:
	var parts := PackedStringArray()
	for id: StringName in roster:
		parts.append(String(id))
	return ",".join(parts).md5_text()


## How many of each ID a roster holds. For the quota assertions, and for anyone
## debugging a crowd that reads wrong.
static func census(roster: Array) -> Dictionary:
	var counts: Dictionary = {}
	for id: StringName in roster:
		counts[id] = int(counts.get(id, 0)) + 1
	return counts
