# Changelog

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
