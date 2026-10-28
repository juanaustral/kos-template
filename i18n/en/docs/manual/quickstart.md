# KOS in ten minutes

1. **Requirements**: Git and Ruby 3 installed ([how](01-installation.md)). Check with `git --version` and `ruby -v`.
2. **Copy the template** into a folder of your own, e.g. `~/kos`. If you received it on GitHub, use "Use this template" and create a **private** repository.
3. **Open a terminal in that folder** and run:
   ```
   ruby tools/kos_init.rb --lang en
   ```
   Answer: your name, language, form of address, style, areas, modules and AIs. At the end it must say `Errores: 0` (zero errors).
4. **Save**: `git add -A && git commit -m "KOS installed"`.
5. **Connect an AI** ([guide](03-connect-your-ais.md)). If you use Claude Code, Codex, Cursor or Gemini CLI, open them in the folder. If you use a chat, paste `adapters/paste-into-any-ai.md`.
6. **First test**: type *"Read AGENTS.md and summarize KOS in five lines."*
7. **First log**: *"Note this idea in KOS: …"* The AI must create a file in `knowledge/inbox/` and end with three lines (`Logged in KOS`, `Verified with`, `Pending`).

Done. From now on, everything you decide or learn with an AI stays in your files.
