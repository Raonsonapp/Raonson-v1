#!/usr/bin/env python3
"""«Навбати ту» (Add Yours) — стикери занҷирии сторис, мисли Instagram.
 ⚠️ Ба сервери МАҲАЛЛӢ мезанад.
"""
import json, os, sys, time, urllib.request, urllib.error
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
S = os.environ.get("SUFFIX", "ay")
tA, A = user(f"ya{S}", "+992900940001"); tB, Bb = user(f"yb{S}", "+992900940002")
tC, C = user(f"yc{S}", "+992900940003"); tP, P = user(f"yp{S}", "+992900940004")
call("POST", f"/follow/{A}", tok=tB); call("POST", f"/follow/{A}", tok=tC); call("POST", f"/follow/{Bb}", tok=tC)
IMG = "https://example.com/s.jpg"
def story(tok, sticker):
    return call("POST", "/stories/", {"mediaUrl": IMG, "mediaType": "image", "sticker": sticker}, tok)
def sticker_of(tok, owner, sid):
    st, r = call("GET", f"/stories/?userId={owner}", tok=tok)
    lst = r if isinstance(r, list) else r.get("stories", [])
    return next((s.get("sticker") for s in lst if s.get("_id") == sid), None)

st, r = story(tA, {"kind": "addyours", "prompt": "Акси аввали телефонат"})
root = r.get("_id") or r.get("id")
ok("занҷир сохта шуд", st in (200, 201) and root, (st, r))
st, _ = story(tA, {"kind": "addyours"})
ok("бе мавзӯъ ва бе joinOf — 400", st == 400, st)

s = sticker_of(tB, A, root) or {}
ok("тамошобин стикерро мебинад", s.get("kind") == "addyours" and s.get("prompt") == "Акси аввали телефонат", s)
ok("1 иштирокчӣ, B ҳанӯз ҳамроҳ нашудааст", s.get("participants") == 1 and s.get("joined") is False, s)

st, r = story(tB, {"kind": "addyours", "joinOf": root, "prompt": "мавзӯи дигар"})
bsid = r.get("_id") or r.get("id")
ok("B ҳамроҳ шуд", st in (200, 201) and bsid, (st, r))
time.sleep(0.5)
sb = sticker_of(tC, Bb, bsid) or {}
ok("мавзӯи занҷир НАМЕИВАЗАД", sb.get("prompt") == "Акси аввали телефонат", sb)
ok("chainId = сторияи аввал", sb.get("chainId") == root, sb)
s = sticker_of(tB, A, root) or {}
ok("2 иштирокчӣ, B joined=true", s.get("participants") == 2 and s.get("joined") is True, s)

st, n = call("GET", "/notifications/", tok=tA)
lst = n if isinstance(n, list) else (n.get("notifications") or n.get("items") or [])
ok("оғозкунанда огоҳ шуд", any((x.get("type") or x.get("kind")) == "story_addyours" for x in lst), str(lst)[:200])

story(tC, {"kind": "addyours", "joinOf": bsid})  # аз сторияи B ҳамроҳ мешавад
st, ch = call("GET", f"/stories/addyours/{root}", tok=tB)
ok("рӯйхати занҷир: 3 сторис", st == 200 and len(ch.get("stories", [])) == 3, (st, ch))
ok("ҳамроҳшавӣ аз сторияи дигар ҳам ба ҳамон занҷир", ch.get("participants") == 3, ch)

call("PUT", "/users/me/privacy", {"isPrivate": True}, tC); call("PUT", "/profile/privacy", {"private": True}, tC)
call("POST", f"/users/{A}/block", tok=tP)
st, ch = call("GET", f"/stories/addyours/{root}", tok=tP)
ok("басташуда сторияи A-ро дар занҷир намебинад", st == 200 and all(x["user"]["_id"] != A for x in ch.get("stories", [])), ch)
st, _ = call("GET", "/stories/addyours/nest", tok=tB)
ok("занҷири нест — 404", st == 404, st)

bad = [x for x in res if not x[0]]
print()
for g, n_, d in res: print(("  ✅ " if g else "  ❌ ") + n_ + ("" if g else f"\n       → {d}"))
print(f"\n{len(res) - len(bad)}/{len(res)} гузашт")
sys.exit(1 if bad else 0)
