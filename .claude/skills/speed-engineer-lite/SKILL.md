---
name: "speed-engineer-lite"
description: "Use when a page/app is slow, before launch, or when writing Supabase/Postgres queries, lists, image uploads or loading states. Short checklist, minimal credit use."
---

# Speed Engineer Lite

Goal: keep the app fast with real data, using the fewest steps. Fix only what is slow or being written now. No full-project scans, no refactors, no side changes unless the user approves.

## Mode
- **Build**: apply the rules below to the code being written, then run the checklist at the end.
- **Fix-slow**: ask which page or action is slow. Find the biggest bottleneck with evidence (payload size, query count, EXPLAIN ANALYZE), fix that one thing, report before and after.
- **Audit** (only if the user asks): read-only. Report problems by impact with file:line and the smallest fix. Stop and ask which one to start with.

Do not ask scale questions unless the answer changes the fix. If unsure, assume a small project (under 1,000 users, tables under 100k rows) and say so in one line.

## Rules

### 1. Database
- Index every foreign key column and every column used in WHERE, ORDER BY, JOIN or RLS policies. For filter plus sort, use one composite index, e.g. (user_id, created_at desc).
- Add indexes through a migration file. Do not touch the database, Supabase settings or permissions unless asked.
- No N+1: fetch related data in one query (nested select or join). Never run a query inside a loop or per list row.
- Select only the needed columns. No select * on wide tables.

### 2. Pagination
- Every list query has a limit (default 20, max 100, enforced on the server).
- Stable order: order by created_at desc, id desc.
- Filter and search on the server, never download a whole table to filter in JavaScript.
- Offset pagination is fine for small or admin tables. Use keyset (cursor) pagination for feeds or tables over about 100k rows.
- Avoid exact count(*) on big tables.

### 3. Images
- Compress and resize before upload or on upload: long side up to 1600px, WebP, quality about 75-80.
- Show thumbnails in lists, the larger image only on detail views.
- Set width and height, use loading="lazy" below the fold, but never on the main top image.
- Ask before adding a dependency or a paid service.

### 4. Caching
- Classify the data first: static, public, per-user, or exact (money, stock).
- Static or public data: cache with a clear way to refresh when it is edited. Per-user data: client cache only. Money or stock: never cache.
- Never put user-specific data in a shared cache. No Redis for small projects.

### 5. Loading UX
- Every async view has loading (skeleton matching the layout), empty and error states. No blank screen.
- Run independent requests in parallel (Promise.all), not in a chain.
- Buttons that send a request show a pending state and block double submit.

## Guardrails
- Do not change behavior, data, order or permissions while optimizing.
- Ask before: adding a dependency, adding a paid service, changing schema beyond indexes, or touching production data.
- One fix at a time, test only the affected part, do not deploy unless asked.
- Never weaken security for speed.
- Explain each change in one short line, in the user's language.

## Checklist before saying done
- [ ] New queries have the indexes they need (via migration)
- [ ] No N+1, only needed columns selected
- [ ] Lists have a server limit and stable order
- [ ] Images are resized, compressed, sized correctly
- [ ] Cached data has a refresh path, private data not shared
- [ ] Loading, empty and error states exist
- [ ] Nothing added beyond what the project size needs