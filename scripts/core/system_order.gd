## **THE ORDER SYSTEMS TICK IN, DECLARED ONCE.** TDD-01 §4.
##
## PURE and Core so it can be compared against the document that specifies it —
## `test_system_tick_order.gd` parses TDD-01 §4's diagram and asserts this list
## matches it, stage for stage, in order.
##
## **NOT SCENE-TREE ORDER.** Ticking systems in the order they happen to sit
## under `Systems/` makes the dependency invisible: it is correct until somebody
## drags a node in the editor, and then suspicion is computed against last tick's
## crowd. Nothing errors, nothing looks different, and a player accrues "alone"
## suspicion inside a pocket that has already re-formed.
##
## Three of the nine boundaries carry a real argument, and they are the reason
## this is a declaration rather than a convention:
##
## **Crowd before Suspicion**, because `TUN-SUSPICION-GAIN-OPEN` depends on
## whether an NPC is within `TUN-SUSPICION-OPEN-RADIUS`. A tick of lag lets a
## player be "alone" inside a pocket that has already re-formed.
##
## **Suspicion before Detection**, because detection renders per-observer state
## from *tier*. A tick of lag makes the silhouette disagree with the tier
## indicator, which is an information-channel defect.
##
## **Kill/Stun before Contract**, because the cycle must be repaired in the same
## tick the death resolves — nobody is ever contractless at a tick boundary.
class_name SystemOrder
extends RefCounted

## The ten stages of §4, in order. Names are the diagram's, lowercased and
## slugged — the guard compares against the document, so they are not free.
const STAGES: Array[StringName] = [
	&"ingest",
	&"pawn",
	&"crowd",
	&"suspicion",
	&"detection",
	&"abilities",
	&"combat",
	&"contract",
	&"score",
	&"snapshot",
]

## Stages that do not belong to a `GameSystem` at all, and never will.
##
## `ingest` is the router draining its queues, `pawn` is the pawn state machine
## substepping, and `snapshot` is the builder. They occupy a position in the
## order because *when* they happen matters, but registering a system under one
## of them would be a category error — and the director refuses it.
const NOT_SYSTEMS: Array[StringName] = [&"ingest", &"pawn", &"snapshot"]


static func position_of(stage: StringName) -> int:
	return STAGES.find(stage)


static func is_a_system_stage(stage: StringName) -> bool:
	return STAGES.has(stage) and not NOT_SYSTEMS.has(stage)
