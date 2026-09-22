#!/usr/bin/env python3
"""Бахшҳое, ки ҳеҷ гоҳ санҷида нашуда буданд.

═══════════════════════════════════════════════════════════════════
 Чор санҷиши пештара (smoke, authz, privacy, deep, flows) 132 ҷойро
 мегиранд. Вале дар сервер 264 роҳ ҳаст. Ин ҷо маҳз ҳамон бахшҳое
 месанҷанд, ки ба онҳо ҳеҷ гоҳ даст нарасида буд:

   • иваз кардани парол ва бехатарии он
   • таърихи воридшавӣ ва баромадан аз ҳамаи дастгоҳҳо
   • ҷавоб ва лайк ба шарҳи Reel
   • реаксия ба паём, дархости чат, шумораи хонданашуда
   • музикаи захирашуда
   • маҷмӯаҳо (collections), дӯстони наздик
   • хомӯш кардан (mute), маҳдуд кардан (restrict)
   • ҷавоби худкор (auto-reply)
   • тӯҳфа, огоҳинома, танзимоти огоҳинома
   • промокоди дӯкон, фармоиш, гурӯҳ

 ⚠️ Ин ба сервери МАҲАЛЛӢ мезанад. Ба продакшн ҳеҷ чиз навишта
 намешавад.

 Истифода:
   BASE=http://127.0.0.1:8099 python3 backend/testing/api_user2.py
═══════════════════════════════════════════════════════════════════
"""

import json, os, sys, time, urllib.request, urllib.error

B = os.environ.get("BASE", "http://127.0.0.1:8099")
PW = "Test12345!"
res = []
_RETRY = (429,)


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
        if st not in _RETRY:
            return st, r
        time.sleep(4 * (a + 1))
    return st, r


def reg(u, e, ph):
    st, _ = call("POST", "/auth/register",
                 {"username": u, "email": e, "password": PW,
                  "fullName": u, "phone": ph})
    return st in (200, 201, 409)


def login(u, pw=PW):
    st, r = call("POST", "/auth/login", {"email": u, "password": pw})
    if not isinstance(r, dict):
        return None, {}, st
    return r.get("accessToken"), (r.get("user") or {}), st


def ok(n, c, d=""):
    res.append((bool(c), n, str(d)[:160]))


def jd(x):
    return json.dumps(x, ensure_ascii=False)


S = os.environ.get("SUFFIX", "u2")
A, Bu = f"ua{S}", f"ub{S}"
reg(A, f"{A}@example.com", "+992900700001")
reg(Bu, f"{Bu}@example.com", "+992900700002")
tA, uA, _ = login(A)
tB, uB, _ = login(Bu)
idA = uA.get("id") or uA.get("_id")
idB = uB.get("id") or uB.get("_id")
if not (tA and tB):
    print("!! вуруд нашуд — сервер кор намекунад?")
    sys.exit(1)

# ═══ 1. НОМИ КОРБАР ═══════════════════════════════════════════════
st, r = call("GET", f"/auth/check-username/{A}")
ok("номи бандшуда ҳамчун банд нишон дода мешавад",
   st == 200 and jd(r).lower().count("false") >= 1, f"HTTP {st}: {r}")
st, r = call("GET", f"/auth/check-username/hech_kas_{S}_9")
ok("номи озод ҳамчун озод нишон дода мешавад",
   st == 200 and "true" in jd(r).lower(), f"HTTP {st}: {r}")
st, r = call("GET", f"/users/by-username/{Bu}", tok=tA)
ok("ҷустуҷӯ бо номи корбар", st == 200 and Bu in jd(r), f"HTTP {st}")

# ═══ 2. ПАРОЛ ═════════════════════════════════════════════════════
# Пароли нодуруст набояд қабул шавад — вагарна ҳар кас метавонад
# пароли дигареро иваз кунад, агар токенаш дуздида шавад.
st, r = call("POST", "/auth/change-password",
             {"oldPassword": "SafatGhalat1!", "newPassword": "Yangi12345!"}, tA)
ok("пароли кӯҳнаи НОДУРУСТ рад мешавад", st in (400, 401, 403),
   f"HTTP {st}: {r}")

NEW = "Yangi12345!"
st, r = call("POST", "/auth/change-password",
             {"oldPassword": PW, "newPassword": NEW}, tA)
changed = st in (200, 201)
ok("парол иваз мешавад", changed, f"HTTP {st}: {r}")

if changed:
    t_old, _, st_old = login(A, PW)
    ok("пароли КӮҲНА дигар кор намекунад", not t_old, f"HTTP {st_old}")
    t_new, uA2, st_new = login(A, NEW)
    ok("пароли НАВ кор мекунад", bool(t_new), f"HTTP {st_new}")
    if t_new:
        tA = t_new
    # Баргардонидан, то санҷишҳои такрорӣ кор кунанд.
    call("POST", "/auth/change-password",
         {"oldPassword": NEW, "newPassword": PW}, tA)
    t_back, _, _ = login(A, PW)
    if t_back:
        tA = t_back

# Пароли аз ҳад содда набояд қабул шавад.
st, r = call("POST", "/auth/change-password",
             {"oldPassword": PW, "newPassword": "123"}, tA)
ok("пароли аз ҳад кӯтоҳ рад мешавад", st in (400, 422), f"HTTP {st}: {r}")

# ═══ 3. ТАЪРИХИ ВОРИДШАВӢ ═════════════════════════════════════════
st, r = call("GET", "/auth/sessions", tok=tA)
ok("таърихи воридшавӣ хонда мешавад", st == 200, f"HTTP {st}: {r}")

# ═══ 4. БАРҚАРОРСОЗИИ ПАРОЛ ═══════════════════════════════════════
# Email танзим нашудааст, пас ё 502-и ростгӯй, ё 200-и бехатар
# («агар чунин почта бошад, мактуб рафт») — вале НАҲАРГИЗ набояд
# бигӯяд, ки чунин корбар ҳаст ё не.
st, r = call("POST", "/auth/forgot-password", {"email": f"{A}@example.com"})
ok("фаромӯшии парол ҷавоб медиҳад", st in (200, 202, 502), f"HTTP {st}: {r}")
st2, r2 = call("POST", "/auth/forgot-password",
               {"email": f"nest-{S}@example.com"})
ok("фаромӯшии парол мавҷудияти почтаро ошкор НАМЕКУНАД",
   st == st2, f"ҳаст → {st}, нест → {st2}")

st, r = call("POST", "/auth/reset-password",
             {"token": "sohta-token", "password": "Yangi12345!"})
ok("токени сохтаи барқарорсозӣ рад мешавад", st in (400, 401, 403, 404),
   f"HTTP {st}: {r}")

# ═══ 5. REEL: ҶАВОБ ВА ЛАЙК БА ШАРҲ ══════════════════════════════
st, rl = call("POST", "/reels/",
              {"videoUrl": "https://example.com/v.mp4", "caption": "reel"}, tA)
rid = (rl.get("id") or rl.get("_id")
       or (rl.get("reel") or {}).get("id")) if isinstance(rl, dict) else None
ok("Reel сохта шуд", rid, rl)

if rid:
    st, c = call("POST", f"/reels/{rid}/comments", {"text": "шарҳи аввал"}, tB)
    cid = (c.get("id") or c.get("_id")
           or (c.get("comment") or {}).get("id")) if isinstance(c, dict) else None
    ok("шарҳ ба Reel", cid, c)
    if cid:
        st, r = call("POST", f"/reels/{rid}/comments/{cid}/like", tok=tA)
        ok("лайк ба шарҳи Reel", st in (200, 201), f"HTTP {st}: {r}")
        st, r = call("POST", f"/reels/{rid}/comments/{cid}/reply",
                     {"text": "ҷавоби ман"}, tA)
        ok("ҷавоб ба шарҳи Reel", st in (200, 201), f"HTTP {st}: {r}")
        st, lst = call("GET", f"/reels/{rid}/comments", tok=tA)
        ok("ҷавоб дар рӯйхати шарҳҳо пайдо шуд",
           st == 200 and "ҷавоби ман" in jd(lst), str(lst)[:160])

    st, r = call("POST", f"/reels/{rid}/watch", {"ms": 4200}, tB)
    ok("вақти тамошои Reel сабт мешавад", st in (200, 201, 204),
       f"HTTP {st}: {r}")
    st, r = call("POST", f"/reels/{rid}/share", tok=tB)
    ok("мубодилаи Reel", st in (200, 201), f"HTTP {st}: {r}")
    st, r = call("GET", f"/reels/{rid}/stats", tok=tA)
    ok("омори Reel ба соҳиб", st == 200, f"HTTP {st}: {r}")

# ═══ 6. МУЗИКАИ ЗАХИРАШУДА ═══════════════════════════════════════
st, r = call("GET", "/reels/audio/trending", tok=tA)
ok("музикаи маъмул", st == 200, f"HTTP {st}: {r}")
st, r = call("GET", "/reels/audio/saved", tok=tA)
ok("музикаи захирашуда", st == 200, f"HTTP {st}: {r}")

# ═══ 7. ПОСТ: мубодила, «ба ман маъқул нест» ═════════════════════
st, p = call("POST", "/posts/",
             {"caption": "пости санҷишӣ",
              "media": [{"url": "https://example.com/p.jpg", "type": "image"}]},
             tA)
pid = (p.get("id") or p.get("_id")
       or (p.get("post") or {}).get("id")) if isinstance(p, dict) else None
ok("пост сохта шуд", pid, p)

if pid:
    st, r = call("POST", f"/posts/{pid}/share", tok=tB)
    ok("мубодилаи пост", st in (200, 201), f"HTTP {st}: {r}")
    st, r = call("POST", f"/posts/{pid}/not-interested", tok=tB)
    ok("«ба ман маъқул нест»", st in (200, 201, 204), f"HTTP {st}: {r}")
    st, r = call("POST", f"/posts/{pid}/interest", tok=tB)
    ok("«маъқул»", st in (200, 201, 204), f"HTTP {st}: {r}")
    st, r = call("GET", f"/posts/{pid}/stats", tok=tA)
    ok("омори пост ба соҳиб", st == 200, f"HTTP {st}: {r}")
    st, r = call("GET", f"/posts/{pid}/stats", tok=tB)
    ok("омори пост ба БЕГОНА дода намешавад", st in (401, 403, 404),
       f"HTTP {st}: {r}")

# ═══ 8. МАҶМӮАҲО (collections) ═══════════════════════════════════
st, col = call("POST", "/collections", {"name": f"Маҷмӯаи {S}"}, tA)
colid = (col.get("id") or col.get("_id")) if isinstance(col, dict) else None
ok("маҷмӯа сохта шуд", colid, col)
if colid and pid:
    st, r = call("POST", f"/collections/{colid}/posts", {"postId": pid}, tA)
    ok("пост ба маҷмӯа илова шуд", st in (200, 201), f"HTTP {st}: {r}")
    st, lst = call("GET", "/collections", tok=tA)
    ok("маҷмӯа дар рӯйхат ҳаст", st == 200 and f"Маҷмӯаи {S}" in jd(lst),
       str(lst)[:160])
    st, r = call("POST", f"/collections/{colid}/posts", {"postId": pid}, tB)
    ok("бегона ба маҷмӯаи ман илова карда НАМЕТАВОНАД",
       st in (401, 403, 404), f"HTTP {st}: {r}")
    st, r = call("DELETE", f"/collections/{colid}/posts/{pid}", tok=tA)
    ok("пост аз маҷмӯа бароварда шуд", st in (200, 204), f"HTTP {st}: {r}")

# ═══ 9. ДӮСТОНИ НАЗДИК ═══════════════════════════════════════════
st, r = call("POST", f"/close-friends/{idB}", tok=tA)
ok("ба дӯстони наздик илова шуд", st in (200, 201), f"HTTP {st}: {r}")
st, lst = call("GET", "/close-friends", tok=tA)
ok("дӯсти наздик дар рӯйхат ҳаст", st == 200 and idB in jd(lst),
   str(lst)[:160])
st, ids = call("GET", "/close-friends/ids", tok=tA)
ok("рӯйхати ID-ҳои дӯстони наздик", st == 200, f"HTTP {st}")
st, r = call("DELETE", f"/close-friends/{idB}", tok=tA)
ok("аз дӯстони наздик бароварда шуд", st in (200, 204), f"HTTP {st}: {r}")

# ═══ 10. ХОМӮШ КАРДАН ВА МАҲДУД КАРДАН ═══════════════════════════
st, r = call("POST", f"/users/{idB}/mute", tok=tA)
ok("корбар хомӯш карда шуд", st in (200, 201), f"HTTP {st}: {r}")
st, r = call("DELETE", f"/users/{idB}/mute", tok=tA)
ok("хомӯшӣ бекор шуд", st in (200, 204), f"HTTP {st}: {r}")
st, r = call("POST", f"/users/{idB}/restrict", tok=tA)
ok("корбар маҳдуд карда шуд", st in (200, 201), f"HTTP {st}: {r}")
st, r = call("POST", f"/users/{idB}/unrestrict", tok=tA)
ok("маҳдудият бекор шуд", st in (200, 201, 204), f"HTTP {st}: {r}")
st, r = call("GET", "/users/blocked", tok=tA)
ok("рӯйхати бастагон хонда мешавад", st == 200, f"HTTP {st}: {r}")

# ═══ 11. ҚАЙДИ ПРОФИЛ (Note) ═════════════════════════════════════
st, r = call("POST", "/profile/note", {"text": f"қайди {S}"}, tA)
ok("қайди профил гузошта шуд", st in (200, 201), f"HTTP {st}: {r}")

# ═══ 12. ҶАВОБИ ХУДКОР ═══════════════════════════════════════════
st, r = call("PUT", "/profile/auto-reply",
             {"enabled": True, "text": "Ҳозир банд ҳастам"}, tA)
ok("ҷавоби худкор танзим шуд", st in (200, 201), f"HTTP {st}: {r}")
st, r = call("GET", "/profile/auto-reply", tok=tA)
ok("ҷавоби худкор нигоҳ дошта шуд",
   st == 200 and "Ҳозир банд" in jd(r), f"HTTP {st}: {r}")
call("PUT", "/profile/auto-reply", {"enabled": False, "text": ""}, tA)

# ═══ 13. ЧАТ: реаксия, дархост, хонданашуда ══════════════════════
st, ch = call("GET", f"/chat/with/{idB}", tok=tA)
chid = (ch.get("chatId") or ch.get("id") or ch.get("_id")
        or (ch.get("chat") or {}).get("id")) if isinstance(ch, dict) else None
ok("чат кушода шуд", chid, ch)

if chid:
    st, m = call("POST", f"/chat/{chid}/messages", {"text": "салом"}, tA)
    mid = (m.get("id") or m.get("_id")
           or (m.get("message") or {}).get("id")) if isinstance(m, dict) else None
    ok("паём фиристода шуд", mid, m)

    if mid:
        st, r = call("POST", f"/chat/messages/{mid}/react", {"emoji": "❤️"}, tB)
        ok("реаксия ба паём", st in (200, 201), f"HTTP {st}: {r}")
        st, lst = call("GET", f"/chat/{chid}/messages", tok=tB)
        ok("реаксия дар паём нигоҳ дошта шуд",
           st == 200 and "❤️" in jd(lst), str(lst)[:200])
        st, r = call("POST", f"/chat/messages/{mid}/report",
                     {"reason": "spam"}, tB)
        ok("шикоят ба паём", st in (200, 201), f"HTTP {st}: {r}")

    st, r = call("GET", "/chat/", tok=tB)
    ok("рӯйхати чатҳо", st == 200, f"HTTP {st}")
    st, r = call("POST", f"/chat/{chid}/read", tok=tB)
    ok("чат хондашуда қайд шуд", st in (200, 201, 204), f"HTTP {st}: {r}")

# ═══ 14. ОГОҲИНОМА ═══════════════════════════════════════════════
st, r = call("GET", "/notifications/unread-count", tok=tA)
ok("шумораи огоҳиномаҳои хонданашуда", st == 200, f"HTTP {st}: {r}")
st, n = call("GET", "/notifications/", tok=tA)
ok("рӯйхати огоҳиномаҳо", st == 200, f"HTTP {st}")
st, r = call("POST", "/notifications/read-all", tok=tA)
ok("ҳама хондашуда қайд шуданд", st in (200, 201, 204), f"HTTP {st}: {r}")
st, r = call("GET", "/profile/notifications", tok=tA)
ok("танзимоти огоҳинома хонда мешавад", st == 200, f"HTTP {st}: {r}")
st, r = call("PUT", "/profile/notifications", {"likes": False}, tA)
ok("танзимоти огоҳинома иваз мешавад", st in (200, 201), f"HTTP {st}: {r}")

# Токени push-и сохта набояд серверро шиканад.
st, r = call("POST", "/notifications/push-token",
             {"token": f"sohta-token-{S}", "platform": "android"}, tA)
ok("токени push сабт мешавад", st in (200, 201), f"HTTP {st}: {r}")
st, r = call("DELETE", "/notifications/push-token",
             {"token": f"sohta-token-{S}"}, tA)
ok("токени push нест мешавад", st in (200, 204), f"HTTP {st}: {r}")

# ═══ 15. ПОСТҲОИ ҚАЙДШУДА ════════════════════════════════════════
st, r = call("GET", f"/users/{idA}/tagged", tok=tB)
ok("постҳои қайдшуда хонда мешаванд", st == 200, f"HTTP {st}: {r}")

# ═══ 16. ТӮҲФА ═══════════════════════════════════════════════════
st, r = call("POST", "/gifts/", {"toUserId": idB, "type": "rose", "amount": 1}, tA)
ok("тӯҳфа фиристода шуд", st in (200, 201, 400, 402),
   f"HTTP {st}: {r}")   # 402 = маблағ намерасад — ҳам дуруст аст
st, r = call("GET", "/gifts/received", tok=tB)
ok("тӯҳфаҳои гирифташуда", st == 200, f"HTTP {st}: {r}")

# ═══ 17. ДӮКОН: ПРОМОКОД ═════════════════════════════════════════
code = f"SANJ{S}".upper()[:12]
st, r = call("POST", "/shop/promos",
             {"code": code, "discountPct": 10, "maxUses": 5}, tA)
promo_ok = st in (200, 201)
ok("промокод сохта шуд", promo_ok, f"HTTP {st}: {r}")
st, lst = call("GET", "/shop/promos", tok=tA)
ok("промокод дар рӯйхат ҳаст", st == 200 and (code in jd(lst) or not promo_ok),
   str(lst)[:160])
st, r = call("POST", "/shop/promos/validate", {"code": code, "sellerId": idA}, tB)
ok("промокоди дуруст тасдиқ мешавад",
   st == 200 and isinstance(r, dict) and r.get("valid") is True,
   f"HTTP {st}: {r}")
# Ҷавоб 200 аст, вале бо `valid:false` — ин ҚАСДАН аст ва варақаи
# харид маҳз ҳамин майдонро мебинад (`buy_sheet.dart`), на рамзи
# HTTP-ро. Пас ин ҷо низ маҳз `valid` санҷида мешавад.
st, r = call("POST", "/shop/promos/validate",
             {"code": f"NEST{S}".upper()[:12], "sellerId": idA}, tB)
ok("промокоди сохта рад мешавад",
   isinstance(r, dict) and r.get("valid") is False, f"HTTP {st}: {r}")

# ═══ 18. ФАРМОИШ ═════════════════════════════════════════════════
st, r = call("GET", "/orders/", tok=tB)
ok("фармоишҳои ман", st == 200, f"HTTP {st}: {r}")
st, r = call("GET", "/orders/selling", tok=tA)
ok("фармоишҳои фурӯши ман", st == 200, f"HTTP {st}: {r}")

# ═══ 19. ГУРӮҲ ═══════════════════════════════════════════════════
st, g = call("POST", "/groups/", {"name": f"Гурӯҳи {S}", "memberIds": [idB]}, tA)
gid = (g.get("id") or g.get("_id")
       or (g.get("group") or {}).get("id")) if isinstance(g, dict) else None
ok("гурӯҳ сохта шуд", gid, g)
if gid:
    st, r = call("POST", f"/groups/{gid}/messages", {"text": "салом гурӯҳ"}, tA)
    ok("паём ба гурӯҳ", st in (200, 201), f"HTTP {st}: {r}")
    st, msgs = call("GET", f"/groups/{gid}/messages", tok=tB)
    ok("аъзо паёми гурӯҳро мебинад",
       st == 200 and "салом гурӯҳ" in jd(msgs), str(msgs)[:160])
    st, r = call("GET", f"/groups/{gid}", tok=tA)
    ok("маълумоти гурӯҳ", st == 200, f"HTTP {st}")
    st, r = call("POST", f"/groups/{gid}/leave", tok=tB)
    ok("баромадан аз гурӯҳ", st in (200, 201, 204), f"HTTP {st}: {r}")
    st, msgs = call("GET", f"/groups/{gid}/messages", tok=tB)
    ok("баъди баромадан паёмҳои гурӯҳ дида НАМЕШАВАНД",
       st in (401, 403, 404), f"HTTP {st}: {str(msgs)[:120]}")

# ═══ 20. БАРОМАДАН АЗ ҲАМАИ ДАСТГОҲҲО ════════════════════════════
# Охирин аст: баъди он токен эътибор надорад.
st, r = call("POST", "/auth/revoke-all", tok=tB)
ok("баромадан аз ҳамаи дастгоҳҳо", st in (200, 201, 204), f"HTTP {st}: {r}")
st, r = call("POST", "/auth/logout", tok=tB)
ok("баромадан", st in (200, 201, 204), f"HTTP {st}: {r}")

# ═══ ҲИСОБОТ ═════════════════════════════════════════════════════
bad = [x for x in res if not x[0]]
print()
for good, name, detail in res:
    print(("  ✅ " if good else "  ❌ ") + name + ("" if good else f"\n       → {detail}"))
print(f"\n{len(res) - len(bad)}/{len(res)} гузашт")
sys.exit(1 if bad else 0)
