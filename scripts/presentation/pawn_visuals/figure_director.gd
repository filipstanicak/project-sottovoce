## **TELLS THE PLAYERS' FIGURES WHAT THEIR PAWNS ARE DOING.** US-0109. CLIENT ONLY.
##
## A figure works out for itself how it is moving and where it stands. What it
## cannot see is its pawn's state: that it is climbing, mid-kill, stunned, dead.
## The local pawn's state is in its own context and every other player's has been
## on the wire since US-0029, read by nothing; this hands each to its figure.
##
## **EVERY ACT HERE IS PAST THE ANONYMITY BOUNDARY** (ANIMATION_SPEC §1). Idle,
## blend-walk, stroll, sitting and leaning are not acts: they are read from
## movement and place, the same way for a player and a civilian, so there is
## nothing in this file that could give a clone away.
class_name FigureDirector
extends Node

## The pawn states a figure shows as something other than walking.
const ACTS := {
	&"Climb": FigureMotion.Act.CLIMB,
	&"Vault": FigureMotion.Act.AIRBORNE,
	&"Drop": FigureMotion.Act.AIRBORNE,
	&"KillAnim": FigureMotion.Act.STRIKE,
	&"StunAnim": FigureMotion.Act.SHOVE,
	&"Stunned": FigureMotion.Act.REEL,
	&"Staggered": FigureMotion.Act.STAGGER,
	&"Choking": FigureMotion.Act.CHOKE,
	&"Dead": FigureMotion.Act.FALL,
	&"Lunging": FigureMotion.Act.DASH,
}

## `NpcBrain.State`'s order, which is what a civilian's record carries.
const NPC_STARTLE := 3
const NPC_GAWK := 4

var _driver: LocalPawnDriver
var _local: PersonaBody
var _remotes: RemotePawns


func bind(driver: LocalPawnDriver, local: PersonaBody, remotes: RemotePawns) -> void:
	_driver = driver
	_local = local
	_remotes = remotes


## What a pawn in `state` is shown doing.
static func act_of(state: StringName) -> FigureMotion.Act:
	return ACTS.get(state, FigureMotion.Act.NONE)


## What a civilian whose brain is in `state` is shown doing.
static func act_of_npc(state: int) -> FigureMotion.Act:
	if state == NPC_STARTLE:
		return FigureMotion.Act.FLINCH
	if state == NPC_GAWK:
		return FigureMotion.Act.GAWK
	return FigureMotion.Act.NONE


func _physics_process(_delta: float) -> void:
	if _local != null and _driver != null and _driver.ctx != null:
		_local.act(act_of(_driver.ctx.state_id))
	if _remotes == null:
		return
	for slot: int in _remotes.slots():
		var pawn := _remotes.pawn_of(slot)
		var body := null if pawn == null else pawn.get_node_or_null("PersonaVisuals") as PersonaBody
		if body != null:
			body.act(act_of(_remotes.state_of(slot)))
