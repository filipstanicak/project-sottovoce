## The action buffer. TDD-06 §3, GDD-02 §7.3.
##
## Forgives an input pressed slightly **early** — before the thing it asks for is
## legal. A traverse pressed 0.15 s before the wall is in probe range is honoured
## when the wall arrives, rather than dropped.
##
## **THIS RUNS INSIDE `step()`, ON BOTH PEERS.** It is not a client convenience.
## The buffer changes what the simulation does, so a client-only buffer would
## have the client predicting a vault the server never performed — and the
## correction would snap the pawn backwards through the wall it just climbed.
## That is why the counters live in `PawnContext` and not in the sampler.
##
## Counted in TICKS, never seconds. An accumulated float would expire on a
## different frame on the server than on the client's replay, which is the exact
## shape of a desync nobody can reproduce.
##
## **`Tuning.step_ticks()`, not `Tuning.ticks()`.** These counters advance once
## per `step()`, which runs at 60 Hz, while `ticks()` converts at the 30 Hz net
## tick. Using the wrong one halves the window — 0.20 s of forgiveness becomes
## 0.10 s — and both numbers are plausible integers, so nothing fails.
##
## The OTHER buffer — the reconciliation ring of `TUN-NET-INPUT-BUFFER-SIZE`
## unacked commands — is `InputHistory`, and is client-only for the opposite
## reason: it exists to replay what the server has not yet answered.
class_name PawnInputBuffer
extends RefCounted


## Arm on press, decay by one otherwise. Called once per `step()`, before the
## state runs, so a press and its consumption can happen on the same tick.
static func tick(ctx: PawnContext, input: InputCommand) -> void:
	if input.traverse:
		ctx.traverse_buffer_ticks = Tuning.step_ticks(&"TUN-TRAVERSE-INPUT-BUFFER")
	elif ctx.traverse_buffer_ticks > 0:
		ctx.traverse_buffer_ticks -= 1

	if input.ability_1 or input.ability_2:
		ctx.ability_buffer_ticks = Tuning.step_ticks(&"TUN-ABILITY-INPUT-BUFFER")
	elif ctx.ability_buffer_ticks > 0:
		ctx.ability_buffer_ticks -= 1


## Take the buffered traverse, if there is one. CONSUMING, because a buffered
## input must fire exactly once: a traverse that stayed armed would re-trigger
## on the next legal frame and vault the player somewhere they did not ask for.
static func consume_traverse(ctx: PawnContext) -> bool:
	if ctx.traverse_buffer_ticks <= 0:
		return false
	ctx.traverse_buffer_ticks = 0
	return true


static func consume_ability(ctx: PawnContext) -> bool:
	if ctx.ability_buffer_ticks <= 0:
		return false
	ctx.ability_buffer_ticks = 0
	return true


## Whether a traverse is armed, without spending it. For tells and animation
## anticipation, which must not steal the input.
static func has_traverse(ctx: PawnContext) -> bool:
	return ctx.traverse_buffer_ticks > 0


static func has_ability(ctx: PawnContext) -> bool:
	return ctx.ability_buffer_ticks > 0
