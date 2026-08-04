---
id: US-0011
title: String table and Strings autoload
version: 0.1.0
status: draft
owner: Technical Director
last_updated: 2026-08-03
depends_on: [TDD-02-STRUCTURE]
---

# US-0011 — String table and Strings autoload

| | |
|---|---|
| **Milestone** | M0 |
| **Epic** | `EPIC-DATA` |
| **Systems** | — |
| **Estimate** | S |
| **Depends on** | US-0010 |

## Description

`data/strings/en.csv` and the Strings autoload. Localisation is out of scope; the table is not
(ASM-0023).

Retrofitting a string table across a finished UI is a multi-day refactor with a long tail of
missed strings. Doing it from commit one costs approximately nothing and makes the deferred work
a data task.

## Acceptance criteria

- [ ] `data/strings/en.csv` exists in Godot translation CSV format.
- [ ] `Strings.get(key)` resolves; a missing key logs push_error and returns the key.
- [ ] Namespaces reserved: ui, bonus, ability, persona, caption, credits, menu.
- [ ] `test_no_literal_strings.gd` finds no user-facing literal outside `data/strings/`.

## Test notes

The test scans for quoted strings assigned to Label.text, Button.text and similar.

## Notes

Every bonus name and every audio caption lives here, which also gives the IP guardrails one place
to review user-visible vocabulary.
