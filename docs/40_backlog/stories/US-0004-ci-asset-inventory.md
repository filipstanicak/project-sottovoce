---
id: US-0004
title: CI — asset licence inventory
version: 0.1.0
status: done
owner: Technical Director
last_updated: 2026-08-21
depends_on: [DOC-ASSET-LICENSES, TDD-12-BUILD]
---

# US-0004 — CI: asset licence inventory

| | |
|---|---|
| **Milestone** | M0 |
| **Epic** | `EPIC-SCAFFOLD` |
| **Systems** | — |
| **Estimate** | S |
| **Depends on** | US-0002 |

## Description

A CI job asserting every non-authored asset has a licence row in `ASSET_LICENSES.md`, and every
row corresponds to a real file.

Checked in both directions: a stale row is as much a defect as a missing one, because it means
someone deleted an asset and left a claim about it, which makes the register untrustworthy.

## Acceptance criteria

- [x] `.ci/check_asset_inventory.sh` enumerates assets and parses the register.
- [x] Fails on an asset with no row.
- [x] Fails on a row with no asset.
- [x] `assets/greybox/**` and `assets/procedural/**` are exempt.
- [x] Extending the exemption list requires an ADR, noted in the script header.
- [x] Required check on `main`.
      > **True since 2026-08-21**, verified by pushing straight at `main` with `--no-verify` so the client hook could not answer for it: *"Changes must be made through a pull request. 7 of 7 required status checks are expected."* `.github/main-ruleset.json`, TDD-12 §1.3.

## Test notes

Verify both failure directions deliberately — add an unregistered file, then a stale row.

## Notes

Licence provenance is trivially cheap at import time and extremely expensive to reconstruct
later.

> **Outstanding.** The unticked criterion above is blocked by the GitHub
> plan, not by the work: branch protection needs GitHub Pro on a private repo. Server-side branch protection and rulesets
> both return 403 on a free private repository, so `main` has no *required*
> checks — only agreed ones plus a local pre-push hook. Full account and the
> promotion path: [`../../20_tdd/12_build_and_ci.md`](../../20_tdd/12_build_and_ci.md) §1.3.
> Tick it the moment the plan allows.
