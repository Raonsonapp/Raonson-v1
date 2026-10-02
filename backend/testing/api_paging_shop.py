#!/usr/bin/env python3
"""Саҳифабандӣ, тахфифи маҳсул, «Ҷолиб нест» ва Live — шартномаи нав.

═══════════════════════════════════════════════════════════════════
 Чаро ин файл ҳаст

 Барнома акнун рӯйхатҳои профил (постҳо, Reels, захирашудаҳо,
 обуначиён), шарҳҳо, огоҳиномаҳо ва ҳаштагро саҳифа ба саҳифа бор
 мекунад. Пеш танҳо саҳифаи аввал (20–50 унсур) дида мешуд ва
 боқимонда ҳеҷ гоҳ нишон дода намешуд. Ин скрипт месанҷад, ки сервер
 `page`/`limit`-ро ҳамон тавре мефаҳмад, ки барнома интизор аст:
 саҳифаи дуюм — унсурҳои ДИГАР, бе такрор.

 Ҳамчунин:
   • тахфифи фаъол (salePct) дар ҳар шакли пост меояд — «Харид» дар
     лента нархи воқеиро нишон медиҳад;
   • «Ҷолиб нест»-ро бекор кардан мумкин аст (DELETE);
   • баҳои маҳсул бе харид сабаби фаҳмо бармегардонад;
   • Live-и нав дар рӯйхат аст ва бо /end аз он мебарояд.

 Истифода:
   BASE=http://127.0.0.1:8099 SUFFIX=x1 python3 backend/testing/api_paging_shop.py

 ⚠️ Ба сервери МАҲАЛЛӢ мезанад. Ба продакшн чизе навишта намешавад.
═══════════════════════════════════════════════════════════════════
"""

import hashlib, json, os, sys, time, urllib.request, urllib.error

B = os.environ.get("BASE", "http://127.0.0.1:8099")
PW = "Test12345!"
res = []


def _once(m, p, body=None, tok=None):
    req = urllib.request.Request(
        B + p,
        data=json.dumps(body).encode() if body is not None else None,
        method=m)
    req.add_header('Content-Type', 'application/json')
    if tok:
        req.add_header('Authorization', 'Bearer ' + tok)
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            raw = r.read().decode()
            return r.status, (json.loads(raw) if raw else {})
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
        try:
            return e.code, json.loads(raw)
        except Exception:
            return e.code, raw
    except Exception as e:
        return 0, str(e)


def call(m, p, body=None, tok=None):
    st, r = 0, None
    for a in range(4):
        st, r = _once(m, p, body, tok)
        if st != 429:
            return st, r
        time.sleep(4 * (a + 1))
    return st, r


def ok(n, c, d=""):
    res.append((bool(c), n, str(d)[:160]))


S = os.environ.get("SUFFIX", "pg")
# Рақами телефон аз SUFFIX — то ду иҷро ҳамдигарро напахшанд.
_h = int(hashlib.sha1(S.encode()).hexdigest(), 16)


def phone(i):
    return "+99293" + str((_h + i * 7919) % 10_000_000).zfill(7)


def reg_login(u, i):
    call("POST", "/auth/register",
         {"username": u, "email": f"{u}@example.com", "password": PW,
          "fullName": u, "phone": phone(i)})
    st, r = call("POST", "/auth/login", {"email": u, "password": PW})
    if not isinstance(r, dict) or not r.get("accessToken"):
        print("!! вуруд нашуд —", u, st, r)
        sys.exit(1)
    usr = r.get("user") or {}
    return r["accessToken"], (usr.get("id") or usr.get("_id"))


def ids(lst):
    return [(x.get("_id") or x.get("id")) for x in lst if isinstance(x, dict)]


def items(r, key):
    if isinstance(r, list):
        return r
    return (r or {}).get(key) or []


A, Bn = f"pgxa{S}", f"pgxb{S}"
tA, idA = reg_login(A, 1)
tB, idB = reg_login(Bn, 2)
TAG = f"pg{S}".lower()

# ═══ 1. ПОСТҲО: профил ва ҳаштаг, саҳифа ба саҳифа ═════════════════
pids = []
for i in range(5):
    st, p = call("POST", "/posts/",
                 {"caption": f"пост {i} #{TAG}",
                  "media": [{"url": f"https://example.com/{S}{i}.jpg",
                             "type": "image"}]}, tA)
    pid = (p.get("id") or p.get("_id")) if isinstance(p, dict) else None
    if pid:
        pids.append(pid)
ok("5 пост сохта шуд", len(pids) == 5, pids)

st, p1 = call("GET", f"/users/{idA}/posts?page=1&limit=2", tok=tB)
st2, p2 = call("GET", f"/users/{idA}/posts?page=2&limit=2", tok=tB)
st3, p3 = call("GET", f"/users/{idA}/posts?page=3&limit=2", tok=tB)
a1, a2, a3 = ids(items(p1, "posts")), ids(items(p2, "posts")), ids(items(p3, "posts"))
ok("профил: саҳифаи 1 ва 2 — 2-тоӣ", len(a1) == 2 and len(a2) == 2, (a1, a2))
ok("профил: саҳифаи 3 — боқимонда (1)", len(a3) == 1, a3)
ok("профил: ҳамаи 5 пост бе такрор", sorted(a1 + a2 + a3) == sorted(pids),
   (a1, a2, a3))

st, h1 = call("GET", f"/posts/hashtag/{TAG}?page=1&limit=3", tok=tB)
st, h2 = call("GET", f"/posts/hashtag/{TAG}?page=2&limit=3", tok=tB)
b1, b2 = ids(items(h1, "posts")), ids(items(h2, "posts"))
ok("ҳаштаг: саҳифаи 2 постҳои дигар медиҳад",
   len(b1) == 3 and len(b2) == 2 and not set(b1) & set(b2), (b1, b2))

# ═══ 2. ШАРҲҲО ═════════════════════════════════════════════════════
cids = []
if pids:
    for i in range(3):
        st, c = call("POST", f"/posts/{pids[0]}/comments",
                     {"text": f"шарҳ {i}"}, tB)
        cid = (c.get("id") or c.get("_id")
               or (c.get("comment") or {}).get("id")) if isinstance(c, dict) else None
        if cid:
            cids.append(cid)
    st, c1 = call("GET", f"/posts/{pids[0]}/comments?page=1&limit=2", tok=tA)
    st, c2 = call("GET", f"/posts/{pids[0]}/comments?page=2&limit=2", tok=tA)
    d1, d2 = ids(items(c1, "comments")), ids(items(c2, "comments"))
    ok("шарҳҳо: саҳифаи 2 — шарҳи кӯҳнатарин, бе такрор",
       len(d1) == 2 and len(d2) == 1 and not set(d1) & set(d2)
       and sorted(d1 + d2) == sorted(cids), (d1, d2, cids))

# ═══ 4. ОБУНАЧИЁН ══════════════════════════════════════════════════
call("POST", f"/follow/{idA}", tok=tB)
st, f1 = call("GET", f"/users/{idA}/followers?page=1&limit=1", tok=tA)
st2, f2 = call("GET", f"/users/{idA}/followers?page=2&limit=1", tok=tA)
g1 = ids(items(f1, "followers"))
ok("обуначиён: page/limit (1 нафар — саҳифаи 2 холӣ)",
   st == 200 and st2 == 200 and g1 == [idB] and items(f2, "followers") == [],
   (st, g1, f2))

# ═══ 5. ЗАХИРАШУДАҲО ═══════════════════════════════════════════════
for pid in pids[:3]:
    call("POST", f"/posts/{pid}/save", tok=tB)
st, s1 = call("GET", "/profile/saved?page=1&limit=2", tok=tB)
st, s2 = call("GET", "/profile/saved?page=2&limit=2", tok=tB)
q1, q2 = ids(items(s1, "posts")), ids(items(s2, "posts"))
ok("захирашудаҳо: саҳифаи 2 боқимондаро медиҳад",
   len(q1) == 2 and len(q2) == 1 and not set(q1) & set(q2), (q1, q2))

# ═══ 3. ОГОҲИНОМАҲО ════════════════════════════════════════════════
# Лайкҳо + обуна + шарҳҳо — огоҳиномаҳои гуногун барои A.
for pid in pids[:4]:
    call("POST", f"/posts/{pid}/like", tok=tB)
# Огоҳинома метавонад каме баъдтар сабт шавад — то 5 сония интизор.
for _ in range(10):
    st, n1 = call("GET", "/notifications?page=1&limit=2", tok=tA)
    st2, n2 = call("GET", "/notifications?page=2&limit=2", tok=tA)
    e1, e2 = ids(items(n1, "notifications")), ids(items(n2, "notifications"))
    if len(e1) == 2 and e2:
        break
    time.sleep(0.5)
ok("огоҳиномаҳо: page/limit кор мекунад",
   st == 200 and st2 == 200 and len(e1) == 2 and len(e2) >= 1
   and not set(e1) & set(e2), (st, st2, e1, e2))

# ═══ 6. ТАХФИФИ МАҲСУЛ (salePct) ═══════════════════════════════════
st, pr = call("POST", "/posts/", {
    "caption": f"маҳсул {S}",
    "media": [{"url": f"https://example.com/{S}prod.jpg", "type": "image"}],
    "isProduct": True, "price": 100, "currency": "TJS",
    "productName": f"Курта {S}", "shopWhatsapp": "+992900000000",
    "contactRaonson": False}, tA)
prod = (pr.get("id") or pr.get("_id")) if isinstance(pr, dict) else None
ok("маҳсул сохта шуд", prod, pr)
if prod:
    st, r = call("GET", f"/posts/{prod}", tok=tB)
    ok("бе тахфиф salePct = 0", st == 200 and r.get("salePct") == 0,
       f"HTTP {st}: {str(r)[:140]}")
    st, r = call("PUT", f"/posts/{prod}/sale", {"salePct": 20, "saleDays": 1}, tA)
    ok("тахфиф 20% гузошта шуд", st == 200, f"HTTP {st}: {r}")
    st, r = call("GET", f"/posts/{prod}", tok=tB)
    ok("GET /posts/:id тахфифро медиҳад (salePct 20)",
       st == 200 and r.get("salePct") == 20, f"HTTP {st}: {str(r)[:140]}")
    st, r = call("GET", f"/users/{idA}/posts?limit=50", tok=tB)
    got = [x for x in items(r, "posts") if (x.get("_id") or x.get("id")) == prod]
    ok("профил: пости маҳсул salePct дорад",
       got and got[0].get("salePct") == 20, str(got)[:140])
    others = [x.get("salePct") for x in items(r, "posts")
              if (x.get("_id") or x.get("id")) != prod]
    ok("постҳои оддӣ salePct = 0", others and all(v == 0 for v in others),
       others)
    # Нархи фармоиш — ҳамон нархе, ки «Харид» акнун нишон медиҳад.
    st, o = call("POST", f"/posts/{prod}/order", {"note": "x"}, tB)
    ok("фармоиш бо нархи тахфифӣ (80)",
       st in (200, 201) and abs(float(o.get("price", 0)) - 80) < 0.01,
       f"HTTP {st}: {o}")
    # Баҳо бе гирифтани мол — сабаби фаҳмо, на хатои холӣ.
    st, r = call("POST", f"/posts/{prod}/review", {"rating": 5, "text": "аъло"}, tB)
    ok("баҳо бе харид: 403 бо паём",
       st == 403 and isinstance(r, dict) and r.get("message"), f"HTTP {st}: {r}")
    # Тахфифро хомӯш кардан → боз 0.
    call("PUT", f"/posts/{prod}/sale", {"salePct": 0}, tA)
    st, r = call("GET", f"/posts/{prod}", tok=tB)
    ok("баъди хомӯш кардан salePct = 0", r.get("salePct") == 0, str(r)[:120])

# ═══ 7. «ҶОЛИБ НЕСТ» — БЕКОР КАРДАН ════════════════════════════════
if pids:
    st, r = call("POST", f"/posts/{pids[1]}/not-interested", tok=tB)
    ok("«ҷолиб нест»", st == 200, f"HTTP {st}")
    st, r = call("DELETE", f"/posts/{pids[1]}/not-interested", tok=tB)
    ok("«ҷолиб нест»-ро бекор кардан мумкин аст",
       st == 200 and r.get("not_interested") is False, f"HTTP {st}: {r}")
    st, r = call("DELETE", f"/posts/{pids[1]}/not-interested", tok=tB)
    ok("бекоркунии такрорӣ хато намедиҳад", st == 200, f"HTTP {st}")

# ═══ 8. LIVE ═══════════════════════════════════════════════════════
st, lv = call("POST", "/live/start", {"title": f"эфир {S}"}, tA)
lid = lv.get("id") if isinstance(lv, dict) else None
ok("эфир оғоз шуд", st == 200 and lid, f"HTTP {st}: {lv}")
st, r = call("GET", "/live/", tok=tB)
ok("эфири нав дар рӯйхат аст",
   lid in [s.get("id") for s in items(r, "streams")], str(r)[:140])
st, r = call("POST", f"/live/{lid}/end", tok=tB)
ok("бегона эфирро хотима дода наметавонад", st == 403, f"HTTP {st}")
st, r = call("POST", f"/live/{lid}/end", tok=tA)
ok("ҳост эфирро хотима дод", st == 200, f"HTTP {st}")
st, r = call("GET", "/live/", tok=tB)
ok("эфири хотимаёфта аз рӯйхат рафт",
   lid not in [s.get("id") for s in items(r, "streams")], str(r)[:140])

# ═══ 9. БИНАНДАГОНИ СТОРИ: limit=200 қабул мешавад ═════════════════
st, s = call("POST", "/stories/",
             {"mediaUrl": f"https://example.com/{S}s.jpg", "mediaType": "image"}, tA)
sid = (s.get("id") or s.get("_id")) if isinstance(s, dict) else None
if sid:
    call("POST", f"/stories/{sid}/view", tok=tB)
    st, r = call("GET", f"/stories/{sid}/viewers?limit=200", tok=tA)
    ok("бинандагони сторӣ бо limit=200",
       st == 200 and idB in ids(r.get("viewers") or []), f"HTTP {st}: {str(r)[:140]}")

# ═══ 10. ДАРХОСТИ ОБУНА БА ҲИСОБИ ПӮШИДА — БЕКОР КАРДАН ════════════
C = f"pc{S}"
tC, idC = reg_login(C, 3)
call("PUT", "/profile/", {"isPrivate": True}, tC)
st, r = call("POST", f"/follow/{idC}", tok=tB)
ok("обуна ба ҳисоби пӯшида → requested (на following)",
   st == 200 and r.get("requested") is True and not r.get("following"),
   f"HTTP {st}: {r}")


def req_ids():
    _, rq = call("GET", "/follow/requests", tok=tC)
    lst = rq.get("requests") if isinstance(rq, dict) else rq
    return ids(lst or []) + [
        (x.get("user") or {}).get("_id") for x in (lst or []) if isinstance(x, dict)]


ok("дархост дар рӯйхати соҳиб аст", idB in req_ids(), req_ids())
st, r = call("DELETE", f"/follow/{idC}", tok=tB)
ok("дархостро бекор кардан (DELETE /follow/:id)", st == 200, f"HTTP {st}: {r}")
ok("баъди бекор дархост аз рӯйхати соҳиб рафт", idB not in req_ids(), req_ids())
_, nr = call("GET", "/notifications", tok=tC)
left = [n for n in items(nr, "notifications")
        if n.get("type") == "follow_request"
        and ((n.get("fromUser") or n.get("from_user") or n.get("user") or {}).get("_id")
             or n.get("fromUserId")) == idB]
ok("огоҳиномаи «мехоҳад обуна шавад» ҳам рафт", not left, str(left)[:140])
st, prof = call("GET", f"/users/{idC}", tok=tB)
u = prof.get("user", prof) if isinstance(prof, dict) else {}
ok("профил: followRequestSent = false", u.get("followRequestSent") in (False, None),
   str(u)[:140])

# ═══ 11. ПАЁМҲОИ ГУРӮҲ — ТАЪРИХИ КӮҲНА ════════════════════════════
st, g = call("POST", "/groups/", {"name": f"г{S}", "memberIds": [idB]}, tA)
gid = (g.get("id") or g.get("_id")
       or (g.get("group") or {}).get("_id")) if isinstance(g, dict) else None
ok("гурӯҳ сохта шуд", gid, f"HTTP {st}: {g}")
if gid:
    mids = []
    for i in range(3):
        st, m = call("POST", f"/groups/{gid}/messages", {"text": f"п{i}"}, tA)
        mids.append((m or {}).get("_id") or (m or {}).get("id"))
    st, m1 = call("GET", f"/groups/{gid}/messages?page=1&limit=2", tok=tB)
    st, m2 = call("GET", f"/groups/{gid}/messages?page=2&limit=2", tok=tB)
    x1, x2 = ids(items(m1, "messages")), ids(items(m2, "messages"))
    ok("гурӯҳ: саҳифаи 2 — паёми кӯҳнатарин",
       len(x1) == 2 and x2 == [mids[0]], (x1, x2, mids))

# ═══ 12. СУРУДИ ПРОФИЛ: сабт, нишон, нест кардан ══════════════════
song = {"title": "Суруд", "artist": "Хонанда", "artUrl": "",
        "previewUrl": "https://example.com/p.m4a", "trackMs": 200000,
        "startMs": 1000, "endMs": 31000}
st, r = call("PUT", "/profile/", {"username": A, "bioSong": song}, tA)
ok("суруди профил сабт шуд", st == 200, f"HTTP {st}: {str(r)[:120]}")
st, r = call("GET", f"/users/{idA}", tok=tB)
u = r.get("user", r) if isinstance(r, dict) else {}
ok("бегона суруди профилро мегирад",
   (u.get("bioSong") or {}).get("title") == "Суруд", str(u.get("bioSong"))[:120])
st, r = call("PUT", "/profile/", {"username": A, "bioSong": {}}, tA)
st, r = call("GET", f"/users/{idA}", tok=tB)
u = r.get("user", r) if isinstance(r, dict) else {}
ok("суруди профил бо {} нест мешавад", not u.get("bioSong"), str(u.get("bioSong")))

# ═══ ҲИСОБОТ ═════════════════════════════════════════════════════
bad = [x for x in res if not x[0]]
print()
for good, name, detail in res:
    print(("  ✅ " if good else "  ❌ ") + name
          + ("" if good else f"\n       → {detail}"))
print(f"\n{len(res) - len(bad)}/{len(res)} гузашт")
sys.exit(1 if bad else 0)
