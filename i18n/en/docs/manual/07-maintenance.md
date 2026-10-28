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

## Updating the template
When you receive a new KOS version, read its `CHANGELOG.md`. Improvements usually live in `ONBOARDING/`, `tools/` and `docs/`: copy those over yours (never `knowledge/`, `projects/` or `decisions/`, which are your data) and run the validator.

Next: [Privacy and security](08-privacy-and-security.md).
