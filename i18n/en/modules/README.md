# Optional modules

A module adds lists, recipes and checks for a specific use. Enable them with the wizard (`ruby tools/kos_init.rb --lang en`) or later with `ruby tools/kos_init.rb --only-module <name>`.

| Module | What it adds |
|---|---|
| `lists` | Movies, series and books in `knowledge/lists/`, with recipes so an AI adds them without duplicates or overwriting ratings. |
| `finance` | A `projects/finance/` project with expenses in CSV, categories and format checks. |

Creating your own module: see `docs/manual/09-customize.md`.
