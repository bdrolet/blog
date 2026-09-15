---
title: "Hello, World"
pubDate: 2025-01-15
description: "Welcome to the blog. Here's what to expect and how it's built."
tags: ["meta"]
---

Welcome to the blog. This is where I write about things I find interesting: systems programming, infrastructure, and the occasional deep dive into tooling.

## Why Another Blog?

Writing helps me think. I kept losing notes across Notion, Bear, and random markdown files scattered across my filesystem. Having a single, static, version-controlled place feels right.

## What to Expect

Posts will be technical and opinionated. I'll write about:

- **Infrastructure** — Kubernetes, containers, GitOps
- **Languages** — Go, Rust, occasionally Python when I must
- **Tools** — whatever's currently on my `$PATH` that I find interesting

## The Stack

This blog is built with [Astro](https://astro.build) and hosted on Cloudflare Pages. Source is in Git. Posts are Markdown. Pushing to `main` builds and publishes. That's it.

```bash
git push origin main
```

It did start out more elaborate — a Docker image serving the static build through nginx, running as a pod in a Kubernetes cluster behind a load balancer. That worked fine, and cost about eighteen dollars a month in load balancer alone to serve a few hundred kilobytes of HTML that never changes between deploys. The container was doing nothing the CDN wasn't already better at.

Simple is good.
