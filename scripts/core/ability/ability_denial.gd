## **WHY AN ABILITY REQUEST WAS REFUSED.** TDD-09 §1.1, US-0066. PURE.
##
## Five validations, five reasons, and one value for "it was not refused". The
## reason travels on `NET-S2C-ABILITY-DENIED` so the client can cancel the tell it
## already played and say *why* — GDD-02 §9's failure mode 7 is a player pressing a
## button, seeing nothing, and blaming the game.
##
## **THIS IS THE OPPOSITE OF THE STUN REFUSAL, AND THE DIFFERENCE IS WHO IT IS
## ABOUT.** `SYS-STUN` answers every rejection identically, because a reason there
## would be a free identity probe: press at a stranger and read whether the answer
## means *not your pursuer* or *your pursuer, being careful*. Every reason here is a
## fact about **the presser's own kit and their own body** — their cooldown, their
## loadout, their state, their aim. None of them names or describes anybody else,
## so none of them can be used to learn anything about a stranger.
class_name AbilityDenial
extends RefCounted

enum Why {
	## Not refused.
	NONE,
	## The slot holds nothing in this match's locked loadout.
	NOT_EQUIPPED,
	## This ability's own cooldown has not expired.
	ON_COOLDOWN,
	## `TUN-ABILITY-GLOBAL-COOLDOWN` since the last activation of anything.
	GLOBAL_COOLDOWN,
	## Stunned, dead, mid-kill or respawning.
	ILLEGAL_STATE,
	## Reserved. **Aim is CLAMPED rather than refused** (TDD-09 §1.1), so nothing
	## returns this today — it exists because the protocol row does, and because an
	## ability that needs a hard range limit should reach for the reason that
	## already means what it means rather than inventing a sixth.
	OUT_OF_RANGE,
	## Reserved for an ability that requires line of sight. None of the MVP three
	## does: Cinderfall is thrown, Lunge is a dash, Second Face is on the self.
	NO_LOS,
}

## The string-table key for a reason, so the HUD never holds a user-facing literal
## (never-do #10). Absent keys are a `test_ability_validation.gd` failure rather
## than a silent fallback to the key itself.
const KEYS: Dictionary = {
	Why.NOT_EQUIPPED: &"ui.ability.not_equipped",
	Why.ON_COOLDOWN: &"ui.ability.on_cooldown",
	Why.GLOBAL_COOLDOWN: &"ui.ability.global_cooldown",
	Why.ILLEGAL_STATE: &"ui.ability.illegal_state",
	Why.OUT_OF_RANGE: &"ui.ability.out_of_range",
	Why.NO_LOS: &"ui.ability.no_los",
}


static func key_for(why: Why) -> StringName:
	return KEYS.get(why, &"")
