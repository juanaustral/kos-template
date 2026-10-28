# Glossary

| Term | Meaning |
|---|---|
| **KOS** | Your knowledge system: memory in files any AI can read. |
| **AGENTS.md** | The single entry point. The first thing any AI reads. |
| **Source of truth** | The place that rules when in doubt. In KOS, your files. |
| **Logging rule** | Whatever is decided, created or learned is written into KOS as part of the same work (DEC-001). |
| **Wrap-up** | The three lines at the end of a piece of work: Logged in KOS, Verified with, Pending. |
| **Validator** | `tools/kos_validate.rb`: checks that nothing is broken. |
| **Recipe** | Exact instructions for a routine task (`ONBOARDING/RECIPES.md`). |
| **Inbox** | Where new, unreviewed material lands. |
| **Base** | What's reviewed and current. |
| **History** | What was replaced; not valid as current truth. |
| **Project** | A folder in `projects/` with brief, manifest and tasks. |
| **Manifest** | `manifest.yaml`: what an AI may read and write in that project and with what autonomy. |
| **Registry** | `registry/projects.yaml`: the master list of projects. |
| **Decision (DEC)** | A rule or choice recorded in `decisions/`. Never deleted; replaced. |
| **Module** | An optional add-on (lists, finance). |
| **Adapter** | The file that connects a specific AI to `AGENTS.md`. |
| **Autonomy A1/A2/A3** | How much the AI may do without asking you. |
| **Commit** | A change saved in Git, with date and description. |
