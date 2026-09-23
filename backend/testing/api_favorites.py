#!/usr/bin/env python3
"""Лентаи «Обунаҳо» ва «Дӯстдоштаҳо» — мисли Instagram.
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
def ok(n, c, d=""): res.append((bool(c), n, str(d)[:200]))
def ids(r): return [p.get("_id") for p in (r.get("posts") or [])] if isinstance(r, dict) else []

S = os.environ.get("SUFFIX", "fv")
tMe, Me = user(f"fm{S}", "+992900950001")
tF, F = user(f"ff{S}", "+992900950002")   # обуна
tV, V = user(f"fv{S}", "+992900950003")   # обуна + дӯстдошта
tX, X = user(f"fx{S}", "+992900950004")   # бегона (кушода)
if not all([tMe, tF, tV, tX]): print("!! вуруд нашуд"); sys.exit(1)
call("POST", f"/follow/{F}", tok=tMe); call("POST", f"/follow/{V}", tok=tMe)
def post(tok, cap):
    st, p = call("POST", "/posts/", {"caption": cap, "media": [{"url": "https://example.com/a.jpg", "type": "image"}]}, tok)
    return p.get("_id") or p.get("id")
pF = post(tF, "аз обуна"); pV = post(tV, "аз дӯстдошта"); pX = post(tX, "аз бегона"); pMe = post(tMe, "аз худам")

st, r = call("POST", f"/users/{V}/favorite", {"favorite": True}, tMe)
ok("ба дӯстдоштаҳо илова шуд", st == 200 and r.get("favorite") is True, f"HTTP {st}: {r}")
st, r = call("GET", "/users/favorites", tok=tMe)
ok("рӯйхати дӯстдоштаҳо", V in json.dumps(r), r)
st, r = call("GET", f"/users/{V}", tok=tMe)
ok("профил isFavorite=true", r.get("isFavorite") is True, {k: r.get(k) for k in ("username", "isFavorite")})
st, r = call("POST", f"/users/{Me}/favorite", {"favorite": True}, tMe)
ok("худро илова кардан — рад", st == 400, f"HTTP {st}")

time.sleep(3.5)
st, r = call("GET", "/posts/feed?mode=following&limit=50", tok=tMe); fol = ids(r)
ok("«Обунаҳо»: пости обуна ҳаст", pF in fol, fol[:5])
ok("«Обунаҳо»: пости дӯстдошта ҳаст", pV in fol)
ok("«Обунаҳо»: пости худам ҳаст", pMe in fol)
ok("«Обунаҳо»: пости БЕГОНА нест", pX not in fol)
st, r = call("GET", "/posts/feed?mode=favorites&limit=50", tok=tMe); fav = ids(r)
ok("«Дӯстдоштаҳо»: танҳо дӯстдошта", pV in fav and pF not in fav and pX not in fav, fav[:5])
st, r = call("GET", "/posts/feed?limit=50", tok=tMe); allp = ids(r)
ok("лентаи умумӣ ҳамаашро дорад", pX in allp and pF in allp, allp[:5])
ok("кэш режимҳоро омехта НАКАРД", set(fav) != set(allp))

st, r = call("POST", f"/users/{V}/favorite", {"favorite": False}, tMe)
ok("аз дӯстдоштаҳо хориҷ шуд", r.get("favorite") is False, r)
time.sleep(3.5)
st, r = call("GET", "/posts/feed?mode=favorites&limit=50", tok=tMe)
ok("баъди хориҷ лентаи дӯстдоштаҳо холӣ", pV not in ids(r), ids(r)[:5])
st, r = call("GET", "/users/favorites", tok=tF)
ok("рӯйхати ман ба дигарон намоён нест", V not in json.dumps(r), r)

bad = [x for x in res if not x[0]]
print()
for g, n, d in res: print(("  ✅ " if g else "  ❌ ") + n + ("" if g else f"\n       → {d}"))
print(f"\n{len(res) - len(bad)}/{len(res)} гузашт")
sys.exit(1 if bad else 0)
