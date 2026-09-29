#!/usr/bin/env python3
"""Мувофиқати маълумот байни барнома ва сервер (майдонҳое, ки барнома мехонад).
 ⚠️ Сервери МАҲАЛЛӢ.
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
S = os.environ.get("SUFFIX", "ct")
tA, A = user(f"ka{S}", "+992900900101"); tB, Bb = user(f"kb{S}", "+992900900102")
tC, C = user(f"kc{S}", "+992900900103")
IMG = "https://example.com/p.jpg"
call("POST", f"/follow/{A}", tok=tB); call("POST", f"/follow/{A}", tok=tC); call("POST", f"/follow/{Bb}", tok=tC)
st, p = call("POST", "/posts/", {"caption": "контракт", "media": [{"url": IMG, "type": "image"}], "location": "Душанбе"}, tA)
pid = p.get("_id")
call("POST", f"/posts/{pid}/like", tok=tA); call("POST", f"/posts/{pid}/share", tok=tB)

st, me = call("GET", "/profile/me", tok=tA)
mp = next((x for x in me.get("posts", []) if x.get("_id") == pid), {})
ok("профили ман: пост бо муаллиф (ном)", (mp.get("user") or {}).get("username") == f"ka{S}", mp.get("user"))
ok("профили ман: liked=true", mp.get("liked") is True, mp.get("liked"))
ok("профили ман: isPinned ва location ҳаст", "isPinned" in mp and mp.get("location") == "Душанбе", mp)

st, feed = call("GET", "/posts/?limit=20", tok=tB)
fp = next((x for x in feed.get("posts", []) if x.get("_id") == pid), {})
ok("лента: sharesCount = 1", fp.get("sharesCount") == 1, fp.get("sharesCount"))
ok("лента: collaborators ва taggedUsers ҳаст", "collaborators" in fp and "taggedUsers" in fp, list(fp.keys()))

st, one = call("GET", f"/posts/{pid}", tok=tB)
ok("пости ягона: location", one.get("location") == "Душанбе", one.get("location"))

st, cm = call("POST", f"/posts/{pid}/comments", {"text": "салом"}, tB)
ok("шарҳи нав бо ном ва аватар", (cm.get("user") or {}).get("username") == f"kb{S}", cm.get("user"))

# Хоҳиши обуна ба ҳисоби пӯшида
call("PUT", "/profile/", {"isPrivate": True}, tC)
tD, D = user(f"kd{S}", "+992900900104")
call("POST", f"/follow/{C}", tok=tD)
st, u = call("GET", f"/users/{C}", tok=tD)
ok("«Дархост фиристода шуд» баъди аз нав кушодан", u.get("followRequestSent") is True, u.get("followRequestSent"))
st, u = call("GET", f"/users/{A}", tok=tC)
ok("обунаҳои умумӣ: B ба A обуна аст (C мебинад)", u.get("mutualCount", 0) >= 1 and f"kb{S}" in u.get("mutualNames", []), (u.get("mutualCount"), u.get("mutualNames")))

bad = [x for x in res if not x[0]]
print()
for g_, n_, d in res: print(("  ✅ " if g_ else "  ❌ ") + n_ + ("" if g_ else f"\n       → {d}"))
print(f"\n{len(res) - len(bad)}/{len(res)} гузашт")
sys.exit(1 if bad else 0)
