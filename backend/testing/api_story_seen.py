#!/usr/bin/env python3
"""Ҳалқаи сторис: «дида шуд» аз сервер — ҳам барои тамошобин, ҳам барои соҳиб.
 Корбар: «ҳалқаи сторисам гум намешавад, дар ҳоле ки ман сторисамро худам дидаам».
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
def viewed(tok, owner, sid):
    st, r = call("GET", f"/stories/?userId={owner}", tok=tok)
    lst = r if isinstance(r, list) else r.get("stories", [])
    x = next((s for s in lst if s.get("_id") == sid), {})
    return x.get("viewed")
S = os.environ.get("SUFFIX", "sn")
tA, A = user(f"na{S}", "+992900980001"); tB, Bb = user(f"nb{S}", "+992900980002")
call("POST", f"/follow/{A}", tok=tB)
st, s = call("POST", "/stories/", {"mediaUrl": "https://example.com/s.jpg", "mediaType": "image"}, tA)
sid = s.get("_id") or s.get("id")
ok("стори бо майдони viewed=false меояд (тамошобин)", viewed(tB, A, sid) is False, viewed(tB, A, sid))
ok("стори бо майдони viewed=false меояд (соҳиб)", viewed(tA, A, sid) is False, viewed(tA, A, sid))
call("POST", f"/stories/{sid}/view", tok=tB); time.sleep(0.3)
ok("тамошобин дид → viewed=true", viewed(tB, A, sid) is True, viewed(tB, A, sid))
call("POST", f"/stories/{sid}/view", tok=tA); time.sleep(0.3)
ok("СОҲИБ стории худро дид → viewed=true", viewed(tA, A, sid) is True, viewed(tA, A, sid))
st, r = call("GET", f"/stories/{sid}/viewers", tok=tA)
ok("соҳиб дар рӯйхати бинандагон НЕСТ (мисли Instagram)", A not in json.dumps(r), r)
bad = [x for x in res if not x[0]]
print()
for g, n, d in res: print(("  ✅ " if g else "  ❌ ") + n + ("" if g else f"\n       → {d}"))
print(f"\n{len(res) - len(bad)}/{len(res)} гузашт")
sys.exit(1 if bad else 0)
