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

def views(tok, kind, id_):
    out = {}
    paths = ([("feed", "/posts/?limit=50"), ("smart", "/posts/smart-feed?limit=50"),
              ("profile", f"/users/{A}/posts"), ("profileMe", "/profile/me") if tok == tA else ("profileU", f"/profile/ya{S}"),
              ("explore", "/explore"), ("single", f"/posts/{id_}")]
             if kind == "post" else
             [("reels", "/reels/?limit=50"), ("smart", "/reels/smart?limit=50"),
              ("profile", f"/users/{A}/reels"), ("explore", "/explore"), ("single", f"/reels/{id_}")])
    for name, p in paths:
        st, r = call("GET", p, tok=tok)
        x = find(r, id_)
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
st, p = call("POST", "/posts/", {"caption": "якхела", "media": [{"url": IMG, "type": "image"}]}, tA); pid = p["_id"]
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
st, r = call("POST", "/reels/", {"videoUrl": VID, "caption": "reel якхела"}, tA); rid = r.get("_id")
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
        st, r = call("GET", p, tok=tok)
        x = find(r, id_)
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
st, r2 = call("POST", "/reels/", {"videoUrl": VID, "caption": "тамошо якхела"}, tA); rid2 = r2.get("_id")
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
v = views_of(tE, "reel", rid2, "тамошо якхела")
views_same("reel: тамошоҳо дар /reels, smart, профил, explore, ҷустуҷӯ, ягона — 3", v, 3)
st, stt = call("GET", f"/reels/{rid2}/stats", tok=tA)
ok("reel: омори соҳиб ҳамон 3", stt.get("views") == 3, stt)

# Пост: тамошо дар explore == омори соҳиб; такрор ҳисоб намешавад.
st, p2 = call("POST", "/posts/", {"caption": "тамошои пост", "media": [{"url": IMG, "type": "image"}]}, tA)
pid2 = p2["_id"]
call("POST", f"/posts/view/{pid2}", tok=tB); call("POST", f"/posts/view/{pid2}", tok=tB)
call("POST", "/posts/view-batch", {"postIds": [pid2]}, tC)
for t in (tB, tC, tD, tE): call("POST", f"/posts/{pid2}/like", tok=t)  # explore аз рӯи лайк
v = views_of(tF, "post", pid2, "тамошои пост")
st, pst = call("GET", f"/posts/{pid2}/stats", tok=tA)
# Пеш танҳо Explore рақам дошт; профил ва пости кушодашуда умуман
# views надоштанд, ва ҷустуҷӯ ба ҷои он лайкҳоро нишон медод.
views_same("пост: тамошоҳо дар explore, профил, /profile, ҷустуҷӯ, ягона — 2", v, 2)
ok("пост: омори соҳиб ҳамон 2", pst.get("views") == 2, pst)
# Соҳиб ҳам дар профили худ (/profile/me) ҳамон рақамро мебинад.
st, me = call("GET", "/profile/me", tok=tA)
x = find(me, pid2)
ok("пост: /profile/me — ҳамон 2", x is not None and x.get("viewsCount") == 2 and x.get("views") == 2, x)

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
for g_, n_, d in res: print(("  ✅ " if g_ else "  ❌ ") + n_ + ("" if g_ else f"\n       → {d}"))
print(f"\n{len(res) - len(bad)}/{len(res)} гузашт")
sys.exit(1 if bad else 0)
