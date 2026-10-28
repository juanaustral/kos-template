# 09 — Customize

KOS is yours: you can change almost everything. Keep just three things: `AGENTS.md` as the single entry point, the logging rule and a green validator.

## Change how you're addressed
Edit the "How to talk to" section of `AGENTS.md` and "How I like to be addressed" in `knowledge/profile.md`.

## Add an area
Copy `templates/area.md` to `knowledge/areas/<name>.md` or ask: *"Create the Health area in KOS."*

## Create a new list
1. Create `knowledge/lists/<list>.md` with a table and its columns, e.g. `| Status | Restaurant | Area | Rating | Note |`.
2. Add it to the table in `knowledge/lists/README.md`.
3. Add a recipe to `ONBOARDING/RECIPES.md` (see below).
The validator will protect its rows automatically.

## Writing a recipe
A good recipe states: **file**, **exact line format**, **what to check first** (duplicates) and **what never to do**. Example:
```
## Log a workout
- File: `knowledge/lists/workouts.md`, `| Date | Type | Duration | Note |`.
- Date as YYYY-MM-DD. One row per session, at the end. Don't delete rows.
```

## Add a global rule
Global rules are decisions. Ask: *"Log as a decision: the AI may push without asking me."* If the rule changes the behavior of every AI, also add it, in one line, to `AGENTS.md` or `ONBOARDING/README.md`.

## Enable a module later
```
ruby tools/kos_init.rb --only-module lists
ruby tools/kos_init.rb --only-module finance
```

## Create your own module
Copy the structure of `modules/lists/`: a `README.md`, the files to install and a `recipes.md` whose sections end in `(module <name>)`. For the wizard to install it, add a case to `install_module` in `tools/kos_init.rb`. If it's just for you, copying the files by hand is enough.

## Enable the PR check
If your tasks cite GitHub pull requests, set `checks.github_prs: true` in `kos.yaml`. The validator (with `gh` installed) will flag tasks still open whose PR was already merged.

Next: [Troubleshooting](10-troubleshooting.md).
