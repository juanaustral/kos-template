# 03 — Connect your AIs

Every AI reads the same entry point: `AGENTS.md`. There are two families:

- **AIs with file access** (Claude Code, Codex, Cursor, Gemini CLI and other agents): read and write KOS directly. The best experience.
- **Chat AIs** (Claude.ai, ChatGPT, Gemini web): read what you upload and give you "To log in KOS" blocks that you paste yourself or hand to an AI with file access.

## Claude Code
1. If you chose `claude-code` in the wizard, you already have `CLAUDE.md` and `.claude/skills/kos/`. If not, copy `adapters/claude-code/CLAUDE.md` to the root and `adapters/claude-code/skills/kos/` to `.claude/skills/kos/`.
2. Open a terminal in the folder and run `claude`.
3. To have Claude Code use KOS **from any folder**, add to your `~/.claude/CLAUDE.md`:
   ```
   My memory and source of truth is KOS, at <path to your KOS>. Before working, read its AGENTS.md and follow its rules. Whatever is decided or learned gets logged there.
   ```

## Codex (OpenAI)
Reads `AGENTS.md` at the root automatically. Open Codex in the KOS folder and you're set. To use it from other repositories, add the same line to your `~/.codex/AGENTS.md`.

## Cursor
With `cursor` in the wizard you get `.cursor/rules/kos.mdc`. Open the KOS folder in Cursor and use the agent chat.

## Gemini CLI
With `gemini` in the wizard you get `GEMINI.md`. Run `gemini` in the folder.

## Claude.ai and ChatGPT
Follow `adapters/claude-ai.md` or `adapters/chatgpt.md`. In short: create a Project, paste `adapters/paste-into-any-ai.md` into its instructions and upload the key files. If your KOS is on GitHub, connect GitHub so it always reads the current version.

## Any other AI
Paste the text from `adapters/paste-into-any-ai.md` as the first message.

## Turn off the AI's own memory (for these topics)
KOS works because there is **one source**. If the AI keeps its own version of you, contradictions appear. In ChatGPT and Claude.ai you can turn off or review memory in settings.

## Cold-start test
Do it with every new AI, in a conversation with no prior context:
1. *"Read AGENTS.md and summarize KOS in five lines."* It should mention: source of truth, logging rule, Wrap-up, what needs your approval.
2. *"Note in KOS the idea: try KOS with another AI."* It should create `knowledge/inbox/YYYY-MM-DD-….md` with `Status: proposed`.
3. *"Add a task to my-first-project: review my profile."* It should edit `tasks.md` following the recipe, run the validator and end with the three lines.
If an AI fails, see [Troubleshooting](10-troubleshooting.md).

Next: [Daily use](04-daily-use.md).
