# Workflow for AIs (long work)

Status: current. Read it only if the work spans several sessions, touches several projects or involves a lot of writing.

## Model
```
{{OWNER_NAME}} owns KOS.
KOS holds the durable knowledge.
AIs are temporary clients.
Base decides what remains true.
```

| Layer | Role |
|---|---|
| Base | Reviewed knowledge and current decisions. |
| Your session memory | Temporary context. It gets lost. |
| Inbox | Captured material, not yet trusted. |
| Work | Drafts, analysis and plans. |
| History | What was replaced. |
| Generated | Rebuildable indexes and views. |

## Before starting
1. Read `AGENTS.md` and `ONBOARDING/README.md`.
2. Define the scope: global, area, project or task.
3. Read the project's `manifest.yaml` and `project.md`. The manifest says which folders you may read and write (`tools.read`, `tools.write`) and the autonomy level (`security.max_autonomy`).
4. Define what "done" means and how you will verify it.

## Autonomy levels
- **A1**: you only read and propose. {{OWNER_NAME}} writes.
- **A2**: you write small, reversible changes in KOS; ask for approval for everything on the list in `ONBOARDING/README.md`.
- **A3**: you also run agreed external actions (publish, deploy) without asking each time. Only if a current decision allows it.

## During the work
- One change per commit. Validate after each one.
- If work is left half done, record the state in `projects/<id>/tasks.md` (what was done, what is left, next action) so another AI can continue without your memory.
- If you find contradictory information, apply the order of authority and say so.

## Handoff between sessions or AIs
When closing a long session, write in the task in progress:
- what changed (files and commits),
- how it was verified,
- what is left and the single next action.
The next AI starts by reading `AGENTS.md` and that task. Nothing depends on your memory.

## Memory proposals
What you learn about {{OWNER_NAME}} or their domains goes to `knowledge/inbox/` with `Status: proposed`. Never into your platform's memory.
