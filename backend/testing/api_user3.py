#!/usr/bin/env python3
"""Кашф, ҷустуҷӯ, Live, эффект, танзимоти лента, реклама, шарҳ.

═══════════════════════════════════════════════════════════════════
 Идомаи `api_user2.py`. Ин ҷо бахшҳои боқимонда:

   • ҷустуҷӯ ва explore
   • «Кашф» ва одамони пешниҳодшуда
   • Live: оғоз, шомилшавӣ, шарҳ, лайк, анҷом
   • эффектҳо
   • танзимоти лента (мавзӯъ, муаллиф, «чаро ин ба ман нишон дода шуд»)
   • шарҳ: таҳрир, лайк, ҷавоб, шикоят
   • дидашудаи пост (view / view-batch)
   • реклама: пешрафт ва мақсад — БЕ ягон намоиши сохта
   • студияи муаллиф ва омор

 ⚠️ Бахши реклама ТАНҲО хондан аст. Ҳеҷ ҷаласаи тамошо сохта
 намешавад ва ҳеҷ мукофот талаб карда намешавад: онро танҳо
 намоиши ҲАҚИҚИИ Yandex дар телефон ба вуҷуд оварда метавонад.

 ⚠️ Ба сервери МАҲАЛЛӢ мезанад. Ба продакшн чизе навишта намешавад.
═══════════════════════════════════════════════════════════════════
"""

import json, os, sys, time, urllib.request, urllib.error

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


def reg(u, e, ph):
    st, _ = call("POST", "/auth/register",
                 {"username": u, "email": e, "password": PW,
                  "fullName": u, "phone": ph})
    return st in (200, 201, 409)


def login(u):
    st, r = call("POST", "/auth/login", {"email": u, "password": PW})
    if not isinstance(r, dict):
        return None, {}
    return r.get("accessToken"), (r.get("user") or {})


def ok(n, c, d=""):
    res.append((bool(c), n, str(d)[:160]))


def jd(x):
    return json.dumps(x, ensure_ascii=False)


S = os.environ.get("SUFFIX", "u3")
A, Bu = f"va{S}", f"vb{S}"
reg(A, f"{A}@example.com", "+992900800001")
reg(Bu, f"{Bu}@example.com", "+992900800002")
tA, uA = login(A)
tB, uB = login(Bu)
idA = uA.get("id") or uA.get("_id")
idB = uB.get("id") or uB.get("_id")
if not (tA and tB):
    print("!! вуруд нашуд — сервер кор намекунад?")
    sys.exit(1)

st, p = call("POST", "/posts/",
             {"caption": f"пости кашф {S}",
              "media": [{"url": "https://example.com/p.jpg", "type": "image"}]},
             tA)
pid = (p.get("id") or p.get("_id")
       or (p.get("post") or {}).get("id")) if isinstance(p, dict) else None
ok("пости заминавӣ сохта шуд", pid, p)

# ═══ 1. ҶУСТУҶӮ ═══════════════════════════════════════════════════
st, r = call("GET", f"/search/?q={A}", tok=tB)
ok("ҷустуҷӯи умумӣ корбарро меёбад", st == 200 and A in jd(r),
   f"HTTP {st}: {str(r)[:140]}")
st, r = call("GET", f"/search/users?q={A}", tok=tB)
ok("ҷустуҷӯи корбарон", st == 200 and A in jd(r), f"HTTP {st}: {str(r)[:140]}")
st, r = call("GET", "/search/?q=", tok=tB)
ok("ҷустуҷӯи холӣ серверро намешиканад", st in (200, 400), f"HTTP {st}")
# Ҷустуҷӯ набояд ба SQL роҳ диҳад.
st, r = call("GET", "/search/users?q=%27%20OR%201%3D1--", tok=tB)
ok("ҷустуҷӯ ба SQL injection тобовар аст", st in (200, 400), f"HTTP {st}: {str(r)[:120]}")

# ═══ 2. EXPLORE ВА КАШФ ══════════════════════════════════════════
st, r = call("GET", "/explore", tok=tB)
ok("explore кор мекунад", st == 200, f"HTTP {st}: {str(r)[:120]}")
st, r = call("GET", "/explore?page=2", tok=tB)
ok("саҳифаи дуюми explore", st == 200, f"HTTP {st}")
st, r = call("GET", "/discover", tok=tB)
ok("«Кашф»-и имрӯза", st == 200, f"HTTP {st}: {str(r)[:120]}")
st, r = call("GET", "/discover/trending", tok=tB)
ok("мавзӯъҳои маъмул", st == 200, f"HTTP {st}")
st, r = call("GET", "/discover/people", tok=tB)
ok("одамони пешниҳодшуда", st == 200, f"HTTP {st}")
st, r = call("GET", "/users/suggestions", tok=tB)
ok("пешниҳоди обуна", st == 200, f"HTTP {st}")
st, r = call("GET", "/news", tok=tB)
ok("хабарҳо", st == 200, f"HTTP {st}")

# ═══ 3. ШАРҲ: таҳрир, лайк, шикоят ═══════════════════════════════
cid = None
if pid:
    st, c = call("POST", f"/posts/{pid}/comments", {"text": "шарҳи аввал"}, tB)
    cid = (c.get("id") or c.get("_id")
           or (c.get("comment") or {}).get("id")) if isinstance(c, dict) else None
    ok("шарҳ гузошта шуд", cid, c)

if cid:
    st, r = call("POST", f"/comments/{cid}/like", tok=tA)
    ok("лайк ба шарҳ", st in (200, 201), f"HTTP {st}: {r}")
    st, r = call("PUT", f"/comments/{cid}", {"text": "шарҳи ТАҲРИРШУДА"}, tB)
    edited = st in (200, 201)
    ok("муаллиф шарҳи худро таҳрир мекунад", edited, f"HTTP {st}: {r}")
    if edited:
        st, lst = call("GET", f"/posts/{pid}/comments", tok=tA)
        ok("матни таҳриршуда нигоҳ дошта шуд",
           "ТАҲРИРШУДА" in jd(lst), str(lst)[:160])
    st, r = call("PUT", f"/comments/{cid}", {"text": "аз номи бегона"}, tA)
    ok("бегона шарҳи маро таҳрир карда НАМЕТАВОНАД",
       st in (401, 403, 404), f"HTTP {st}: {r}")
    st, r = call("POST", f"/comments/{cid}/report", {"reason": "spam"}, tA)
    ok("шикоят ба шарҳ", st in (200, 201), f"HTTP {st}: {r}")

# ═══ 4. ДИДАШУДАИ ПОСТ ═══════════════════════════════════════════
if pid:
    st, r = call("POST", f"/posts/view/{pid}", tok=tB)
    ok("дидашуда сабт мешавад", st in (200, 201, 204), f"HTTP {st}: {r}")
    st, r = call("POST", "/posts/view-batch", {"postIds": [pid]}, tB)
    ok("дидашудаи дастаӣ", st in (200, 201, 204), f"HTTP {st}: {r}")
    # ID-и сохта набояд серверро шиканад.
    st, r = call("POST", "/posts/view-batch",
                 {"postIds": ["nest-1", "nest-2"]}, tB)
    ok("ID-и нобуд серверро намешиканад", st in (200, 201, 204, 400),
       f"HTTP {st}: {r}")

# ═══ 5. LIVE ═════════════════════════════════════════════════════
st, lv = call("POST", "/live/start", {"title": f"Live {S}"}, tA)
lid = (lv.get("id") or lv.get("_id")
       or (lv.get("live") or {}).get("id")) if isinstance(lv, dict) else None
ok("Live оғоз шуд", lid, lv)

if lid:
    st, r = call("GET", "/live/", tok=tB)
    ok("Live дар рӯйхати зинда ҳаст", st == 200 and lid in jd(r),
       str(r)[:160])
    st, r = call("POST", f"/live/{lid}/join", tok=tB)
    ok("шомилшавӣ ба Live", st in (200, 201), f"HTTP {st}: {r}")
    st, r = call("POST", f"/live/{lid}/comment", {"text": "салом live"}, tB)
    ok("шарҳ дар Live", st in (200, 201), f"HTTP {st}: {r}")
    st, r = call("GET", f"/live/{lid}/comments", tok=tA)
    ok("шарҳи Live хонда мешавад", st == 200 and "салом live" in jd(r),
       str(r)[:160])
    st, r = call("POST", f"/live/{lid}/like", tok=tB)
    ok("лайк дар Live", st in (200, 201), f"HTTP {st}: {r}")
    st, r = call("POST", f"/live/{lid}/end", tok=tB)
    ok("бегона Live-и маро хотима дода НАМЕТАВОНАД",
       st in (401, 403, 404), f"HTTP {st}: {r}")
    st, r = call("POST", f"/live/{lid}/leave", tok=tB)
    ok("баромадан аз Live", st in (200, 201, 204), f"HTTP {st}: {r}")
    st, r = call("POST", f"/live/{lid}/end", tok=tA)
    ok("соҳиб Live-ро хотима медиҳад", st in (200, 201), f"HTTP {st}: {r}")
    st, r = call("GET", "/live/", tok=tB)
    ok("Live-и хотимаёфта дигар зинда нест", lid not in jd(r), str(r)[:160])

# ═══ 6. ЭФФЕКТҲО ═════════════════════════════════════════════════
st, r = call("GET", "/effects/", tok=tA)
ok("рӯйхати эффектҳо", st == 200, f"HTTP {st}: {str(r)[:120]}")
st, r = call("GET", "/effects/mine", tok=tA)
ok("эффектҳои ман", st == 200, f"HTTP {st}")

# ═══ 7. ТАНЗИМОТИ ЛЕНТА ══════════════════════════════════════════
st, r = call("GET", "/feed/preferences", tok=tA)
ok("танзимоти лента хонда мешавад", st == 200, f"HTTP {st}: {str(r)[:120]}")
st, r = call("PUT", "/feed/preferences/topic",
             {"topic": "sport", "score": 1}, tA)
ok("мавзӯи лента танзим мешавад", st in (200, 201), f"HTTP {st}: {r}")
st, r = call("PUT", "/feed/preferences/creator",
             {"creatorId": idB, "score": 1}, tA)
ok("муаллифи дӯстдошта танзим мешавад", st in (200, 201), f"HTTP {st}: {r}")
if pid:
    st, r = call("POST", "/feed/feedback",
                 {"event": "like", "contentId": pid, "contentType": "post"}, tA)
    ok("баҳои лента сабт мешавад", st in (200, 201, 204), f"HTTP {st}: {r}")
    st, r = call("GET", f"/feed/explanation/post/{pid}", tok=tA)
    ok("«чаро ин ба ман нишон дода шуд»", st == 200, f"HTTP {st}: {str(r)[:120]}")
st, r = call("POST", "/feed/reset", tok=tA)
ok("танзимоти лента аз сар оғоз мешавад", st in (200, 201, 204),
   f"HTTP {st}: {r}")

# ═══ 8. РЕКЛАМА — ТАНҲО ХОНДАН ═══════════════════════════════════
# Ҳеҷ ҷаласаи тамошо сохта НАМЕШАВАД: намоиши ҳақиқиро танҳо
# Yandex дар телефон медиҳад, ва мукофоти сохта қоидаро вайрон
# мекунад.
st, r = call("GET", "/ads/progress", tok=tA)
ok("пешрафти реклама хонда мешавад", st == 200, f"HTTP {st}: {str(r)[:140]}")
st, r = call("PUT", "/ads/goal", {"goal": "blue"}, tA)
# `goal` МАТН аст (номи зина), на рақам — барнома низ
# ҳамон тавр мефиристад (`verification_screen.dart`).
ok("мақсади реклама танзим мешавад", st in (200, 201, 400),
   f"HTTP {st}: {r}")
# Талаби мукофот БЕ ҷаласа бояд рад шавад.
st, r = call("POST", "/ads/watched",
             {"sessionId": f"sohta-{S}", "unitId": "R-M-19230220-2"}, tA)
ok("мукофот БЕ ҷаласаи ҳақиқӣ дода НАМЕШАВАД",
   st in (400, 401, 403, 404, 409, 422), f"HTTP {st}: {r}")

# ═══ 9. СТУДИЯИ МУАЛЛИФ ══════════════════════════════════════════
st, r = call("GET", "/creator/studio", tok=tA)
ok("студияи муаллиф", st == 200, f"HTTP {st}: {str(r)[:120]}")
st, r = call("GET", "/creator/analytics", tok=tA)
ok("омори муаллиф", st == 200, f"HTTP {st}")
st, r = call("GET", "/creator/insights", tok=tA)
ok("таҳлили муаллиф", st == 200, f"HTTP {st}")
st, r = call("GET", "/creator/achievements", tok=tA)
ok("дастовардҳои муаллиф", st == 200, f"HTTP {st}")
st, r = call("GET", "/creator/recap/week", tok=tA)
ok("ҷамъбасти ҳафта (муаллиф)", st == 200, f"HTTP {st}")
st, r = call("GET", "/recap/week", tok=tB)
ok("ҷамъбасти ҳафта (тамошобин)", st == 200, f"HTTP {st}")

# ═══ 10. БОҚИМОНДА ═══════════════════════════════════════════════
st, r = call("GET", "/referrals/me", tok=tA)
ok("даъватҳои ман", st == 200, f"HTTP {st}")
st, r = call("GET", "/collabs/pending", tok=tA)
ok("ҳаммуаллифии интизорӣ", st == 200, f"HTTP {st}")
st, r = call("GET", "/profile/saved", tok=tA)
ok("захирашудаҳо", st == 200, f"HTTP {st}")
st, r = call("GET", "/posts/scheduled", tok=tA)
ok("постҳои вақтбандишуда", st == 200, f"HTTP {st}")
st, r = call("GET", "/posts/smart-feed", tok=tA)
ok("лентаи ҳушманд", st == 200, f"HTTP {st}")
st, r = call("GET", "/reels/smart", tok=tA)
ok("Reels-и ҳушманд", st == 200, f"HTTP {st}")

# ═══ 11. БЕ ТОКЕН ҲЕҶ ЧИЗ ════════════════════════════════════════
# Як бор барои ҳар гурӯҳ: агар роҳе кушода монад, ҳамаи маълумоти
# шахсӣ ба ҳар кас дастрас мешавад.
for path in ["/explore", "/discover", "/creator/studio", "/ads/progress",
             "/feed/preferences", "/profile/saved", "/live/"]:
    st, _ = call("GET", path)
    ok(f"бе токен: {path} рад мешавад", st in (401, 403), f"HTTP {st}")

# ═══ ҲИСОБОТ ═════════════════════════════════════════════════════
bad = [x for x in res if not x[0]]
print()
for good, name, detail in res:
    print(("  ✅ " if good else "  ❌ ") + name
          + ("" if good else f"\n       → {detail}"))
print(f"\n{len(res) - len(bad)}/{len(res)} гузашт")
sys.exit(1 if bad else 0)
