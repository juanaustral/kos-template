# Knowledge — what {{OWNER_NAME}} knows

The system's rules are in `AGENTS.md` and `decisions/`. This folder is context for better decisions, not rules.

| Folder / File | Purpose |
|---|---|
| `profile.md` | {{OWNER_NAME}}'s profile: who they are, how they work, what they prefer. |
| `areas/` | Knowledge by domain (work, finance, health, learning...). Template: `templates/area.md`. |
| `inbox/` | Unsorted material (Inbox). Reviewed, then promoted or archived. |
| `lists/` | Lists with fixed columns: notes, reminders, tools and those of active modules. |
| `archive/` | History: replaced material worth keeping at hand. |

## For AI agents
1. Current decisions (`decisions/index.md`) take priority over any file in `knowledge/`.
2. If two sources contradict each other: {{OWNER_NAME}}'s current instruction → decisions → Base → Work → History.
3. Anything new you learn goes to `inbox/` with `Status: proposed`.
