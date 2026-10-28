---
id: DEC-003
title: Criteria for keeping KOS light
status: approved
date: {{FECHA_INSTALACION}}
source: KOS base decision
---

# DEC-003 — Keep KOS light

## Decision
Before leaving something in KOS, answer three questions:
1. Will an AI or {{OWNER_NAME}} need it to decide or act soon? If not, it goes to Git history or `knowledge/archive/`.
2. Does it change a current decision or a project's status? If yes, it stays.
3. Does it repeat something already in another file? If yes, link instead of duplicating.

## Reason
Every extra file costs every AI reading time and tokens, and multiplies contradictions. A small, current KOS gets used; a huge one gets ignored.

## Consequences
- Decisions are never deleted: their status changes.
- Once a month, review `knowledge/inbox/` and archive what wasn't used (see `docs/manual/07-maintenance.md`).
