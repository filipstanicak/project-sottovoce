---
id: DOC-PAWN-NAV-CONSTANTS
title: Shared pawn navigation constants
version: 0.1.0
status: draft
owner: Codex
last_updated: 2026-09-08
depends_on: [TDD-08-CROWD]
---

# pawn-nav-constants

Move the eight NAV_* constants from VetraioLayout to PawnNavigation in Core.
They describe the shared pawn and bake contract, not one district. Preserve every
value and keep the constants independent of autoloads; both map generators remain
SceneTree scripts launched with -s.

Affected systems: shared map geometry, navmesh baking, crowd clearance/rescue, and
the tests consuming those dimensions. No gameplay tuning or protocol changes.
Expected shared-manual change: one concise checkpoint in CLAUDE.md describing the
new owner, measured test counts and byte-identical map reproduction. AGENTS.md and
the checkpoint entry points remain pointers.

## Acceptance

- [ ] All eight definitions live only in PawnNavigation; consumers use that owner.
- [ ] Values are unchanged; no VetraioLayout.NAV_* reference remains in executable code.
- [ ] Both generators reproduce all their committed scene outputs byte-identically.
- [ ] Unit, architecture and integration suites pass from a clean archive, with script counts checked.
- [ ] Lint, format, IP and asset checks pass; handoff names the checked commit.

## Verification plan

Import the fresh worktree before its first suite. Capture scene hashes before and
after running tools/generate_map_vetraio.gd and tools/generate_map_sandbox.gd. Check
only generated scene paths for an empty diff while source edits are uncommitted;
after committing, regeneration must leave the complete tracked tree clean.

PR #210 is merged and the branch has been rebased before this planning commit.
Implementation has not started at this checkpoint.
