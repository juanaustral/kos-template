---
id: DEC-001
title: Permanent rule — every AI logs its work in KOS
status: approved
date: {{FECHA_INSTALACION}}
source: KOS base decision
---

# DEC-001 — Permanent logging rule

## Decision
Every AI, tool or version working with {{OWNER_NAME}} reads the KOS entry point (`AGENTS.md`) before working and **logs in KOS** whatever is decided, created, learned or changes status, as part of the same work. The rule's text lives in `AGENTS.md` and does not change without {{OWNER_NAME}}'s explicit approval.

## Reason
A conversation does not archive itself: only what gets written into KOS remains. That way {{OWNER_NAME}} can switch AIs without rebuilding anything and without depending on any platform's memory.

## The Wrap-up
Every piece of work that changed something ends with three lines:
```
Logged in KOS: <files written> | nothing to log
Verified with: <concrete evidence> | not verified
Pending:       <what is left>. Next action: <one only>
```

## Consequences
- An AI's own memory is not a source about {{OWNER_NAME}}.
- If an AI cannot write, it hands over a "To log in KOS" block.
