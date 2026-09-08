---
id: DOC-SPLIT-THE-SNAPSHOT
title: Split the snapshot without changing the wire
version: 0.1.0
status: done
owner: Codex
last_updated: 2026-09-08
---

# split-the-snapshot

The 397-line Snapshot is close to the 400-line ceiling. Separate
its value object from a SnapshotCodec holding encoding, decoding and quantised
fingerprints together. Preserve all public Snapshot fields, constants and methods,
including static deserialise/state helpers, using thin compatibility delegations.

Keeping everything in one file makes declaration-to-wire comparison easier, but
has exhausted the size budget. Splitting readers from writers would instead separate
the two definitions that must agree byte-for-byte. A codec is the chosen seam:
one ordered implementation of the wire, with no reflection or reordered fields.
The cost is navigating between field declarations and codec; fixed byte fixtures,
size tests and round trips protect that boundary.

Scope: scripts/net/protocol/snapshot.gd and its new codec, focused compatibility
tests, and this decision record. No timer work, field additions/removals/renames,
quantisation changes, state-index ordering changes, or protocol changes.
Dependency: none on US-0079. The initial blocker claim was wrong: `phase` and
`ticks_remaining` already exist. PR #213 is merged and this branch is rebased on it.
Expected shared-manual update: mark the 397-line blocker resolved after the split;
keep that edit narrow and reconcile with the other agent's checkpoint.

Verification: import before tests; capture baseline bytes before moving code;
compare complete encoded packets and decode/re-encode the frozen packets. Run
all architecture, unit and integration suites through .ci/run_gut.sh from a clean
archive of the final commit, plus lint/format/IP/asset checks. Final results and
exact SHA belong to the PR handoff. The implementation is complete: Snapshot is
167 lines and SnapshotCodec is 261. Fixed bytes remain 57, remote records 10 and
NPC records 8. Initial unit (195 scripts) and architecture (57 scripts) runs pass.
A temporary symmetric swap of hunt/hunted in both writer and reader was detected
by the frozen-byte tests while the record widths stayed unchanged; it was reverted.
Final clean-archive results are reported against an exact commit in PR #214.
