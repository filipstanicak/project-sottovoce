## **EVERYTHING A SYSTEM NEEDS, PASSED EXPLICITLY.** TDD-01 §5.
##
## The project's dependency-injection seam: **if it is not on `MatchContext`, a
## system cannot reach it.** Systems receive their dependencies rather than
## looking them up, so the whole dependency graph is visible in one file instead
## of scattered across thirty `get_node` calls that only fail at runtime.
##
## Constructed by `MatchDirector`, once per match, and torn down with it.
##
## **THE FIELDS ARRIVE WITH THEIR SYSTEMS.** TDD-01 §5 lists `crowd`, `cycle`,
## `score_log` and `lag_comp` too. Declaring them now as nulls of types that do
## not exist would be fields nobody can use and one compile error each time
## someone renames a class that has not been written. They land in M3 and M4 with
## the systems that own them — `lag_comp` arrived first, in US-0035, because
## ADR-0010 records the ring at M2 and consumes it at M4.
##
## In `scripts/systems/` rather than `scripts/core/`, where TDD-01 §6's file
## table puts it. Core is pure by law — `test_core_is_pure.gd` — and a context
## holding live pawns is server state, not a value type. The document's own
## §1.3 draws the line where the guard does.
class_name MatchContext
extends RefCounted

## **MONOTONIC SERVER TICK SINCE MATCH START.** Never wall-clock, never a frame
## count: it is the number every deterministic thing in the project is written
## against, and it advances exactly once per net tick even if a frame took 200 ms.
var tick: int = 0

## `MatchPhase.Phase`. The server's own answer, not the client's mirror.
var phase: int = MatchPhase.Phase.LOBBY

## peer id -> the authoritative pawn. Populated by `SYS-SPAWN` in M4; the
## director exposes it now because the pawn substep walks it.
var pawns: Dictionary = {}

## **peer id -> `PawnContext`**, the simulation state behind those bodies.
##
## A second dictionary rather than a richer one, because `pawns` holds the
## `CharacterBody3D` and four consumers want exactly that — positions, bands,
## startle radii. A system wanting *state* wanted the body's owner and could not
## reach it: `PawnHost.context_for()` is server plumbing, not a dependency, and
## `SYS-SUSPICION` needs velocity, state and elevation every tick.
##
## **THE TWO ARE WRITTEN AND ERASED TOGETHER, IN `PawnHost`, ON ADJACENT LINES**,
## and `test_pawn_host.gd` asserts they never disagree. Two dictionaries keyed the
## same way is a drift risk worth naming rather than one worth hiding.
var pawn_contexts: Dictionary = {}

## **peer id -> the `PawnStateMachine` that owns that pawn's transitions.**
##
## The third of the parallel three, added by US-0060 and for the same reason as
## the second: `SYS-KILL` has to *put* a killer into `KillAnim` and a victim into
## `Dead`, and a system that reached the machine with `get_node("PawnStateMachine")`
## off `pawns[peer]` would be doing scene plumbing to express a dependency.
##
## **THE MACHINE IS NOT STATE.** Every state object is shared by every pawn and
## all the mutable data lives in `PawnContext` — so this is a handle to the
## transition *graph*, not to anything per-pawn. Written and erased in `PawnHost`
## beside the other two, with the same key-set assertion.
var pawn_machines: Dictionary = {}

## **WHAT A PLAYER IS OWED IN INSTANT SUSPICION, NOT YET INTEGRATED.** Queued by
## `SYS-KILL` for a failed kill and a witnessed one, drained by `SYS-SUSPICION` at
## the top of its own pass.
##
## **HERE RATHER THAN ON `SuspicionSystem`** as of US-0060, for the reason its own
## docstring predicted — *"public so `SYS-COMBAT` and `SYS-ABILITY` can owe a
## player points"* — and the way a system reaches another system's state in this
## project is that the state is on the context. `SuspicionSystem` adopts this one
## by reference rather than mirroring it, so the two cannot drift.
##
## **AND NOT ON `PawnContext`**: that object is replayed during prediction
## reconciliation, so a queue of gameplay impulses living there would be walked
## once per replayed command.
var impulses := SuspicionImpulses.new()

## **THE CINDER CLOUDS.** Placed by `SYS-ABILITY` (nothing places one yet), read
## by `SYS-DETECTION` for line of sight and by `SYS-KILL` for TDD-10 §3's first
## gate. **On the context rather than inside detection**, because it now has two
## readers in different stages and the second one arrived in US-0060 — a volume
## list owned by one system and reached through it by another is the shape
## `announced_contracts` was moved here to avoid.
var cinderfall := CinderfallVolumes.new()

## **EVERY LIVE CHASE.** `SYS-DETECTION` opens and refreshes them, `SYS-CONTRACT`
## consumes the ones that empty. US-0097, ADR-0014.
##
## Here rather than on either system for the reason `cinderfall` and `lockouts` are
## here: two systems at two stages ask about the same rows, and a system reaching
## another system's state does it through the context. `SYS-DETECTION` sits at
## stage 5 and `SYS-CONTRACT` at stage 8, so an escape is detected and repaired in
## the same tick.
var pursuit := PursuitBoard.new()

## **THE COMBAT TIMERS BOTH COMBAT SYSTEMS TOUCH.** US-0061. `SYS-STUN` writes the
## exile and the flail stagger; `SYS-KILL` reads both — a locked-out hunter may
## not re-initiate on the player who stunned them, and a staggered player may not
## initiate at all. Two private dictionaries would drift the first time somebody
## added a write to one, which is `announced_contracts`' lesson.
var lockouts := CombatLockouts.new()

## **THE ONLY WAY POINTS ENTER THE GAME.** ADR-0004, US-0064. Append-only, and
## adopted by reference like `lockouts` and `impulses` rather than mirrored — a
## second copy of a score log is a scoreboard that disagrees with a results
## screen, which is the defect TDD-10 §1.1 is entirely about.
##
## **NOTHING CLIENT-SIDE MAY HOLD ONE.** `test_score_no_direct_mutation.gd`
## refuses any mention under `presentation/`, `mirrors/` or `pawn/`.
var score := ScoreLog.new()

## **THE FOUR THINGS A BONUS NEEDS THAT ONE TICK CANNOT ANSWER.** US-0065.
## Sampled by `SYS-SUSPICION` (speed) and `SYS-DETECTION` (line of sight) at stages
## 4 and 5, read by `SYS-KILL` at stage 7 — **upstream of the initiation it is
## judged at**, which is why there is no system at the `score` stage.
##
## **NOT ON `PawnContext`, WHICH IS WHERE TDD-10 §2.1 PUTS IT.** That object is
## replayed during prediction reconciliation, so a client replaying twenty commands
## would push twenty duplicate speed samples into a gameplay buffer.
var score_windows := ScoreWindows.new()

## `MapData` for the loaded map. Read-only to systems.
var map: MapData = null

## **PEER ID -> WIRE SLOT**, for this match. Written by `Net` at the handshake
## and read by anything that names a player on the wire.
##
## It is here rather than reachable through the `Net` autoload for the reason the
## router learned the hard way: a builder whose answers come from a global cannot
## be *asked a question* in a test — every assertion collapses to "there is no
## slot", which stays true whatever the code does. If it is not on
## `MatchContext`, a system cannot reach it.
var slots := SlotTable.new()

## **500 MS OF PAST TRANSFORMS.** Recorded every tick from US-0035; **read by
## nothing until M4**, when kill and stun validate against a rewound world.
##
## Built at M2 on purpose (ADR-0010): the ring is proven before anything depends
## on it, so the M4 work is validation logic rather than infrastructure.
var lag_comp := LagCompHistory.new()

## **ONE GRID, SHARED BY FOUR CONSUMERS.** Rebuilt by `CrowdDirector` at the top
## of the `crowd` stage (US-0042) and read by suspicion, blending, startle
## propagation and gawk arbitration.
##
## It lives here rather than on the director for the reason the router learned
## the hard way: a system whose answers come from another system's field cannot
## be *asked a question* in a test. Suspicion runs after crowd precisely so that
## what it reads is this tick's.
var crowd_hash := SpatialHash.new()

## **ONE COMPASS READING PER HUNTER, THIS TICK.** Filled by `SYS-DETECTION` — the
## server half of `SYS-COMPASS` lives there, because TDD-07 §1's diagram makes the
## bearing and the lock steps 9 and 10 of the detection pass — and read by
## `SnapshotBuilder`. A missing reading means *no contract*, never due north.
var compass := CompassBoard.new()

## **WHAT EACH OBSERVER SEES OF EACH SUBJECT, THIS TICK.** Filled by
## `SYS-DETECTION` at the `detection` stage and read by `SnapshotBuilder` at the
## `snapshot` stage — four positions apart in `SystemOrder`, with neither knowing
## the other exists. Absent means `PLAIN`.
var render_states := RenderMatrix.new()

## **peer -> the contract that peer has been TOLD about**, which is not always the
## one the graph holds: `SYS-CONTRACT` repairs the cycle in the tick a death
## resolves and holds the *announcement* for `TUN-CONTRACT-REASSIGN-DELAY`.
##
## Detection and the Compass both follow this one. Rendering from the graph would
## put a tint on a player the hunter has not been given yet — the silhouette
## arriving before the Compass, and the breath worth nothing.
var announced_contracts: Dictionary = {}

## **THE FOUR PROCESSIONS, AND THE FIFTH SLOT IN EACH THAT NO NPC MAY TAKE.**
## Built by `CrowdDirector.setup()` (US-0043) and published here for `SYS-BLEND`,
## which is the thing that empty slot was reserved for.
##
## It is on the context rather than reached through the director for the reason
## the router learned the hard way: a system whose answers come from another
## system's field cannot be *asked a question* in a test. Null wherever there is
## no crowd — the integration harness and every client — so a caller must check.
var formations: CrowdFormations = null

## **THE CROWD.** Ninety pre-allocated NPC bodies and the roster derived for them
## (US-0039). Null until `server_root.gd` stands it up — a system must check,
## because the integration harness has no crowd and neither does a client.
var crowd: NpcPool = null

## **THE MATCH SEED.** Everything derived rather than replicated comes from this:
## the crowd roster today (US-0039), and at M4 whatever else must agree on every
## peer without spending bandwidth.
##
## **IT REACHES CLIENTS IN `NET-S2C-MATCH-START`, WHICH IS NOT SENT YET.** The
## protocol already declares the field (`match_seed:u64`); `SYS-MATCH` sends it,
## and that is M4's. Until then only the server has it, which is survivable
## precisely because nothing client-side derives anything from it yet — the crowd
## is not on the wire.
var match_seed: int = 0

## The seeded RNG. **THE ONLY SOURCE OF GAMEPLAY RANDOMNESS**, server-side —
## `randf` and `randi` are banned outside `scripts/presentation/`, because a
## match must replay identically from its seed.
var rng: RandomNumberGenerator = null


## Seconds per net tick. Every system's `tick(ctx, dt)` receives exactly this.
static func net_dt() -> float:
	return 1.0 / Tuning.net.server_tick


## Seconds per pawn substep. Half of `net_dt()`, and the difference matters:
## see `MatchDirector._substep_pawns`.
static func step_dt() -> float:
	return 1.0 / Tuning.net.client_input_rate


## Seconds since the match started, derived from the tick rather than measured.
##
## Derived on purpose. A clock read from `Time` would drift from the tick count
## under load, and then two answers to "how long is left" would exist — one the
## players see and one the scoring uses.
func elapsed() -> float:
	return float(tick) * net_dt()
