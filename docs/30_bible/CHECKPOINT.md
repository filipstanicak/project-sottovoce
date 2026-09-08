# The checkpoint procedure

*One home. Every agent entry point that offers a "save" or "checkpoint" command
is a **pointer to this file** and holds no copy of the steps below.*

**WHY THIS FILE EXISTS, MEASURED RATHER THAN ASSERTED.** On 2026-09-08 there were
two copies of this procedure in one repository — `.claude/commands/save.md` and
`.agents/skills/source-command-save/SKILL.md` — and they had **already diverged in
substance, not merely in naming**. One instructed its agent to write the live
project state into `CLAUDE.md`; the other instructed a second agent to write it
into `AGENTS.md`. So two agents were told, in writing, to checkpoint the same
project into two different documents, and neither instruction was wrong on its own
terms. **The drift was not an accident; it was instructed.**

That is the same shape this corpus has now paid for five times — `NETWORK_PROTOCOL.md`
drifting unguarded for two milestones under a note claiming it was checked, the seed's
phantom `test_claude_md_synced.gd`, TDD-12 §11's twelve absent hooks, `test/metrics/`,
and `AGENTS.md` itself. **A rule written twice is a rule that disagrees with itself
later**, and the second copy is always the one nobody reads before acting.

`test_agent_entry_points_are_pointers.gd` is what keeps this true: it refuses an
entry point that has grown a copy of the steps, and it refuses one whose pointer
names a file that does not exist. **A length cap alone would not do it** — a short
file can still carry a wrong instruction — so the target is resolved rather than
merely mentioned.

---

Bring every place that records project state up to date, so this session could
end right now and the next one resume with no loss. Work through all of it — a
partial checkpoint is worse than none, because it looks done.

**Be accurate, not tidy.** If something is half-finished, blocked, or turned out
to be wrong, say so in the document rather than rounding it up. A checkpoint that
overstates progress is how the next session wastes an afternoon.

## 1. Land the working tree

Nothing uncommitted survives. If there are changes, commit them on a branch and
open a PR — never push to `main` (ADR-0009; `.githooks/pre-push` enforces it).
If the work is genuinely incomplete, commit it anyway with the commit message
saying exactly what is unfinished.

## 2. Story files — `docs/40_backlog/stories/`

For every story touched since the last checkpoint:

- `status:` is `draft`, `in-progress` or `done`
- `last_updated:` is today
- Tick every acceptance criterion **that is actually true**. Verify against the
  repository; do not tick from memory.
- An unmet criterion stays **unticked**, with a one-line note saying what blocks
  it. Ticking it anyway makes every other tick untrustworthy.

## 3. `CLAUDE.md` — the "Where the work is right now" section

This is read first by a fresh session, so a stale version is worse than none.
Update:

- Which milestone, and how many of its stories are done
- What exists and works, with real numbers (test counts, CI job count)
- **What is not yet possible** — say plainly if nothing is playable/runnable yet
- The traps: anything that has already cost an hour, or would
- Local environment facts that are not derivable from the repo

## 4. `docs/40_backlog/ROADMAP.md`

Milestone status, and — more importantly — **flag any listed deliverable that is
only half-true**. A roadmap that overstates what is enforced stops anyone
checking.

## 5. Other corpus documents

If the session changed how something works, sync the document that governs it —
this is the Definition of Done docs-sync rule, not optional. Common ones:
`docs/20_tdd/12_build_and_ci.md` for CI, `docs/30_bible/DATA_SCHEMA.md` for
resource shapes, `NAMING_AND_IDS.md` for ID grammar. Fix any count or claim the
session made false.

## 6. Memory — `.claude/projects/<project>/memory/`

Update the project-state memory and `MEMORY.md`. Memory is for what is true when
the repo is **not** open; keep it short and point at `CLAUDE.md` for detail.
Delete memories that have become wrong.

## 7. Generated artefacts and tooling

Anything the session generated must be reproducible from the repository alone.
If a script that produced committed files lives outside the repo, move it in.
**Verify by reproduction, not inspection**: regenerate, then confirm `git diff`
is empty.

## 8. Verify from a clean checkout, then report

```bash
git archive HEAD | tar -x -C <tmpdir>
```

Run the full suite there — not in the working tree. Git does not track empty
directories, and a working-tree pass has proved nothing before.

Then tell me, briefly:

- What changed since the last checkpoint
- Exactly where to pick up, and what the next story is
- Anything still broken, blocked or uncertain — including mistakes made this
  session that have not been fixed
- Tell me the exact promt which you need to continue from a new session

---

## 9. The handoff block, when more than one agent works this repo

Two agents cannot see each other's session. **The repository is the only channel
between them**, so a checkpoint that reads well to a human and says nothing
specific is a checkpoint the other agent cannot act on. Close every checkpoint
with this block, in the PR body and in the chat:

```
Story      US-0000, or the slug if there is no story
Branch/PR  the branch, and the PR number if one is open
Commit     the exact SHA the checks passed on
Changed    the systems touched, not the file list
Tests      which suites ran, where, and what they read
Open       what is unfinished, blocked, or was got wrong and not yet fixed
Next       the one thing the next session should do first
```

**`Commit` is the load-bearing line.** "Green" means the checks passed on *one
tree*; a later commit on the same branch has not been checked until its own run
finishes. Naming the SHA is what stops the next agent inheriting a claim that was
true of a tree that no longer exists.

**And "green" is not "compatible".** The suites assert what somebody thought to
assert. `NET-C2S-ABILITY-REQUEST` had its RPC, its authority row, its channel, its
router hop, its server wiring and five validations — and **no caller**, under three
completed stories, with every suite green. Q and F did nothing at all. A green run
says the tests passed; it never says the feature is reachable.

**One agent checkpoints per piece of work.** Both writing "Where the work is right
now" in the same window is a guaranteed conflict at the same anchor line, and
resolving it by hand is how a real finding gets dropped from one of the two.
