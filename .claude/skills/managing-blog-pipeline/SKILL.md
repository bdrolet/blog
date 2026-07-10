---
name: managing-blog-pipeline
description: Use when working the blog backlog in this repo — capturing a blog idea, checking the backlog/board, moving a draft between stages, or publishing the next queued post on cadence. Triggers on "capture an idea", "add to the blog backlog", "show the blog board", "what should I publish next", "start drafting X", "mark X ready", "publish next".
---

# Managing the Blog Pipeline

The backlog lives in `pipeline/` (see `pipeline/README.md` for the why). Folders
are kanban columns: `ideas.md` (inbox) → `drafting/` → `ready/` → published posts
in `src/content/blog/`.

**`pipeline/` is gitignored — drafts are local-only.** So moves inside the
pipeline use plain `mv` (never `git mv`), and nothing in `pipeline/` is ever
`git add`ed. Only the finished post gets committed, once it reaches
`src/content/blog/` in `publish next`.

Pick the verb that matches the request.

## capture — add an idea (zero friction)

Append a single bullet to `pipeline/ideas.md`. Don't create a file, don't ask for
detail beyond a one-line angle. Confirm in one sentence.

## board — show the kanban + cadence status

Read all stages and print:

1. **Ideas** — count and the list from `pipeline/ideas.md`.
2. **Drafting** — each file in `pipeline/drafting/` with its `next:` action.
3. **Ready** — each file in `pipeline/ready/`, ordered by `ready_since` (FIFO =
   next to publish first).
4. **Cadence** — compute and report:
   - Last published = newest `pubDate` across `src/content/blog/*.md`.
   - Target = the `Cadence target: N days` line in `pipeline/README.md`.
   - If `today - last_published >= target`: say you're **due**, name the front of
     the ready queue, and offer to publish it. If the ready queue is empty, point
     at the closest `drafting/` piece instead.
   - If not due: say when the next drip is due.
   - **Buffer warning:** if `ready/` has 0–1 pieces, note the buffer is running
     low and suggest a capture/draft batch before the queue empties.

## start — graduate an idea into a draft

1. Propose a kebab-case `slug` from the idea.
2. Create `pipeline/drafting/<slug>.md` with this frontmatter:

   ```markdown
   ---
   title: "Working title"
   slug: <slug>
   created: <today YYYY-MM-DD>
   target: "the angle / who it's for"
   next: "the next concrete action to move this forward"
   tags: []
   ---
   ```
3. Remove that idea's line from `pipeline/ideas.md`.
   (No `git` — these files are gitignored; just edit and write.)

## ready — mark a draft finished and queued

1. `mv pipeline/drafting/<slug>.md pipeline/ready/<slug>.md`  (plain `mv`)
2. Add `ready_since: <today>` to its frontmatter (this drives the FIFO drip).

## publish next — the manual drip trigger

1. Choose the front of the ready queue (lowest `ready_since`) unless the user
   names another piece.
2. Check `src/content/blog/<slug>.md` does NOT already exist. If it does, stop and
   ask for a new slug.
3. `mv pipeline/ready/<slug>.md src/content/blog/<slug>.md`  (plain `mv` — the
   source is gitignored, the destination is tracked).
4. Transform the moved file's frontmatter to the published schema (follow the
   **adding-blog-entry** skill): keep `title` and `tags`; **author a real
   one-sentence `description`**; set `pubDate` to today; drop `slug`, `created`,
   `target`, `next`, `ready_since`. Confirm the `description` with the user if
   unsure.
5. Run `npm run build` to confirm the schema accepts it and it renders.
6. Commit (the deploy step requires a clean tree):

   ```bash
   git add src/content/blog/<slug>.md && git commit -m "Publish: <title>"
   ```
7. Hand off to the **deploying-blog** skill to build and ship.

## Notes

- Never move pipeline files into `src/content/blog/` except via `publish next` —
  half-formed frontmatter will fail the content schema and break the build.
- Batching is encouraged: capture several ideas at once, draft in one session,
  publish in another. The stages support it; nothing forces one piece end-to-end.
