# Adapters: how to connect each AI to KOS

Every AI reads the same entry point: `AGENTS.md`. An adapter is just the bridge so each tool finds it.

| AI | What to do | File |
|---|---|---|
| Claude Code | The wizard copies `CLAUDE.md` and the skill to the root | `claude-code/` |
| Codex (OpenAI) | Reads `AGENTS.md` on its own; nothing needed | — |
| Cursor | The wizard copies the rule to `.cursor/rules/` | `cursor/kos.mdc` |
| Gemini CLI | The wizard copies `GEMINI.md` to the root | `gemini/GEMINI.md` |
| Claude.ai (Projects) | Paste instructions and upload files | `claude-ai.md` |
| ChatGPT (Projects or GPT) | Paste instructions and upload files | `chatgpt.md` |
| Any other | Paste the text as the first message | `paste-into-any-ai.md` |

Step-by-step guide: `docs/manual/03-connect-your-ais.md`.
