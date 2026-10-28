# 06 — Recipes

Recipes are exact instructions so any AI does routine tasks the same way every time. They live in `ONBOARDING/RECIPES.md`. You just ask in plain language:

| You want | Ask something like | What the AI does |
|---|---|---|
| Note an idea | "Note in KOS: …" | Creates a file in `knowledge/inbox/`. |
| See what's next | "What's next on X?" | Reads `tasks.md` and gives you the next action. |
| Add a task | "Add to X the task …" | New line under To do, dated. |
| Close a task | "I finished …" | Marks it done and moves it to Done. |
| Log a decision | "Log it as a decision" | `decisions/DEC-NNN-….md` + index. |
| Create a project | "Create the project …" | Folder, brief, manifest, tasks, registry and index. |
| Change a status | "Pause / archive X" | Changes the status in all three places. |
| A reminder | "Remind me on May 3rd …" | Row in `knowledge/lists/reminders.md` (doesn't touch your calendar without permission). |
| Save a tool | "Save this app: …" | Row in `knowledge/lists/software.md`. |
| Movie, series or book (lists module) | "Add the movie …" | Row in the list, no duplicates. |
| An expense (finance module) | "I spent 25 on groceries today" | Row in `projects/finance/data/expenses.csv`. |
| A balance (finance module) | "How much did I spend in March?" | Sums by month and category, stating the period. |

## Rules every recipe follows
- Read the file, make the smallest change, reread, validate and commit.
- Don't invent data: unknown fields stay empty or the AI asks.
- Never delete rows or overwrite your notes or ratings.

To create your own recipes: [Customize](09-customize.md).

Next: [Maintenance](07-maintenance.md).
