#!/usr/bin/env python3
"""«Лайкҳоро пинҳон кун» ва «Шарҳҳоро хомӯш кун» — дар ҲАР экран.
 Корбар: «лайкро пинҳон кун, шарҳро пинҳон кун дар профил ва Reels кор накард».
 ⚠️ Ба сервери МАҲАЛЛӢ мезанад.
"""
import json, os, sys, time, urllib.request, urllib.error
B = os.environ.get("BASE", "http://127.0.0.1:8099"); PW = "Test12345!"; res = []
def _once(m, p, body=None, tok=None):
    req = urllib.request.Request(B + p, data=json.dumps(body).encode() if body is not None else None, method=m)
    req.add_header('Content-Type', 'application/json')
    if tok: req.add_header('Authorization', 'Bearer ' + tok)
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            raw = r.read().decode(); return r.status, (json.loads(raw) if raw else {})
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
        try: return e.code, json.loads(raw)
        except Exception: return e.code, raw
    except Exception as e: return 0, str(e)
def call(m, p, body=None, tok=None):
    for a in range(4):
        st, r = _once(m, p, body, tok)
        if st != 429: return st, r
        time.sleep(4 * (a + 1))
    return st, r
def user(u, ph):
    call("POST", "/auth/register", {"username": u, "email": f"{u}@example.com", "password": PW, "fullName": u, "phone": ph})
    st, r = call("POST", "/auth/login", {"email": u, "password": PW})
    return r.get("accessToken"), (r.get("user") or {}).get("id") or (r.get("user") or {}).get("_id")
def ok(n, c, d=""): res.append((bool(c), n, str(d)[:220]))
def find(lst, i):
    if isinstance(lst, dict): lst = lst.get("posts") or lst.get("reels") or lst.get("data") or []
    return next((x for x in lst if (x.get("_id") or x.get("id")) == i), None)

S = os.environ.get("SUFFIX", "hd")
tA, A = user(f"ha{S}", "+992900970001"); tB, Bb = user(f"hb{S}", "+992900970002")
call("POST", f"/follow/{A}", tok=tB)
st, p = call("POST", "/posts/", {"caption": "x", "media": [{"url": "https://example.com/a.jpg", "type": "image"}]}, tA)
pid = p.get("_id") or p.get("id")
st, r = call("POST", "/reels/", {"videoUrl": "https://example.com/v.mp4", "caption": "r"}, tA)
rid = r.get("_id") or r.get("id") or (r.get("reel") or {}).get("_id")
for t in (tB,): call("POST", f"/posts/{pid}/like", tok=t); call("POST", f"/reels/{rid}/like", tok=t)
for t in (tA,): call("POST", f"/posts/{pid}/like", tok=t)

st, r = call("POST", f"/posts/{pid}/hide-likes", tok=tA); ok("пост: лайкҳо пинҳон шуд", r.get("hideLikes") is True, r)
st, r = call("POST", f"/posts/{pid}/toggle-comments", tok=tA); ok("пост: шарҳҳо хомӯш шуд", r.get("commentsOff") is True, r)
st, r = call("POST", f"/reels/{rid}/hide-likes", tok=tA); ok("Reel: лайкҳо пинҳон шуд", (r.get("hideLikes") is True), r)
st, r = call("POST", f"/reels/{rid}/toggle-comments", tok=tA); ok("Reel: шарҳҳо хомӯш шуд", (r.get("commentsOff") is True or r.get("commentsDisabled") is True), r)
time.sleep(3.5)

def check_post(name, path):
    st, r = call("GET", path, tok=tB)
    x = r if (isinstance(r, dict) and (r.get("_id") == pid)) else find(r, pid)
    if x is None and isinstance(r, dict) and isinstance(r.get("post"), dict): x = r["post"]
    if x is None: ok(f"{name}: пост ёфт шуд", False, f"HTTP {st} {str(r)[:120]}"); return
    lc = x.get("likesCount", x.get("likes"))
    ok(f"{name}: шумораи лайк ба бегона ПИНҲОН", lc in (-1, None) or x.get("hideLikes") is True and lc in (-1, None), {"likesCount": lc, "hideLikes": x.get("hideLikes")})
    ok(f"{name}: «шарҳҳо хомӯш» ба барнома мерасад", x.get("commentsOff") is True or x.get("commentsDisabled") is True, {k: x.get(k) for k in ("commentsOff", "commentsDisabled")})

check_post("лента", "/posts/feed?limit=50")
check_post("лентаи ҳушманд", "/posts/smart-feed?limit=50")
check_post("профил", f"/users/{A}/posts")
check_post("пост аз ID", f"/posts/{pid}")

def check_reel(name, path):
    st, r = call("GET", path, tok=tB)
    x = r if (isinstance(r, dict) and (r.get("_id") == rid or r.get("id") == rid)) else find(r, rid)
    if x is None: ok(f"{name}: Reel ёфт шуд", False, f"HTTP {st} {str(r)[:120]}"); return
    lc = x.get("likesCount", x.get("likes"))
    ok(f"{name}: лайки Reel ба бегона ПИНҲОН", lc in (-1, None), {"likesCount": lc, "hideLikes": x.get("hideLikes")})
    ok(f"{name}: «шарҳҳо хомӯш» дар Reel", x.get("commentsOff") is True or x.get("commentsDisabled") is True, {k: x.get(k) for k in ("commentsOff", "commentsDisabled")})

check_reel("Reels", "/reels/?limit=50")
check_reel("Reels-и ҳушманд", "/reels/smart?limit=50")
check_reel("Reels-и профил", f"/users/{A}/reels")
check_reel("Reel аз ID", f"/reels/{rid}")

st, r = call("POST", f"/posts/{pid}/comments", {"text": "бояд рад шавад"}, tB)
ok("пост: бегона ба шарҳи хомӯш навишта НАМЕТАВОНАД", st in (403, 423), f"HTTP {st}: {r}")
st, r = call("POST", f"/reels/{rid}/comments", {"text": "бояд рад шавад"}, tB)
ok("Reel: бегона ба шарҳи хомӯш навишта НАМЕТАВОНАД", st in (403, 423), f"HTTP {st}: {r}")
st, r = call("GET", f"/posts/{pid}", tok=tA)
x = r.get("post", r) if isinstance(r, dict) else {}
ok("соҳиб шумораи лайки худро МЕБИНАД", (x.get("likesCount") or 0) >= 1, x.get("likesCount"))

bad = [x for x in res if not x[0]]
print()
for g, n, d in res: print(("  ✅ " if g else "  ❌ ") + n + ("" if g else f"\n       → {d}"))
print(f"\n{len(res) - len(bad)}/{len(res)} гузашт")
sys.exit(1 if bad else 0)
