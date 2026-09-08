# Project Sottovoce

**The operating manual for this repository is [`/CLAUDE.md`](CLAUDE.md). Read it in
full before doing anything else.** It holds the thesis, the six design laws, the
tech constraints, the folder map, the naming rules, the routing table, the
never-do list, the stop-and-ask protocol, the current state of the work, the
eighteen traps and the local toolchain. Nothing in it is duplicated here.

This file is a pointer, and that is a decision rather than an omission. It carried
a **6 529-line verbatim copy** of `CLAUDE.md` until 2026-09-08, and by then the
copy had already drifted: its test-count row was two days stale, its header named
a source file — `docs/30_bible/Codex.md_SEED.md` — **that has never existed**, and
it claimed to be checked by `test_claude_md_synced.gd`, which reads `CLAUDE.md`
and its seed and has never so much as opened this file.

That is the shape this corpus has paid for five times, and the claim is always
worse than the gap: a document asserting it is checked is what stops anybody
checking. `test_agent_entry_points_are_pointers.gd` now resolves the link above
rather than trusting it.

## The checkpoint command

`docs/30_bible/CHECKPOINT.md`, reached through
`.agents/skills/source-command-save/SKILL.md`. One home, one procedure, whichever
agent runs it.
