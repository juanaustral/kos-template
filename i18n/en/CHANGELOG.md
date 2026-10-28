# Changelog

## 1.4.4 — 2026-10-28
- Bilingual README (Spanish and English): how it works, prerequisites, instructions for an AI to install and use KOS, connection per AI and tool, authorship and license.
- Three images in `docs/img/` (cover, flow and zones).

## 1.4.3 — 2026-10-28
- CHANGELOG without personal names (the licensor appears only in `LICENSE.md`).

## 1.4.2 — 2026-10-28
- License now names its licensors (`Required Notice` line in `LICENSE.md`).
- `kos_privacy_check.rb`: list lines starting with `!` are allowed exact phrases.

## 1.4.1 — 2026-10-28
- License: PolyForm Shield 1.0.0. You may use KOS for anything (personal, work, clients) and change it; you may not sell it or offer it as your own product, even for free. `LICENSE.md` has a summary and the official text.
- `kos_write.rb` can edit `.gitignore`; its test ignores `KOS_AGENTE` from the shell; `kos_doctor.rb` hides Git warnings about unreadable folders.

## 1.4.0 — 2026-10-28
- New: several AIs at once without overwriting each other. `tools/kos_write.rb` is the single write gate (lock, commits only its own change with the AI as author, validates first, clash-free decision numbers, work claims and Wrap-up). Manual: `docs/manual/11-several-ais.md`.
- New: `tools/kos_sync.rb` (the only pull/push with GitHub, for cron) and `tools/kos_doctor.rb` (stuck locks, forgotten changes, sync, decision index, validator; `--arreglar`).
- Backups include the full Git history (`kos-historial.bundle`) and verification checks it.
- The validator also detects AWS, Slack and Google keys.
- AI-guided installation for people who don't use the terminal (quickstart).

## 1.3.0 — 2026-10-28
- New: `ruby tools/kos_update.rb --from <zip or folder>` updates KOS to a new version. It replaces only the engine (rules, tools, manual, templates, modules, adapters), never your data. `--dry-run` shows the plan without touching anything.
- Engine files you edited are respected: the new version is saved next to them as `.kos-new` and the validator warns.
- Data migrations by `schema_version` (`tools/migraciones/`).
- `.kos/lock.yaml` records the installed version and a fingerprint of each engine file. New `VERSION` file.

## 1.2.0 — 2026-10-28
- Fix: a name or style with quotes or backslashes no longer breaks `kos.yaml` or the manifests.
- Fix: the wizard changes no files until all questions are answered; an error or Ctrl-C leaves nothing half-done.
- Fix: the list-rows check also works on GitHub (compares with the state before the push). To delete on purpose: `[allow-row-drop]` in the commit message.
- New: the validator runs before every commit (a `pre-commit` hook installed by the wizard).
- New: `ruby tools/kos_init.rb --refill` fills your details into a new version's files and restores module recipes.
- Tests for the four cases.

## 1.1.0 — 2026-10-28
- Full English version: `ruby tools/kos_init.rb --lang en`.

## 1.0.0 — 2026-10-27
- First release: the KOS method (AI entry point, rules, zones, recipes, mandatory logging and the Wrap-up).
- Setup wizard `tools/kos_init.rb`.
- Validator with optional modules, verifiable backup and privacy check.
- Adapters for Claude Code, Claude.ai, ChatGPT, Codex, Cursor and Gemini.
- Optional modules: lists and finance.
- Complete user manual.
