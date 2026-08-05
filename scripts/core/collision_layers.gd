## The four physics layers, as masks. TDD-06 §1.2, `project.godot` `[layer_names]`.
##
## Named here because a mask written as `1` at a call site is a number in a
## script, and nobody reviewing it can tell whether it means WORLD or "the first
## layer, whatever that is now". `test_collision_layers_match_project.gd` asserts
## these against `project.godot`, so the two cannot drift.
##
## **`WORLD` IS THE ONLY LAYER TRAVERSAL MAY PROBE**, and that is a determinism
## requirement rather than an optimisation. Static geometry is identical on every
## peer by construction; NPC and player positions are interpolated on clients and
## authoritative on the server. A probe that could hit a moving body would
## resolve differently on the two machines and produce a different traversal —
## the client would vault something the server did not (TDD-03 §3.3).
class_name CollisionLayers
extends RefCounted

## Static map geometry, climbable façades, vaultable furniture.
const WORLD: int = 1 << 0

## Player capsules.
const PAWN: int = 1 << 1

## Crowd capsules.
const NPC: int = 1 << 2

## Blend props, zone volumes, spawn markers. Queried separately, never probed.
const TRIGGER: int = 1 << 3

## Layer name -> mask, in `project.godot` order. The guard reads this; nothing on
## the hot path does.
const BY_NAME: Dictionary = {
	&"WORLD": WORLD,
	&"PAWN": PAWN,
	&"NPC": NPC,
	&"TRIGGER": TRIGGER,
}

## What a traversal probe is allowed to see. Referenced by name at every cast, so
## widening it is one visible edit rather than four invisible ones.
const TRAVERSAL_MASK: int = WORLD
