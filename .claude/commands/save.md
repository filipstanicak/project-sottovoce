---
description: Checkpoint the project so a cold session can resume without losing anything
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
