---
name: "source-command-save"
description: "Checkpoint the project so a cold session can resume without losing anything"
---

# source-command-save

Read `docs/30_bible/CHECKPOINT.md` now and follow it exactly. It is the whole
procedure and this file is deliberately a pointer to it.

**Do not reproduce the steps here.** This file and `.claude/commands/save.md` each
held a full copy until 2026-09-08, and the two had already diverged in substance:
this one instructed its agent to write the live project state into `AGENTS.md`
while the other named `CLAUDE.md`, and its memory path read `.Codex/` against the
other's `.claude/`. Nothing was wrong on either side in isolation, which is exactly
why nobody caught it. `test_agent_entry_points_are_pointers.gd` refuses a copy
growing back here.

**This file is versioned on purpose.** Machine-specific configuration is not — see
`.gitignore` — but the working rules two agents share have to be reviewable by
both, or the next divergence is invisible again.
