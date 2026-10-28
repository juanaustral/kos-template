# Connect KOS to Claude.ai (Projects)

Claude.ai can't see your disk. There are two ways to give it KOS:

## Option A — Project with files (no GitHub)
1. On claude.ai, create a Project called "KOS".
2. In **Project instructions**, paste the text from `adapters/paste-into-any-ai.md` (from the horizontal line down).
3. In **Project knowledge**, upload: `AGENTS.md`, `ONBOARDING/README.md`, `ONBOARDING/RECIPES.md`, `projects/index.md`, `knowledge/profile.md` and the folder of the project you'll work on.
4. When Claude gives you a "To log in KOS" block, paste it into the file it names (or ask an AI with file access, like Claude Code, to do it).
5. Every so often, re-upload the files that changed.

## Option B — GitHub connector
If your KOS is in a GitHub repo, connect GitHub on claude.ai and add the repo to the Project. Claude will read the current files; to write, it will still hand over "To log in KOS" blocks.

## Important
Turn off or ignore Claude.ai's memory for KOS topics: KOS is the source.
