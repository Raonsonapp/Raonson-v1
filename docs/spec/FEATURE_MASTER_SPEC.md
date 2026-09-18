# 01 Authentication & Account Switching

## Account switcher
- Show current avatar + username.
- Tap account selector -> bottom sheet with all signed-in accounts.
- Each account row: avatar, username, unread badge, optional verification badge.
- Selecting an account immediately changes:
  - avatar
  - username
  - feed/recommendations
  - notifications
  - DM inbox
  - stories
  - profile
  - drafts
  - saved state
  - privacy/settings context
  - creator/business dashboard context
- Animate avatar crossfade + content fade/slide.
- Never briefly show the previous account's private data after switching.
- Show a short skeleton while account-scoped data is refreshed.
- Support add account, remove account, log out one account, log out all.
- Preserve separate push-token/account associations.

# 02 Home / Feed

- Infinite vertical feed.
- Pull-to-refresh with progress indicator.
- Skeleton placeholders before media loads.
- Progressive image loading: tiny preview -> medium -> final.
- Video poster first; never block the feed waiting for full video.
- Autoplay only when item is sufficiently visible.
- Pause when leaving viewport.
- Mute/unmute persists according to product setting.
- Like: optimistic heart state, counter update, rollback on failure.
- Double-tap: heart burst animation centered on media.
- Comment, share, save, repost.
- Long press -> contextual menu.
- Not interested / hide / mute / report.
- Feed ranking should use recency, relationship, interest, engagement, content quality, and safety signals.
- Preserve scroll position when returning from a detail screen.
- Cache recently viewed feed items.
- Retry failed media without resetting the whole feed.

# 03 Posts / Carousels

- Single photo/video.
- Carousel with horizontal swipe and page indicator.
- Pinch-to-zoom media.
- Caption expand/collapse.
- Mentions, hashtags, location, music, alt text.
- Comments enabled/disabled.
- Like-count visibility setting where supported.
- Save to collection.
- Archive/delete/edit controls for owner.
- Collaboration flow.
- Share to Story/DM.
- Loading, upload progress, cancel, retry.
- Draft autosave.

# 04 Stories

- Horizontal story tray.
- Story rings: unseen / seen / close-friends / live state.
- Tap left/right navigation.
- Hold to pause.
- Swipe down/up for navigation.
- Story progress bars.
- Photo/video/text story creation.
- Stickers: poll, quiz, question, slider, countdown, Add Yours, location, mention, link, music, GIF.
- Close Friends.
- Story archive.
- Highlights.
- Story reply/reaction.
- Viewer list for owner.
- 24-hour expiration.
- Upload compression and progressive upload.
- Preload next story media while current story is playing.
- Avoid flashing black frames between stories.

# 05 Reels

- Full-screen vertical pager.
- Preload next and previous media.
- Adaptive streaming/quality based on network.
- Poster/thumbnail first.
- Play/pause.
- Mute/unmute.
- Like/comment/share/save/repost.
- Follow creator.
- Audio page.
- Remix/template where supported.
- Friends tab.
- Captions.
- Translation/dubbing where available.
- Comments panel as bottom sheet.
- Swipe-to-next with spring motion.
- Return to exact playback position.
- View/replay/watch-time analytics.
- Retention analytics for creators.

# 06 Camera / Effects

- Front/rear camera.
- Flash.
- Timer.
- Speed.
- Zoom.
- Grid.
- Focus.
- Exposure.
- Filters.
- AR face effects.
- World AR.
- Green screen/background replacement.
- Cutout.
- Blur.
- Glitch/VHS/neon/chromatic/lens effects.
- Beauty controls where applicable.
- Text/sticker/GIF/drawing.
- Effect preview must be real-time and degrade gracefully on low-end devices.

# 07 AI Creation

- AI image generation/editing.
- Restyle.
- Background generation/replacement.
- Object removal/replacement.
- AI stickers.
- AI captions.
- Translation.
- AI dubbing.
- AI voice/effects where supported.
- AI recommendation/search assistance.
- Every AI action needs progress, cancel, error, retry and disclosure where appropriate.

# 08 Search / Explore

- Search users, hashtags, audio, places, posts and Reels.
- Search history.
- Suggested searches.
- Recent results.
- Explore grid.
- Personalized ranking.
- Search loading skeleton.
- Empty state with useful next action.
- Typing debounce.
- Cached recent results.
- Safe-content filtering.

# 09 Profile

- Avatar.
- Username/name/bio.
- Links.
- Followers/following/posts counts.
- Posts grid.
- Reels tab.
- Tagged tab.
- Highlights.
- Pinned posts.
- Reposts tab where supported.
- Follow/unfollow with optimistic UI.
- Private account request flow.
- Profile share/QR.
- Edit profile.
- Account-specific settings.

# 10 Social Graph

- Follow.
- Follow request.
- Accept/decline.
- Remove follower.
- Block.
- Restrict.
- Mute.
- Close Friends.
- Suggested accounts.
- Mutual followers.
- Follower/following lists.
- Relationship state must update consistently across Feed, Profile, Search, comments and DMs.

# 11 Direct Messages

- One-to-one chat.
- Group chat.
- Text, image, video, GIF, sticker, emoji, voice.
- Reply, react, forward, copy, edit, delete.
- Pin message.
- Search conversation.
- Shared media.
- Typing indicator.
- Read state.
- Online/activity state.
- Message requests.
- Disappearing/vanish behavior where supported.
- Voice/video calls.
- Screen sharing where supported.
- Chat themes.
- Optimistic send with pending state.
- Failed message -> retry.
- Offline queue -> send when connection returns.
- Reconnect without duplicate messages.

# 12 Notes / Instants

Notes:
- Text/music/status.
- Audience selection.
- Reply/reaction.

Instants:
- Real-time photo capture.
- Close Friends or mutual-followers audience.
- View-once behavior.
- Expiration.
- Emoji reaction/reply.
- Undo/unsend.
- Private archive.
- Recap to Stories.
- Snooze controls.
- Privacy/safety controls.

# 13 Notifications

- Likes.
- Comments.
- Replies.
- Follows.
- Follow requests.
- Mentions.
- Tags.
- DMs.
- Story interactions.
- Reposts.
- Live.
- Security alerts.
- Notification grouping.
- Deep-link to exact object.
- Mark read/unread.
- Badge counts.
- Push notification preferences.

# 14 Live

- Start/stop Live.
- Guest/co-host.
- Comments.
- Reactions.
- Moderation.
- Questions/polls where supported.
- Live notifications.
- Viewer count.
- Archive/save.
- Network-quality indicator.
- Reconnect after temporary network loss.

# 15 Reposts / Friends / Map

- Repost public posts/Reels.
- Optional note on repost.
- Original author attribution.
- Repost tab on profile.
- Friends tab for relevant activity.
- Hide own activity where supported.
- Mute activity from selected accounts.
- Map: opt-in location sharing.
- Location-based posts/Reels/Stories/Notes.
- Clear privacy controls.
- Location sharing can be stopped immediately.

# 16 Creator / Business / Insights

- Professional account.
- Creator/business modes.
- Dashboard.
- Reach.
- Impressions/views.
- Engagement.
- Followers.
- Audience demographics where available.
- Content performance.
- Reels plays/replays.
- Watch time.
- Retention.
- Monetization tools.
- Branded content.
- Product tagging/shopping where supported.
- Ads/promotions where supported.

# 17 Monetization

- Subscriptions.
- Subscriber-only content.
- Gifts/badges where supported.
- Creator marketplace.
- Branded content.
- Ads/promotions.
- Product/affiliate tools where supported.
- Payout/account status UI.

# 18 Privacy / Security / Safety

- Public/private account.
- Hidden Words.
- Comment filters.
- Message filters.
- Block.
- Restrict.
- Mute.
- Report.
- Appeal/review status.
- Login activity.
- 2FA.
- Authenticator.
- SMS/email verification.
- Passkeys where supported.
- Security alerts.
- Suspicious-login protection.
- Account recovery.
- Teen safety settings.
- Family supervision where supported.
- Sensitive-content controls.

# 19 Settings

- Account.
- Privacy.
- Notifications.
- Security.
- Content preferences.
- Language.
- Media quality.
- Data usage.
- Accessibility.
- Appearance/theme where supported.
- Saved.
- Archive.
- Activity.
- Blocked/restricted/muted lists.
- Help/support.
- About.

# 20 Performance / Weak Network

## Weak internet behavior
- Show low-resolution poster immediately.
- Start video at a lower bitrate.
- Upgrade quality after bandwidth stabilizes.
- Preload only the next 1–2 items.
- Cancel downloads for items scrolled far away.
- Cache thumbnails and recent media.
- Retry with exponential backoff.
- Never freeze the UI while networking.
- Show compact connection indicator only when useful.
- Keep text/comments usable while media waits.
- Offline-like local UI for likes/saves/follows, then synchronize.
- Resolve conflicts from server truth.
- Avoid duplicate requests after reconnect.
- Resume interrupted uploads/downloads when possible.

## Loading animation
- Skeleton shimmer for lists.
- Circular progress for direct media actions.
- Indeterminate spinner only for short blocking operations.
- Use fade-in when media becomes ready.
- Never show a blank white/black screen between content.

# 21 Accessibility

- Screen reader labels.
- Minimum touch targets.
- Dynamic text size.
- Reduced motion setting.
- Captions.
- High contrast.
- Color must not be the only state indicator.
- Haptic feedback can be disabled.
- Voice-over friendly media controls.

# 22 Error / Empty / Loading States

Every screen needs:
- Loading.
- Loaded.
- Empty.
- Offline.
- Server error.
- Permission denied.
- Rate limited.
- Authentication expired.
- Upload failed.
- Media failed.
- Retry.
- Back navigation.
- Safe fallback.

# 23 Design System / Motion

## Motion rules
- Fast micro-interactions: ~120–220ms.
- Standard transitions: ~200–350ms.
- Modal/bottom-sheet: spring or ease-out.
- Avoid excessive animation.
- Respect reduced-motion preference.

## Core animations
- Double-tap heart burst.
- Like icon scale + spring.
- Follow button state morph.
- Story ring progress.
- Story viewer transition.
- Bottom navigation icon transition.
- Tab indicator slide.
- Bottom sheet spring.
- Image shared-element transition.
- Profile avatar transition.
- Carousel snap.
- Reel swipe spring.
- Comment sheet slide.
- Toast/snackbar enter/exit.
- Skeleton shimmer.
- Upload progress.
- Download progress.
- Pull-to-refresh.
- Haptic tap feedback.

# 24 Backend / State Contracts

Each object should have explicit:
- id
- owner_id
- created_at
- updated_at
- visibility
- moderation_state
- deleted_at

Client states:
- idle
- loading
- loaded
- refreshing
- submitting
- success
- error
- offline
- retrying

Use server-authoritative IDs and timestamps.
Use idempotency keys for likes, follows, messages and uploads.
Use cursor pagination rather than offset for large feeds.
Use WebSocket/realtime for chat/presence where appropriate.
Use push notifications for background events.
Use CDN/object storage for media.

# 25 QA / Acceptance Criteria

Test:
- account switching with 2–5 accounts
- slow 2G/3G-like network
- intermittent network
- offline -> online transition
- low RAM
- app background/foreground
- rotation where supported
- interrupted uploads
- duplicate taps
- rapid scrolling
- very long captions/comments
- deleted content while viewing
- blocked user while profile is open
- private account request race
- notification deep links
- expired story
- expired session
- token refresh
- WebSocket reconnect
- duplicate push notification
- video buffering
- audio focus changes
- accessibility/reduced motion

# IMPORTANT PRODUCT RULE

Do not copy Instagram source code, private APIs, proprietary assets, or exact branded artwork.
Implement the observable interaction patterns and your own design system.