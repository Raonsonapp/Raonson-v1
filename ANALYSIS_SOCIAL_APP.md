# Raonson Repo Analysis (Focused on 5 main screens)

## Scope
This analysis focuses on the 5 core screens and auth stability:
- Home
- Reels
- Chat
- Search
- Profile
- Login/Register/session restore flow

## What is already fixed
1. Backend auth normalization and duplicate handling in register/login.
2. Middleware provides both `req.userId` and `req.user` shape for controller compatibility.
3. Login token persists to secure storage.
4. App restores token on startup before deciding home/login screen.
5. Home duplicate bottom-nav issue addressed by keeping one nav source and feed as content.

## Current architecture quality
- App shell: **Good baseline** (route + nav + auth state exist).
- Repositories/controllers: **Present but mixed maturity**.
- Error handling: **Improved for auth, still basic in feature screens**.
- UX completeness: **MVP level**, not yet Instagram/TikTok parity.

## Remaining gaps to make 5 screens production-ready

### 1) Home
- Needs better empty/error UX and retry actions.
- Needs deterministic pagination guard for slow networks.

### 2) Reels
- Needs buffering/error states per media item.
- Needs prefetch and watch-progress signal.

### 3) Chat
- Needs robust reconnect strategy and offline queue.
- Needs unread counters synced with notifications.

### 4) Search
- Needs debounce + ranking and result sections (users/posts/hashtags).
- Needs loading placeholders and recent search history.

### 5) Profile
- Needs stronger fallback UI for no content and network failures.
- Needs edit-profile / follow-state sync consistency.

## Immediate next sprint plan (recommended)
1. Unify API error model across all repositories/controllers.
2. Add retry widgets and skeleton loaders to all 5 screens.
3. Add integration tests for startup auth restore + bottom-nav switching.
4. Add backend pagination/index audit for feed/reels/search endpoints.

## File count snapshot
- Tracked files (`git ls-files`): use command below.
- All files in working tree (`find . -type f`): use command below.

```bash
git ls-files | wc -l
find . -type f | wc -l
```
