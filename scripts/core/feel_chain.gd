## The stages between a key press and the player seeing a response. GDD-02 §5.
##
## **THE BUDGET IS 80 ms AND ONLY PART OF IT CAN BE MEASURED TODAY.** That is the
## whole reason this class exists rather than a bare number in a test: a harness
## that measured three stages of five and reported "42 ms, within budget" would
## be stating something false in a form nobody re-reads. The stages are declared
## here, each marked measured or blocked, and `test_feel_chain.gd` fails the day
## the blocker is lifted so the harness gets finished rather than forgotten.
##
## §5's real argument for the number: the game is decided at 2.5 m inside a 0.4 s
## contest window, so 80 ms is a fifth of the window. Past ~100 ms players stop
## trusting close-range timing, and the moment they stop trusting it they stop
## attempting patient close-range kills — which deletes the game.
##
## PURE. Which stages exist is a fact about the project; measuring them needs a
## running client and lives in `test/integration/test_feel_latency.gd`.
class_name FeelChain
extends RefCounted

## What a key press passes through on its way to the player's eye.
enum Stage { SAMPLE, SIMULATE, APPLY, ANIMATE, PRESENT }

## Per stage: the enum value, what happens in it, and what blocks measuring it.
## An empty `blocked_by` means the integration harness measures it today.
const STAGES: Array[Dictionary] = [
	{
		"stage": Stage.SAMPLE,
		"what": "Input polled into an InputCommand by InputSampler",
		"blocked_by": "",
	},
	{
		"stage": Stage.SIMULATE,
		"what": "PawnStateMachine.step() turns the command into velocity and a state",
		"blocked_by": "",
	},
	{
		"stage": Stage.APPLY,
		"what": "LocalPawnDriver moves the body; ctx.position changes",
		"blocked_by": "",
	},
	{
		"stage": Stage.ANIMATE,
		"what": "The blend tree reacts and the mesh visibly changes pose",
		"blocked_by": "no animation clips exist — US-0019 owes root motion, ANIMATION_SPEC",
	},
	{
		"stage": Stage.PRESENT,
		"what": "The frame reaches the display",
		"blocked_by": "headless CI has no display; needs a frame capture on real hardware",
	},
]


static func measured() -> Array[Dictionary]:
	return STAGES.filter(func(s: Dictionary) -> bool: return String(s["blocked_by"]).is_empty())


static func unmeasured() -> Array[Dictionary]:
	return STAGES.filter(func(s: Dictionary) -> bool: return not String(s["blocked_by"]).is_empty())


## `TUN-FEEL-INPUT-TO-ANIM-MAX`, the whole chain's ceiling.
##
## **A MEASUREMENT UNDER THIS IS NECESSARY, NOT SUFFICIENT.** It covers the
## stages above that carry no `blocked_by`; the rest still has to fit in what is
## left over.
static func budget_ms() -> float:
	return Tuning.movement.input_to_anim_max


## Milliseconds for a count of `PawnState.step()` ticks, which run at
## `TUN-NET-CLIENT-INPUT-RATE` — 60 Hz, not the 30 Hz net tick. Getting this
## wrong doubles every number the harness prints, and 33 ms is as plausible a
## reading as 16 (CLAUDE.md trap 9).
static func ms_for_ticks(ticks: int) -> float:
	return float(ticks) * 1000.0 / maxf(Tuning.net.client_input_rate, 1.0)


static func within_budget(ms: float) -> bool:
	return ms <= budget_ms()


## One sentence naming what a reading does not include, for the harness to print
## next to its number. A measurement without this line is a measurement that will
## be quoted as though it were the whole chain.
static func coverage_note() -> String:
	var blocked: PackedStringArray = []
	for s: Dictionary in unmeasured():
		blocked.append("%s (%s)" % [Stage.keys()[int(s["stage"])], s["blocked_by"]])
	return (
		"measures %d of %d stages; NOT covered: %s"
		% [measured().size(), STAGES.size(), ", ".join(blocked)]
	)
