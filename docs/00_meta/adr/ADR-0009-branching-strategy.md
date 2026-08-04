---
id: ADR-0009
title: Trunk-based development
version: 1.0.0
status: accepted
owner: Technical Director
last_updated: 2026-08-03
depends_on: [DOC-SCOPE-FENCE]
supersedes: none
---

# ADR-0009 — Trunk-based development

## Context

Small team, one shipping target, no release branches to maintain, no customers on old
versions. The dominant risks to velocity are not merge conflicts in code — they are:

1. **Scene and resource merge conflicts.** `.tscn` and `.tres` are text but merge badly.
   A three-way merge on node ordering or sub-resource IDs produces files that load and are
   subtly wrong. The cost of a conflicted scene is *re-authoring it*, and that cost scales
   with how long the branch lived.
2. **Integration drift on a networked game.** A branch that changes the RPC catalogue or the
   snapshot format is incompatible with `main` in a way tests on the branch will not reveal —
   the branch tests against itself.
3. **Agent-generated work in parallel.** Multiple agent sessions producing large diffs
   against different bases is the fastest way to reach a state nobody can reconcile.

All three get worse superlinearly with branch lifetime. That points at short branches
regardless of which named workflow we adopt.

## Options considered

| Option | Pros | Cons | Verdict |
|---|---|---|---|
| **Trunk-based: short feature branches (≤ 2 days) merged to `main`, `main` always green** | Minimises scene-conflict exposure; integration problems surface within hours; CI protects one branch; simple mental model. | Requires discipline about small, mergeable increments; incomplete features must be hidden behind a flag or be genuinely inert. | **Chosen** |
| GitFlow (develop + release + feature + hotfix) | Well-known; supports parallel releases. | We have no parallel releases. All the ceremony, none of the benefit. Long-lived `develop` maximises scene-conflict risk. | Rejected |
| Direct commits to `main`, no branches | Simplest. | No pre-merge CI gate. On a networked game, a broken `main` blocks every playtest. | Rejected |
| Long-lived feature branches per milestone | Milestone work stays isolated. | An M3 crowd branch and an M4 loop branch would both touch the snapshot format and diverge for weeks. This is the exact failure mode. | Rejected |

## Decision

**Trunk-based development on `main`, with short-lived feature branches.**

| Rule | Detail |
|---|---|
| **Branch naming** | `us/US-0042-compass-lock-arc`, `fix/<slug>`, `docs/<slug>`, `chore/<slug>`. The story ID in the branch name is how work links to the backlog. |
| **Branch lifetime** | Target ≤ 2 days, hard ceiling 5. A branch older than 5 days must be split or merged behind a flag; this is a Definition-of-Done item, not a suggestion. |
| **`main` is always green** | CI (headless import, `gdlint`, GUT, `ip-guard`, `asset-inventory`, export templates) is a required check. No merge on red. |
| **Merge strategy** | Squash merge. One commit per story on `main` keeps the history a readable list of completed work, and makes `git revert` of a whole story trivial. |
| **Rebase, don't merge, before opening a PR** | Keeps the branch's diff minimal and the eventual squash clean. |
| **No direct pushes to `main`** | Including by agents. Including for "trivial" fixes. |

> **Enforcement gap, recorded 2026-08-04.** The two rows above are policy, not
> yet mechanism. Branch protection and rulesets both require GitHub Pro on a
> private repository, and the API returns 403 on the current plan. Squash-only
> merging *is* enforced server-side; "no direct push" and "no merge on red" are
> currently enforced only by `.githooks/pre-push` and by discipline. A local
> hook is bypassable and does not survive a fresh clone until `core.hooksPath`
> is set. Full detail and the promotion path:
> [`../../20_tdd/12_build_and_ci.md`](../../20_tdd/12_build_and_ci.md) §1.3.
| **Incomplete work is inert, not absent** | A partially-built system merges when it is *harmless*: unregistered, unreferenced, behind a `Tuning`-driven flag, or reachable only from a debug command. It does not wait on a branch. |
| **Scene files are claimed** | Before editing a `.tscn` that someone else may be editing, say so. A conflicted scene is re-authored in the editor, never hand-merged (see `.gitattributes` and [`../../30_bible/SCENE_AND_NODE_CONVENTIONS.md`](../../30_bible/SCENE_AND_NODE_CONVENTIONS.md) §7). This is a process rule because no tooling solves it. |
| **Commit message convention** | `<type>(<scope>): <summary>` — types `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `perf`. Scope is a system slug (`compass`, `crowd`, `net`) or a doc section (`gdd`, `tdd`, `bible`). Body explains *why*. |

### Feature flags

Flags live in `TuningProfile` (ADR-0005), not in code:

```gdscript
class_name FeatureFlags
extends Resource

## Enable ABIL-SECONDFACE. Off until US-0051 completes. Remove this flag at M5 exit.
@export var enable_second_face: bool = false
```

Every flag carries a comment naming the story that removes it. **A flag with no removal
story is technical debt with a nice name**, and the Definition of Done checks for it.

## Consequences

### Positive
- Scene conflicts stay rare because branches are short.
- Netcode incompatibilities surface within hours, when the change is still in someone's head.
- One protected branch means one CI configuration to maintain.
- `main` is always playtestable, so a spontaneous "can we try this tonight?" is always yes —
  which matters disproportionately for a game that can only be validated with six humans.
- Squash-merged story commits give the roadmap a mechanical audit trail.

### Negative — stated honestly
- **Feature flags accumulate.** Each one is a branch in the code that must be reasoned about
  and tested. The removal-story rule is the mitigation, and it requires enforcement or it
  decays.
- Splitting work into ≤ 2-day mergeable increments is genuine design effort, and some things
  resist it. The netcode prediction work (ADR-0002) is the clearest example — it is hard to
  land in pieces that are individually inert. Expect to break the 2-day target there, with an
  explicit note in the PR.
- Squash merge loses intra-branch commit granularity. Accepted: the granularity that matters
  is the story.
- No release branch means no way to patch a shipped build while `main` moves on. Irrelevant
  pre-M6; if the project ships, that is a new ADR.

### Neutral / follow-on
- Tags mark milestones (`m0-foundation`, `m4-the-loop`), giving a checkout point per
  milestone without a branch.

## Compliance

- [ ] `main` has branch protection: required status checks, no force push, no direct push.
- [ ] Required checks: `import`, `lint`, `test`, `ip-guard`, `asset-inventory`, `export`.
- [ ] Every branch name matches `^(us|fix|docs|chore|perf)/[a-z0-9-]+$`.
- [ ] Every commit message matches `^(feat|fix|docs|refactor|test|chore|perf)\(.+\): .+`.
- [ ] Every `FeatureFlags` field's docstring names the story that removes it.
- [ ] No branch on the remote is older than 5 days without a note in its PR explaining why.

## Revisit trigger

Reopen if the team grows beyond ~6 contributors, if a shipped build ever needs patching
independently of `main`, or if scene conflicts become frequent despite short branches — the
latter would indicate the scene granularity rules need fixing, which is a
`SCENE_AND_NODE_CONVENTIONS.md` problem rather than a branching one.
