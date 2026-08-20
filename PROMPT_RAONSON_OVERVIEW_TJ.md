# Промти пурра барои шарҳи барномаи Raonson

> Ин файлро тамом нусхабардорӣ карда, ба ChatGPT (ё ҳар AI-и дигар) паст кунед.
> AI ба шумо як шарҳи пурра оид ба хусусиятҳо, миқдори наздикӣ ба Instagram
> ва ҳамаи ҷузъиёти дигарро медиҳад.

---

## ПРОМТ (нусхабардорӣ ва паст кунед):

Ба ман як таҳлили пурра ва расмии барномаи иҷтимоии зерин бо номи **Raonson** бо забони тоҷикӣ бинавис. Ба ҳар як бахш посух деҳ:

1. **Барнома Raonson чист?** — тавсифи умумӣ (1-2 сатр).
2. **Ҳамаи хусусиятҳо ва функсияҳояшро номбар кун** (гурӯҳбандӣ бо категорияҳо, аз рӯи маълумоти зер).
3. **Дар кадом сайту платформаҳо кор мекунад?**
4. **Чанд фоиз ба Instagram монанд аст?** (бо тавзеҳ — чиро мисли Instagram дорад, чиро дигар/иловагӣ дорад, чиро надорад).
5. **Технологияи (stack) он чист?**
6. **Кӣ Raonson-ро сохтааст?**

Дар посух аз рӯи маълумоти зер (ки аз коди воқеии барнома гирифта шудааст) кор кун ва чизи навро аз худ илова накун:

---

### Маълумоти дақиқ дар бораи Raonson:

**Созанда:** Ehson Mahmadmurodov (@raonson)

**Забони асосӣ:** тоҷикӣ (иловатан русӣ ва англисӣ дастрас аст — иваз кардани забон дар танзимот, дар логин ва регистратсия).

**Технология (stack):**
- **Client (замимаи мобилӣ ва web):** Flutter/Dart — дар Android, iOS, Web, macOS, Linux ва Windows кор мекунад (як код барои 6 платформа).
- **Backend (сервер):** Go (Gin) — 176 endpoint API дар 216 функсия.
- **Базаи додаҳо:** PostgreSQL (Supabase).
- **Мемория медиа:** Cloudflare R2 (S3-compatible).
- **Cache:** In-process (RAM) + Upstash Redis (ихтиёрӣ, дуюмдараҷа).
- **Realtime:** WebSocket (сокети зинда).
- **Notifications:** FCM (Firebase Cloud Messaging).
- **Hosting:** Hugging Face Space (Docker).
- **AI:** OpenAI (GPT-4o, Moderation, Chat Completions).
- **Мусиқӣ:** iTunes Search API (ройгон).
- **Analytics:** In-house (без Google Analytics).
- **Ads (реклама):** Ads Manager дохилӣ (interstitial байни рилс, rewarded видео барои зеркашӣ).

**Хусусиятҳои асосии барнома:**

### 1. Аутентификатсия ва аккаунт
- Регистратсияи 4-қадама: маълумот → номи корбар → акс → пайдо кардани дӯстон.
- Логин бо телефон, номи корбар ё почта.
- Барқарорсозии парол тавассути SMS/email (Twilio + SMTP).
- Тасдиқи почта ва рамзи OTP.
- Ду забон дар танзимот: тоҷикӣ / русӣ / англисӣ.
- Multi-account (якчанд аккаунт дар як барнома).
- Танзимоти амният ва махфият.

### 2. Пост (Post) — мисли Instagram
- Расм ё видео нашр кардан.
- Тавсиф (caption) то 2200 аломат.
- Filter-ҳои расм (photo filters — мисли Instagram).
- Илова кардани мусиқӣ (аз iTunes).
- Ҷойгиршавӣ (location).
- Зикр кардани корбарон (@mentions).
- Соавторҳо (collaborators — 2 корбар 1 пост).
- Text overlay, sticker, эмодзӣ.
- Расм кашидан дар боли пост (draw).
- Пинҳон кардани like (hide likes).
- Хомӯш кардани шарҳҳо (comments-off).
- Ба бойгонӣ гузоштан (archive).
- Пин кардани пост (pin).
- Ҷолиб аст / Ҷолиб нест (interested/not-interested).
- Таҳрири тавсиф.
- Иваз кардани мусиқӣ.
- Ҳамрадиф формати аслии расм (aspect ratio, мисли Instagram).
- Тарҷумаи тавсиф (AI Translate).

### 3. Reels (Рилс) — мисли Instagram Reels
- Видеои амудӣ, swipe вертикалӣ.
- Compress худкор (720p баланд + 480p паст барои интернети суст).
- Thumbnail-и аслӣ аз кадри аввали видео.
- Preloading-и 2 видеои навбатӣ.
- Адаптивӣ бо интернет: Wi-Fi → баланд, mobile → паст.
- Double-tap барои like.
- Like counter, comment, share, save.
- Мубодила (share) ба чат ё дигар барномаҳо.
- Илова ба story.
- Нусхабардории силка.
- Reel аз силка (Aparat/YouTube) — embed player.
- Track watch-time (муддати тамошо).
- Not interested (алгоритм ёд мегирад).
- Reel stats (танҳо соҳиб).
- Reel comments бо reply, like, тарҷума.
- «Кӣ ин рилсро мебинед» — тавзеҳи алгоритм.
- Interstitial реклама байни рилс (ҳар 5 рилс).
- Rewarded ad барои зеркашии видео.

### 4. Stories (Сториз) — мисли Instagram
- Story-и 24-соата.
- Story editor: matn, sticker, эмодзӣ, расм кашидан.
- Мусиқӣ дар story.
- Ҷавоб (reply) ба story.
- Like ва view counter.
- Highlights (Актуальный) — story-ҳои доимӣ дар профил.
- Story ring (halqa) дар аватар агар story фаъол дошта бошад.
- Инвалидатсияи фаврии cache: story-и нав дар 1-3 сония ба ҳама намоён.
- Хомӯш кардани reply (replies-off).
- Ба бойгонӣ гузоштан.

### 5. Профил ва дӯстон
- Профил бо аватар, bio, мусиқии профил, note (60 аломат, 24 соат).
- Note бо суруд (Spotify-style status).
- Followers/Following (пайравон/пайравӣ).
- Follow requests барои профили хусусӣ.
- Мутақобилан unfollow.
- Block/Unblock.
- Mute (хомӯш кардан).
- Restrict (маҳдуд кардан).
- Report (шикоят).
- Global follow sync (як бор пахш → ҳама ҷо иваз).
- Suggested users (пешниҳод).
- Пайдо кардан аз рӯи contacts (телефон).
- Профили хусусӣ (private).
- Grid-и постҳо / Tagged / Reels / Saved.
- Пост-ҳои таърих (activity log).
- Таҳрири профил (username, bio, phone, email).
- Иваз кардани username ҳар 14 рӯз як бор.

### 6. Feed (лента)
- Feed «оддӣ» ва Feed «ҳушманд» (smart-feed).
- Алгоритми ranking: following + тозагӣ + like + comment + interest score + завқ + завли AI (0-100).
- Инфинити скролл, pull-to-refresh.
- Real image aspect ratio (мисли Instagram, на танҳо 4:5).
- Realtime updates (WebSocket).
- Cache 3-сония (ба ҷои 30-сония) — like/follow фавран намоён.

### 7. Chat (Паём)
- Direct messages 1-ба-1.
- Group chats (сохтан, узвон, идора, invite link, ЮРЛ QR).
- Паёми овозӣ (voice message).
- Recording waveform.
- Тасвир, видео, файл, GPS location.
- Reactions (emoji ба паём).
- Reply ба паёми алоҳида.
- Delete message.
- Chat requests (Instagram-style).
- Accept/delete/block аз дохили request.
- Chat themes (мавзӯъ барои ҳар чат ҷудогона).
- Voice/video call (Screen).
- Realtime online status ва last seen.
- Typing indicator.
- Message read status.
- Note bar (мисли Instagram).
- Faster open (chat кушодан 1 сония).

### 8. Search (Ҷустуҷӯ) + Explore
- Ҷустуҷӯи корбарон, ҳэштег, пост, реел, аудио.
- Recent history + saved accounts.
- Explore grid бо quilted layout (айнан мисли Instagram Explore).
- Fullscreen explore reel viewer.
- **AI Search** — дархости забони табиӣ («видеоҳои имрӯз дар бораи футбол»).
- Ҷустуҷӯи мусиқӣ тавассути iTunes.
- Long-press preview.

### 9. Notifications
- Инбоки огоҳиҳо.
- Foreground push notifications (FCM).
- Танзими огоҳиҳо (like, comment, follow, story reply).
- Realtime WebSocket-и огоҳиҳо.

### 10. Gifts (Тӯҳфаҳо) — монеат надорад дар Instagram
- Фиристодани тӯҳфа ба post, reel, ё чат.
- Экономика: коин, тарҷума ба пул.
- Gift sheet.

### 11. Shop (Магоза) — Instagram Shop-и монанд
- Пости-маҳсулот (product post).
- Нарх, асъор, ном.
- Ҷои магоза (GPS location).
- Тамос: WhatsApp / телефон / тавассути Raonson.
- Фармоишҳо (orders): худам харидам, худам фурӯхтам.
- Комиссия барои платформа.
- Marketplace-и умумӣ (/shop).
- «Магоза» бе cache — маҳсулоти нав фавран.

### 12. Effects (Филтр/эффектҳо) — мисли TikTok/Instagram effects
- Creator effects marketplace.
- Пулакӣ (premium) ё ройгон.
- Комиссия ба созанда.
- Эффектҳои худамро сохта фурӯшам.

### 13. Anime бахш (иловагӣ — уникалӣ)
- Плеер-и худӣ.
- 480p ройгон, 720p+1080p танҳо барои VIP.
- Танҳо контенти ҳалол (haram filter).
- Aparat integration.
- Trending anime.
- Зеркашӣ (download) — rewarded ad.

### 14. News (Ахбор) — уникалӣ
- RSS-и манбаъҳои боэътимод.
- Дар Settings.
- Cache дохили handler.

### 15. Learn (Омӯзиш) — AI Tutor уникалӣ
- «Устоз AI» — муаллими коднависӣ.
- 6 track: app (Flutter), backend, design (UI/UX), icons, website (HTML/CSS/JS), AI.
- ChatGPT-style интерфейс.
- Ба тоҷикӣ бо мисолҳои содда (қуттӣ, хишт, ошхона).
- Ҳар дарс бо 1 вазифаи амалӣ тамом мешавад.

### 16. Promote (Тарғиб) — мисли Instagram Promote
- Ду шакли ҳадаф: профил, вебсайт, паём.
- Аудитория, буҷа, муддат.
- Пардохт → фаъол.

### 17. Admin panel
- Panel-и идоракунӣ (танҳо соҳиби барнома).
- Ban/unban.
- Verify (галочка).
- VIP додан.
- Statistics.

### 18. AI features (тавассути OpenAI — уникалӣ, ки Instagram надорад)

**⭐⭐⭐⭐⭐ AI Moderation** — модератсияи худкори пост/шарҳ/reel/reply (OpenAI Moderation API). Спам, ҳақорат, мӯҳтавои номатлуб автоматӣ блок мешавад.

**⭐⭐⭐⭐⭐ AI Post Creator** — «Дар бораи футбол пост навис» → AI пости тайёр бо матн, эмодзӣ, ҳэштег месозад. Ба забони худи корбар.

**⭐⭐⭐⭐⭐ AI Comment** — тугмаи ⚡ дар қатори навиштани шарҳ — AI шарҳи мувофиқ пешниҳод мекунад.

**⭐⭐⭐⭐☆ AI Profile Assistant** — «фотограф аз Душанбе» → AI Bio-и касбӣ месозад.

**⭐⭐⭐⭐⭐ AI Translate** — зери ҳар пост/шарҳ тугмаи «Тарҷума кардан» — тарҷума ба забони фаъоли барнома (tj/ru/en).

**⭐⭐⭐⭐⭐ AI Moderation** — гуфта шуд.

**⭐⭐⭐⭐⭐ AI Feed** — ҳар пости нав холи AI мегирад (0-100 — сатҳи ҷолибият) ва ин ба алгоритми smart-feed илова мешавад, аз ҷумла following, тозагӣ, лайк, тамошо.

**⭐⭐⭐⭐⭐ AI Search** — «Видеоҳои Тоҷикистон дар бораи футбол» → AI ба калидвожа/навъи мӯҳтаво/давра табдил медиҳад, баъд backend ILIKE search мекунад.

**⭐⭐⭐⭐⭐ AI Chat Assistant** — «Ёрдамчии AI» дар боли Chat: ChatGPT-и дохилӣ, ки дар бораи барнома ҷавоб медиҳад. Агар пурсанд «Ин барномаро кӣ сохт?» → ҳамеша «Ehson Mahmadmurodov».

**AI Hashtag Generator** — тугмаи «AI ҳэштег» дар create-post → 5-8 ҳэштеги мувофиқ бо расм ва тавсиф.

### 19. Cache ва Performance
- Middleware cache бо userID (пеш аз фикс — cross-user data leak буд).
- 3-сония cache барои personalized (feed, stories, post).
- 5-дақиқа cache барои explore.
- 30-сония cache барои search.
- InvalidateUserCache пас аз ҳар write.
- In-process cache primary (0ms), Redis secondary (20-50ms).
- GZIP compression (3-5× трафик кам).

### 20. Ислоҳҳои муҳими охирин
- Стори now дар 1-3 сония ба ҳама намоён (қаблан 3 дақиқа буд).
- Лайк дигар пас аз refresh кам намешавад.
- Follow/Unfollow фавран нав мешавад.
- Post/Reel delete фавран аз ҳамаи экранҳо мебарояд.
- Забон дар логин/регистратсия ҳақиқатан иваз мешавад (қаблан tr() кор мекард, аммо экран рendering намешуд).
- Story upload 5-10 маротиба тезтар (пеш аз бор кардан фишурда мешавад).
- Upload retry 3 маротиба ҳангоми интернети суст.
- Reels 500 хато ислоҳ шуд (comments_count column лозим буд).

---

Пас аз хондани ин маълумот:
- Ба ман шарҳи пурра деҳ бо ҳамаи бахшҳо.
- Ҳисоб кун, ки чанд фоиз ба Instagram монанд аст (бо тавзеҳ).
- Инчунин гуфт, ки чиро Raonson дорад, ки Instagram надорад.
- Дар кадом платформаҳо (Android, iOS, Web ва ғ.) кор мекунад.
- Дар охир бо як ҷумла хулоса кун.
