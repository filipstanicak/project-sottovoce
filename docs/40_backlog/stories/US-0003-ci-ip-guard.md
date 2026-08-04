---
id: US-0003
title: CI — IP guard
version: 0.1.0
status: done
owner: Technical Director
last_updated: 2026-08-04
depends_on: [DOC-IP-GUARDRAILS, TDD-12-BUILD]
---

# US-0003 — CI: IP guard

| | |
|---|---|
| **Milestone** | M0 |
| **Epic** | `EPIC-SCAFFOLD` |
| **Systems** | — |
| **Estimate** | S |
| **Depends on** | US-0002 |

## Description

A hard-failing CI job that greps the whole repository for banned franchise terms. Not a warning —
a build failure.

Renaming later does not work: names leak into commit history, asset filenames, screenshots, build
artefacts and playtester vocabulary, and the cost grows superlinearly.

## Acceptance criteria

- [x] `.ci/banned_terms.txt` contains every term from IP_GUARDRAILS §2.1–2.3.
- [x] `.ci/ip_guard_exclude.txt` lists exactly two files.
- [x] The job scans code, comments, docs, filenames and paths, case-insensitively.
- [ ] It is a hard failure and a required check on `main`.
- [x] A commit with a banned term in a comment fails the build (verified deliberately).

## Test notes

`test_banned_terms_sync.gd` asserts the list matches IP_GUARDRAILS exactly.
`test_ip_guard_exclusions.gd` asserts exactly two exemptions — a third requires an ADR.

## Notes

Terms are ≥ 4 characters and reviewed for collisions. If a false positive appears, fix the term
rather than weakening the check.

> **Outstanding.** The unticked criterion above is blocked by the GitHub
> plan, not by the work: hard failure yes; *required check* needs GitHub Pro. Server-side branch protection and rulesets
> both return 403 on a free private repository, so `main` has no *required*
> checks — only agreed ones plus a local pre-push hook. Full account and the
> promotion path: [`../../20_tdd/12_build_and_ci.md`](../../20_tdd/12_build_and_ci.md) §1.3.
> Tick it the moment the plan allows.
