# 12 — Shared skills

A skill is a recipe an AI follows for a task (a folder with a `SKILL.md`, open agentskills.io format). In KOS, skills live in `skills/` and all your AIs use them: Claude Code, Codex and any agent that reads files. One copy, in Git, with your backup.

## The idea
- **One source.** No per-tool copies drifting apart.
- **You approve.** AIs propose improvements; a person listed in `skills/config.yaml` approves them. If an approved skill changes without approval, the validator reports an error.
- **Even quality.** Each skill has test cases (`evals/casos.md`). Before approving, test them on the AIs you use and record the result.

## Commands
The tool's command names are in Spanish.

| To | Command |
|---|---|
| See what is there | `ruby tools/kos_skills.rb estado` |
| Start a skill or a change | `ruby tools/kos_skills.rb proponer <name>` |
| Submit the proposal | `ruby tools/kos_skills.rb entregar <name> --agente <who> --motivo "..."` |
| See what changes | `ruby tools/kos_skills.rb diff <name>` |
| Approve or reject | `ruby tools/kos_skills.rb aprobar <name> --por <person>` / `rechazar <name> --por <person> --motivo "..."` |
| Bring in someone else's skill | `ruby tools/kos_skills.rb importar <folder> --fuente <url>` |
| Link for Claude Code or Codex | `ruby tools/kos_skills.rb enlazar claude --destino .claude/skills` / `enlazar codex` |

You do not have to type them: ask your AI ("propose a skill for...", "approve the proposal for..."). The `skills-kos` skill teaches it the process.

## Approvers
The setup assistant puts your name in `skills/config.yaml` (key `aprobadores`). If two or more people share the KOS, add each one: any of them can approve.

## Someone else's skills
`importar` recognizes that a skill is someone else's (it does not say `origen: propia`, or it has a license or author), shows you author, license, scripts and risks, and asks:

> This skill is someone else's. Do you want to import it as is, or adapt it to our system to avoid errors and problems?

- **As is** (`--modo tal-cual`): exact copy, marked `origen: tercero`.
- **Adapted** (`--modo adaptar`, recommended): a draft in KOS format, marked `origen: adaptada`. The original is kept aside for reference only.

No license, no import: the skill belongs to its author. Skills from public registries can carry hidden instructions or harmful scripts; that is why they are read before approval.

## How each AI uses them
- **Claude Code**: links in this KOS's `.claude/skills/`. The setup assistant creates them if you chose Claude Code.
- **Codex**: `enlazar codex` creates links in `~/.agents/skills/`.
- **Others**: read `skills/` directly; `AGENTS.md` tells them where it is.
