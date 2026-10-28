# 07 — Maintenance

## The validator
```
ruby tools/kos_validate.rb
```
Checks: critical files, valid YAML, registered projects with briefs, consistent statuses, broken links, secret patterns, lost list rows, finance data and unfilled placeholders. It must report **0 errors** (`Errores: 0`). AIs run it after every change; if you use GitHub, it also runs on every push and once a day.

## Backups
Git is already a history, but a separate backup protects against deletions and serious mistakes.
```
ruby tools/kos_backup.rb                     # creates backups/kos-<date>.tar.gz and its SHA256
ruby tools/kos_backup.rb --verify backups/kos-<date>.tar.gz   # proves it restores correctly
```
- Keep the copy off your computer (external drive, encrypted cloud).
- **Test the restore once a quarter.** A backup that was never tested isn't a backup.
- If you use a private GitHub repo, you already have a second copy; the local backup covers losing access.

## Keep it light (DEC-003)
Every extra file costs every AI reading time. Once a month, ask:
> "Review the inbox and the areas. Suggest what to promote, what to archive and which duplicates to link."

Rule of thumb: if it doesn't help decide or act soon, it goes to the archive or Git history; if it repeats another file, link it.

## Suggested weekly review (15 minutes)
1. *"Which projects are active and what's each one's next action?"*
2. *"Any tasks in progress for more than two weeks?"*
3. *"Review the inbox."*
4. Commit and push.

## Updating KOS
When you receive a new version (ZIP or folder):

1. Save your state: `git add -A && git commit -m "before update"`.
2. See what would change, touching nothing: `ruby tools/kos_update.rb --from ~/Downloads/kos-vX.Y.Z.zip --dry-run`.
3. Update: the same command without `--dry-run`.

What it does: it replaces only the **engine** (rules, tools, manual, templates, modules and adapters) and fills it in with your name, form of address, modules and AIs from `kos.yaml`. **It never touches your data**: `knowledge/`, `projects/`, `decisions/`, `registry/` or your values in `kos.yaml`. If a new version changes the shape of your data, it ships a migration that runs on its own.

If you edited an engine file by hand (for example `AGENTS.md`), yours stays and the new version is saved next to it as `AGENTS.md.kos-new`. Compare them, keep what you want and delete the `.kos-new` (the validator warns you while it exists).

Finally: review with `git diff` and save with `git add -A && git commit -m "KOS X.Y.Z"`. To undo: `git reset --hard && git clean -fd`.

If your KOS predates 1.3.0, the first time add `--overwrite` and use the new version's updater: `ruby <new-folder>/tools/kos_update.rb --from <new-folder> --root . --overwrite`.

Next: [Privacy and security](08-privacy-and-security.md).
