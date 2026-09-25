#!/usr/bin/env python3
"""Даври дуюми аудит: номи админ, рамзи барқарорӣ, телефон, лимитҳо,
 мағоза, гурӯҳ, саҳифабандӣ, нест кардани ҳисоб. ⚠️ Сервери МАҲАЛЛӢ.
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
S = os.environ.get("SUFFIX", "s2")
tA, A = user(f"ta{S}", "+992900910101"); tB, Bb = user(f"tb{S}", "+992900910102")
tC, C = user(f"tc{S}", "+992900910103")
IMG = "https://example.com/p.jpg"

# 1. Номи «RAONSON» гирифтан мумкин нест (роҳи админ шудан)
st, r = call("PUT", "/profile/", {"username": "RAONSON"}, tA)
ok("«RAONSON» / «raonson» — банд (409)", st == 409, (st, str(r)[:120]))
st, r = call("PUT", "/profile/username", {"username": "admin"}, tA)
ok("«admin» — банд", st == 409, st)
st, r = call("PUT", "/users/", {"username": "Bad Name!"}, tA)
ok("номи нодуруст тавассути PUT /users — 400", st == 400, (st, r))

# 2. Рамзи барқарорӣ: баъди 5 кӯшиш қуфл
call("POST", "/auth/forgot-password", {"identifier": f"tb{S}"})
def once(m, p, body):
    req = urllib.request.Request(B + p, data=json.dumps(body).encode(), method=m)
    req.add_header('Content-Type', 'application/json')
    try:
        with urllib.request.urlopen(req, timeout=30) as r: return r.status
    except urllib.error.HTTPError as e: return e.code
codes = [once("POST", "/auth/reset-password", {"identifier": f"tb{S}", "otp": f"99999{i}", "newPassword": "Hack12345!"}) for i in range(6)]
ok("кӯшиши 5-ум рамзро қуфл мекунад (429)", 429 in codes, codes)
st, r = call("POST", "/auth/reset-password", {"identifier": "nest-nest-nest", "otp": "123456", "newPassword": "Hack12345!"})
ok("ҳисоби нест: ҳамон ҷавоби «рамз нодуруст» (бе фош кардан)", st == 400 and "нодуруст" in json.dumps(r, ensure_ascii=False), (st, r))

# 3. Телефони каси дигарро гирифтан мумкин нест
st, r = call("PUT", "/profile/phone", {"phone": "+992900910102"}, tA)
ok("рақами B ба A гузошта намешавад — 409", st == 409, (st, r))
st, r = call("POST", "/auth/login", {"email": f"tb{S}", "password": PW})
ok("B ҳамоно ворид мешавад", st == 200 and r.get("accessToken"), st)

# 4. Лимитҳо алоҳида: 30 дархости лента ивази рамзро намебандад
for _ in range(30): call("GET", "/posts/?limit=5", tok=tC)
st, r = call("POST", "/auth/change-password", {"oldPassword": "wrong", "newPassword": "Whatever123!"}, tC)
ok("баъди лента ивази рамз 429 намедиҳад", st != 429, st)

# 5. Мағоза: нарх ва ҳолати фармоиш
st, p = call("POST", "/posts/", {"caption": "мол", "media": [{"url": IMG, "type": "image"}], "isProduct": True, "price": 1e12, "productName": "x"}, tA)
ok("нархи 1e12 — 400", st == 400, st)
st, p = call("POST", "/posts/", {"caption": "мол", "media": [{"url": IMG, "type": "image"}], "isProduct": True, "price": 100, "productName": "Китоб"}, tA)
pid = p.get("_id")
st, o = call("POST", f"/posts/{pid}/order", {}, tB); oid = o.get("_id")
ok("фармоиш сохта шуд", st in (200, 201) and oid, (st, o))
st, r = call("POST", f"/posts/{pid}/review", {"rating": 5, "text": "аъло"}, tC)
ok("баҳо бе харид — 403", st == 403, st)
st, r = call("PUT", f"/orders/{oid}/status", {"status": "delivered"}, tA)
ok("pending → delivered якбора — 409", st == 409, st)
for stt in ["confirmed", "shipping", "delivered"]:
    st, r = call("PUT", f"/orders/{oid}/status", {"status": stt}, tA)
ok("confirmed → shipping → delivered", st == 200, (st, r))
st, r = call("PUT", f"/orders/{oid}/status", {"status": "pending"}, tA)
ok("delivered → pending — 409", st == 409, st)
st, bal = call("GET", "/gifts/balance", tok=tB)
ok("cashback: 5 ситора (5% аз 100)", bal.get("balance") == 5, bal)
st, r = call("POST", f"/posts/{pid}/review", {"rating": 5, "text": "аъло"}, tB)
ok("харидор баҳо мегузорад", st == 200, st)

# 6. Гурӯҳ: басташуда илова намешавад
call("POST", f"/users/{A}/block", tok=tC)
st, g = call("POST", "/groups/", {"name": "g", "memberIds": [Bb, C]}, tA)
gid = g.get("_id") or g.get("id")
st, info = call("GET", f"/groups/{gid}", tok=tA)
ids = json.dumps(info)
ok("корбаре, ки A-ро бастааст, ба гурӯҳ НАМЕАФТАД", Bb in ids and C not in ids, ids[:300])

# 7. limit бузург
st, r = call("GET", "/posts/?limit=1000000", tok=tB)
ok("limit=1000000 → ҳадди аксар 100", st == 200 and len(r.get("posts", [])) <= 100 and r.get("limit") == 100, (st, r.get("limit")))

# 8. Нест кардани ҳисоб воқеан кор мекунад ва token мемирад
st, r = call("DELETE", "/users/", tok=tC)
ok("ҳисоб нест шуд", st == 200, (st, r))
st, _ = call("GET", "/profile/me", tok=tC)
ok("token-и ҳисоби нестшуда кор намекунад", st == 401, st)

bad = [x for x in res if not x[0]]
print()
for g_, n_, d in res: print(("  ✅ " if g_ else "  ❌ ") + n_ + ("" if g_ else f"\n       → {d}"))
print(f"\n{len(res) - len(bad)}/{len(res)} гузашт")
sys.exit(1 if bad else 0)
