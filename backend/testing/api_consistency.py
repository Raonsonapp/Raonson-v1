#!/usr/bin/env python3
"""Як пост / Reel — ҳамон лайк, шарҳ, «лайк кардам», «лайкҳо пинҳон» ва
 обуна дар ҲАМАИ экранҳо (лента, smart, профил, explore, ягона). ⚠️ Сервери МАҲАЛЛӢ.
"""
import json, os, sys, time, urllib.request, urllib.error, urllib.parse
B = os.environ.get("BASE", "http://127.0.0.1:8099"); PW = "Test12345!"; res = []
def call(m, p, body=None, tok=None):
    req = urllib.request.Request(B + p, data=json.dumps(body).encode() if body is not None else None, method=m)
    req.add_header('Content-Type', 'application/json')
    if tok: req.add_header('Authorization', 'Bearer ' + tok)
    for a in range(4):
        try:
            with urllib.request.urlopen(req, timeout=30) as r:
                raw = r.read().decode(); return r.status, (json.loads(raw) if raw else {})
        except urllib.error.HTTPError as e:
            if e.code == 429: time.sleep(4 * (a + 1)); continue
            raw = e.read().decode()
            try: return e.code, json.loads(raw)
            except Exception: return e.code, raw
    return 429, {}
def user(u, ph):
    call("POST", "/auth/register", {"username": u, "email": f"{u}@example.com", "password": PW, "fullName": u, "phone": ph})
    st, r = call("POST", "/auth/login", {"email": u, "password": PW})
    return r.get("accessToken"), (r.get("user") or {}).get("id") or (r.get("user") or {}).get("_id")
def ok(n, c, d=""): res.append((bool(c), n, str(d)[:200]))
S = os.environ.get("SUFFIX", "cs")
tA, A = user(f"ya{S}", "+992900890101"); tB, Bb = user(f"yb{S}", "+992900890102")
tC, C = user(f"yc{S}", "+992900890103")
IMG = "https://example.com/p.jpg"; VID = "https://example.com/v.mp4"

def find(obj, id_):
    if isinstance(obj, dict):
        if (obj.get("_id") or obj.get("id")) == id_ and ("likesCount" in obj or "likes" in obj): return obj
        for v in obj.values():
            r = find(v, id_)
            if r is not None: return r
    if isinstance(obj, list):
        for v in obj:
            r = find(v, id_)
            if r is not None: return r
    return None

CROWDED = object(); crowded = set()
def get_item(tok, p, id_):
    # /explore аз рӯи лайкҳо мураттаб ва саҳифабандӣ дорад. Дар БД-и
    # муштараки санҷишҳо (ҳазорҳо пости бо лайкҳои зиёд) мундариҷаи нав
    # метавонад дар 15 саҳифаи аввал набошад — он гоҳ Explore барои ин
    # санҷиш «дастнорас» (на «MISSING») ҳисоб мешавад ва ҷудо гуфта мешавад.
    if p != "/explore":
        st, r = call("GET", p, tok=tok)
        x = find(r, id_)
        # Лентаҳои мураттаб (лента, smart, Reels) низ дар БД-и пур метавонанд
        # ин мундариҷаро дар саҳифаи аввал надошта бошанд.
        if x is None and p.split("?")[0] in ("/posts/", "/posts/smart-feed", "/reels/", "/reels/smart"):
            crowded.add(id_); return CROWDED
        return x
    for pg in range(1, 16):
        st, r = call("GET", f"/explore?page={pg}", tok=tok)
        x = find(r, id_)
        if x is not None: return x
        if not isinstance(r, dict) or not r.get("hasMore"): return None
    crowded.add(id_)
    return CROWDED

def views(tok, kind, id_):
    out = {}
    paths = ([("feed", "/posts/?limit=50"), ("smart", "/posts/smart-feed?limit=50"),
              ("profile", f"/users/{A}/posts"), ("profileMe", "/profile/me") if tok == tA else ("profileU", f"/profile/ya{S}"),
              ("explore", "/explore"), ("single", f"/posts/{id_}"),
              ("search", "/search/?q=" + urllib.parse.quote(f"якхела {S}"))]
             if kind == "post" else
             [("reels", "/reels/?limit=50"), ("smart", "/reels/smart?limit=50"),
              ("profile", f"/users/{A}/reels"), ("explore", "/explore"), ("single", f"/reels/{id_}"),
              ("search", "/search/?q=" + urllib.parse.quote(f"reel якхела {S}"))])
    for name, p in paths:
        x = get_item(tok, p, id_)
        if x is CROWDED: continue
        if x is None: out[name] = None; continue
        u = x.get("user") or {}
        out[name] = (x.get("likesCount", x.get("likes")), x.get("commentsCount", x.get("comments")),
                     x.get("liked", x.get("isLiked")), x.get("hideLikes"),
                     u.get("isFollowing"), x.get("saved", x.get("isSaved")),
                     x.get("sharesCount"))
    return out

def same(label, v, idx, expect=None, skip_none=True):
    vals = {k: (t[idx] if t else "MISSING") for k, t in v.items()}
    present = {k: x for k, x in vals.items() if not (skip_none and x is None)}
    uniq = set(map(str, present.values()))
    good = len(uniq) == 1 and (expect is None or str(expect) in uniq)
    ok(label, good, vals)

# ── ПОСТ ──
st, p = call("POST", "/posts/", {"caption": f"якхела {S}", "media": [{"url": IMG, "type": "image"}]}, tA); pid = p["_id"]
call("POST", f"/posts/{pid}/like", tok=tB); call("POST", f"/posts/{pid}/like", tok=tC)
call("POST", f"/posts/{pid}/comments", {"text": "1"}, tB)
call("POST", f"/follow/{A}", tok=tB)
time.sleep(0.5)
v = views(tB, "post", pid)
same("пост: лайкҳо дар ҳама ҷо 2", v, 0, 2)
same("пост: шарҳҳо дар ҳама ҷо 1", v, 1, 1)
same("пост: «ман лайк кардам» дар ҳама ҷо true", v, 2, True)
call("POST", f"/posts/{pid}/save", tok=tB); call("POST", f"/posts/{pid}/share", tok=tC)
v = views(tB, "post", pid)
same("пост: «сабт шуд» дар ҳама ҷо true", v, 5, True)
same("пост: паҳн дар ҳама ҷо 1", v, 6, 1)
same("пост: обуна дар ҳама ҷо true", v, 4, True, skip_none=False)
call("POST", f"/posts/{pid}/like", tok=tB)  # unlike
v = views(tB, "post", pid)
same("пост: баъди бекор кардани лайк фавран 1 дар ҳама ҷо", v, 0, 1)
same("пост: liked=false дар ҳама ҷо", v, 2, False)
call("POST", f"/posts/{pid}/hide-likes", tok=tA)
v = views(tB, "post", pid)
same("пост: лайкҳо пинҳон — дар ҳама ҷо -1", v, 0, -1)
same("пост: hideLikes=true дар ҳама ҷо", v, 3, True)
va = views(tA, "post", pid)
same("пост: соҳиб рақами воқеиро мебинад (1)", va, 0, 1)
call("POST", f"/posts/{pid}/hide-likes", tok=tA)
v = views(tB, "post", pid)
same("пост: аз нав фаъол — 1 дар ҳама ҷо", v, 0, 1)

# ── REEL ──
st, r = call("POST", "/reels/", {"videoUrl": VID, "caption": f"reel якхела {S}"}, tA); rid = r.get("_id")
ok("reel сохта шуд", rid, r)
call("POST", f"/reels/{rid}/like", tok=tB); call("POST", f"/reels/{rid}/like", tok=tC)
call("POST", f"/reels/{rid}/comments", {"text": "x"}, tC)
time.sleep(0.5)
v = views(tB, "reel", rid)
same("reel: лайкҳо дар ҳама ҷо 2", v, 0, 2)
same("reel: шарҳҳо дар ҳама ҷо 1", v, 1, 1)
same("reel: isLiked дар ҳама ҷо true", v, 2, True)
same("reel: обуна (isFollowing) дар ҳама ҷо true", v, 4, True)
call("POST", f"/reels/{rid}/hide-likes", tok=tA)
v = views(tB, "reel", rid)
same("reel: лайкҳо пинҳон — -1 дар ҳама ҷо", v, 0, -1)
call("POST", f"/reels/{rid}/hide-likes", tok=tA)
v = views(tB, "reel", rid)
same("reel: аз нав фаъол — 2 дар ҳама ҷо", v, 0, 2)
# Обуна бекор → дар ҳама ҷо false
call("DELETE", f"/follow/{A}", tok=tB); call("POST", f"/unfollow/{A}", tok=tB)
v = views(tB, "reel", rid)
same("reel: баъди бекор кардани обуна — false дар ҳама ҷо", v, 4, False)

# ── ТАМОШОҲО: як рақам дар ҳамаи экранҳо ─────────────────────────────
# Reel → reels.views_count (ҳар корбар як бор; /view ва /watch ҳарду).
# Пост → COUNT(post_views) (ҳар корбар як бор).
tD, D = user(f"yd{S}", "+992900890104"); tE, E = user(f"ye{S}", "+992900890105")
tF, F = user(f"yf{S}", "+992900890106")

def views_of(tok, kind, id_, q=""):
    # Ҳамаи экранҳое, ки тамошоро нишон медиҳанд: лента, smart, профил
    # (ҷадвал ва /profile/:username), Explore, ҷустуҷӯ ва худи пост/Reel.
    sq = "/search/?q=" + urllib.parse.quote(q)
    paths = ([("reels", "/reels/?limit=50"), ("smart", "/reels/smart?limit=50"),
              ("profile", f"/users/{A}/reels"), ("explore", "/explore"), ("single", f"/reels/{id_}"),
              ("search", sq)]
             if kind == "reel" else
             [("explore", "/explore"), ("profile", f"/users/{A}/posts"),
              ("profileU", f"/profile/ya{S}"), ("single", f"/posts/{id_}"),
              ("search", sq)])
    out = {}
    for name, p in paths:
        x = get_item(tok, p, id_)
        if x is CROWDED: continue
        if x is None: out[name] = None; continue
        out[name] = (x.get("viewsCount"), x.get("views"))
    return out

def views_same(label, v, expect):
    present = {k: t for k, t in v.items() if t is not None}
    # Ҳарду калид ("viewsCount" ва "views") бояд ҳамон рақам бошанд.
    both = all(t[0] == t[1] for t in present.values())
    uniq = {t[0] for t in present.values()}
    need = set(v) if len(v) > 1 else {"explore"}
    ok(label + f" ({len(present)} экран: {sorted(present)})",
       both and uniq == {expect} and set(present) == need, v)

# Reel-и нав, то рақамҳо аз сифр оғоз шаванд.
st, r2 = call("POST", "/reels/", {"videoUrl": VID, "caption": f"тамошо якхела {S}"}, tA); rid2 = r2.get("_id")
st, v1 = call("POST", f"/reels/{rid2}/view", tok=tB)                 # B: профил → reel
call("POST", f"/reels/{rid2}/view", tok=tB)                          # такрор — ҳисоб намешавад
st, w1 = call("POST", f"/reels/{rid2}/watch", {"watchMs": 3000, "completed": False}, tC)  # C: лентаи Reels
call("POST", f"/reels/{rid2}/watch", {"watchMs": 5000, "completed": True}, tC)            # такрор
st, v3 = call("POST", f"/reels/{rid2}/view", tok=tD)                 # D: боз як бинанда
ok("reel: /view рақами навро бармегардонад (1)", v1.get("viewsCount") == 1 and v1.get("views") == 1, v1)
ok("reel: /watch ҳам тамошо ҳисоб мекунад (2)", w1.get("viewsCount") == 2, w1)
ok("reel: такрор ҳисоб намешавад (3 бинанда → 3)", v3.get("viewsCount") == 3, v3)
# Explore аз рӯи лайк мураттаб аст (LIMIT 20) — лайкҳо, то reel он ҷо бошад.
for t in (tB, tC, tD, tF): call("POST", f"/reels/{rid2}/like", tok=t)
# E ҳеҷ гоҳ ин reel-ро надидааст (smart онро пинҳон намекунад) ва кэш надорад.
v = views_of(tE, "reel", rid2, f"тамошо якхела {S}")
views_same("reel: тамошоҳо дар /reels, smart, профил, explore, ҷустуҷӯ, ягона — 3", v, 3)
st, stt = call("GET", f"/reels/{rid2}/stats", tok=tA)
ok("reel: омори соҳиб ҳамон 3", stt.get("views") == 3, stt)

# Пост: тамошо дар explore == омори соҳиб; такрор ҳисоб намешавад.
st, p2 = call("POST", "/posts/", {"caption": f"тамошои пост {S}", "media": [{"url": IMG, "type": "image"}]}, tA)
pid2 = p2["_id"]
call("POST", f"/posts/view/{pid2}", tok=tB); call("POST", f"/posts/view/{pid2}", tok=tB)
call("POST", "/posts/view-batch", {"postIds": [pid2]}, tC)
for t in (tB, tC, tD, tE): call("POST", f"/posts/{pid2}/like", tok=t)  # explore аз рӯи лайк
v = views_of(tF, "post", pid2, f"тамошои пост {S}")
st, pst = call("GET", f"/posts/{pid2}/stats", tok=tA)
# Пеш танҳо Explore рақам дошт; профил ва пости кушодашуда умуман
# views надоштанд, ва ҷустуҷӯ ба ҷои он лайкҳоро нишон медод.
views_same("пост: тамошоҳо дар explore, профил, /profile, ҷустуҷӯ, ягона — 2", v, 2)
ok("пост: омори соҳиб ҳамон 2", pst.get("views") == 2, pst)
# Соҳиб ҳам дар профили худ (/profile/me) ҳамон рақамро мебинад.
st, me = call("GET", "/profile/me", tok=tA)
x = find(me, pid2)
ok("пост: /profile/me — ҳамон 2", x is not None and x.get("viewsCount") == 2 and x.get("views") == 2, x)

# ── КЭШИ ГАРМ: тамошо/лайк/обуна баъди он ки экранҳо аллакай кушода буданд ──
# ⚠️ Шикояти соҳиб: «дар Explore тамошо меафзояд, дар профил 5 мемонад».
# Санҷиши боло бо корбаре буд, ки кэш надошт. Ин ҷо G ва A аввал ҳамаи
# экранҳоро мекушоянд (кэши ҷавобҳо гарм мешавад: профил 3с, explore ва
# ҷустуҷӯ 30с), баъд бинандаи нав тамошо мекунад ва ФАВРАН ҳамон экранҳо
# бояд рақами навро диҳанд — на рақами кэшшуда.
tG, G = user(f"yg{S}", "+992900890107"); tH, H = user(f"yh{S}", "+992900890108")
tI, I = user(f"yi{S}", "+992900890109")

def owner_views(kind, id_):
    # Соҳиб: профили худ (ҷадвал + /profile/me) ва ягона.
    paths = ([("profile", f"/users/{A}/reels"), ("single", f"/reels/{id_}")] if kind == "reel" else
             [("profile", f"/users/{A}/posts"), ("profileMe", "/profile/me"), ("single", f"/posts/{id_}")])
    out = {}
    for name, p in paths:
        st, r = call("GET", p, tok=tA)
        x = find(r, id_)
        out[name] = None if x is None else (x.get("viewsCount"), x.get("views"))
    return out

def all_same(label, vs, expect):
    flat = {}
    for who, v in vs.items():
        for k, t in v.items():
            flat[f"{who}.{k}"] = t
    missing = [k for k, t in flat.items() if t is None]
    vals = {t for t in flat.values() if t is not None}
    ok(label, not missing and vals == {(expect, expect)}, flat)

before_r = views_of(tG, "reel", rid2, f"тамошо якхела {S}"); before_ro = owner_views("reel", rid2)
before_p = views_of(tG, "post", pid2, f"тамошои пост {S}"); before_po = owner_views("post", pid2)
all_same("кэши гарм: reel пеш аз тамошои нав — 3 дар ҳама ҷо", {"G": before_r, "A": before_ro}, 3)
all_same("кэши гарм: пост пеш аз тамошои нав — 2 дар ҳама ҷо", {"G": before_p, "A": before_po}, 2)
st, hv = call("POST", f"/reels/{rid2}/view", tok=tH)
st, iw = call("POST", f"/reels/{rid2}/watch", {"watchMs": 1200, "completed": False}, tI)
ok("reel: ҷавоби /view ва /watch рақами навро медиҳад (4, 5)",
   hv.get("viewsCount") == 4 and iw.get("viewsCount") == 5, (hv, iw))
# Бе sleep: «фавран» маънои дархости навбатиро дорад.
all_same("кэши гарм: reel баъди 2 тамошои нав — 5 ФАВРАН дар ҳама ҷо (G ва соҳиб)",
         {"G": views_of(tG, "reel", rid2, f"тамошо якхела {S}"), "A": owner_views("reel", rid2)}, 5)
st, pv = call("POST", f"/posts/view/{pid2}", tok=tH)
ok("пост: /posts/view рақами навро медиҳад (3)", pv.get("viewsCount") == 3 and pv.get("views") == 3, pv)
all_same("кэши гарм: пост баъди /posts/view — 3 ФАВРАН дар ҳама ҷо (G ва соҳиб)",
         {"G": views_of(tG, "post", pid2, f"тамошои пост {S}"), "A": owner_views("post", pid2)}, 3)
st, pb = call("POST", "/posts/view-batch", {"postIds": [pid2]}, tI)
ok("пост: /posts/view-batch рақамҳоро медиҳад (4)", (pb.get("views") or {}).get(pid2) == 4, pb)
all_same("кэши гарм: пост баъди 2 тамошои нав — 4 ФАВРАН дар ҳама ҷо (G ва соҳиб)",
         {"G": views_of(tG, "post", pid2, f"тамошои пост {S}"), "A": owner_views("post", pid2)}, 4)
st, stt = call("GET", f"/reels/{rid2}/stats", tok=tA)
ok("кэши гарм: омори reel-и соҳиб ҳамон 5", stt.get("views") == 5, stt)
st, pst = call("GET", f"/posts/{pid2}/stats", tok=tA)
ok("кэши гарм: омори пости соҳиб ҳамон 4", pst.get("views") == 4, pst)

# Лайк / шарҳ / паҳн / сабт бо кэши гарм — экранҳо аввал кушода, баъд амал.
def counters(tok, kind, id_):
    paths = ([("reels", "/reels/?limit=50"), ("profile", f"/users/{A}/reels"),
              ("explore", "/explore"), ("single", f"/reels/{id_}")] if kind == "reel" else
             [("profile", f"/users/{A}/posts"), ("profileU", f"/profile/ya{S}"),
              ("explore", "/explore"), ("single", f"/posts/{id_}")])
    out = {}
    for name, p in paths:
        x = get_item(tok, p, id_)
        if x is CROWDED: continue
        out[name] = None if x is None else (x.get("likesCount"), x.get("commentsCount"), x.get("sharesCount"))
    return out
for kind, id_, base in (("reel", rid2, "/reels"), ("post", pid2, "/posts")):
    b0 = counters(tG, kind, id_)
    call("POST", f"{base}/{id_}/like", tok=tH)
    call("POST", f"{base}/{id_}/comments", {"text": "гарм"}, tH)
    call("POST", f"{base}/{id_}/share", tok=tH)
    call("POST", f"{base}/{id_}/save", tok=tH)
    b1 = counters(tG, kind, id_)
    present = {k: t for k, t in b1.items() if t is not None}
    grew = all(b0.get(k) is None or (all(isinstance(a, int) and isinstance(b, int) and a == b + 1 for a, b in zip(t, b0[k])))
               for k, t in present.items())
    ok(f"кэши гарм: {kind} лайк/шарҳ/паҳн +1 ФАВРАН дар ҳама ҷо",
       len(present) >= 3 and len({t for t in present.values()}) == 1 and grew, (b0, b1))

# Обуначиён / обунаҳо / шумораи постҳо дар сарлавҳаи профил (кэши гарм).
def header(tok):
    out = {}
    for name, p in (("profileU", f"/profile/ya{S}"), ("users", f"/users/{A}")):
        st, r = call("GET", p, tok=tok)
        u = r.get("user", r) if isinstance(r, dict) else {}
        out[name] = (u.get("followersCount"), u.get("followingCount"), u.get("postsCount"))
    st, r = call("GET", "/profile/me", tok=tA)
    u = r.get("user", r) if isinstance(r, dict) else {}
    out["me"] = (u.get("followersCount"), u.get("followingCount"), u.get("postsCount"))
    return out
h0 = header(tG)
call("POST", f"/follow/{A}", tok=tI)
h1 = header(tG)
ok("кэши гарм: обуначиён +1 ФАВРАН дар /profile, /users ва /profile/me",
   len({t for t in h1.values()}) == 1 and all(h1[k][0] == h0[k][0] + 1 for k in h1), (h0, h1))
# Ҷустуҷӯи корбарон ҳамон рақами обуначиёнро медиҳад, ки сарлавҳаи профил.
fc = {}
for name, p in (("search", f"/search/?q=ya{S}"), ("searchUsers", f"/search/users?q=ya{S}")):
    st, r = call("GET", p, tok=tG)
    lst = r.get("users", []) if isinstance(r, dict) else (r if isinstance(r, list) else [])
    hit = [u for u in lst if (u.get("_id") or u.get("id")) == A]
    fc[name] = hit[0].get("followersCount") if hit else None
ok("обуначиён: ҷустуҷӯ == сарлавҳаи профил", set(fc.values()) == {h1["profileU"][0]}, (fc, h1))
call("POST", f"/follow/{A}", tok=tI); call("DELETE", f"/follow/{A}", tok=tI)
h2 = header(tG)
ok("кэши гарм: бекор кардани обуна −1 ФАВРАН дар ҳама ҷо",
   len({t for t in h2.values()}) == 1 and all(h2[k][0] == h0[k][0] for k in h2), (h0, h2))

# ── ОБУНА аз Reels баъди «бозкушоӣ» ─────────────────────────────────
# Клиент баъди бозкушоӣ маълумоти навро аз сервер мегирад: он бояд
# обунаро нигоҳ дорад (на кэши куҳна). F ба A аз Reels обуна мешавад.
st, fr = call("POST", f"/follow/{A}", tok=tF)
ok("обуна аз Reels: сервер қабул кард", st < 400 and fr.get("following") is True, fr)
st, sm = call("GET", "/reels/smart?limit=50", tok=tF)
x = find(sm, rid2)
ok("обуна: /reels/smart user.isFollowing=true", x is not None and (x.get("user") or {}).get("isFollowing") is True, x and x.get("user"))
st, rl = call("GET", "/reels/?limit=50", tok=tF)
x = find(rl, rid2)
ok("обуна: /reels/ user.isFollowing=true", x is not None and (x.get("user") or {}).get("isFollowing") is True, x and x.get("user"))

bad = [x for x in res if not x[0]]
print()
if crowded:
    print(f"  ℹ️  Explore пур аст (БД-и муштарак): {len(crowded)} id дар 15 саҳифа набуд — танҳо дигар экранҳо санҷида шуданд")
for g_, n_, d in res: print(("  ✅ " if g_ else "  ❌ ") + n_ + ("" if g_ else f"\n       → {d}"))
print(f"\n{len(res) - len(bad)}/{len(res)} гузашт")
sys.exit(1 if bad else 0)
