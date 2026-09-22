#!/usr/bin/env python3
"""Санҷиши СЕРВЕРИ ЗИНДА — ҳамаи бахшҳо, аз аввал то охир.

═══════════════════════════════════════════════════════════════════
 Чаро ин файл ҳаст

 Тестҳои Go функсияҳои ҷудогонаро месанҷанд. Тестҳои Dart матни
 кодро мехонанд. Ҳеҷ кадоме намегӯяд:

   • оё пост воқеан сохта мешавад;
   • оё музика дар он нигоҳ дошта мешавад;
   • оё лайк огоҳинома медиҳад;
   • оё паёми такрорӣ дукарата сабт мешавад.

 Ин скрипт серверро бо базаи ҳақиқӣ мепартояд, ду корбари санҷишӣ
 месозад ва ҳамаи ҷараёнҳоро мегузаронад — маҳз ҳамон тавре ки
 барнома мекунад.

 Истифода:
   BASE=http://127.0.0.1:8099 python3 backend/testing/api_smoke.py

 ⚠️ ҲЕҶ ГОҲ ба сервери ПРОДАКШН нагузаронед: он корбар, пост ва
 стори месозад.
═══════════════════════════════════════════════════════════════════
"""

import json
import os
import sys
import urllib.error
import urllib.request

BASE = os.environ.get("BASE", "http://127.0.0.1:8099")
PW = "Test12345!"

results = []


def call(method, path, body=None, token=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(BASE + path, data=data, method=method)
    req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", "Bearer " + token)
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
    except Exception as e:  # шабака, timeout
        return 0, str(e)


def check(name, method, path, body=None, token=None, expect=(200, 201)):
    st, resp = call(method, path, body, token)
    results.append((st in expect, name, st, resp))
    return st, resp


def expect(name, condition, detail=""):
    results.append((bool(condition), name, "—", detail))


def register(username, email, phone):
    st, _ = call("POST", "/auth/register", {
        "username": username, "email": email, "password": PW,
        "fullName": username, "phone": phone,
    })
    # 409 = аллакай ҳаст (такрори иҷро) — ин хато нест
    return st in (200, 201, 409)


def login(username):
    st, r = call("POST", "/auth/login", {"email": username, "password": PW})
    if not isinstance(r, dict):
        return None, {}
    return r.get("accessToken"), (r.get("user") or {})


def main():
    suffix = os.environ.get("SUFFIX", "smoke")
    a, b = f"alpha{suffix}", f"beta{suffix}"

    expect("бақайдгирии корбари 1", register(a, f"{a}@example.com", "+992900100001"))
    expect("бақайдгирии корбари 2", register(b, f"{b}@example.com", "+992900100002"))

    t1, u1 = login(a)
    t2, u2 = login(b)
    expect("вуруд", bool(t1 and t2))
    if not (t1 and t2):
        report()
        return 1

    id1 = u1.get("id") or u1.get("_id")
    id2 = u2.get("id") or u2.get("_id")

    # ── Бехатарӣ ──
    check("пароли нодуруст рад мешавад", "POST", "/auth/login",
          {"email": a, "password": "wrong"}, expect=(400, 401))
    check("бе токен дастрасӣ нест", "GET", "/profile/me", expect=(401,))
    check("тасдиқи почта бе вуруд рад мешавад", "POST", "/auth/verify-email",
          {"email": "x@example.com"}, expect=(401,))

    # ── Профил ва обуна ──
    check("профили худам", "GET", "/profile/me", token=t1)
    check("тағйири профил", "PUT", "/profile/", {"bio": "санҷиш"}, token=t1)
    check("обуна шудан", "POST", f"/follow/{id2}", token=t1)
    check("рӯйхати обунашудагон", "GET", f"/users/{id2}/followers", token=t1)

    # ── Пост бо МУЗИКА ──
    st, p = check("сохтани пост", "POST", "/posts/", {
        "media": [{"url": "https://example.com/a.jpg", "type": "image"}],
        "caption": "Санҷиш #тест",
        "song": {
            "title": "Суруд", "artist": "Хонанда",
            "previewUrl": "https://audio-ssl.itunes.apple.com/x.m4a",
            "startMs": 30000, "endMs": 45000, "trackMs": 210000,
        },
    }, t1)
    pid = None
    if isinstance(p, dict):
        pid = p.get("id") or p.get("_id") or (p.get("post") or {}).get("id")

    if pid:
        st, g = check("пост хонда мешавад", "GET", f"/posts/{pid}", token=t1)
        song = (g.get("song") or (g.get("post") or {}).get("song")
                if isinstance(g, dict) else None) or {}
        # Маҳз ин ду сатр камбудии «номаша мегуяд, намехонад»-ро мегиранд.
        expect("музикаи пост суроға дорад", bool(song.get("previewUrl")), song)
        expect("ҷои оғози музика нигоҳ дошта шуд",
               song.get("startMs") == 30000, song)

        check("лайк", "POST", f"/posts/{pid}/like", token=t2)
        check("шарҳ", "POST", f"/comments/{pid}", {"text": "Шарҳи санҷишӣ"}, t2)
        st, cm = check("шарҳҳо хонда мешаванд", "GET", f"/comments/{pid}", token=t1)
        lst = cm.get("comments") if isinstance(cm, dict) else cm
        expect("шарҳ дар рӯйхат пайдо шуд", bool(lst))
        check("нигоҳ доштан", "POST", f"/posts/{pid}/save", token=t2)

        st, n = check("огоҳиномаҳо", "GET", "/notifications", token=t1)
        items = n.get("notifications") if isinstance(n, dict) else n
        kinds = [str(i.get("type") or i.get("kind")) for i in (items or [])] \
            if isinstance(items, list) else []
        expect("огоҳиномаи ЛАЙК сохта мешавад",
               any("like" in k for k in kinds), kinds[:8])
        expect("огоҳиномаи ШАРҲ сохта мешавад",
               any("comment" in k for k in kinds), kinds[:8])

    # ── Чат ──
    st, h = check("кушодани чат", "GET", f"/chat/with/{id2}", token=t1)
    cid = h.get("chatId") or h.get("id") if isinstance(h, dict) else None
    if cid:
        check("фиристодани паём", "POST", f"/chat/{cid}/messages",
              {"text": "Салом", "clientId": "smoke-1"}, t1)
        st, hist = check("таърихи чат", "GET", f"/chat/{cid}/messages", token=t1)
        msgs = hist.get("messages") if isinstance(hist, dict) else hist
        expect("паём дар таърих ҳаст", bool(msgs))

        # Идемпотентӣ: ҳамон `clientId` набояд паёми дуюм созад.
        # Бе ин, паёми офлайн ҳангоми баргаштани интернет дукарата
        # мешуд.
        call("POST", f"/chat/{cid}/messages",
             {"text": "Салом", "clientId": "smoke-1"}, t1)
        st, h2 = call("GET", f"/chat/{cid}/messages", token=t1)
        m2 = h2.get("messages") if isinstance(h2, dict) else h2
        expect("такрори clientId паёми дукарата намесозад",
               isinstance(m2, list) and isinstance(msgs, list)
               and len(m2) == len(msgs),
               f"{len(msgs or [])} → {len(m2 or [])}")

        st, chats = check("рӯйхати чат", "GET", "/chat/", token=t2)
        rows = chats.get("chats") if isinstance(chats, dict) else []
        expect("шуморандаи хонданашуда кор мекунад",
               any((c or {}).get("unreadCount", 0) > 0 for c in (rows or [])),
               rows[:1] if rows else rows)

    # ── Стори ──
    st, s = check("сохтани стори", "POST", "/stories/",
                  {"mediaUrl": "https://example.com/s.jpg",
                   "mediaType": "image"}, t1)
    sid = None
    if isinstance(s, dict):
        sid = s.get("id") or s.get("_id") or (s.get("story") or {}).get("id")
    if sid:
        check("тамошои стори", "POST", f"/stories/{sid}/view", token=t2)
        check("тамошобинони стори", "GET", f"/stories/{sid}/viewers", token=t1)

    # ── Хондан: ҳар бахши барнома ──
    for name, path in [
        ("лента", "/posts/feed"),
        ("explore", "/explore"),
        ("кашфи имрӯз", "/discover"),
        ("дар авҷ", "/discover/trending"),
        ("тавсияи одамон", "/discover/people"),
        ("ҷустуҷӯи корбар", "/search/users?q=alpha"),
        ("Reels", "/reels"),
        ("сторисҳо", "/stories/"),
        ("гурӯҳҳо", "/groups/"),
        ("калимаҳои пинҳон", "/profile/hidden-words"),
        ("даъватҳои ҳамкорӣ", "/collabs/pending"),
        ("дӯстони наздик", "/close-friends/ids"),
        ("коллексияҳо", "/collections"),
        ("Live", "/live/"),
        ("эффектҳо", "/effects/"),
        ("тӯҳфаҳо", "/gifts/received"),
        ("студияи муаллиф", "/creator/studio"),
        ("дӯкон", "/shop"),
        ("хабарҳо", "/news"),
        ("сессияҳо", "/auth/sessions"),
    ]:
        check(name, "GET", path, token=t1)

    # ── Рамзи телефон: бояд РӮИРОСТ хато диҳад, на «фиристода шуд» ──
    #
    # Дар CI ҳеҷ канал танзим нашудааст. Ҷавоби дуруст 502 аст.
    # Агар ин ҷо 200 барояд — маънои он ки барнома равзанаи «рамзро
    # ворид кунед» мекушояд ва корбар паёмеро интизор мешавад, ки
    # ҳеҷ гоҳ намеояд. Маҳз ҳамин камбудӣ буд.
    st, otp = call("POST", "/auth/send-phone-otp", {"phone": "+992900100009"})
    expect("рамзи нафиристода 502 медиҳад, на «фиристода шуд»",
           st in (502, 429), f"HTTP {st}: {otp}")

    return report()


def report():
    ok = sum(1 for r in results if r[0])
    print()
    print("=" * 72)
    print(f"  {ok}/{len(results)} гузашт")
    print("=" * 72)
    for good, name, st, detail in results:
        extra = ""
        if not good:
            d = detail if isinstance(detail, str) else json.dumps(
                detail, ensure_ascii=False)
            extra = "  " + d[:150]
        print(f"{'OK  ' if good else 'FAIL'} [{st}] {name}{extra}")
    return 0 if ok == len(results) else 1


if __name__ == "__main__":
    sys.exit(main())
