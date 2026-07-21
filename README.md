---
title: Raonson
emoji: 🚀
colorFrom: blue
colorTo: green
sdk: docker
pinned: false
---

# Raonson

Raonson is a Tajik-first social app in the spirit of Instagram — feed, Reels,
Stories, chat, gifts, and a shop — with an integrated set of AI features built
on OpenAI's API. The Flutter client runs on Android, iOS, web, macOS, Linux
and Windows, and the Go backend (PostgreSQL + Cloudflare R2, optional Redis)
is deployed on Hugging Face Spaces.

Created by **Ehson Mahmadmurodov**.

## AI features

Every AI feature fails gracefully if `OPENAI_API_KEY` isn't configured, so
the rest of the app keeps working normally.

- **AI Moderation** — post captions, reel captions, comments, and replies are
  screened via OpenAI's Moderation endpoint before they're stored.
- **AI Post Creator** — type a topic and get a ready-to-publish caption with
  emoji and hashtags, in the language of the topic.
- **AI Hashtag suggestions** — one tap to append 5–8 fitting hashtags to your
  caption (uses the image too when available).
- **AI Comment suggestions** — one tap to draft a natural, friendly comment
  for a post, based on its caption and cover image.
- **AI Profile Assistant** — generates a short professional bio from a
  profession/interest prompt.
- **AI Translate** — inline "Translate" toggle under any post caption or
  comment, translating to the user's app language (tj / ru / en).
- **AI Feed ranking** — each new post is asynchronously scored 0–100 by
  OpenAI and the score feeds into the smart-feed ranking as an additional
  signal, alongside following/recency/engagement.
- **AI Search** — natural-language search ("videos about football in
  Tajikistan"): GPT parses the query into keywords + content type + timeframe
  and the backend runs the actual search.
- **AI Chat Assistant ("Ёрдамчии AI")** — a pinned entry in the Chat inbox
  that answers questions about the app in the user's language.

## Development note

**ChatGPT (GPT-5.6) was used to help design features, improve the application
architecture, generate documentation, refine prompts, and assist with
development throughout the project.**

## Stack

- **Client**: Flutter (Dart), i18n via a lightweight `tr()` helper (Tajik /
  Russian / English), realtime updates over WebSocket, uploads to R2.
- **Backend**: Go (Gin) + PostgreSQL, Cloudflare R2 for media, optional
  Upstash Redis as a secondary cache, in-process cache as the primary tier.
- **AI**: OpenAI Chat Completions + Moderation endpoints via a small
  `utils/openai_client.go` wrapper.

## Configuration

The backend reads all secrets from environment variables (Hugging Face
Space → Settings → Secrets). Nothing sensitive is committed to the repo.

- `DATABASE_URL` — PostgreSQL connection string
- `JWT_SECRET`, `JWT_REFRESH_SECRET` — token signing
- `CF_ACCOUNT_ID`, `CF_R2_ACCESS_KEY`, `CF_R2_SECRET_KEY`,
  `CF_R2_BUCKET`, `CF_R2_PUBLIC_URL` — media storage
- `OPENAI_API_KEY` (optional) — enables the AI features above
- `SMTP_USER`, `SMTP_PASS` — password-reset email (any SMTP)

See `backend/.env.example` for the full list.
