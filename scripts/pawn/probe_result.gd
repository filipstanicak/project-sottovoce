## What the traversal probes found this tick. TDD-06 §4.
##
## MINIMAL — the three forward probes, the resolver and the forgiveness windows
## arrive in US-0017 and US-0018. It exists now because `PawnContext` holds one
## and `PawnState.step()` reads it, and a field typed `Variant` today is a field
## nobody types correctly later.
class_name ProbeResult
extends RefCounted

## Nothing was hit. Distinguished from "hit at height 0" — which is a floor.
var has_hit: bool = false

## Height of the hit surface above the pawn's feet, in metres. This is the value
## the resolver compares against the vault and mantle thresholds, so it must
## never be derived from an interpolated body — probes mask WORLD only, and that
## is a determinism requirement rather than an optimisation (TDD-06 §1.2).
var height: float = 0.0

## Distance forward to the hit, in metres.
var distance: float = 0.0

## Surface normal, for deciding whether a face is climbable.
var normal: Vector3 = Vector3.UP


func clear() -> void:
	has_hit = false
	height = 0.0
	distance = 0.0
	normal = Vector3.UP
