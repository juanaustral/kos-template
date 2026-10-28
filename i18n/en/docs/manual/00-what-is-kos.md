# 00 — What is KOS

## The problem
You use several AIs. Each one remembers a different piece of you, its own way, on servers you don't control. When you switch tools, accounts or models, you start from scratch. What you decided a month ago in a chat no longer exists anywhere.

## The idea
KOS flips the relationship: **the memory is yours and lives in your files**. AIs are temporary workers who come in, read the rules, do the work and leave a record of what changed.

- **Plain files**: Markdown, YAML and CSV. Readable with any editor, today and twenty years from now.
- **Git**: every change is dated and attributed, can be undone and is easy to back up.
- **One entry point**: `AGENTS.md`. Any AI reads it first and knows what to do.
- **Shared rules**: where each thing goes, what needs your approval, how to wrap up a piece of work.

## What you gain
- **Switch AIs without losing anything.** Claude today, another tomorrow: they all read the same files.
- **Continuity.** A project picks up where it left off, even after a month or a different AI.
- **Control.** You see everything an AI wrote, and nothing sensitive leaves without your say-so.
- **Less repetition.** You never explain again who you are or how you like to work.

## The three pieces that make it work
1. **The logging rule (DEC-001).** Whatever is decided, created or learned is written into KOS as part of the same work. If it was only said in the chat, it doesn't exist.
2. **The Wrap-up.** Every piece of work ends with three lines: what was logged, how it was verified and what's pending. Read three lines and you know whether the work was done right.
3. **The validator.** A program checks that nothing broke: consistent statuses, links, secrets, deleted rows. The AI runs it and, if you use GitHub, it also runs on its own.

## What it is not
- Not an app or a service: no account, server or subscription.
- Not an AI: it works with the ones you already use.
- Not a complex task manager: it's an ordered memory any AI understands.

Next: [Installation](01-installation.md).
