# Writing rules and sensitive data

Status: current.

## How to write
- For tasks, inbox, decisions and lists use the single write gate: `ruby tools/kos_write.rb --agente <your-name> <operation>` (see `--ayuda`). It writes one at a time even when other AIs are working, commits only your change under your name and validates first.
- If you edit by hand: never `git add -A` or `git commit -a` (you would sweep up another AI's half-done work). Commit only your paths. One change per commit, with a clear message. Never store secrets.
- If you work on a copy on another machine: `git pull` before writing. In a folder shared by several AIs, `tools/kos_sync.rb` does the pull and push.
- Long work on a project: announce it with `kos_write.rb tomar --proyecto <id>` and check `reclamos` before starting.
- New captures and ideas: `knowledge/inbox/YYYY-MM-DD-topic.md`.
- Lists: edit the file in `knowledge/lists/` respecting its columns. Do not overwrite {{OWNER_NAME}}'s notes, ratings or statuses. Do not delete rows.
- Do not replace a document silently: if something changes, keep the previous version as history.
- Use the templates in `templates/` for new files.
- When done, validate: `ruby tools/kos_validate.rb` (0 errors) and verify by rereading what you wrote.

## Keep KOS light (DEC-003)
Before leaving something in KOS, ask:
1. Will an AI or {{OWNER_NAME}} need it to decide or act soon? If not, it goes to Git history or `knowledge/archive/`.
2. Does it change a current decision or a project's status? If yes, it stays.
3. Does it repeat something already in another file? If yes, link instead of duplicating.
Decisions are never deleted: their status is updated (current, replaced, closed).

## Consistent status (DEC-002)
- A project has the same status in `registry/projects.yaml`, `projects/index.md` and its `project.md`. When changing it, touch all three in the same commit. The validator checks this.
- If `kos.yaml` enables `checks.github_prs`, a task citing a PR (`github.com/owner/repo/pull/N` or `owner/repo#N`) must be closed when the PR is merged.

## Sensitive data
- Finance, health and third-party data are **Confidential**: store them only if {{OWNER_NAME}} asks, and never full card, account or ID numbers or passwords.
- Keys and tokens never go in KOS. The validator looks for secret patterns and fails if it finds them.
- Mark each file's sensitivity: `Public`, `Internal` or `Confidential`.

## If you can't access something
Ask {{OWNER_NAME}} for the folder or file. Don't guess its contents.
