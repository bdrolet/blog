# blog.drolet.cloud

Ben's blog. [Astro](https://astro.build), static output, Markdown and MDX posts.

## Deploying

There is nothing to run. The repo is a [Cloudflare Pages](https://pages.cloudflare.com)
project: **pushing to `main` builds and publishes the site**, usually in under a
minute. Anything committed to `main` goes live, so drafts stay uncommitted or
outside `src/content/blog/`.

| | |
|---|---|
| Live | https://blog.drolet.cloud |
| Pages URL | https://blog-jl5.pages.dev |
| Build | `npm run build` → `dist`, Node 22.12.0 |

The Pages project itself is defined in Terraform, in a different repo —
`~/src/infra/cloudflare/drolet-cloud.tf`, `cloudflare_pages_project.blog`.
Change the build command, output directory or Node version there rather than in
the Cloudflare dashboard, or the next `terraform apply` will revert it.

`.claude/skills/deploying-blog/` has the deploy and build-status workflow, and
`scripts/deploy-status.sh` there polls a running build to success or failure.

## Writing

Posts are Markdown or MDX in `src/content/blog/`, one file per post, with the
filename as the URL slug. Frontmatter is type-checked against the schema in
`src/content.config.ts`:

```yaml
---
title: "Post title"
pubDate: 2026-09-15
description: "One or two sentences — used in the RSS feed and meta tags."
tags: ["infrastructure"]
---
```

`src/consts.ts` holds the site title and description, which feed the RSS
channel and the default meta tags. The canonical URLs, the sitemap and the RSS
links all derive from `site` in `astro.config.mjs` — if that is wrong, every one
of them is wrong, silently.

## Commands

| Command | Action |
| :--- | :--- |
| `npm install` | Install dependencies |
| `npm run dev` | Dev server at `localhost:4321` |
| `npm run build` | Build to `./dist/` — the same command Pages runs |
| `npm run preview` | Serve the built site locally |

## Credit

The theme started from Astro's blog starter, which is based on
[Bear Blog](https://github.com/HermanMartinus/bearblog/).
