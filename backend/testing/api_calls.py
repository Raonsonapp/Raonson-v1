#!/usr/bin/env python3
"""Занги аудио/видео ва Live: канал ва token аз сервер.
 Корбар: «видеозвонок ва звонок бин ки воқеан мешавад ва одамҳо байни худ гап зада метавонанд».
 Agora номи каналро то 64 байт қабул мекунад — "uuid_uuid" 73 буд ва занг пайваст намешуд.
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
S = os.environ.get("SUFFIX", "cl")
tA, A = user(f"ca{S}", "+992900970001"); tB, Bb = user(f"cb{S}", "+992900970002"); tC, C = user(f"cc{S}", "+992900970003")

st, ra = call("POST", "/calls/token", {"peerId": Bb}, tA)
st2, rb = call("POST", "/calls/token", {"peerId": A}, tB)
ok("A → B: канал дода шуд", st == 200 and ra.get("channel"), (st, ra))
ok("ҳарду тараф ҲАМОН канал мегиранд", ra.get("channel") == rb.get("channel"), (ra, rb))
ok("канал < 64 байт (ҳадди Agora)", len(ra.get("channel", "x" * 99).encode()) < 64, ra.get("channel"))
ok("ID-ҳо дар номи канал нестанд", A not in ra.get("channel", "") and Bb not in ra.get("channel", ""), ra)
ok("майдони token ҳаст (холӣ, агар certificate набошад)", "token" in ra, ra)
st, rc = call("POST", "/calls/token", {"peerId": C}, tA)
ok("ҷуфти дигар — канали дигар", rc.get("channel") and rc.get("channel") != ra.get("channel"), rc)
st, _ = call("POST", "/calls/token", {"peerId": A}, tA)
ok("ба худ занг — 400", st == 400, st)
st, _ = call("POST", "/calls/token", {"peerId": "00000000-0000-0000-0000-000000000000"}, tA)
ok("корбари нест — 404", st == 404, st)
st, _ = call("POST", "/calls/token", {"peerId": Bb})
ok("бе воридшавӣ — 401", st == 401, st)
call("POST", f"/users/{C}/block", tok=tA)
st, _ = call("POST", "/calls/token", {"peerId": A}, tC)
ok("басташуда ба A занг зада наметавонад — 403", st == 403, st)

st, lv = call("POST", "/live/start", {"title": "санҷиш"}, tA)
lid = lv.get("id")
st, h = call("POST", f"/live/{lid}/token", tok=tA)
ok("Live: ҳост token/канал мегирад", st == 200 and h.get("host") is True and h.get("channel") == lv.get("channel"), (st, h))
st, v = call("POST", f"/live/{lid}/token", tok=tB)
ok("Live: тамошобин — host=false", st == 200 and v.get("host") is False, (st, v))
st, _ = call("POST", f"/live/{lid}/token", tok=tC)
ok("Live: басташуда эфирро намебинад — 404", st == 404, st)
call("POST", f"/live/{lid}/end", tok=tA)
st, _ = call("POST", f"/live/{lid}/token", tok=tB)
ok("Live: эфири тамомшуда — 404", st == 404, st)

bad = [x for x in res if not x[0]]
print()
for g, n, d in res: print(("  ✅ " if g else "  ❌ ") + n + ("" if g else f"\n       → {d}"))
print(f"\n{len(res) - len(bad)}/{len(res)} гузашт")
sys.exit(1 if bad else 0)
