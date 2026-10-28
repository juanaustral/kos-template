# Recipes: how to do routine tasks in KOS

They all follow the same rule: **read the file, make the smallest change, reread to verify, validate and commit** (`ruby tools/kos_validate.rb` must report 0 errors). If the request is ambiguous, don't write: ask {{OWNER_NAME}}.

## Capture an idea or note
- New file: `knowledge/inbox/YYYY-MM-DD-topic.md` using `templates/inbox.md` (`# Title`, `Source`, `Date`, `Status: proposed`, `Sensitivity` and the text).
- Do not promote it to a project or to Base without approval. An idea is not an active project.
- Loose notes already sorted: `knowledge/lists/notes.md` (`| Date | Topic | Note | Status | Source |`).

## See projects and next steps
- List and status: `projects/index.md`. Detail: `projects/<folder>/project.md` ("Next action" section).
- Tasks: `projects/<folder>/tasks.md`. The next step is the first task under `## In progress`; if empty, the first under `## To do`.

## Add or move a task
- File: `projects/<folder>/tasks.md`, with sections `## In progress`, `## To do`, `## Backlog`, `## Blocked`, `## Done`.
- Line: `- [ ] Title — context (created YYYY-MM-DD)`. When finished: `- [x] Title (done YYYY-MM-DD)` and move it to `## Done`.
- A task is marked done only when the result was verified (published, delivered, merged), not before.

## Log a decision
- New file: `decisions/DEC-NNN-short-topic.md` using `templates/decision.md` (`NNN` = next free number in `decisions/index.md`).
- Add the row to `decisions/index.md`. If it replaces another, change the old one's status to `replaced by DEC-NNN`; never delete it.

## Create a project
1. Ask {{OWNER_NAME}} to confirm the name, goal and status.
2. Create `projects/<id>/` with `manifest.yaml`, `project.md` and `tasks.md` from `templates/` (`id` in lowercase with hyphens).
3. Add the project to `registry/projects.yaml` and a row to `projects/index.md`. The status must match in all three places.

## Change a project's status
- Change `lifecycle` in `registry/projects.yaml`, the Status column in `projects/index.md` and the `Status:` line in `project.md`, in the same commit. Values: `active`, `paused`, `finished`, `archived`.

## Log a reminder
- File: `knowledge/lists/reminders.md`, `| Status | Date | Time | Reminder | Context | Source |`.
- If date or time is missing, mark it "to be clarified". Do not write to calendars or external services without approval.

## Save a tool or app
- File: `knowledge/lists/software.md`, `| Status | Name | Category | Use | Link | Note | Source |`.

## Learning something about {{OWNER_NAME}}
- Don't keep it in your memory. Propose it in `knowledge/inbox/` with `Status: proposed`. It only goes into `knowledge/profile.md` or `knowledge/areas/` with their approval.

<!-- kos:modules -->
