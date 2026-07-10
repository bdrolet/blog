# Blog Pipeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an in-repo blog backlog that captures ideas, moves them through phases, and publishes on a sustainable cadence — driven by a new `managing-blog-pipeline` skill.

**Architecture:** A `pipeline/` directory at the repo root (outside the Astro content glob) holds an `ideas.md` inbox and `drafting/` + `ready/` stage folders. Folders are kanban columns; moving a piece is a `git mv`. A new skill documents the workflow and, when invoked, performs the file operations, renders the board, computes the cadence nudge, and hands off to `deploying-blog` at the publish boundary. No runtime code, no second app, no new infrastructure.

**Tech Stack:** Plain Markdown, git, Astro 6 content collections (existing), Claude Code skills.

## Global Constraints

- `pipeline/` MUST live outside `src/content/blog/` — the content glob base is `./src/content/blog` (`src/content.config.ts`), so pipeline files must never match it, hit the schema, or appear in `dist/`.
- Published posts MUST satisfy the existing schema: required `title`, `description`, `pubDate`; optional `updatedDate`, `tags`. Follow the `adding-blog-entry` skill for the published-post format and kebab-case slug naming.
- The `deploying-blog` skill refuses a dirty working tree. Therefore `publish next` MUST commit the moved post before handing off to deploy.
- Cadence default is **14 days**, stored as a single editable line in `pipeline/README.md`.
- Stages are exactly four: Ideas → Drafting → Ready → Published. No editing column.
- Repo visibility note: `origin` is `github.com:bdrolet/blog.git`. If that repo is public, `pipeline/` drafts become publicly visible. Confirm with the user before first push (see Handoff).

---

### Task 1: Scaffold the `pipeline/` directory and docs

**Files:**
- Create: `pipeline/README.md`
- Create: `pipeline/ideas.md`
- Create: `pipeline/drafting/.gitkeep`
- Create: `pipeline/ready/.gitkeep`

**Interfaces:**
- Produces: the directory layout and the cadence config line (`Cadence target: 14 days`) that Task 2's skill reads via grep; the `ideas.md` inbox that `capture`/`start` mutate.

- [ ] **Step 1: Create `pipeline/README.md`** with this exact content:

```markdown
# The Blog Pipeline

A backlog for capturing ideas, iterating on them, and publishing on a steady
drip — all in this repo as plain Markdown in git. Driven by the
`managing-blog-pipeline` Claude Code skill.

## Config

Cadence target: 14 days

(Change that number to change the publish rhythm. It is the one knob.)

## How it works

Folders are the kanban columns. Moving a piece forward is a `git mv`.

- `ideas.md` — the idea inbox. Just a bulleted list; capturing costs one sentence.
- `drafting/` — one file per piece you're actively writing.
- `ready/` — finished drafts, queued to publish (the buffer).
- Published posts live in `src/content/blog/` (outside this folder).

Ask the skill to `capture` an idea, show the `board`, `start` an idea into a
draft, mark a draft `ready`, or `publish next`.

## Why it's shaped this way

**It resolves the pull/push tension.** Writing is pull-driven and bursty;
publishing wants to be steady. A backlog decouples them: capture and draft when
you're *pulled*, and let publishing draw from the buffer on a drip. **The
schedule governs the publish step, never the writing step.**

**Zero-friction capture.** Without a parking spot, every idea pressures you to
act now, and that pressure makes you freeze or drop it. Ideas are one-line
entries so capture never costs anything.

**A buffer of drafts ahead** decouples writing days from publishing days (a dry
week doesn't break the streak) and acts as a momentum flywheel — a pile of
half-finished pieces pulls you back in.

**Batching.** Capturing (critic off), drafting (critic off), and editing (critic
on) use different mental gears. Doing all three on one piece flips the inner
critic on and off constantly; that switching is the tax. Work in modes across
several pieces instead — the stage folders are the batch queues. Spend scarce
burst-energy on generation; defer the cheap mechanical steps.

**Sustainable, not aggressive cadence.** Publishing faster than you generate
drains the buffer and puts you back to scrambling; sprinting also thins the work,
which is counterproductive for a lighthouse strategy built on compounding,
permanent pieces. A rhythm you always hit is self-reinforcing; a missed one reads
as failure. Every-2-weeks held for a year beats weekly-then-burnout.

**No second app.** If you spend more time maintaining the system than writing,
you've optimized for the wrong thing. The folders are the board, the files are
the drafts, the skill renders the view only when asked.
```

- [ ] **Step 2: Create `pipeline/ideas.md`** with this exact content:

```markdown
# Idea Inbox

One line per idea — lowest possible friction. Add a dash of context if it helps
future-you remember the angle. When you commit to one, ask the skill to `start`
it and it graduates into a file in `drafting/`.

- (example) The one k8s footgun nobody warns you about — delete this line
```

- [ ] **Step 3: Create the stage-folder keepers**

```bash
mkdir -p pipeline/drafting pipeline/ready
printf '' > pipeline/drafting/.gitkeep
printf '' > pipeline/ready/.gitkeep
```

- [ ] **Step 4: Verify the build stays clean and nothing leaks**

Run:
```bash
npm run build && find dist -path '*pipeline*' -print
```
Expected: build succeeds; the `find` prints **nothing** (no pipeline files in `dist/`).

- [ ] **Step 5: Commit**

```bash
git add pipeline/
git commit -m "Add blog pipeline scaffolding (inbox, stage folders, README)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: Author the `managing-blog-pipeline` skill

**Files:**
- Create: `.claude/skills/managing-blog-pipeline/SKILL.md`

**Interfaces:**
- Consumes: `pipeline/ideas.md`, `pipeline/drafting/`, `pipeline/ready/` (Task 1); the cadence line `Cadence target: 14 days` in `pipeline/README.md`; the `adding-blog-entry` and `deploying-blog` skills.
- Produces: the documented verbs `capture`, `board`, `start`, `ready`, `publish next` and the pipeline-piece frontmatter shape used by Task 3.

- [ ] **Step 1: Create `.claude/skills/managing-blog-pipeline/SKILL.md`** with this exact content:

````markdown
---
name: managing-blog-pipeline
description: Use when working the blog backlog in this repo — capturing a blog idea, checking the backlog/board, moving a draft between stages, or publishing the next queued post on cadence. Triggers on "capture an idea", "add to the blog backlog", "show the blog board", "what should I publish next", "start drafting X", "mark X ready", "publish next".
---

# Managing the Blog Pipeline

The backlog lives in `pipeline/` (see `pipeline/README.md` for the why). Folders
are kanban columns: `ideas.md` (inbox) → `drafting/` → `ready/` → published posts
in `src/content/blog/`. Moving a piece forward is a `git mv`. Everything is plain
Markdown in git.

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
4. Use `git add -A pipeline/` so the removal and new file are staged together.

## ready — mark a draft finished and queued

1. `git mv pipeline/drafting/<slug>.md pipeline/ready/<slug>.md`
2. Add `ready_since: <today>` to its frontmatter (this drives the FIFO drip).

## publish next — the manual drip trigger

1. Choose the front of the ready queue (lowest `ready_since`) unless the user
   names another piece.
2. Check `src/content/blog/<slug>.md` does NOT already exist. If it does, stop and
   ask for a new slug.
3. Transform the frontmatter to the published schema (follow the
   **adding-blog-entry** skill): keep `title` and `tags`; **author a real
   one-sentence `description`**; set `pubDate` to today; drop `slug`, `created`,
   `target`, `next`, `ready_since`. Confirm the `description` with the user if
   unsure.
4. `git mv pipeline/ready/<slug>.md src/content/blog/<slug>.md` and apply the
   frontmatter edit.
5. Run `npm run build` to confirm the schema accepts it and it renders.
6. Commit (the deploy step requires a clean tree):

   ```bash
   git add -A && git commit -m "Publish: <title>"
   ```
7. Hand off to the **deploying-blog** skill to build and ship.

## Notes

- Never move pipeline files into `src/content/blog/` except via `publish next` —
  half-formed frontmatter will fail the content schema and break the build.
- Batching is encouraged: capture several ideas at once, draft in one session,
  publish in another. The stages support it; nothing forces one piece end-to-end.
````

- [ ] **Step 2: Verify the skill is well-formed**

Run:
```bash
head -4 .claude/skills/managing-blog-pipeline/SKILL.md
```
Expected: a frontmatter block with `name: managing-blog-pipeline` and a `description:` starting with "Use when working the blog backlog".

- [ ] **Step 3: Commit**

```bash
git add .claude/skills/managing-blog-pipeline/SKILL.md
git commit -m "Add managing-blog-pipeline skill

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: End-to-end dry run (verification, leaves tree clean)

**Files:**
- Temporary only: a throwaway piece moved through the stages, then reverted. No committed changes.

**Interfaces:**
- Consumes: the scaffolding (Task 1) and the skill's documented file shapes (Task 2).

- [ ] **Step 1: Simulate capture → start**

```bash
printf -- '- throwaway dry-run idea\n' >> pipeline/ideas.md
cat > pipeline/drafting/dry-run-throwaway.md <<'EOF'
---
title: "Dry Run Throwaway"
slug: dry-run-throwaway
created: 2026-07-10
target: "verifying the pipeline"
next: "delete me"
tags: []
---
Body.
EOF
```

- [ ] **Step 2: Simulate ready**

```bash
git mv pipeline/drafting/dry-run-throwaway.md pipeline/ready/dry-run-throwaway.md 2>/dev/null || mv pipeline/drafting/dry-run-throwaway.md pipeline/ready/dry-run-throwaway.md
```
Expected: the file now lives in `pipeline/ready/`.

- [ ] **Step 3: Simulate publish transform and confirm the build accepts it**

```bash
mkdir -p src/content/blog
cat > src/content/blog/dry-run-throwaway.md <<'EOF'
---
title: "Dry Run Throwaway"
pubDate: 2026-07-10
description: "A throwaway post used to verify the publish transform."
tags: []
---
Body.
EOF
rm pipeline/ready/dry-run-throwaway.md
npm run build && find dist -path '*pipeline*' -print
```
Expected: build succeeds; `find` prints **nothing** (pipeline never leaks); `dist/` contains a rendered `dry-run-throwaway` page.

- [ ] **Step 4: Confirm the cadence inputs are readable**

```bash
grep -n 'Cadence target' pipeline/README.md
ls src/content/blog/*.md
```
Expected: the cadence line prints; the blog folder lists real posts (the board's cadence calc has its inputs).

- [ ] **Step 5: Revert everything — leave the tree exactly as committed**

```bash
rm -f src/content/blog/dry-run-throwaway.md
git checkout -- pipeline/ideas.md
git clean -fd pipeline/drafting pipeline/ready
git status --short
```
Expected: `git status --short` prints **nothing** — no residue from the dry run. (No commit for this task; it is verification only.)
