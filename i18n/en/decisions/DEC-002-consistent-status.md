---
id: DEC-002
title: Project status consistent across registry, index and brief
status: approved
date: {{FECHA_INSTALACION}}
source: KOS base decision
---

# DEC-002 — Consistent status

## Decision
A project's status is written in three places: `registry/projects.yaml` (`lifecycle`), `projects/index.md` (Status column) and `projects/<id>/project.md` (`Status:` line). All three say the same and change in the same commit. A task is marked done only when its result is verified.

## Reason
If each file says something different, no AI knows what is true: closed projects get resumed and active ones get forgotten.

## Consequences
- `tools/kos_validate.rb` fails if a project is open in one place and closed in another.
