# KOS — your memory, any AI

KOS is a system that keeps **your knowledge in your own files instead of inside an AI's memory**. Projects, tasks, decisions, ideas and lists live in plain-text folders (Markdown) under Git. Any AI (Claude, ChatGPT, Codex, Cursor, Gemini) reads the same entry point, follows the same rules and logs what it does. Switch AIs whenever you want and lose nothing.

## Five-step setup
1. Install **Git** and **Ruby 3** (see `docs/manual/01-installation.md`).
2. Copy this template into a folder of your own (or use "Use this template" on GitHub).
3. In that folder run `ruby tools/kos_init.rb --lang en` and answer the questions.
4. Save: `git add -A && git commit -m "KOS installed"`.
5. Connect your first AI (`docs/manual/03-connect-your-ais.md`) and ask: *"Read AGENTS.md and summarize KOS in five lines."*

One-page version: [`docs/manual/quickstart.md`](docs/manual/quickstart.md).

## What lives where
| Folder | What it holds |
|---|---|
| `AGENTS.md` | The single entry point for any AI. |
| `ONBOARDING/` | Rules, recipes and workflow for AIs. |
| `projects/` | One folder per project: brief, manifest and tasks. |
| `decisions/` | Current and past decisions. |
| `knowledge/` | Your profile, areas, unsorted ideas (inbox) and lists. |
| `registry/` | Master list of projects and the critical zones (`zonas.yaml`). |
| `templates/` | Starting points for new files. |
| `adapters/` | How to connect each AI. |
| `modules/` | Optional modules (lists, finance). |
| `skills/` | Skills shared by all your AIs, approved by you ([manual](docs/manual/12-shared-skills.md)). |
| `tools/`, `tests/` | Setup wizard, validator, backup, privacy check, and protection (email approval, protection level). |
| `docs/manual/` | The manual, for you. |

## Protection
Ordinary things (tasks, ideas, lists) flow freely and are reversible. **Critical** things (the rules, the tools, Git history, mass deletions) only change with your approval: you get an email with the exact change and a code, and you confirm it with your PIN. Check your real level with `ruby tools/kos_proteccion.rb nivel` ([manual](docs/manual/13-protection.md)). On a personal computer the ceiling is level 2; a real lock needs a Linux server and the AI running as an unprivileged user.

## Manual
Start with [`docs/manual/00-what-is-kos.md`](docs/manual/00-what-is-kos.md). Full index in [`docs/manual/README.md`](docs/manual/README.md).

License: PolyForm Shield 1.0.0 (use it for anything; do not sell or redistribute it) — [`LICENSE.md`](LICENSE.md). Changes: [`CHANGELOG.md`](CHANGELOG.md).
