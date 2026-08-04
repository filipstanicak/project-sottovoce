---
id: BIBLE-DOD
title: Definition of Done
version: 0.1.0
status: draft
owner: Technical Director
last_updated: 2026-08-03
depends_on: [BIBLE-CODING-STANDARDS, BIBLE-TEST-PLAN, BIBLE-AGENT-PLAYBOOK, DOC-IP-GUARDRAILS]
---

# Definition of Done

> **A story is done when every box below is ticked, and not before.** This is a gate, not a
> guideline. "Done except for the tests" is not done; "done, I'll update the docs after" is not
> done.
>
> **Why it is this long:** most of this project's failure modes are silent. A missing clone
> animation, a predicted suspicion value, an uncaptioned audio event, a document that drifted —
> none of these break a build, and none survive being caught late. Every item here exists
> because the thing it catches is invisible in review.

---

## 1. The checklist

Copy into the PR description and tick as you go.

### Correctness

- [ ] **Every acceptance criterion in the story file is ticked, and each is actually true.**
      A ticked box that is not true is worse than an unticked one — it stops anyone checking.
- [ ] The change does what the story asked and **nothing more**. Extra work is unreviewed work.
- [ ] Manually verified in a running build, not only in tests.

### Tests

- [ ] Tests written that **would have caught the bug this story was about**.
- [ ] New Core or Systems files have a matching test file (`test_test_mirrors_source.gd`).
- [ ] `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test/unit -gexit` passes.
- [ ] `... -gdir=res://test/arch -gexit` passes.
- [ ] Integration suite passes if the change touches net, pawn, crowd or scoring.
- [ ] **No test skipped, weakened or deleted.** If an architecture test fails, the change is
      wrong or an ADR is needed — never the test.

### Tunables

- [ ] **No new gameplay literal.** Every number that affects play or feel is in a `.tres` with a
      `TUN-` ID.
- [ ] New tunables have a TUNABLES.md row: value, unit, range, **one-line rationale**.
- [ ] `@export_range` matches the documented Range; the docstring's last token is the `TUN-` ID.
- [ ] `test_tuning_docs_sync.gd` passes bidirectionally.
- [ ] If a value changed, a `TEL-` measurement justifies it — recorded in `DECISION_LOG.md`.
      **Opinions are not sufficient grounds to change a tuning value.**

### Code quality

- [ ] `gdlint scripts/ test/ tools/` clean.
- [ ] `gdformat --check scripts/ test/ tools/` clean.
- [ ] No file > 400 lines; no function > 40.
- [ ] Everything typed, including return types.
- [ ] No new warnings.
- [ ] Signals are past-tense facts; private members prefixed `_`.
- [ ] No `get_node` outside a widget's own subtree.
- [ ] No `randf`/`randi` outside `scripts/presentation/`.
- [ ] Nothing added to `scripts/pawn/` that breaks determinism (`Time.*`, lookups, autoloads
      other than `Tuning`).

### Multiplayer

- [ ] **Tested with 3 clients** via `tools/local_playtest.gd`.
- [ ] No client-authoritative outcome introduced. No new message expresses "I did X".
- [ ] Any new C2S message has a **non-empty authority check**, called first in the handler.
- [ ] No gameplay state newly predicted beyond the local pawn's movement.
- [ ] Any new replicated field is in `NETWORK_PROTOCOL.md` **and** TDD-04 §6
      (`test_protocol_docs_sync.gd`).
- [ ] Bandwidth impact measured if the change touches the snapshot.

### Design integrity

- [ ] If an ability was added or changed: it has **two tell channels, ≥ 1 environmental or
      audio** (`test_ability_has_tell.gd`).
- [ ] If an animation was added: is it reachable while Anonymous? If so it is **authored on the
      clone rig in the same commit** and added to `anonymous_clip_names`.
- [ ] If an audio event was added: bus assignment correct, and captioned if it is information.
- [ ] If an information channel was added: it has a row in the master table
      ([`../10_gdd/03_social_stealth.md`](../10_gdd/03_social_stealth.md) §11.1), all six columns.
- [ ] No design law violated ([`/CLAUDE.md`](../../CLAUDE.md)).
- [ ] Nothing added from the never-do list — **including no minimap, kill-cam, global kill feed,
      nameplate or hit-direction indicator**.

### Strings and assets

- [ ] No user-facing string literal; all keys resolve in `data/strings/en.csv`.
- [ ] Any new asset has an `ASSET_LICENSES.md` row **in this commit**.
- [ ] Licence is on the accepted list.

### IP

- [ ] `ip-guard` passes — no banned term in code, comments, commits, branch names, filenames or docs.
- [ ] Any new user-visible name is **functional-original** and registered in `GLOSSARY.md`.
- [ ] The review question in [`../00_meta/IP_GUARDRAILS.md`](../00_meta/IP_GUARDRAILS.md) §5
      answered. If the answer is yes, maybe, or *I'd have to think about it* — rework it.

### Documentation

- [ ] **If this change made a document wrong, the document is fixed in this commit.** Not a
      follow-up.
- [ ] `DECISION_LOG.md` appended if a decision was made.
- [ ] An ADR written if the decision constrains future work, adds scope, is expensive to reverse,
      or rejects an obvious alternative for a non-obvious reason.
- [ ] `COVERAGE_MATRIX.md` updated if a `SYS-` ID was added or changed.
- [ ] `implementation_plan.md` matches what was actually built.

### Process

- [ ] Branch named `us/US-####-slug`, lifetime ≤ 5 days.
- [ ] Commits follow `<type>(<scope>): <summary>` with a body explaining **why**.
- [ ] Rebased on `main`, squash-merged.
- [ ] Any feature flag added names the story that removes it.
- [ ] CI green on all six jobs.
- [ ] **The story file is marked.** `status: done`, `last_updated` bumped, and every
      acceptance criterion ticked. An unmet criterion stays **unticked** with a
      one-line note saying what blocks it — a story marked done over a criterion
      that is not true makes the whole backlog unreadable as a status view.

---

## 2. The docs-sync item

Called out separately because it is the mitigation for `RISK-AGENT-DRIFT`, the highest-impact
risk in the register.

> **If your change makes a document wrong, fix the document in the same commit.**

Not in a follow-up story. Not "when I have time". The same commit.

**Why the strictness:** documentation that has drifted is worse than absent documentation,
because it is *confidently* wrong. An agent starting a fresh session reads the corpus and trusts
it — that is the entire premise of this project's structure. A stale document does not merely
fail to help; it actively misleads the reader most dependent on it.

| Change | Also update |
|---|---|
| A tunable value | TUNABLES.md row + rationale |
| A `SYS-` behaviour | Its GDD chapter **and** TDD chapter |
| An RPC or payload | `NETWORK_PROTOCOL.md` **and** TDD-04 §6 |
| An event-bus signal | `SIGNAL_AND_EVENT_BUS.md` |
| A resource field | `DATA_SCHEMA.md` |
| An animation | `ANIMATION_SPEC.md` + the parity table |
| An audio event | `AUDIO_BIBLE.md` + the event table |
| A design law or scope boundary | `/CLAUDE.md`, `CLAUDE.md_SEED.md`, `SCOPE_FENCE.md` |
| A new `SYS-` ID | `COVERAGE_MATRIX.md` |

---

## 3. What "multiplayer-tested with 3 clients" means

Not "it compiled and one client connected".

1. `tools/local_playtest.gd` — one headless server, three tiled clients.
2. All three connect, ready up, and enter a match.
3. **Exercise the changed feature on all three**, not just the host's.
4. Verify the feature behaves identically from each client's view.
5. If it touches visibility or anonymity: confirm **the same player renders differently to
   different observers** — the per-observer render state is the easiest thing to break and the
   hardest to notice.
6. Disconnect one client mid-match; confirm the contract cycle repairs and play continues.

---

## 4. When an item does not apply

Write `N/A — <reason>` rather than deleting the line. A checklist with silently removed items
stops being a checklist.

> `- [x] N/A — no assets added`

---

## 5. Definition of Done for a milestone

Beyond every story being done:

- [ ] The milestone's exit criterion in [`../40_backlog/ROADMAP.md`](../40_backlog/ROADMAP.md) is
      **demonstrable**, not merely believed.
- [ ] The feel-regression checklist ([`TEST_PLAN.md`](TEST_PLAN.md) §7.2) run by a named person.
- [ ] The playtest script run with 4–6 humans, all twelve questions asked, logged to
      `docs/40_backlog/playtests/`.
- [ ] Performance profiled in the standard scenario; every budget row within target at **p99**.
- [ ] `COVERAGE_MATRIX.md` has no gap rows.
- [ ] Every document exercised by this milestone reviewed for drift and promoted from `draft` to
      `review` if it survived contact.
- [ ] Open questions due at this milestone answered or explicitly deferred with a new date.
- [ ] A tag pushed (`m3-crowd`).

---

## 6. What Done does *not* require

Stated so nobody gates on the wrong thing, and so `SCOPE_FENCE` §5 is honoured in practice.

| Not required | Until |
|---|---|
| Final art | M6 |
| Final audio | M6 |
| Polished animation blends | M6 — **clone parity is required from the start** |
| Menu presentation | M6 |
| Optimisation beyond the stated budgets | Never — the budgets *are* the target |
| Support for player counts outside 4–6 | Never |
| Localisation | Post-MVP — the string table is required, translation is not |

---

## 7. Enforcement

| Item class | Enforced by |
|---|---|
| Tests, lint, format, IP, assets, exports | CI — six required checks, cannot be merged around |
| Tunables, docs-sync, protocol-sync, ID grammar | `test/arch/` source scans |
| Multiplayer testing, feel checks, the review question | **Human. Honour system.** |

The third row is the weak one, and it is weak by necessity — no CI job can run three clients and
judge whether a stun *felt* decisive. The mitigation is that those items are few, specific, and
named, rather than a vague instruction to "test it properly".

---

## 8. Acceptance criteria for this document

- [ ] Every CI-enforceable item has a named job or test.
- [ ] Every item is objective — a reviewer can tell whether it passed without judgement, except
      the three explicitly marked human.
- [ ] The checklist is copied into every PR description.
- [ ] No item duplicates another; each catches something distinct.
- [ ] The milestone checklist (§5) matches the ROADMAP exit criteria.
