---
id: US-0006
title: ID constants and glossary sync
version: 0.1.0
status: done
owner: Technical Director
last_updated: 2026-08-04
depends_on: [BIBLE-NAMING-IDS, DOC-GLOSSARY]
---

# US-0006 — ID constants and glossary sync

| | |
|---|---|
| **Milestone** | M0 |
| **Epic** | `EPIC-DATA` |
| **Systems** | — |
| **Estimate** | S |
| **Depends on** | US-0005 |

## Description

`scripts/core/ids.gd` — StringName constants for every ID namespace, with a bidirectional test
against GLOSSARY.md Appendix A.

StringName rather than String because IDs are compared on the hot path — every score append,
every ability lookup, every state transition — and comparison is pointer-equal and
allocation-free.

## Acceptance criteria

- [x] `Ids` declares constants for every SCORE-, ABIL-, PASV-, PERSONA-, ARCH-, MAP-, EVT-, NET-, SFX-, MUS- and ANIM- ID in the corpus.
- [x] All are StringName literals.
- [x] `test_ids_match_glossary.gd` passes bidirectionally.
- [x] `test_id_grammar.gd` validates every ID against its namespace regex.
- [x] `test_ids_are_stringname.gd` finds no String ID constant.

## Test notes

Bidirectional matters: an ID in code but not the glossary is undocumented; one in the glossary
but not code is a name nobody implemented.

## Notes

IDs are immutable once merged. A wrong name is deprecated with a note, never renamed or reused.
