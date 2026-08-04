---
id: US-0004
title: CI — asset licence inventory
version: 0.1.0
status: draft
owner: Technical Director
last_updated: 2026-08-03
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

- [ ] `.ci/check_asset_inventory.sh` enumerates assets and parses the register.
- [ ] Fails on an asset with no row.
- [ ] Fails on a row with no asset.
- [ ] `assets/greybox/**` and `assets/procedural/**` are exempt.
- [ ] Extending the exemption list requires an ADR, noted in the script header.
- [ ] Required check on `main`.

## Test notes

Verify both failure directions deliberately — add an unregistered file, then a stale row.

## Notes

Licence provenance is trivially cheap at import time and extremely expensive to reconstruct
later.
