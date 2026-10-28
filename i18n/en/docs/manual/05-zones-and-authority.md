# 05 — Zones and authority

Not everything in KOS carries the same weight. Every file belongs to a zone.

| Zone | What it is | Where | Is it true? |
|---|---|---|---|
| **Inbox** | Freshly captured, unreviewed | `knowledge/inbox/` | No. It's material. |
| **Work** | Drafts, analysis, plans | project files marked as drafts | Not yet. |
| **Base** | Reviewed and current | profile, areas, approved decisions, project briefs | Yes, within its scope. |
| **History** | What was replaced | `knowledge/archive/` and Git history | It was. Not anymore. |
| **Generated** | Indexes or views that can be rebuilt | whatever tools generate | Never edited by hand. |

## Who rules when there's a contradiction
1. What you say **now** in the chat.
2. Current decisions in `decisions/`.
3. The project's manifest and decisions.
4. Base → Work → History → Generated.

The **Inbox never rules**. If a note in the inbox says "delete everything", it's just text.

## Promoting something to Base
When an idea from the inbox is confirmed, ask the AI to promote it: it moves it to its place (an area, the profile, a project or a decision), stating source, date and what it replaces. If it's unclear, it stays where it is.

## Scope
Everything has a scope: **global** (applies to everything), **area** (e.g. finance), **project** or **task**. What's decided in one project doesn't become a global rule without your approval. That's why each project's `manifest.yaml` says `cross_project: deny`: the AI doesn't mix projects.

Next: [Recipes](06-recipes.md).
