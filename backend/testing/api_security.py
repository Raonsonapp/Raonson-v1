#!/usr/bin/env python3
"""Хатоҳое, ки аудит ёфт: ҳар кадом бо корбари воқеӣ санҷида мешавад.
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
S = os.environ.get("SUFFIX", "sc")
tA, A = user(f"qsa{S}", "+992900920001"); tB, Bb = user(f"qsb{S}", "+992900920002")
tC, C = user(f"qsx{S}", "+992900920003")
IMG = "https://example.com/p.jpg"

# 1. Қабули дархости обунаи нестбуда
st, r = call("POST", f"/follow/request/{Bb}/accept", tok=tA)
ok("дархости нестбударо «қабул» кардан — 404", st == 404, (st, r))
st, r = call("GET", f"/users/{A}", tok=tA)
ok("B маҷбуран ба A обуна НАШУД", (r.get("followersCount") or 0) == 0, r.get("followersCount"))

# 2. Тӯҳфа ситора аз ҳеҷ чиз намесозад
st, r = call("POST", "/gifts/", {"toUserId": Bb, "stars": 50}, tA)
ok("тӯҳфа бе ситора — 402", st == 402 and r.get("need") == 50, (st, r))
st, r = call("GET", "/gifts/balance", tok=Bb and tB)
ok("гиранда ситораи қалбакӣ нагирифт", st == 200 and r.get("balance") == 0, r)
st, r = call("POST", "/gifts/", {"toUserId": Bb, "stars": 5000}, tA)
ok("ҳадди аксар 1000", st == 400, st)

# 3. Профили бегона: телефон ва 2FA пинҳон
st, r = call("GET", f"/users/{A}", tok=tB)
ok("телефони бегона дида НАМЕШАВАД", "phone" not in r and "twoFactor" not in r, list(r.keys())[:40])
st, r = call("GET", f"/users/{A}", tok=tA)
ok("соҳиб телефони худро мебинад", "phone" in r, list(r.keys())[:40])

# 4. Ҳисоби пӯшида: /profile/:username постҳоро намедиҳад
call("POST", "/posts/", {"caption": "махфӣ", "media": [{"url": IMG, "type": "image"}]}, tA)
call("PUT", "/profile/", {"isPrivate": True}, tA); call("PUT", "/profile/privacy", {"private": True}, tA)
st, me = call("GET", f"/users/{A}", tok=tA)
st, r = call("GET", f"/profile/qsa{S}", tok=tB)
ok("пӯшида: постҳо ба бегона НАМЕРАВАНД", me.get("isPrivate") is True and r.get("posts") == [], (me.get("isPrivate"), len(r.get("posts") or [])))

# 5. Иҷозати шарҳ
call("PUT", "/profile/", {"isPrivate": False}, tA)
st, p = call("POST", "/posts/", {"caption": "шарҳ", "media": [{"url": IMG, "type": "image"}]}, tA)
pid = p.get("_id")
call("PUT", "/profile/", {"allowComments": False}, tA)
st, r = call("POST", f"/posts/{pid}/comments", {"text": "салом"}, tB)
ok("«Иҷозати шарҳ» хомӯш — 403", st == 403, (st, r))
call("PUT", "/profile/", {"allowComments": True}, tA)
st, r = call("POST", f"/posts/{pid}/comments", {"text": "салом"}, tB)
ok("фаъол — шарҳ мешавад", st in (200, 201), (st, r))

# 6. Reel-и пӯшида/басташуда: лайк бо id намешавад
call("POST", f"/users/{A}/block", tok=tC)
st, r = call("POST", f"/posts/{pid}/like", tok=tC)
ok("басташуда пости A-ро лайк карда наметавонад", st == 404, st)

# 7. Чат: паём ба chatId-и бегона
st, r = call("POST", f"/chat/{A}_{Bb}/messages", {"text": "аз номи дигар", "receiverId": A}, tC)
ok("паём ба чати ду нафари дигар — 403", st == 403, (st, r))

# 8. Ивази рамз token-ҳои кӯҳнаро бекор мекунад
tB2 = call("POST", "/auth/login", {"email": f"qsb{S}", "password": PW})[1].get("accessToken")
st, r = call("POST", "/auth/change-password", {"oldPassword": PW, "newPassword": "NewPass12345!"}, tB)
ok("рамз иваз шуд ва token-и нав омад", st == 200 and r.get("accessToken"), (st, r))
new = r.get("accessToken")
st, _ = call("GET", "/profile/me", tok=tB2)
ok("дастгоҳи дигар (token-и кӯҳна) баромад", st == 401, st)
st, _ = call("GET", "/profile/me", tok=new)
ok("ин дастгоҳ дар ҳисоб монд", st == 200, st)

# 9. Live: бинанда як бор ҳисоб мешавад
st, lv = call("POST", "/live/start", {"title": "t"}, tA)
lid = lv.get("id")
for _ in range(5): call("POST", f"/live/{lid}/join", tok=new)
st, r = call("POST", f"/live/{lid}/join", tok=new)
ok("5 бор ворид шуд — 1 бинанда", r.get("viewers") == 1, r)
st, r = call("POST", f"/live/{lid}/comment", {"text": "салом"}, tC)
ok("басташуда дар Live шарҳ навишта наметавонад", st == 404, st)
call("POST", f"/live/{lid}/end", tok=tA)

bad = [x for x in res if not x[0]]
print()
for g, n_, d in res: print(("  ✅ " if g else "  ❌ ") + n_ + ("" if g else f"\n       → {d}"))
print(f"\n{len(res) - len(bad)}/{len(res)} гузашт")
sys.exit(1 if bad else 0)
