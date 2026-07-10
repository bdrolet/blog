# Blog Pipeline — Design

**Date:** 2026-07-10
**Status:** Approved, pre-implementation

A system for capturing blog ideas, iterating on them through phases, and
publishing them on a steady cadence — entirely in-repo, driven through Claude
Code. No second app, no maintenance tax.

---

## Motivation

This section is the *why* behind the system. It is reproduced (condensed) in the
built `pipeline/README.md` so the reasoning lives next to the tool.

### The tension it resolves

The *Building Lighthouses* post commits to a pull-based philosophy: *"Writing.
Not on a schedule. Not to stay visible. When I have something to say, I write it.
When I don't, I don't."* Yet the goal here is to "keep on a schedule" and "keep
up with a good pace." These only *look* contradictory.

**A backlog decouples bursty input from steady output.** You capture and draft
when you're *pulled* — which comes in bursts. The backlog is a buffer.
Publishing draws from the buffer on a steady drip, so the lighthouse shines
consistently *without* forcing generation on demand. **The schedule governs the
publish step, never the writing step.**

### What the research found (and why each piece works)

Four searches across bloggers', newsletter writers', and content teams'
workflows. Five patterns recur:

1. **A zero-friction idea inbox.** Capture everything the moment it strikes;
   work the raw material later. *Why:* without a parking spot, every idea
   pressures you to act *now*, and that pressure makes you freeze or abandon it.
   The capture cost must be near zero or you won't do it when it matters.

2. **One source, multiple views (kanban / calendar / table).** The most-praised
   setup is a single content store viewed as a board (what's stuck?), a calendar
   (what's next out?), and a list. *Why:* one source of truth, looked at through
   whichever lens the moment needs — no syncing two systems.

3. **Own-your-files, frictionless writing.** Heavy writers prefer plain local
   markdown they own — "fast capture, zero friction, a file structure you
   actually own." *Why:* the tool disappears and you write. (You already have
   markdown in git; you'd be doing this natively.)

4. **A buffer of drafts ahead.** Solo bloggers write ahead and bank drafts.
   *Why, two mechanisms:* (a) it decouples writing days from publishing days, so
   a dry week doesn't break the streak; (b) it's a momentum flywheel — a pile of
   half-finished pieces *pulls* you back in, which for a Projector is the right
   fuel.

5. **Batching + a sustainable-not-aggressive cadence.** See below — the two ideas
   that keep the whole thing running.

**The caution that shaped the design:** *"If you're spending more time
maintaining your system than writing, you've optimized for the wrong thing."*
This is why we add no second app. The folders are the board, the files are the
drafts, the skill renders the view only when asked.

### Batching

Group like tasks into blocks instead of taking one piece idea→draft→edit→publish
in a single sitting. *Why:* each mode uses a different mental gear — capturing is
divergent (critic off), drafting is generative flow (critic off), editing is
convergent (critic on). Doing all three on one piece flips the inner critic on
and off every few minutes; that switching is the tax. Batching removes it.

Mapped to pull/push: **spend scarce burst-energy purely on generation** (capture
several ideas, draft two while hot), and defer the cheap mechanical steps (polish,
publish) to a separate low-energy block. The stage folders *are* the batch queues.

### Sustainable, not aggressive cadence

Pick a rhythm you can hold indefinitely, not the fastest you can sprint.
*Why aggressive backfires:*

1. **It drains the buffer** — publishing faster than you generate empties the
   ready queue, and every publish day becomes a scramble. The buffer's protective
   function collapses and you're back to push.
2. **Quality debt** — sprinting thins the work, which is counterproductive for a
   *lighthouse* strategy built on compounding, permanent pieces. One weak post
   that ranks is worse than none.
3. **The streak-break spiral** — a missed weekly slot reads as failure and kills
   momentum; a slower rhythm you always hit is self-reinforcing.

Counterintuitively, slower is often *more* total output: every-2-weeks held for a
year is 26 solid posts; weekly-then-burnout-at-week-7 is 7. Consistency is a
function of sustainability, not ambition.

**Net:** batching keeps generation cheap; a sustainable cadence keeps the buffer
from running dry. Together they let a bursty, pull-driven writer publish like a
metronome without ever writing on a metronome.

---

## Goals / Non-goals

**Goals**
- Capture ideas at near-zero friction.
- Iterate pieces through clear phases with an at-a-glance board.
- Publish on a sustainable drip, drawn from a buffer of ready drafts.
- Keep everything in-repo as plain markdown in git — one source of truth.
- Compose with the existing `adding-blog-entry` and `deploying-blog` skills.

**Non-goals**
- No external tool (Notion/Trello/Obsidian) or second place to live.
- No automation that ships to production on its own — publishing is a manual
  nudge the author triggers.
- No separate editing/review stage (solo author; editing happens in Drafting).
- No new build infrastructure or cron.

---

## Architecture

### Directory layout — folders are the kanban columns

```
blog/
├── pipeline/                    ← NEW, outside src/ so it never touches the build
│   ├── README.md                ← how the system works + the motivation + the one config value
│   ├── ideas.md                 ← the idea inbox: a flat bulleted list
│   ├── drafting/                ← one .md file per piece being actively written
│   │   └── <slug>.md
│   └── ready/                   ← finished drafts, queued to publish (the buffer)
│       └── <slug>.md
└── src/content/blog/            ← EXISTING, unchanged: only real, published posts
```

Moving a piece forward is a `git mv` between folders — the stage is unambiguous
from the file's location, with full git history. Because `pipeline/` sits outside
the Astro content glob (`base: './src/content/blog'`), half-formed pieces never
hit the content schema and never leak into `dist/`.

**Stages: Ideas → Drafting → Ready → Published.** Four, no more.

### Two-tier capture

- **Ideas** are *lines* in `pipeline/ideas.md`. Capture costs one sentence — no
  file, no frontmatter, no pressure.
- Committing to one graduates it into a **file** in `drafting/`.

### File formats

**Pipeline piece (`drafting/` and `ready/`)** — lightweight frontmatter:

```markdown
---
title: "Working title"
slug: proposed-slug
created: 2026-07-10
target: "the angle / who it's for"
next: "the next concrete action to move this forward"
tags: []                 # provisional
ready_since: 2026-07-24  # added only when moved to ready/ (drives FIFO drip)
---
Free-form notes and the draft body grow here.
```

The `next:` field is read back by the board so a piece never sits as "what was I
doing here?"

**Published post transform.** On publish, the lightweight frontmatter becomes the
real content-collection schema (reusing `adding-blog-entry`):

```markdown
---
title: "Final Title"
pubDate: 2026-07-10          # set to today
description: "One-sentence summary shown in the listing"   # authored at publish
tags: ["...", "..."]
---
```

`created`, `target`, `next`, `ready_since`, `slug` are dropped; `description` is
written; the file is `git mv`'d to `src/content/blog/<slug>.md`.

---

## The skill: `managing-blog-pipeline`

A new skill in `.claude/skills/managing-blog-pipeline/`, alongside the existing
two. It documents the workflow; on invocation Claude performs the file operations.

| Verb | Action |
|---|---|
| **capture** "idea…" | Append a line to `pipeline/ideas.md`. |
| **board** / status | Read all stages; print the kanban view + cadence status. |
| **start** an idea | Idea line → new `drafting/<slug>.md` with lightweight frontmatter; remove the line from `ideas.md`. |
| **ready** a draft | `git mv drafting/<slug>.md ready/`; stamp `ready_since: today`. |
| **publish next** | Transform a `ready/` piece to the real schema, set `pubDate: today`, `git mv` to `src/content/blog/`, then hand off to `deploying-blog`. |

### Board view

Renders on demand (research pattern #2 — one source, viewed as a board):

- **Ideas:** count + the list.
- **Drafting:** each piece with its `next:` action.
- **Ready:** the queue, ordered by `ready_since` (FIFO).
- **Cadence status:** derived below.

### Cadence nudge (the "schedule")

- **Last published:** the newest `pubDate` across `src/content/blog/`.
- **Target cadence:** a single value stored in `pipeline/README.md` (default
  **14 days**), so changing rhythm is a one-line edit.
- **Output:** e.g. *"Last published 15 days ago — you're due. Next in the ready
  queue: 'X' (ready 6 days). Publish it?"*
- **Empty queue when due:** point at the closest `drafting/` piece instead.
- **Buffer-depth warning:** if the ready queue is steadily draining toward empty,
  surface it as an early signal to slow the drip or run a capture/draft batch —
  *before* hitting empty and scrambling.

The drip is a **nudge you can decline**, never an auto-publish. Due but the piece
isn't good yet → skip, no streak-shame.

---

## Composition with existing skills

- **`adding-blog-entry`** — source of truth for the published-post schema and
  slug/naming rules; `publish next` follows it for the transform.
- **`deploying-blog`** — `publish next` hands off to it to build and ship.

`managing-blog-pipeline` owns everything *before* a post is schema-valid;
handoffs occur at the publish boundary.

---

## Edge cases / error handling

- **Build safety:** pipeline files live outside `src/content/blog/`, so they
  never hit the schema or `dist/`. (Verified against `src/content.config.ts`.)
- **Slug collision:** `publish next` checks `src/content/blog/<slug>.md` doesn't
  already exist before moving.
- **Missing `description` on publish:** the transform must author a real
  `description` and confirm all required schema fields are present, per
  `adding-blog-entry`.
- **Empty ready queue when due:** handled by the nudge (points at drafting).
- **Idea with no slug yet:** `start` proposes a kebab-case slug from the title.

---

## Verification

This is a workflow skill + folder convention, not runtime code. Verify by dry run:

1. `capture` a throwaway idea → appears as a line in `ideas.md`.
2. `start` it → `drafting/<slug>.md` created, line removed.
3. `ready` it → moved to `ready/`, `ready_since` stamped.
4. `publish next` → real frontmatter, moved to `src/content/blog/`.
5. `npm run build` succeeds; the post renders; **confirm `dist/` contains no
   `pipeline/` files** (no leak).
6. `board` prints correct counts, the `next:` actions, and a sane cadence line.
