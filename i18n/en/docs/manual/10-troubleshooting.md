# 10 — Troubleshooting

Validator and wizard messages are in Spanish; the codes in brackets are the same in any language.

| Problem | Fix |
|---|---|
| `ruby: command not found` | Install Ruby 3 ([Installation](01-installation.md)) and open a new terminal. |
| The wizard says KOS is already installed ("ya está instalado") | You already ran it. For a module: `--only-module <name>`. To redo everything: `--forzar`. |
| `ERROR [estado-incongruente]` or `[index-incongruente]` | A project has different statuses in registry, index and brief. Ask: *"Fix project X's status in all three places."* |
| `ERROR [project-unregistered]` | There's a folder in `projects/` that isn't in `registry/projects.yaml`. Register or move it. |
| `ERROR [link-broken]` | A link points to a file that doesn't exist. Fix the path or remove the link. |
| `ERROR [list-rows-dropped]` | Rows were deleted from a list. If by mistake: `git checkout -- knowledge/lists/<file>`. If on purpose: `KOS_ALLOW_ROW_DROP=1 git commit ...` and put `[allow-row-drop]` in the commit message (so GitHub won't fail either). |
| A commit is stopped by validator errors | Since setup, the validator runs before every commit. Fix what it reports. Only in an emergency: `git commit --no-verify`. |
| `placeholder-pendiente` appears after an update | Run `ruby tools/kos_init.rb --refill`. |
| `ERROR [possible-secret-…]` | Something looks like a key. Remove it from the file and, if it reached Git, rotate that key in its service. |
| `ERROR [placeholder-pendiente]` | A `{{…}}` was left unfilled. Replace it by hand. |
| The AI doesn't follow the rules | Ask it to reread `AGENTS.md`. If it's a chat, check that the text from `adapters/paste-into-any-ai.md` is in the instructions. |
| The AI "remembers" old things that aren't in KOS | That's its own memory. Turn it off for these topics or say: *"Use only KOS as the source."* |
| The AI gave no Wrap-up | *"Give me the Wrap-up."* |
| Two KOS copies with different changes | `git pull` on the one that's behind. If there's a conflict, ask an AI to resolve it showing you both versions. |
| I want to undo the AI's last change | `git log` to find the commit and `git revert <commit>`. |
