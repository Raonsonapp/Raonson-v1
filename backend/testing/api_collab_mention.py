#!/usr/bin/env python3
"""Ҳамкорӣ дар пост ва «Илова ба сториси худ» (мисли Instagram).
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

def ok(n, c, d=""): res.append((bool(c), n, str(d)[:180]))
def jd(x): return json.dumps(x, ensure_ascii=False)
S = os.environ.get("SUFFIX", "col")
tA, A = user(f"ca{S}", "+992900980001")   # муаллиф
tB, Bb = user(f"cb{S}", "+992900980002")  # ҳамкор
tC, C = user(f"cc{S}", "+992900980003")   # обуначии ҳамкор
if not (tA and tB and tC): print("!! вуруд нашуд"); sys.exit(1)
nB, nA = f"cb{S}".lower(), f"ca{S}".lower()
st, _ = call("POST", f"/follow/{Bb}", tok=tC); ok("обуна шуд", st in (200, 201), st)

def notifs(tok):
    st, r = call("GET", "/notifications", tok=tok)
    return r if isinstance(r, list) else (r.get("notifications") or [])
def ids(lst): return [p.get("_id") for p in lst]
def user_posts(tok, uid):
    st, r = call("GET", f"/users/{uid}/posts", tok=tok); return r.get("posts") or []

# ── Ҳамкорӣ ──
st, p = call("POST", "/posts/", {"caption": "ҳамкорӣ", "media": [{"url": "https://example.com/c.jpg", "type": "image"}], "collaborators": [nB]}, tA)
pid = p.get("_id"); ok("пост бо даъват сохта шуд", st in (200, 201) and pid, (st, p))
time.sleep(1.5)
n = [x for x in notifs(tB) if x.get("type") == "collab_invite"]
ok("даъват дар огоҳиномаҳо омад", len(n) == 1, n)
st, pend = call("GET", "/collabs/pending", tok=tB)
inv = [i for i in pend.get("invites", []) if i.get("postId") == pid]
ok("даъват дар рӯйхати интизор бо расм", inv and inv[0].get("thumb", "").startswith("https://"), inv)
ok("то қабул дар профили ҳамкор нест", pid not in ids(user_posts(tB, Bb)))
st, g = call("GET", f"/posts/{pid}", tok=tC)
ok("то қабул номи ҳамкор дар пост нест", not g.get("collaborators"), g.get("collaborators"))

st, _ = call("POST", f"/posts/{pid}/collab/accept", tok=tC)
ok("бегона даъватро қабул карда наметавонад", st == 404, st)
st, _ = call("POST", f"/posts/{pid}/collab/accept", tok=tB)
ok("ҳамкор қабул кард", st == 200, st)
time.sleep(1)
ok("огоҳиномаи даъват пас аз ҷавоб нест шуд", not [x for x in notifs(tB) if x.get("type") == "collab_invite"])
ok("муаллиф «қабул кард» гирифт", [x for x in notifs(tA) if x.get("type") == "collab_accepted"])
ok("пост дар профили ҳамкор", pid in ids(user_posts(tC, Bb)))
ok("пост дар профили муаллиф", pid in ids(user_posts(tC, A)))
st, g = call("GET", f"/posts/{pid}", tok=tC)
cu = g.get("collaboratorUsers") or []
ok("номи ҳамкор (на ID) дар пост", cu and cu[0].get("username") == nB, cu)
st, f = call("GET", "/posts/feed?mode=following", tok=tC)
fl = f.get("posts") if isinstance(f, dict) else f
ok("обуначии ҳамкор постро дар лентаи обунаҳо мебинад", pid in ids(fl or []), len(fl or []))
row = [x for x in (fl or []) if x.get("_id") == pid]
ok("дар лента ҳам номи ҳамкор", row and (row[0].get("collaboratorUsers") or [{}])[0].get("username") == nB, row[:1])

# Баромадан аз ҳамкорӣ
st, _ = call("POST", f"/posts/{pid}/collab/decline", tok=tB)
ok("ҳамкор худро хориҷ кард", st == 200, st)
ok("пас аз баромадан дар профили ӯ нест", pid not in ids(user_posts(tC, Bb)))
st, g = call("GET", f"/posts/{pid}", tok=tC)
ok("пас аз баромадан номаш дар пост нест", not g.get("collaboratorUsers"), g.get("collaboratorUsers"))

# Рад кардан
st, p2 = call("POST", "/posts/", {"caption": "рад", "media": [{"url": "https://example.com/d.jpg", "type": "image"}], "collaborators": [nB]}, tA)
pid2 = p2.get("_id"); time.sleep(1)
st, _ = call("POST", f"/posts/{pid2}/collab/decline", tok=tB)
ok("даъват рад шуд", st == 200, st)
ok("радшуда дар профили ӯ нест", pid2 not in ids(user_posts(tC, Bb)))

# Муаллиф ҳамкорро хориҷ мекунад
st, p3 = call("POST", "/posts/", {"caption": "хориҷ", "media": [{"url": "https://example.com/e.jpg", "type": "image"}], "collaborators": [nB]}, tA)
pid3 = p3.get("_id"); time.sleep(1)
call("POST", f"/posts/{pid3}/collab/accept", tok=tB)
st, lst = call("GET", f"/posts/{pid3}/collabs", tok=tA)
ok("муаллиф рӯйхати ҳамкоронро мебинад", [x for x in lst.get("collaborators", []) if x.get("_id") == Bb and x.get("status") == "accepted"], lst)
st, _ = call("GET", f"/posts/{pid3}/collabs", tok=tB)
ok("ғайримуаллиф рӯйхатро намебинад", st == 404, st)
st, _ = call("DELETE", f"/posts/{pid3}/collab/{Bb}", tok=tB)
ok("ғайримуаллиф хориҷ карда наметавонад", st == 404, st)
st, _ = call("DELETE", f"/posts/{pid3}/collab/{Bb}", tok=tA)
ok("муаллиф ҳамкорро хориҷ кард", st == 200, st)
ok("пас аз хориҷ дар профили ҳамкор нест", pid3 not in ids(user_posts(tC, Bb)))
st, _ = call("POST", f"/posts/{pid3}/collab/accept", tok=tB)
ok("хориҷшуда дубора қабул карда наметавонад", st == 404, st)

# ── Сторис: зикр → «Илова ба сториси худ» ──
st, s1 = call("POST", "/stories/", {"mediaUrl": "https://example.com/s.jpg", "mediaType": "image", "mentions": [{"username": nB, "x": 0.5, "y": 0.5}]}, tA)
sid = s1.get("_id") or s1.get("id"); ok("сторис бо зикр сохта шуд", st in (200, 201) and sid, (st, s1))
time.sleep(1.5)
ok("зикршуда огоҳинома гирифт", [x for x in notifs(tB) if x.get("type") == "story_mention"])
st, r = call("POST", "/stories/", {"sharedStoryId": sid}, tC)
ok("зикрнашуда илова карда наметавонад", st == 403, st)
st, r = call("POST", "/stories/", {"sharedStoryId": sid, "mediaUrl": "https://evil.example/x.jpg", "mediaType": "image"}, tB)
ok("зикршуда ба сториси худ илова кард", st in (200, 201), (st, r))
st, my = call("GET", "/stories/my", tok=tB)
mine = my if isinstance(my, list) else []
rs = [x for x in mine if x.get("sharedStoryUser") == nA]
ok("сториси нав бо «@муаллиф»", rs, mine[:1])
ok("медиа аз сториси асл (на аз барнома)", rs and rs[0].get("mediaUrl") == "https://example.com/s.jpg", rs[:1])
time.sleep(1)
ok("муаллиф огоҳинома гирифт", [x for x in notifs(tA) if x.get("type") == "story_reshared"])

bad = [x for x in res if not x[0]]
print()
for g, n, d in res: print(("  ✅ " if g else "  ❌ ") + n + ("" if g else f"\n       → {d}"))
print(f"\n{len(res) - len(bad)}/{len(res)} гузашт")
sys.exit(1 if bad else 0)
