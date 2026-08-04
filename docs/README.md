---
id: DOC-README
title: Project Sottovoce — Documentation Index
version: 0.1.0
status: draft
owner: Documentation Architect
last_updated: 2026-08-03
depends_on: []
---

# Project Sottovoce — Documentation Index

Project Sottovoce is an online multiplayer social-stealth game for 4–6 players set in a
dense Renaissance-Italian city district. Every player is simultaneously a hunter (holding
one contract on another player) and prey (held as a contract by an unknown player). The
district is populated by 60–90 AI civilians, and every playable persona has 8–12 identical
AI doppelgängers walking the streets. You must move slowly and civilianly to stay
invisible, while hunting demands you close distance and commit. A patient, disguised,
blended kill is worth 3–5× a sprinting tackle-kill. Matches are 8 minutes, free-for-all,
score-based.

**The design thesis, preserved in every chapter of this corpus:** this is not a shooter
with hiding. It is a game about restraint, observation, and the terror of being watched.
Speed is a resource that costs anonymity. Every mechanic is evaluated against that thesis.

---

## 1. How to read this corpus

### 1.1 If you are a human joining the project

Read in this order. It is roughly 6 hours end to end.

| Order | Document | Why |
|---|---|---|
| 1 | [`00_meta/GLOSSARY.md`](00_meta/GLOSSARY.md) | Every term in this corpus has one canonical meaning. Read it once so you never guess. |
| 2 | [`10_gdd/01_vision.md`](10_gdd/01_vision.md) | The six design laws. Everything downstream is an application of them. |
| 3 | [`10_gdd/03_social_stealth.md`](10_gdd/03_social_stealth.md) | The core chapter. If you read only one, read this. |
| 4 | [`00_meta/SCOPE_FENCE.md`](00_meta/SCOPE_FENCE.md) | What we are and are not building. |
| 5 | [`50_tuning/TUNABLES.md`](50_tuning/TUNABLES.md) | Every number in the game, with its ID and rationale. |
| 6 | [`20_tdd/01_architecture.md`](20_tdd/01_architecture.md) | How the code is shaped. |
| 7 | [`30_bible/CLAUDE.md_SEED.md`](30_bible/CLAUDE.md_SEED.md) | The operating rules for anyone (human or agent) touching the repo. |
| 8 | [`40_backlog/ROADMAP.md`](40_backlog/ROADMAP.md) | Milestones M0–M6 and their exit criteria. |

### 1.2 If you are an AI agent starting a fresh session

Read exactly these four files before doing anything else. This is the **context-recovery
ritual** and it is specified in full in
[`30_bible/AGENT_PLAYBOOK.md`](30_bible/AGENT_PLAYBOOK.md).

1. `/CLAUDE.md` (repo root)
2. `docs/00_meta/GLOSSARY.md`
3. `docs/50_tuning/TUNABLES.md`
4. The specific story file in `docs/40_backlog/stories/` you were asked to implement

Then follow the routing table in §3 below to find the one or two documents that govern the
system you are touching. Do not read the whole corpus; read the `depends_on` chain of the
document you need.

---

## 2. Document conventions

Every file in `docs/` carries YAML front-matter:

```yaml
---
id: GDD-03-SOCIAL-STEALTH      # unique, immutable once merged
title: The Social Stealth Core
version: 0.1.0                  # semver; minor bump = new content, patch = correction
status: draft                   # draft | review | locked
                                # backlog stories: draft | in-progress | done
owner: Documentation Architect
last_updated: 2026-08-03        # ISO-8601
depends_on: [DOC-GLOSSARY, TUN-INDEX, GDD-01-VISION]
---
```

| Convention | Rule |
|---|---|
| **Numbers** | Never appear as bare prose. Every number is a tunable with an ID, value, unit, range and one-line rationale, defined once in [`50_tuning/TUNABLES.md`](50_tuning/TUNABLES.md) and referenced elsewhere by ID. |
| **Systems** | Every system has an ID (`SYS-COMPASS`, `SYS-SUSPICION`) and is cross-referenced from the GDD, the TDD, the backlog and the test plan. The full mapping lives in [`00_meta/COVERAGE_MATRIX.md`](00_meta/COVERAGE_MATRIX.md). |
| **Diagrams** | Mermaid only, so they render in Git hosting. |
| **Form** | Tables for *what*, prose for *why*. If a sentence would not change an implementation decision, it is deleted. |
| **Repetition** | Deliberate. Each document is written for a reader who has read only that file and its `depends_on` chain. Critical context is restated rather than cross-referenced with "as discussed above". |
| **Tone** | No marketing language. No "revolutionary", "immersive", "AAA-quality". |
| **GDD chapters end with** | Acceptance Criteria (observable, testable) · Failure Modes (how this feels bad if mistuned) · Open Questions. |
| **TDD chapters end with** | Interfaces (exact GDScript signatures) · Files Touched · Test Hooks · Performance Budget Contribution. |
| **Naming** | Original names only. See [`00_meta/IP_GUARDRAILS.md`](00_meta/IP_GUARDRAILS.md) — this is non-negotiable and has a banned-terms list. |

---

## 3. Routing table — "read this before touching that"

Use this when you are about to modify code and need to know which document is authoritative.

| If you are touching… | Read first | Then |
|---|---|---|
| Suspicion, blending, anonymity tiers | `10_gdd/03_social_stealth.md` §3–§4 | `20_tdd/07_suspicion_and_detection.md` |
| The Compass widget or its math | `10_gdd/03_social_stealth.md` §8 | `30_bible/UI_UX_SPEC.md` §5 |
| Contract assignment / the cycle | `10_gdd/03_social_stealth.md` §7 | `20_tdd/10_scoring_and_match_state.md` |
| Kill, stun, contest resolution | `10_gdd/03_social_stealth.md` §10 | `20_tdd/04_networking.md` (lag compensation) |
| Movement, speeds, state machine | `10_gdd/02_player_controller.md` | `20_tdd/06_player_pawn.md` |
| Parkour / traversal probes | `10_gdd/02_player_controller.md` §7 | `20_tdd/06_player_pawn.md` §5 |
| Any ability | `10_gdd/04_abilities.md` | `20_tdd/09_ability_system.md` |
| NPC behaviour, crowd density | `10_gdd/03_social_stealth.md` §6 | `20_tdd/08_crowd_system.md` |
| The map, blockout, metrics | `10_gdd/05_level_design.md` | `30_bible/ART_BIBLE.md` |
| HUD, score feed, menus | `10_gdd/06_ui_audio.md` | `30_bible/UI_UX_SPEC.md` |
| Any sound | `10_gdd/06_ui_audio.md` §5 | `30_bible/AUDIO_BIBLE.md` |
| Score values, bonuses, balance | `10_gdd/07_balance.md` | `50_tuning/BALANCE_MODEL.md` |
| Any RPC or replicated state | `30_bible/NETWORK_PROTOCOL.md` | `20_tdd/04_networking.md` |
| Any `.tres` resource shape | `30_bible/DATA_SCHEMA.md` | `20_tdd/05_data_architecture.md` |
| Any animation | `30_bible/ANIMATION_SPEC.md` | `10_gdd/02_player_controller.md` |
| Adding a new global event | `30_bible/SIGNAL_AND_EVENT_BUS.md` | — |
| CI, exports, the headless server | `20_tdd/12_build_and_ci.md` | `30_bible/DEFINITION_OF_DONE.md` |
| Anything at all, before you commit | `30_bible/DEFINITION_OF_DONE.md` | `30_bible/CODING_STANDARDS.md` |

---

## 4. Full index

### 4.1 `00_meta/` — governance

| File | Contents |
|---|---|
| [`GLOSSARY.md`](00_meta/GLOSSARY.md) | Canonical definition of every term. Written first; everything references it. |
| [`SCOPE_FENCE.md`](00_meta/SCOPE_FENCE.md) | The MVP IN/OUT list. Anything not IN requires an ADR to add. |
| [`IP_GUARDRAILS.md`](00_meta/IP_GUARDRAILS.md) | Banned-terms list, original-naming rules, the pre-commit review question. |
| [`ASSUMPTIONS.md`](00_meta/ASSUMPTIONS.md) | Every decision made in the absence of a stakeholder ruling, with rationale and revisit-by milestone. |
| [`ASSET_LICENSES.md`](00_meta/ASSET_LICENSES.md) | Every third-party asset, its licence, and its attribution string. |
| [`DECISION_LOG.md`](00_meta/DECISION_LOG.md) | Append-only one-line log of every decision; also the ADR index. |
| [`COVERAGE_MATRIX.md`](00_meta/COVERAGE_MATRIX.md) | SYS-ID → GDD chapter → TDD chapter → stories → tests. Any gap is a documentation bug. |
| [`adr/`](00_meta/adr/) | One file per architectural decision record. |

### 4.2 `10_gdd/` — the Game Design Document

| File | Contents |
|---|---|
| [`01_vision.md`](10_gdd/01_vision.md) | Vision statement, the six design laws, audience personas, comparable analysis, USP, the three loops, the four pillars, player psychology, the minute-by-minute emotional beat map. |
| [`02_player_controller.md`](10_gdd/02_player_controller.md) | Input map, speed states, the full pawn state machine, camera, feel budget, parkour probes, traversal cost table, accessibility. |
| [`03_social_stealth.md`](10_gdd/03_social_stealth.md) | **The core chapter.** Anonymity model, suspicion math, blend actions, crowd as level-design material, NPC AI, the contract cycle, the Compass, detection, stun, and the information-economy master table. |
| [`04_abilities.md`](10_gdd/04_abilities.md) | Ability template, the four MVP abilities, three passives, loadout rules, the tell taxonomy, anti-synergy audit, post-MVP backlog. |
| [`05_level_design.md`](10_gdd/05_level_design.md) | Level-design pillars, the MVP map annotated, metrics bible, the chase-theatre principle, blockout-to-art pipeline, the map authoring checklist. |
| [`06_ui_audio.md`](10_gdd/06_ui_audio.md) | HUD wireframe and what is deliberately absent, the score feed as teacher, menu flow, audio design and the full audio event table, reactive music. |
| [`07_balance.md`](10_gdd/07_balance.md) | Match state machine, scoring table with derivations, the balance model, anti-degenerate-strategy audit, skill floor/ceiling, player-count scaling, telemetry plan. |
| [`08_liveops_and_future.md`](10_gdd/08_liveops_and_future.md) | Post-MVP roadmap on an effort/impact grid, the onboarding problem, the population problem, explicit out-of-scope with reasons. |

### 4.3 `20_tdd/` — the Technical Design Document

| File | Contents |
|---|---|
| [`01_architecture.md`](20_tdd/01_architecture.md) | Layer diagram, the dependency rule, autoload inventory, client/server scene topology. |
| [`02_project_structure.md`](20_tdd/02_project_structure.md) | Full folder tree with a purpose line each; the file-placement decision flowchart. |
| [`03_core_loop_and_tick.md`](20_tdd/03_core_loop_and_tick.md) | `_process` vs `_physics_process` vs the fixed net tick; determinism boundaries; time sources. |
| [`04_networking.md`](20_tdd/04_networking.md) | Authority matrix, prediction and reconciliation, snapshot interpolation, the input command struct, lag compensation, bandwidth budget, the full RPC catalogue. |
| [`05_data_architecture.md`](20_tdd/05_data_architecture.md) | Resource-driven design, the no-hardcoded-constants rule, tuning hot-reload. |
| [`06_player_pawn.md`](20_tdd/06_player_pawn.md) | Node composition, state objects, input buffering, traversal probe pseudocode. |
| [`07_suspicion_and_detection.md`](20_tdd/07_suspicion_and_detection.md) | The per-tick update pipeline, ordering guarantees, server-side visibility resolution. |
| [`08_crowd_system.md`](20_tdd/08_crowd_system.md) | Spawn/pool architecture, LOD strategy, the ≤ 2.0 ms/frame budget, navmesh, clone-parity enforcement. |
| [`09_ability_system.md`](20_tdd/09_ability_system.md) | Request → validate → apply → replicate → present. Cooldown authority. Adding an ability in ≤ 3 files. |
| [`10_scoring_and_match_state.md`](20_tdd/10_scoring_and_match_state.md) | Server-side event sourcing; the scoreboard as a fold over an immutable ScoreEvent log. |
| [`11_ui_architecture.md`](20_tdd/11_ui_architecture.md) | Systems → event bus → view models → widgets. One-way data flow. |
| [`12_build_and_ci.md`](20_tdd/12_build_and_ci.md) | Headless import, export presets, `--server`, gdlint/gdformat, GUT layout, the debug console, one-click 3-client playtest. |

### 4.4 `30_bible/` — the AI Development Bible

Operational documents, not essays. These are what make the project agent-legible.

| File | Contents |
|---|---|
| [`CLAUDE.md_SEED.md`](30_bible/CLAUDE.md_SEED.md) | The content copied verbatim to the repo-root `CLAUDE.md`. |
| [`AGENT_PLAYBOOK.md`](30_bible/AGENT_PLAYBOOK.md) | The mandatory agent loop, the context-recovery ritual, the stop-and-ask rule. |
| [`CODING_STANDARDS.md`](30_bible/CODING_STANDARDS.md) | GDScript style, typing policy, signal naming, function/file length limits, error handling. |
| [`NAMING_AND_IDS.md`](30_bible/NAMING_AND_IDS.md) | The ID grammar with a regex per namespace; IDs are immutable once merged. |
| [`PROJECT_STRUCTURE.md`](30_bible/PROJECT_STRUCTURE.md) | Folder responsibilities and where a new file goes. |
| [`SCENE_AND_NODE_CONVENTIONS.md`](30_bible/SCENE_AND_NODE_CONVENTIONS.md) | Scene granularity, node naming, scene-vs-script, composition over inheritance. |
| [`SIGNAL_AND_EVENT_BUS.md`](30_bible/SIGNAL_AND_EVENT_BUS.md) | The global event catalogue with payload schemas; direct signal vs bus. |
| [`DATA_SCHEMA.md`](30_bible/DATA_SCHEMA.md) | Every Resource class: fields, types, ranges, defaults, `.tres` examples. |
| [`NETWORK_PROTOCOL.md`](30_bible/NETWORK_PROTOCOL.md) | The message catalogue as a standalone lookup reference. |
| [`ANIMATION_SPEC.md`](30_bible/ANIMATION_SPEC.md) | Animation list, durations, root-motion policy, blend times, the clone-parity table. |
| [`ART_BIBLE.md`](30_bible/ART_BIBLE.md) | Silhouette-first persona design, the colour-language law, placeholder standards, budgets. |
| [`AUDIO_BIBLE.md`](30_bible/AUDIO_BIBLE.md) | Event table, buses, ducking, the information-vs-atmosphere split. |
| [`UI_UX_SPEC.md`](30_bible/UI_UX_SPEC.md) | Layout grid, type scale, the Compass widget spec, colourblind palettes, the 0.5 s readability test. |
| [`TEST_PLAN.md`](30_bible/TEST_PLAN.md) | The test pyramid, the headless 3-client harness, the 12 playtest questions, feel-regression tests. |
| [`PERFORMANCE_BUDGET.md`](30_bible/PERFORMANCE_BUDGET.md) | The 16.6 ms frame split, memory, bandwidth, the profiling procedure. |
| [`DEFINITION_OF_DONE.md`](30_bible/DEFINITION_OF_DONE.md) | The checklist every story must pass before merge. |
| [`RISK_REGISTER.md`](30_bible/RISK_REGISTER.md) | Probability/impact/mitigation, including agent-drift and its docs-sync mitigation. |

### 4.5 `40_backlog/`

| File | Contents |
|---|---|
| [`ROADMAP.md`](40_backlog/ROADMAP.md) | Milestones M0–M6 with hard, demonstrable exit criteria. |
| [`EPICS.md`](40_backlog/EPICS.md) | Epic definitions grouping the stories. |
| [`stories/`](40_backlog/stories/) | One file per user story, `US-####`, each with milestone, linked SYS-IDs, acceptance checkboxes, test notes, estimate and dependencies. |

### 4.6 `50_tuning/`

| File | Contents |
|---|---|
| [`TUNABLES.md`](50_tuning/TUNABLES.md) | **The single source of truth for every number in the game.** |
| [`BALANCE_MODEL.md`](50_tuning/BALANCE_MODEL.md) | The math behind scoring and pacing; why each score value is what it is. |

---

## 5. Status board

| Section | Status | Notes |
|---|---|---|
| `00_meta/` | **written** | Glossary, scope fence, IP guardrails, ASM-0001..0030, asset register, decision log, ADR-0001..0010, coverage matrix (34 systems, no gaps). |
| `10_gdd/` | **written** | Parts 1–8 complete. |
| `20_tdd/` | **written** | Chapters 1–12 complete. |
| `30_bible/` | **written** | All 17 documents complete. |
| `40_backlog/` | **written** | M0–M6 roadmap, 26 epics, 89 stories. |
| `50_tuning/` | **written** | TUNABLES (~180 values, 20 invariants) and BALANCE_MODEL. |

No document is `locked` until it has survived one implementation milestone without
contradiction.

---

## 6. Non-negotiables, restated here so nobody misses them

1. **Original names only.** Never use the terms in the banned list in
   [`00_meta/IP_GUARDRAILS.md`](00_meta/IP_GUARDRAILS.md). Mechanics are not copyrightable;
   names, characters, art, logos, story, music and trade dress are.
2. **No hardcoded gameplay constants.** Every number lives in a tuning resource and has a
   `TUN-` ID.
3. **The server is authoritative over kills, stuns, suspicion and score.** The client never
   decides that something died.
4. **Every ability has a legible tell.** No invisible instant-wins.
5. **No file over 400 lines. No function over 40 lines.**
6. **Standing still in a crowd is the strongest defensive play in the game.** If a tuning
   change makes running better than patience, the tuning change is wrong.
