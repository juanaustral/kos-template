# 04 — Daily use

You talk to your AI as usual. The difference: you ask it to **log**, and you check the **Wrap-up**.

## Capture an idea
> "Note in KOS: I want to try a short photography course."

It lands in `knowledge/inbox/` as a proposal. It doesn't become a project until you say so.

## Work with tasks
> "What's next on the newsletter project?"
> "Add the task: design the email template."
> "Mark the template task as done."

Each project has a `tasks.md` with five sections: In progress, To do, Backlog, Blocked, Done. **Next** is the first task under In progress (or under To do if In progress is empty).

## Log a decision
> "We decided to publish the newsletter on Tuesdays. Log it as a decision."

It creates `decisions/DEC-NNN-….md` and a row in the index. Decisions are never deleted: if you change your mind, the new one **replaces** the old, which stays marked.

## Create, pause or close a project
> "Create the project 'Moving house' with goal … and next action …"
> "Pause the Moving house project."
> "Archive my-first-project."

The AI changes the status in all three places at once (registry, index and brief). If they drift apart, the validator flags it.

## Resume something after weeks
> "Let's pick up Moving house. Where were we?"

The AI reads `project.md` and `tasks.md` and tells you the status and next action, without depending on old conversations.

## Reading the Wrap-up
Every piece of work that changed something ends like this:
```
Logged in KOS: projects/moving-house/tasks.md
Verified with: validator: 0 errors
Pending:       get moving quotes. Next action: request three quotes.
```
- If it says **"nothing to log"** but something was decided, ask it to log it.
- If it says **"not verified"**, ask why.
- If there's no Wrap-up, ask for it: *"Give me the Wrap-up."*

## When the AI can't write
Chat AIs give you a **"To log in KOS"** block with the file and text. Paste it yourself or hand it to an AI with file access: *"Log this block in KOS."*

## Helpful habits
- End each session with *"Is everything logged?"*.
- Once a week: *"Review the inbox and suggest what to promote or archive."*
- Commit often (or ask the AI to).

Next: [Zones and authority](05-zones-and-authority.md).
