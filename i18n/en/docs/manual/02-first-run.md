# 02 — First run

## 1. Run the wizard
In the KOS folder:
```
ruby tools/kos_init.rb --lang en
```
It asks:

| Question | Example | What it's for |
|---|---|---|
| What AIs should call you | Ana | AIs address you by name and know whose KOS it is. |
| Language | English | The language they answer in. |
| Form of address | informal / formal | How they talk to you. |
| Style | direct and brief, no emojis | The tone of answers. |
| Areas | Work, Health, Finance | Creates one file per area in `knowledge/areas/`. |
| Modules | lists, finance | Adds lists (movies, series, books) or an expense log. |
| AIs | claude-code, cursor | Prepares the files each AI looks for. |

At the end it runs the validator. It must report **0 errors** (`Errores: 0`).

Rather not answer questions? Use options:
```
ruby tools/kos_init.rb --lang en --si --nombre "Ana" --areas "Work,Health" --modulos lists --ias claude-code
```

## 2. Save the state
```
git add -A
git commit -m "KOS installed"
```
(If Git asks for your name and email: `git config --global user.name "Your Name"` and `git config --global user.email "you@example.com"`.)

## 3. Fill in your profile (with help)
Open `knowledge/profile.md`. Fill it in by hand or, better, ask your AI:
> "Interview me briefly, one question at a time, to fill in `knowledge/profile.md`. Show me the text at the end and write it once I approve."

## 4. Add your real projects
Ask your AI, one at a time:
> "Create the project 'Launch my newsletter' in KOS: goal …, status active, next action …"

The AI creates the folder, registers it and adds it to the index ("Create a project" recipe). The example `my-first-project` is for your first test; rename or archive it afterwards.

## 5. What's now in your folder
- `AGENTS.md` with your name and how you like to be addressed.
- `knowledge/profile.md` and your areas, ready to fill in.
- Three base decisions in `decisions/` (mandatory logging, consistent status, keep KOS light).
- The files for the AIs you chose (`CLAUDE.md`, `.cursor/rules/`, `GEMINI.md`).
- `kos.yaml` with your configuration.

Next: [Connect your AIs](03-connect-your-ais.md).
