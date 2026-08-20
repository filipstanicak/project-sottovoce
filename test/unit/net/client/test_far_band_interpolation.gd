## **THE FAR BAND HAS NO INTERPOLATION MARGIN, ASKED WITHOUT A CROWD.**
## TDD-04 §7.2.1, ADR-0007, US-0045.
##
## The owner reported far NPCs stuttering while near ones walk smoothly, and
## `tools/crowd_probe.tscn` measured it live — **1.68 % of drawn frames against
## 0.13 %**. That measurement could not decide a fix: every run caught between
## zero and three *walking* far NPCs, and one run caught none at all, so the
## stretch ADR-0007 asked for in writing was built, could not be shown to help,
## and was reverted rather than shipped unvalidated into the exact band being
## complained about.
##
## **THIS ASKS THE ARITHMETIC INSTEAD.** No crowd, no wire, no nodes: a
## `RenderClock` and a `SnapshotInterpolator` fed a synthetic stream, with a
## **deterministic** arrival jitter rather than an RNG, and the drawn position
## read every client frame. The stall count is reproducible to the event, so an
## A/B decides something.
##
## **THE DETECTOR IS THE LIVE TOOL'S OWN**, `FramePacing.catch_ups`. Two
## measurements of the same defect that use two definitions of it cannot be
## compared, which is `CrowdWire`'s lesson in another domain.
extends GutTest

## 30 s at the client's frame rate. Long enough that the jitter pattern repeats
## many times and no single arrival dominates.
const FRAMES := 1800
const FRAME_DT := 1.0 / 60.0

## Client frames of transport latency before jitter. Any constant does: the clock
## only ever moves forward, so a fixed delay shifts every arrival equally.
const BASE_DELAY := 3

## **A DETERMINISTIC JITTER, NOT AN RNG.** Never-do #8 bans `randi` outside
## presentation, and a seeded generator would still make a failure depend on the
## draw order. These are client frames of lateness — 0 to 3, so at most 50 ms,
## well inside what this session measured on the input queue on localhost.
const JITTER := [0, 1, 0, 2, 1, 3, 0, 1, 2, 0]
const STEADY := [0]

const ID := 7
const PROFILE := "res://data/tuning/default/profile.tres"


func _stroll() -> float:
	return Tuning.crowd.npc_speed_stroll


## Snapshot `k` carries server time `k / TUN-NET-SERVER-TICK` and arrives at frame
## `2k + BASE_DELAY + jitter`. It carries the NPC's record only when `k` is on the
## stride.
##
## **THAT ASYMMETRY IS THE WHOLE FINDING.** The render clock advances from *every*
## snapshot, at 30 Hz; a far NPC's track advances from one in three. So the clock
## reaches the far NPC's newest sample and has nowhere further to go.
## `carried` is `SnapshotAssembler`'s behaviour: it fills every snapshot with every
## NPC it holds, so a record the server omitted arrives again anyway, **re-stamped
## with this tick's time and the position it had three ticks ago**.
func _arrivals(stride: int, jitter: Array, carried: bool) -> Dictionary:
	var out: Dictionary = {}
	for k: int in FRAMES / 2:
		var frame := 2 * k + BASE_DELAY + int(jitter[k % jitter.size()])
		if not out.has(frame):
			out[frame] = []
		var sent := true if carried else k % stride == 0
		var described := k - (k % stride) if carried else k
		var entry := [
			float(k) / Tuning.net.server_tick, sent, float(described) / Tuning.net.server_tick
		]
		(out[frame] as Array).append(entry)
	return out


## Walk one entity in a straight line at stroll speed, delivered at `hz`, and
## return the distance it was drawn each client frame.
func _drawn_steps(hz: float, extra: float, jitter: Array, carried := false) -> Array:
	var stride := int(round(Tuning.net.server_tick / hz))
	var clock := RenderClock.new()
	var interp := SnapshotInterpolator.new()
	var arrivals := _arrivals(stride, jitter, carried)
	var steps: Array = []
	var previous := Vector3.INF
	for f: int in FRAMES:
		clock.advance(FRAME_DT)
		for entry: Array in arrivals.get(f, []) as Array:
			var stamp := float(entry[0])
			clock.observe(stamp)
			if bool(entry[1]):
				var described := float(entry[2])
				interp.push(ID, stamp, Vector3(0.0, 0.0, _stroll() * described), 0.0)
		if not clock.started():
			continue
		var placed: Array = interp.sample(ID, clock.render_time() - extra)
		if placed.is_empty():
			continue
		var at := placed[0] as Vector3
		if previous != Vector3.INF:
			steps.append(previous.distance_to(at))
		previous = at
	return steps


## Hold-then-catch-up events as a percentage of drawn frames.
func _stall_rate(hz: float, extra: float, jitter: Array = JITTER, carried := false) -> float:
	var steps := _drawn_steps(hz, extra, jitter, carried)
	assert_gt(steps.size(), FRAMES / 2, "the harness drew almost nothing — it cannot measure")
	var mid := FramePacing.mean_of(steps)
	assert_gt(mid, 0.0, "nothing moved, so a stall cannot be told from a stand")
	return float(FramePacing.catch_ups(steps, mid)) / float(steps.size()) * 100.0


## **THE VACUOUS-SUCCESS GUARD, AND IT IS THE FIRST TEST FOR A REASON.** A
## detector that flags every stream would report the far band as broken whatever
## the buffer did. The near band is delivered at the full snapshot rate through the
## same harness, the same jitter and the same detector, and must come out clean.
func test_the_near_band_walks_smoothly_at_todays_buffer() -> void:
	var rate := _stall_rate(Tuning.net.snapshot_rate, 0.0)
	assert_lt(rate, 0.5, "the near band stalls too, so this harness measures nothing specific")


## **AND THE SECOND GUARD: THE RATE ALONE IS NOT THE FAULT.** Delivered at 10 Hz
## with no jitter at all, the far band is smooth — so what the fix has to buy is
## tolerance of late arrival, not a higher send rate. Never-do #14's neighbour:
## the cheap answer would be to raise `TUN-NET-NPC-RATE-LOD-HZ`, and this says that
## would be paying bandwidth for the wrong thing.
func test_a_punctual_far_band_does_not_stall() -> void:
	var rate := _stall_rate(Tuning.net.npc_rate_lod_hz, 0.0, STEADY)
	assert_lt(rate, 0.5, "10 Hz stalls even when punctual, so lateness is not the mechanism")


## The defect itself.
func test_the_far_band_stalls_at_todays_buffer() -> void:
	var rate := _stall_rate(Tuning.net.npc_rate_lod_hz, 0.0)
	assert_gt(rate, 1.0, "the far band no longer stalls — has the margin already been given?")


## **AND THE STRETCH REMOVES IT.** One far-band send interval of extra delay, which
## is what ADR-0007 asked for and what `CrowdWire.crowd_extra_delay()` derives.
func test_the_stretch_removes_the_far_band_stall() -> void:
	var before := _stall_rate(Tuning.net.npc_rate_lod_hz, 0.0)
	var after := _stall_rate(Tuning.net.npc_rate_lod_hz, CrowdWire.crowd_extra_delay())
	gut.p("far band: %.2f %% before, %.2f %% after" % [before, after])
	assert_lt(after, 0.5, "the stretch did not settle the far band")
	assert_lt(after, before, "the stretch made no difference at all")


## **AND THE LIVE MECHANISM IS NOT LATENESS AT ALL — IT IS THE ASSEMBLER.**
##
## The stretch above measured 5.01 % to 0.00 % here and moved the live figure by
## **0.01 of a point**, which is a fix that did nothing. `SnapshotAssembler` carries
## the crowd forward — correct on the wire, where absence means "no update" — and
## `NpcView` pushes **everything the snapshot carries** into the interpolator. So a
## far NPC gets a sample every tick at 30 Hz, two in three of them **re-stamped with
## a position it had 100 ms ago**. The interpolator honours that faithfully: it
## reads "did not move" where the server said "no news", holds for two ticks, then
## covers three ticks of ground in one. A staircase, not an underrun.
func test_a_carried_forward_record_draws_a_staircase() -> void:
	var honest := _stall_rate(Tuning.net.npc_rate_lod_hz, CrowdWire.crowd_extra_delay())
	var carried := _stall_rate(
		Tuning.net.npc_rate_lod_hz, CrowdWire.crowd_extra_delay(), JITTER, true
	)
	gut.p("far band: %.2f %% honest, %.2f %% carried forward" % [honest, carried])
	assert_gt(carried, 5.0, "re-stamping a stale record did not produce a staircase")
	assert_gt(carried, honest, "carrying forward is no worse than not, so it is not the mechanism")


## **DERIVED, NEVER CHOSEN.** The margin is exactly one far-band send interval, so
## retuning `TUN-NET-NPC-RATE-LOD-HZ` carries it. Asserted against a *changed*
## profile, because reading the same expression back proves nothing.
func test_the_margin_follows_the_rate_it_compensates_for() -> void:
	var live := Tuning.net.npc_rate_lod_hz
	assert_almost_eq(CrowdWire.crowd_extra_delay(), 1.0 / live, 0.0001, "not one send interval")
	var profile := Tuning.profile.clone()
	profile.net.npc_rate_lod_hz = 20.0
	Tuning.adopt(profile)
	assert_almost_eq(CrowdWire.crowd_extra_delay(), 0.05, 0.0001, "the margin ignored the retune")


## **THE LIVE PROFILE IS PUT BACK WHATEVER HAPPENS.** `Tuning` is an autoload and
## outlives this file; a rate left behind would be handed to whatever runs next.
func after_each() -> void:
	Tuning.adopt((load(PROFILE) as TuningProfile).clone())
