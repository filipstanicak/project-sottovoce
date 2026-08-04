---
id: TDD-12-BUILD
title: "TDD Chapter 12 — Build, CI and Tooling"
version: 0.1.0
status: draft
owner: Technical Director
last_updated: 2026-08-03
depends_on: [TDD-01-ARCHITECTURE, TDD-02-STRUCTURE, TDD-05-DATA, ADR-0001, ADR-0009, DOC-IP-GUARDRAILS]
---

# TDD Chapter 12 — Build, CI and Tooling

> **Context restated.** Project Sottovoce is a Godot 4.7.1 / GDScript game with a dedicated
> headless server, targeting Windows and Linux desktop at 1080p/60. Development is trunk-based
> on `main`, which must always be green and always playtestable, because the game can only be
> validated with 4–6 humans and a spontaneous "can we try this tonight?" must always be yes.
>
> **The tooling thesis:** the balance loop is the project's main risk-reduction activity, so the
> highest-value tools are the ones that shorten *edit → six people playing*. That is what §5
> and §6 are for.
>
> **Implements:** `SYS-DEBUG` (§5), `SYS-TELEMETRY` (§9, the `TelemetrySink` interface —
> the event catalogue is [`../10_gdd/07_balance.md`](../10_gdd/07_balance.md) §8).

---

## 1. CI pipeline

```mermaid
flowchart LR
    PUSH([push / PR]) --> IMPORT["import<br/>headless, cold<br/>≤ 90 s"]
    IMPORT --> LINT["lint<br/>gdlint + gdformat --check"]
    IMPORT --> IPG["ip-guard<br/>banned-terms grep"]
    IMPORT --> ASSET["asset-inventory<br/>bidirectional"]
    LINT --> TEST["test<br/>unit + arch ≤ 45 s"]
    IPG --> TEST
    ASSET --> TEST
    TEST --> ITEST["integration<br/>headless 3-client"]
    ITEST --> EXPORT["export<br/>win/linux client + server"]
    EXPORT --> GREEN([green])
```

All six jobs are **required checks** on `main` (ADR-0009) — see §1.3 for how far
that is currently *enforced* as opposed to merely agreed.

| Job | Fails on | Typical |
|---|---|---|
| `import` | Any import error or script parse failure | ~70 s cold, ~15 s cached |
| `lint` | Any `gdlint` violation; any file `gdformat` would change | ~20 s |
| `ip-guard` | **Any banned term anywhere in the repo** | ~5 s |
| `asset-inventory` | An asset with no licence row, **or a stale row** | ~5 s |
| `test` | Any unit or architecture test failure | ~40 s |
| `integration` | Headless 3-client harness failure | ~180 s |
| `export` | Export failure, or a preset missing an exclusion | ~120 s |

### 1.1 `ip-guard`

```bash
# .ci/ip_guard.sh — HARD failure, not a warning.
# Exactly two files are exempt (they necessarily contain the terms):
#   docs/00_meta/IP_GUARDRAILS.md
#   .ci/banned_terms.txt
# Adding a third requires an ADR.
grep -rIn --exclude-dir=.git \
     --exclude-from=.ci/ip_guard_exclude.txt \
     -i -f .ci/banned_terms.txt . && exit 1 || exit 0
```

It scans **everything** — code, docs, commit messages via a separate hook, asset filenames,
branch names. Renaming later does not work: names leak into history, filenames, screenshots and
playtester vocabulary.

### 1.2 `asset-inventory`

Checked **in both directions**. A stale row is as much a defect as a missing one: it means
someone deleted an asset and left a claim about it, which makes the whole register untrustworthy.

### 1.3 Enforcement status — read this before trusting the word "required"

GitHub's **branch protection and rulesets both require GitHub Pro on a private
repository.** On the current plan the API returns:

```
403  Upgrade to GitHub Pro or make this repository public to enable this feature.
```

So the six checks are **required by agreement, not by the server**. What is
actually enforced today:

| Control | Enforced by | Real? |
|---|---|---|
| Squash-only merges, no merge commits, no rebase | GitHub repo settings | **Yes** — server-side, free |
| Branch auto-deleted on merge | GitHub repo settings | **Yes** — server-side, free |
| CI runs on every push and PR | `ci.yml` triggers | **Yes** |
| CI failure *blocks the merge* | — | **No.** Red can be merged |
| Direct push to `main` refused | `.githooks/pre-push` | **Client-side only** |

`.githooks/pre-push` is a guard rail, not a gate. It is bypassable with
`--no-verify`, it lives on the client, and **a fresh clone does not run it until
`core.hooksPath` is set**:

```bash
git config core.hooksPath .githooks
```

That single command is a required step in any new clone. It stops the accidental
push and the automated one — the actual risk on a solo repo — and it stops
nothing done deliberately.

**Promote this to real enforcement when the plan allows.** Either GitHub Pro, or
making the repository public — but public is gated on the originality review in
`docs/00_meta/IP_GUARDRAILS.md`, so it is not a shortcut. The ruleset JSON is
ready to apply unchanged.

---

## 2. Headless import

```bash
godot --headless --editor --quit-after 200
```

Runs first because everything else depends on a clean import, and because import errors are the
most common cause of "works on my machine". The `.godot/` cache is keyed on `.godot-version`
plus a hash of `project.godot` and all `.import` files.

---

## 3. Export presets

| Preset | Platform | Excludes |
|---|---|---|
| **Server** | Linux x86_64, headless | `scripts/presentation/`, `scripts/mirrors/`, `scenes/ui/`, `assets/` (except map collision + navmesh), `addons/gut/`, `scripts/debug/`, `test/`, `tools/`, `docs/` |
| **Client (release)** | Windows + Linux x86_64 | `scripts/server/`, `addons/gut/`, `scripts/debug/`, `test/`, `tools/`, `docs/`, `data/tuning/local/` |
| **Client (debug)** | Windows + Linux x86_64 | As release, but **keeps** `scripts/debug/` |

> **The server preset's exclusion list is the architecture's proof.** If the server build cannot
> run a full match with all presentation code excluded, a dependency has leaked upward and
> [`01_architecture.md`](01_architecture.md) §1.2 has been violated.
> `test_headless_server_runs_without_presentation.gd` is the assertion.

`test_export_excludes.gd` parses `export_presets.cfg` and asserts every path above is listed —
in particular that `addons/gut/` is excluded from all three, because a test framework inside a
shipped build is both a size cost and an attack surface.

---

## 4. The `--server` entry point

```gdscript
## scripts/server/boot.gd — the ONLY branch between client and server topology.
func _ready() -> void:
    var args := OS.get_cmdline_user_args()
    if "--server" in args:
        _start_server(_parse_port(args), _parse_max_players(args))
    else:
        get_tree().change_scene_to_file("res://scenes/client_root.tscn")

func _start_server(port: int, max_players: int) -> void:
    get_tree().change_scene_to_file("res://scenes/server_root.tscn")
```

```bash
# Dedicated server
./sottovoce_server --headless -- --server --port 27015 --max-players 6

# Client
./sottovoce --  --connect 192.168.1.50:27015
```

| Flag | Default | Purpose |
|---|---|---|
| `--server` | — | Server topology, headless |
| `--port` | 27015 | |
| `--max-players` | 6 | `TUN-LOBBY-MAX-PLAYERS` |
| `--connect <ip:port>` | — | Skip the menu; join directly. **The playtest flag** |
| `--tuning <path>` | `default` | Alternative profile (server only) |
| `--seed <int>` | random | Deterministic clone roster, for reproducing a bug |
| `--record <path>` | — | Dump the `ScoreEvent` log and telemetry on match end |

---

## 5. The debug console

Debug builds only, stripped by the export filter. Opened with `` ` ``.

| Command | Effect |
|---|---|
| `tune <path> <value>` | Live tunable override, e.g. `tune suspicion.gain_sprint 20`. **Server broadcasts to all clients** — a playtest never has mixed values |
| `tune reload` | Re-read `.tres` from disk (§5 of [`05_data_architecture.md`](05_data_architecture.md)) |
| `tune diff` | Show every value differing from the shipped default |
| `show suspicion` | Overlay every player's suspicion, tier and active sources |
| `show cycle` | Draw the contract cycle as a graph |
| `show lagcomp` | **Draw the rewound world at the last kill/stun validation** — the only practical way to diagnose a disputed kill (ADR-0010) |
| `show crowd` | LOD bands, blend-pocket validity, spatial-hash cells |
| `show budget` | Per-system frame time against `TUN-PERF-*` |
| `noprediction` | Disable client prediction. **The only way to tell a feel bug from a prediction bug** (ADR-0002) |
| `netsim <ms> <loss%>` | Synthetic latency and packet loss |
| `spawn npc <persona> <n>` | |
| `set phase final` | Jump to the Final Contract phase |
| `dump scorelog` | Write the `ScoreEvent` log as JSON |

`noprediction` and `show lagcomp` are the two that earn the console's existence: both diagnose
classes of bug that are otherwise nearly undiagnosable from a player report.

---

## 6. One-click 3-client local playtest

The tool with the highest ratio of value to effort in the project.

```gdscript
## tools/local_playtest.gd — editor tool script, bound to a toolbar button.
##
## Launches a headless server plus N client instances on localhost, each
## auto-connecting and auto-readying. Turns "let me test the netcode" from a
## five-minute setup into a keypress, which is the difference between testing
## multiplayer every day and testing it before milestones.
@tool
extends EditorScript

const CLIENTS := 3

func _run() -> void:
    var exe := OS.get_executable_path()
    OS.create_process(exe, ["--headless", "--path", _project_path(),
                            "--", "--server", "--port", "27015"])
    for i in CLIENTS:
        OS.create_process(exe, ["--path", _project_path(),
                                "--", "--connect", "127.0.0.1:27015",
                                "--window-position", _tile_position(i)])
```

Windows are auto-tiled so all three clients are visible simultaneously — necessary for observing
prediction artefacts and for checking that the same player is rendered `PLAIN` on one client and
`HARD` on another.

---

## 7. Test layout

```
test/
├── unit/            mirrors scripts/ one-for-one; no scene, no engine where possible
├── integration/     headless 3-client harness
├── metrics/         map geometry assertions
└── arch/            layer rules, inventories, docs-sync  ← see test/arch/README.md
```

`test/arch/` is separated deliberately: those tests protect the *architecture* rather than
behaviour, they run as source scans rather than by executing code, and they are the ones most
likely to be deleted by someone who does not understand why they exist.

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test/unit  -gexit
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test/arch  -gexit
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test/integration -gexit
```

### 7.1 The integration harness

```gdscript
## Spawns a real server and three real clients IN-PROCESS, then drives them
## with scripted InputCommand sequences. This exercises the actual netcode
## rather than a mock, which is the only way prediction bugs surface.
class_name IntegrationHarness
extends Node

func start(player_count: int, seed: int) -> void
func drive(peer: int, commands: Array[InputCommand]) -> void
func advance_ticks(n: int) -> void
func simulate_latency(peer: int, rtt_ms: float, loss: float) -> void
func assert_all_peers_agree(field: StringName) -> void
```

---

## 8. Lint configuration

```
# .gdlintrc
class-definitions-order: [tools, signals, enums, consts, exports, pub-vars, prv-vars, onreadys]
function-name: "^_?[a-z][a-z0-9]*(_[a-z0-9]+)*$"
class-name: "^[A-Z][a-zA-Z0-9]*$"
max-file-lines: 400
max-line-length: 100
max-public-methods: 20
function-arguments-number: 6
```

`gdformat --check` runs in CI; `gdformat` runs on a pre-commit hook. **Formatting is never a
review topic.**

Project-specific rules beyond `gdlint`, implemented as `test/arch/` source scans because
`gdlint` cannot express them:

| Rule | Test |
|---|---|
| Max function length 40 lines | `test_function_lengths.gd` |
| No gameplay literals in systems/pawn | `test_no_gameplay_literals.gd` |
| No `randf` outside presentation | `test_randf_confined.gd` |
| No autoload except `Tuning` in `scripts/pawn/` | `test_pawn_determinism_grep.gd` |
| No `get_node` outside a widget's subtree | `test_ui_no_gameplay_refs.gd` |
| Typed declarations everywhere | `test_typing_coverage.gd` |

---

## 9. Interfaces

```gdscript
class_name DebugConsole extends CanvasLayer
func register(name: String, callable: Callable, help: String) -> void
func execute(line: String) -> String

class_name TelemetrySink extends RefCounted
func emit_event(id: StringName, fields: Dictionary) -> void
func flush_to(path: String) -> void        ## --record
```

---

## 10. Files this chapter creates

| Path | Purpose |
|---|---|
| `.github/workflows/ci.yml` | The six jobs |
| `.github/actions/setup-godot/action.yml` | Installs the pinned engine; used by `import`, `test`, `export` |
| `.githooks/pre-push` | Refuses a direct push to `main` (§1.3) |
| `.ci/banned_terms.txt` · `ip_guard_exclude.txt` · `ip_guard.sh` | IP enforcement |
| `.ci/check_asset_inventory.sh` | Bidirectional asset check |
| `.gdlintrc` · `.gdformatrc` | Lint config |
| `.godot-version` | Pinned engine version |
| `export_presets.cfg` | Three presets |
| `scenes/boot.tscn` + `scripts/server/boot.gd` | `--server` branch. In `server/`, not the `scripts/` root: a script at the root belongs to no layer, and the layer rule is enforced by folder membership |
| `scripts/server/server_main.gd` | Headless entry |
| `scripts/debug/debug_console.gd` + `commands/*.gd` | The console |
| `tools/local_playtest.gd` | One-click 3-client |
| `tools/tuning_docs_sync.gd` | TUNABLES ↔ `.tres` check |
| `test/integration/integration_harness.gd` | The harness |
| `test/arch/README.md` | Why the architecture guards exist |

---

## 11. Test hooks

| Test | Asserts |
|---|---|
| `test_export_excludes.gd` | Every §3 exclusion is present; `addons/gut/` excluded from all presets |
| `test_headless_server_runs_without_presentation.gd` | A server export with all presentation excluded completes a full match. **The architecture's proof** |
| `test_server_flag.gd` | `--server` produces server topology; its absence produces client topology |
| `test_cli_args.gd` | Every §4 flag parses, with defaults |
| `test_debug_stripped.gd` | A release export contains no `scripts/debug/` symbol |
| `test_ci_required_checks.gd` | `ci.yml` defines all six jobs and each is required |
| `test_banned_terms_sync.gd` | `.ci/banned_terms.txt` matches IP_GUARDRAILS §2.1–2.3 exactly |
| `test_ip_guard_exclusions.gd` | Exactly two files are exempt |
| `test_gut_excluded.gd` | No GUT symbol in any release export |
| `test_import_time.gd` | Cold headless import ≤ 90 s |
| `test_suite_time.gd` | Unit + arch suites ≤ 45 s combined |
| `test_local_playtest_launches.gd` | The tool script launches 1 server + 3 clients and all connect |

---

## 12. Performance budget contribution

**No runtime cost** — all tooling is stripped from release builds. Build-time budgets, recorded
so they are noticed if they grow:

| Item | Budget | Why it matters |
|---|---|---|
| Cold headless import | ≤ 90 s | Runs on every push; above ~2 min it stops being a fast gate |
| Unit + arch suites | ≤ 45 s | Must be fast enough to run before every commit, or it will not be |
| Integration suite | ≤ 180 s | Runs on PR only |
| Full CI, cached | ≤ 6 min | Above ~10 min, people stop waiting and start merging optimistically |
| Debug console overhead (debug builds) | ≤ 0.05 ms/frame | Must not distort the profiling it exists to support |

---

## 13. Open questions

| # | Question | Position | Needed by |
|---|---|---|---|
| 1 | Should the integration suite run on every push, or only on PR? At ~180 s it is the slowest job. | PR only for now. If netcode regressions slip to `main`, promote it to every push and accept the cost | M2 |
| 2 | The banned-terms grep is case-insensitive and substring-based, so short terms could false-positive on legitimate words. | Terms are ≥ 4 characters and reviewed for collisions. If a false positive appears, fix the term list rather than weakening the check | M0 |
| 3 | Should `data/tuning/local/` overrides be usable in a hosted local playtest (all peers on one machine)? Currently the hash check refuses them. | Refuse. The value of "a playtest never has mixed values" exceeds the convenience, and `tune` broadcasts from the server anyway | M2 |
| 4 | Godot version upgrades are pinned in `.godot-version`. What is the upgrade process? | A deliberate, tested operation with an ADR — never background drift. Upgrade on a branch, run the full suite plus a 6-player playtest, then merge | Ongoing |
| 5 | Should CI produce a downloadable playtest build on every green `main`? | Yes, and it is cheap — but it needs a distribution channel the project does not yet have. Revisit at M4 when external playtests begin | M4 |
