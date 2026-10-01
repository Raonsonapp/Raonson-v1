#!/usr/bin/env python3
"""Ҳалқаи сторис — ЯК ҳолат дар ҲАМАИ экранҳо (мисли Instagram).

 Шикояти соҳиб: «сторисро дидам, вале дар Home (сарлавҳаи пост) ҳалқа
 ранга монд». Пеш танҳо GET /stories `viewed` медод; лента, Reels,
 профил, Explore, ҷустуҷӯ, чат ва шарҳҳо танҳо `hasStory` доштанд.

 Ҳоло ҳар ҷо: user.hasStory, user.hasUnseenStory, user.storySeen.
   B сторис мегузорад → A дар ҳама ҷо hasStory=true, unseen.
   A мебинад          → дар ҳама ҷо storySeen=true (фавран, бе кэш).
   B сториси нав      → боз unseen.
 ⚠️ Ба сервери МАҲАЛЛӢ мезанад.
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
def ok(n, c, d=""): res.append((bool(c), n, str(d)[:300]))

S = os.environ.get("SUFFIX", "sr")
tA, A = user(f"rga{S}", "+992900981001")   # тамошобин
tB, Bb = user(f"rgb{S}", "+992900981002")  # муаллиф (сторис мегузорад)
tC, C = user(f"rgc{S}", "+992900981003")   # лайккунандагон — то пост/Reel
tD, D = user(f"rgd{S}", "+992900981004")   # дар Explore (аз рӯи лайк) бошанд
if not (tA and tB and tC and tD): print("!! вуруд нашуд"); sys.exit(1)
uname = f"rgb{S}"
IMG = "https://example.com/ring.jpg"; VID = "https://example.com/ring.mp4"

call("POST", f"/follow/{Bb}", tok=tA)
st, p = call("POST", "/posts/", {"caption": f"ring{S} пост", "media": [{"url": IMG, "type": "image"}]}, tB)
pid = p.get("_id") or p.get("id")
st, r = call("POST", "/reels/", {"videoUrl": VID, "caption": f"ring{S} reel"}, tB)
rid = r.get("_id") or r.get("id")
ok("пост ва Reel сохта шуданд", pid and rid, (p, r))
for t in (tA, tC, tD):
    call("POST", f"/posts/{pid}/like", tok=t)
# Reel — танҳо як лайк: Explore 20 Reel-и беҳтаринро медиҳад ва ин сюита
# набояд Reel-и api_consistency.py-ро (2 лайк) аз он ҷо барорад.
call("POST", f"/reels/{rid}/like", tok=tA)
call("POST", f"/posts/{pid}/comments", {"text": "шарҳи муаллиф"}, tB)
st, ch = call("GET", f"/chat/with/{A}", tok=tB)
chat_id = ch.get("chatId") or ch.get("id") or ch.get("_id")
call("POST", f"/chat/{chat_id}/messages", {"text": "салом"}, tB)

def find_user(obj, uid, path="", out=None):
    """Ҳамаи объектҳои корбари uid (бо майдони hasStory) дар ҷавоб."""
    if out is None: out = []
    if isinstance(obj, dict):
        if (obj.get("_id") or obj.get("id")) == uid and "hasStory" in obj: out.append(obj)
        for k, v in obj.items(): find_user(v, uid, path + "." + k, out)
    elif isinstance(obj, list):
        for v in obj: find_user(v, uid, path, out)
    return out

q = urllib.parse.quote
SURFACES = [
    ("лента /posts/feed",       "/posts/feed?limit=50"),
    ("smart-feed",             "/posts/smart-feed?limit=50"),
    ("пост /posts/:id",         f"/posts/{pid}"),
    ("профил: постҳо",          f"/users/{Bb}/posts"),
    ("профил: reels",           f"/users/{Bb}/reels"),
    ("профил: сарлавҳа /users", f"/users/{Bb}"),
    ("профил /profile/:name",   f"/profile/{uname}"),
    ("reels /reels/",           "/reels/?limit=50"),
    ("reels smart",             "/reels/smart?limit=50"),
    ("reel /reels/:id",         f"/reels/{rid}"),
    ("explore",                 "/explore"),
    ("ҷустуҷӯ /search",         f"/search/?q={q(uname)}"),
    ("ҷустуҷӯ /search/users",   f"/search/users?q={q(uname)}"),
    ("шарҳҳо",                  f"/posts/{pid}/comments"),
    ("чатҳо",                   "/chat/"),
]

def ring_states(tok):
    out = {}
    for name, path in SURFACES:
        st, body = call("GET", path, tok=tok)
        us = find_user(body, Bb)
        if not us:
            out[name] = None
            continue
        out[name] = {(u.get("hasStory"), u.get("hasUnseenStory"), u.get("storySeen")) for u in us}
    return out

def check(label, states, expect, allow_missing=("smart-feed", "reels smart", "explore")):
    # smart-feed/reels smart пости дидашударо пинҳон карда метавонанд ва
    # Explore танҳо 40 пости беҳтаринро медиҳад — он ҷо «набудан» хато нест.
    for name, st in states.items():
        if st is None:
            ok(f"{label}: {name} — корбар ёфт шуд", name in allow_missing, "нест")
            continue
        ok(f"{label}: {name}", st == {expect}, st)

# 1) Ҳанӯз сторис нест.
s0 = ring_states(tA)
check("бе сторис", s0, (False, False, False))

# 2) B сторис мегузорад → A дар ҳама ҷо «надида».
st, s = call("POST", "/stories/", {"mediaUrl": IMG, "mediaType": "image"}, tB)
sid = s.get("_id") or s.get("id")
ok("сторис сохта шуд", sid, s)
s1 = ring_states(tA)
check("сторис нав", s1, (True, True, False))

# 3) A мебинад → ФАВРАН дар ҳама ҷо хокистарӣ (кэш халал намерасонад).
st, v = call("POST", f"/stories/{sid}/view", tok=tA)
ok("POST /stories/:id/view", st < 400, v)
s2 = ring_states(tA)
check("баъди тамошо", s2, (True, False, True))

# Корбари дигар (C ба B обуна нест) — ҳалқа надорад (мисли GET /stories).
st, body = call("GET", f"/users/{Bb}", tok=tC)
ok("бегона (обуна нест): hasStory=false", body.get("hasStory") is False, body.get("hasStory"))

# 4) B сториси НАВ → боз ранга.
st, s = call("POST", "/stories/", {"mediaUrl": IMG, "mediaType": "image"}, tB)
sid2 = s.get("_id") or s.get("id")
s3 = ring_states(tA)
check("сториси дуюм", s3, (True, True, False))
call("POST", f"/stories/{sid2}/view", tok=tA)
s4 = ring_states(tA)
check("ҳарду дида шуд", s4, (True, False, True))

# 5) Соҳиб ҳалқаи худро мебинад: аввал ранга, баъди тамошо хокистарӣ.
st, me = call("GET", "/profile/me", tok=tB)
u = me.get("user") or {}
ok("соҳиб: /profile/me hasUnseenStory=true", u.get("hasStory") is True and u.get("hasUnseenStory") is True, u.get("hasUnseenStory"))
call("POST", f"/stories/{sid}/view", tok=tB); call("POST", f"/stories/{sid2}/view", tok=tB)
st, me = call("GET", "/profile/me", tok=tB)
u = me.get("user") or {}
ok("соҳиб: баъди тамошо storySeen=true", u.get("storySeen") is True, u)

bad = [x for x in res if not x[0]]
print()
for g, n, d in res: print(("  ✅ " if g else "  ❌ ") + n + ("" if g else f"\n       → {d}"))
print(f"\n{len(res) - len(bad)}/{len(res)} гузашт")
sys.exit(1 if bad else 0)
