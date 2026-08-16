## **ONE OF THE FOUR PLAYABLE IDENTITIES.** DATA_SCHEMA §4.2, ART_BIBLE §6.1,
## ANIMATION_SPEC §7, US-0046.
##
## **`anonymous_clip_names` IS LAYER 1 OF FOUR**, and the four exist because a
## single check gets deleted eventually by somebody who does not know why it is
## there. This field is the *declaration* the other three are measured against:
## layer 2 asserts every entry exists in the clone's library, layer 3 asserts a
## running player never plays an off-list clip while Anonymous, and layer 4 is the
## director keeping clones near you (US-0047).
##
## **THE CONSTRAINT FAILS SILENTLY, WHICH IS WHY IT NEEDS FOUR LAYERS.** An
## animator adds a charming idle on the player rig. Nothing breaks, no test fails,
## the crowd count is unchanged — and three weeks later skilled testers pick humans
## out of the crowd reliably and cannot say how. Human review misses this every
## time, because the defect is an *absence* on a rig nobody was editing.
##
## **THE PARITY BOUNDARY IS EXACTLY THE SUSPICION CLIFF.** Parity is required for
## every animation reachable while Anonymous and for nothing else: jog, sprint,
## climb, vault, kill and ability casts need no clone equivalent, because a player
## performing them has already spent their anonymity. The rule is not "clones must
## do everything players do"; it is "clones must do everything a player does
## *while pretending to be a clone*".
class_name PersonaData
extends Resource

## The four silhouettes of ART_BIBLE §6.1. **Mutually distinct is a schema
## requirement** (DATA_SCHEMA §4.4): two personas sharing one would halve the
## number of things a hunter has to tell apart at 40 m.
enum Silhouette { LOW_BROAD, FLOOR_TRIANGLE, TALL_THIN, ROUND_MID }

## The fourteen clips ANIMATION_SPEC §7.1 requires of every persona, in the
## order the table lists them.
##
## **DECLARED HERE RATHER THAN PER-PERSONA BECAUSE IT IS THE SAME SET.** §7.1's
## table has a column per persona and a tick in every cell; four copies of one
## list is four places for it to drift, and the drift would be invisible — the
## persona missing a row would simply have one fewer thing its clones can do.
const PARITY_SET: Array[StringName] = [
	Ids.ANIM_IDLE_BASE,
	Ids.ANIM_IDLE_VAR_A,
	Ids.ANIM_IDLE_VAR_B,
	Ids.ANIM_IDLE_VAR_C,
	Ids.ANIM_TURN_L,
	Ids.ANIM_TURN_R,
	Ids.ANIM_BLENDWALK_LOOP,
	Ids.ANIM_BLENDWALK_START,
	Ids.ANIM_BLENDWALK_STOP,
	Ids.ANIM_STROLL_LOOP,
	Ids.ANIM_BLEND_SIT,
	Ids.ANIM_BLEND_LEAN,
	Ids.ANIM_BLEND_STAND,
	Ids.ANIM_BLEND_GROUP,
]

@export var id: StringName = &""
@export var display_key: StringName = &""
@export var silhouette: Silhouette = Silhouette.LOW_BROAD

## Standing height in metres, ART_BIBLE §6.1. **Not the collider**: every persona
## shares one 1.8 m capsule so that no clone is findable by walking into it, and
## these differ so that no clone is findable by looking. Both are the same rule
## from opposite ends.
@export var stand_height: float = 1.75

## Horizontal scale of the body capsule. Vetraio's ×1.4 shoulders and Lucerna's
## ×0.8 width are the whole of their silhouette claim.
@export var width_scale: float = 1.0

## `PackedScene`, once one exists. **Null today and deliberately so** — IP_GUARDRAILS
## §4 forbids a downloaded model ever entering this repository, so the four
## constructions are built from primitives at runtime by `PersonaBody` instead.
@export var mesh: PackedScene = null

## The clone rig's clips. **Null until an animator authors any** — there are no
## clips in this project at all, which is what leaves layer 2 reporting rather
## than asserting.
@export var animation_library: AnimationLibrary = null

## Reserved by ART_BIBLE §3's colour-language law. Identity hue is the *only*
## saturated colour a persona may carry, and per-instance variation on it is
## forbidden: any variation a player cannot also have is a discriminator, and any
## variation they can have is a cosmetic system, which `SCOPE_FENCE` OUT #3 rules
## out for exactly this reason.
@export var identity_hue: Color = Color.WHITE

## **THE CLONE-PARITY SET.** ANIMATION_SPEC §7.1's table, as names.
@export var anonymous_clip_names: PackedStringArray = PackedStringArray()


## Is `clip` one a player may perform while Anonymous?
##
## **LAYER 3 ASKS THIS EVERY TIME A PLAYER ENTERS AN ANONYMOUS-REACHABLE STATE**,
## in debug builds. A state playing an off-list clip is the failure layer 2 cannot
## see, because layer 2 checks the *declaration* against the library and this
## checks what actually played.
func is_anonymous_clip(clip: StringName) -> bool:
	return anonymous_clip_names.has(String(clip))


## Every clip in `PARITY_SET` this persona is missing from its declaration.
func missing_from_declaration() -> PackedStringArray:
	var absent := PackedStringArray()
	for clip: StringName in PARITY_SET:
		if not anonymous_clip_names.has(String(clip)):
			absent.append(String(clip))
	return absent


## Every declared clip that has no animation in the clone's library.
##
## **AN EMPTY LIBRARY RETURNS EVERY CLIP, NOT NONE.** That is the difference
## between "the rig is complete" and "there is no rig", and a check that
## conflated them would go green the moment somebody deleted the library.
func missing_from_library() -> PackedStringArray:
	var absent := PackedStringArray()
	for clip: String in anonymous_clip_names:
		if animation_library == null or not animation_library.has_animation(clip):
			absent.append(clip)
	return absent


func has_rig() -> bool:
	return animation_library != null
