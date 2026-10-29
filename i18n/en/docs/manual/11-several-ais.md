# 11 — Several AIs at once

If you use more than one AI on the same KOS (for example Claude Code and Codex, or an agent running on its own on a server), they can write at the same time. Without care, one overwrites the other: lines get lost or a commit sweeps up another AI's half-done work.

## The single write gate
AIs write with `tools/kos_write.rb`. Each write goes one at a time (a lock), is validated first and is committed on its own, with the AI's name as author.

| To | Command |
|---|---|
| Add a task | `ruby tools/kos_write.rb --agente claude tarea agregar --proyecto <id> --texto "..."` |
| Close a task | `... tarea cerrar --proyecto <id> --buscar "part of the title"` |
| Capture an idea | `... inbox --titulo "Topic" --texto "..."` |
| Propose a decision | `... decision --titulo "..." --proyecto <id> --texto "..."` (the number is assigned without clashes) |
| Add a row to a list | `... lista --lista movies.md --fila "\| ... \|"` |
| Announce work on a project | `... tomar --proyecto <id> --minutos 60` and `reclamos` to see who is on what |
| Build the Wrap-up | `... cierre --desde "3 hours ago"` |

The AI rules already say so (`ONBOARDING/WRITING-RULES.md`): you don't have to ask every time. Section names are matched to your language (`--seccion "Por hacer"` writes under `## To do`).

## Sync and check on its own
- `ruby tools/kos_sync.rb`: the only one that pulls and pushes to GitHub. On a server, schedule it every 5 minutes (cron). If your copy and GitHub diverge, it touches nothing and warns.
- `ruby tools/kos_doctor.rb`: checks stuck Git locks, forgotten uncommitted changes, sync status, the decision index and the validator. `--arreglar` fixes the safe things; `--silencioso` only speaks up when something is wrong.

## If the AIs run as different users (server)
Put the folder in a shared group: `chgrp -R <group> kos && chmod -R g+w kos && find kos -type d -exec chmod g+s {} +` and `git -C kos config core.sharedRepository group`. `kos_doctor.rb` detects it and warns when a file loses group permission.

So that critical things (rules, tools, history) don't change without your approval, see [Protection](13-protection.md).

Next: [Glossary](glossary.md).
