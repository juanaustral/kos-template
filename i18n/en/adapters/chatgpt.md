# Connect KOS to ChatGPT

ChatGPT can't see your disk. Use a Project (or a custom GPT):

1. Create a Project called "KOS".
2. In **Instructions**, paste the text from `adapters/paste-into-any-ai.md` (from the horizontal line down).
3. In **Files**, upload: `AGENTS.md`, `ONBOARDING/README.md`, `ONBOARDING/RECIPES.md`, `projects/index.md`, `knowledge/profile.md` and the folder of the project you'll use.
4. If your KOS is on GitHub, you can connect GitHub in ChatGPT so it reads the current repo.
5. ChatGPT doesn't write to your files: it gives you "To log in KOS" blocks that you paste yourself (or hand to an AI with file access).

## Important
In Settings → Personalization → Memory, keep ChatGPT from storing KOS data: KOS is the source, not its memory.
