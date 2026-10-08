#!/usr/bin/env python3
"""Функсияҳои нимтамом — ба анҷом расонида шуданд (мисли Instagram).

 Санҷида мешавад:
  • Explore: саҳифабандии воқеӣ — саҳифаи 2 ≠ саҳифаи 1, бе такрор,
    тартиби устувор дар як ҷаласа (seed), «hasMore»;
  • Reels «Ба ман шавқовар нест» — дигар дар /reels, /reels/smart,
    лентаи «Дӯстон» ва Explore намеояд;
  • шарҳҳои Live — ҳамон қоидаи LiveToken: ҳисоби пӯшида ва бастан;
  • «Ҷой»-и Reels — сохтан, дар ҳамаи роҳҳо, саҳифаи ҷой (/reels);
  • бойгонӣ: постҳо ва сторисҳо — рӯйхат ва барқароркунӣ;
  • рӯйхати хомӯшшудагон ва маҳдудшудагон (идоракунӣ);
  • илова кардани сторис ба актуалии МАВҶУДА.
 ⚠️ Ба сервери МАҲАЛЛӢ мезанад.
"""
import json, os, sys, time, urllib.parse, urllib.request, urllib.error
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
def ok(n, c, d=""): res.append((bool(c), n, str(d)[:240]))
def ids(lst): return [x.get("_id") or x.get("id") for x in (lst or []) if isinstance(x, dict)]
def q(s): return urllib.parse.quote(s)

S = os.environ.get("SUFFIX", "cm")
IMG = "https://example.com/c.jpg"; VID = "https://example.com/c.mp4"
tA, A = user(f"cma{S}", "+992900977001")   # муаллифи кушода
tB, Bb = user(f"cmb{S}", "+992900977002")  # тамошобин
tC, C = user(f"cmc{S}", "+992900977003")   # ҳисоби пӯшида
tD, D = user(f"cmd{S}", "+992900977004")   # тамошобинро баст
ok("корбарон сохта шуданд", all([tA, tB, tC, tD]), [A, Bb, C, D])
call("PUT", "/profile/", {"isPrivate": True}, tC)

# ═══ 1. EXPLORE: саҳифабандии воқеӣ ════════════════════════════════
# Барои ду саҳифаи пурра постҳои кофӣ.
for i in range(32):
    call("POST", "/posts/", {"caption": f"explore {S} {i}", "media": [{"url": IMG, "type": "image"}]}, tA)
seed = f"s{S}x1"
st1, p1 = call("GET", f"/explore?page=1&seed={seed}", tok=tB)
st2, p2 = call("GET", f"/explore?page=2&seed={seed}", tok=tB)
ids1, ids2 = ids(p1.get("posts")), ids(p2.get("posts"))
ok("explore саҳифаи 1 — 30 пост", st1 == 200 and len(ids1) == 30, (st1, len(ids1)))
ok("explore саҳифаи 2 холӣ нест", st2 == 200 and len(ids2) > 0, (st2, len(ids2)))
ok("саҳифаи 2 ≠ саҳифаи 1 (бе такрор)", not (set(ids1) & set(ids2)), set(ids1) & set(ids2))
ok("ҷавоб hasMore ва seed дорад", p1.get("hasMore") is True and p1.get("seed") == seed, {k: p1.get(k) for k in ("hasMore", "seed", "page")})
st, again = call("GET", f"/explore?page=1&seed={seed}", tok=tB)
ok("ҳамон seed → ҳамон тартиб (устувор)", ids(again.get("posts")) == ids1, "")
st, other = call("GET", f"/explore?page=1&seed=z{S}y2", tok=tB)
ok("seed-и дигар → тартиби дигар", ids(other.get("posts")) != ids1, "")
# Ҳамаи саҳифаҳо то охир: ягон пост ду бор намеояд.
seen, dup, pg, last = set(), [], 1, None
while pg <= 30:
    st, r = call("GET", f"/explore?page={pg}&seed={seed}", tok=tB)
    cur = ids(r.get("posts")) + ids(r.get("reels"))
    dup += [x for x in cur if x in seen]; seen |= set(cur); last = r
    if not r.get("hasMore"): break
    pg += 1
ok("ҳамаи саҳифаҳо: ягон такрор нест", not dup and pg > 1, (pg, dup[:3]))
ok("саҳифаи охир hasMore=false", last and last.get("hasMore") is False, pg)
st, r = call("GET", "/explore?page=1&seed=bad'seed", tok=tB)
ok("seed-и нодуруст → 200 (тартиби маъмулият)", st == 200 and r.get("seed") == "", (st, r.get("seed") if isinstance(r, dict) else r))

# ═══ 2. Reels «Ба ман шавқовар нест» ═══════════════════════════════
st, rl = call("POST", "/reels/", {"videoUrl": VID, "caption": f"nope {S}"}, tA); rid = rl.get("_id")
call("POST", f"/follow/{A}", tok=tB)
st, r = call("GET", "/reels/?limit=100", tok=tB)
ok("reel пеш аз «шавқовар нест» дар /reels", rid in ids(r.get("reels")), rid)
st, r = call("POST", f"/reels/{rid}/not_interest", tok=tB)
ok("«шавқовар нест» сабт шуд", st == 200, (st, r))
for path in ("/reels/?limit=100", "/reels/?limit=100&friends=1", "/reels/smart?limit=100"):
    st, r = call("GET", path, tok=tB)
    ok(f"пинҳоншуда дар {path} нест", st == 200 and rid not in ids(r.get("reels")), st)
gone = True
for pg in range(1, 6):
    st, r = call("GET", f"/explore?page={pg}&seed={seed}", tok=tB)
    if rid in ids(r.get("reels")): gone = False
ok("пинҳоншуда дар Explore нест", gone)
st, r = call("GET", "/reels/?limit=100", tok=tA)
ok("барои дигарон (муаллиф) reel мемонад", rid in ids(r.get("reels")))
call("POST", f"/reels/{rid}/interest", tok=tB)
st, r = call("GET", "/reels/?limit=100", tok=tB)
ok("«Шавқовар» → reel бармегардад", rid in ids(r.get("reels")))

# ═══ 3. Шарҳҳои Live: ҳамон қоидаи RequireVisible ══════════════════
st, lv = call("POST", "/live/start", {"title": f"хусусӣ {S}"}, tC); lidC = lv.get("id")
call("POST", f"/live/{lidC}/comment", {"text": "сирри эфир"}, tC)
st, r = call("GET", f"/live/{lidC}/comments", tok=tC)
ok("ҳост шарҳҳои худро мебинад", st == 200 and len(r.get("comments") or []) == 1, (st, r))
st, r = call("GET", f"/live/{lidC}/comments", tok=tB)
ok("ғайриобуна шарҳҳои эфири ҳисоби пӯшидаро НАМЕБИНАД", st == 404 and not (r.get("comments") if isinstance(r, dict) else None), (st, r))
st, r = call("POST", f"/live/{lidC}/token", tok=tB)
ok("ғайриобуна token-и эфири пӯшида намегирад", st == 404, (st, r))
st, lv = call("POST", "/live/start", {"title": f"кушода {S}"}, tA); lidA = lv.get("id")
call("POST", f"/live/{lidA}/comment", {"text": "салом"}, tB)
st, r = call("GET", f"/live/{lidA}/comments", tok=tB)
ok("эфири кушода — шарҳҳо намоён", st == 200 and len(r.get("comments") or []) == 1, (st, r))
call("POST", f"/users/{D}/block", tok=tA)
st, r = call("GET", f"/live/{lidA}/comments", tok=tD)
ok("басташуда шарҳҳоро НАМЕБИНАД", st == 404, (st, r))
st, r = call("POST", f"/live/{lidA}/token", tok=tD)
ok("басташуда token намегирад", st == 404, (st, r))
call("POST", f"/live/{lidA}/end", tok=tA); call("POST", f"/live/{lidC}/end", tok=tC)
st, r = call("GET", f"/live/{lidA}/comments", tok=tB)
ok("баъди анҷом шарҳҳо барои тамошобини иҷозатдор боқӣ", st == 200, st)

# ═══ 4. «Ҷой»-и Reels ══════════════════════════════════════════════
st, rl = call("POST", "/reels/", {"videoUrl": VID, "caption": f"ҷой {S}", "locationId": "tj-khujand"}, tA)
lrid = rl.get("_id")
ok("reel бо ҷой сохта шуд", st == 201 and rl.get("locationId") == "tj-khujand" and rl.get("location") == "Хуҷанд", rl)
st, r = call("GET", f"/reels/{lrid}", tok=tB)
ok("/reels/:id ҷой дорад", r.get("locationId") == "tj-khujand" and r.get("location") == "Хуҷанд", r.get("location") if isinstance(r, dict) else r)
st, r = call("GET", "/reels/?limit=100", tok=tB)
x = next((e for e in r.get("reels") or [] if e.get("_id") == lrid), {})
ok("/reels ҷойро мефиристад", x.get("locationId") == "tj-khujand", x.get("location"))
st, r = call("GET", f"/users/{A}/reels", tok=tB)
x = next((e for e in (r if isinstance(r, list) else []) if e.get("_id") == lrid), {})
ok("профил ҷойро мефиристад", x.get("location") == "Хуҷанд", x.get("location"))
st, r = call("GET", "/places/tj-khujand/reels", tok=tB)
ok("саҳифаи ҷой: reel дар /places/:id/reels", st == 200 and lrid in ids(r.get("reels")), (st, ids(r.get("reels"))[:3]))
st, rl2 = call("POST", "/reels/", {"videoUrl": VID, "caption": "x", "location": f"Боғи {S}"}, tA)
ok("ҷойи дастӣ (бе id) сабт шуд", rl2.get("location") == f"Боғи {S}" and rl2.get("locationId") == "", rl2)
st, r = call("GET", "/places/text/reels?name=" + q(f"Боғи {S}"), tok=tB)
ok("ҷойи дастӣ: /places/text/reels", st == 200 and rl2.get("_id") in ids(r.get("reels")), st)
st, rc = call("POST", "/reels/", {"videoUrl": VID, "caption": "x", "locationId": "tj-khujand"}, tC)
st, r = call("GET", "/places/tj-khujand/reels", tok=tB)
ok("ҳисоби пӯшида дар саҳифаи ҷой НЕСТ", rc.get("_id") not in ids(r.get("reels")))
st, r = call("GET", "/places/tj-khujand/reels", tok=tD)
ok("басташуда reel-и муаллифро дар саҳифаи ҷой НАМЕБИНАД", lrid not in ids(r.get("reels")))
st, r = call("GET", "/places/xx-nope/reels", tok=tB)
ok("ҷойи нест → 404", st == 404, st)

# Стикери «📍 Ҷой» дар сторис.
st, sl = call("POST", "/stories/", {"mediaUrl": IMG, "mediaType": "image",
              "sticker": {"kind": "location", "prompt": "Хуҷанд", "url": "tj-khujand"}}, tA)
slid = sl.get("_id") or sl.get("id")
st, r = call("GET", f"/stories/{slid}", tok=tB)
stk = (r or {}).get("sticker") or {}
ok("стикери ҷой: kind=location, placeId", stk.get("kind") == "location" and stk.get("placeId") == "tj-khujand", (st, stk))
st, r = call("POST", "/stories/", {"mediaUrl": IMG, "mediaType": "image",
             "sticker": {"kind": "location", "prompt": ""}}, tA)
ok("стикери ҷой бе ном рад мешавад", st == 400, (st, r))

# ═══ 5. Бойгонӣ: постҳо ва сторисҳо ════════════════════════════════
st, p = call("POST", "/posts/", {"caption": f"бойгонӣ {S}", "media": [{"url": IMG, "type": "image"}]}, tA); apid = p.get("_id")
st, r = call("POST", f"/posts/{apid}/archive", tok=tA)
ok("пост ба бойгонӣ рафт", r.get("archived") is True, r)
st, r = call("GET", "/archive/posts", tok=tA)
ok("бойгонии постҳо: пост ҳаст", st == 200 and apid in ids(r.get("posts")), (st, ids(r.get("posts"))[:3]))
st, r = call("GET", "/archive/posts", tok=tB)
ok("бойгонии дигар корбар намоён нест", apid not in ids(r.get("posts")))
st, r = call("GET", f"/users/{A}/posts", tok=tB)
ok("пости бойгонӣ дар профил нест", apid not in ids(r.get("posts") if isinstance(r, dict) else r))
st, r = call("POST", f"/posts/{apid}/archive", tok=tA)
ok("барқарор: archived=false", r.get("archived") is False, r)
st, r = call("GET", "/archive/posts", tok=tA)
ok("баъди барқарор дар бойгонӣ нест", apid not in ids(r.get("posts")))
st, r = call("POST", f"/posts/{apid}/archive", tok=tB)
ok("бегона бойгонӣ карда наметавонад", st == 403, st)

st, s1 = call("POST", "/stories/", {"mediaUrl": IMG, "mediaType": "image"}, tA)
sid = s1.get("_id") or s1.get("id") or (s1.get("story") or {}).get("_id")
st, r = call("GET", "/archive/stories", tok=tA)
ok("бойгонии сторис: сториси фаъол ҳам ҳаст", st == 200 and sid in ids(r.get("stories")), (st, ids(r.get("stories"))[:3]))
x = next((e for e in r.get("stories") or [] if (e.get("_id") or e.get("id")) == sid), {})
ok("сторис: expired=false, archived=false", x.get("expired") is False and x.get("archived") is False, x)
call("POST", f"/stories/{sid}/archive", tok=tA)
st, r = call("GET", "/archive/stories", tok=tA)
x = next((e for e in r.get("stories") or [] if (e.get("_id") or e.get("id")) == sid), {})
ok("сторис дар бойгонӣ archived=true", x.get("archived") is True, x)
st, r = call("GET", "/stories/", tok=tB)
ok("сториси бойгонӣ дар лента нест", sid not in json.dumps(r), "")
st, r = call("GET", "/archive/stories", tok=tB)
ok("бойгонии сториси дигар корбар намоён нест", sid not in ids(r.get("stories")))

# ═══ 6. Хомӯшшудагон ва маҳдудшудагон ══════════════════════════════
call("POST", f"/users/{C}/mute", tok=tB); call("POST", f"/users/{A}/restrict", tok=tB)
st, r = call("GET", "/users/muted", tok=tB)
ok("рӯйхати хомӯшшудагон", st == 200 and C in ids(r.get("users")), (st, r))
st, r = call("GET", "/users/restricted", tok=tB)
ok("рӯйхати маҳдудшудагон", st == 200 and A in ids(r.get("users")), (st, r))
call("DELETE", f"/users/{C}/mute", tok=tB); call("POST", f"/users/{A}/unrestrict", tok=tB)
st, r = call("GET", "/users/muted", tok=tB)
ok("баъди «Хомӯш накардан» холӣ", C not in ids(r.get("users")))
st, r = call("GET", "/users/restricted", tok=tB)
ok("баъди «Маҳдуд накардан» холӣ", A not in ids(r.get("users")))
st, r = call("GET", "/users/muted", tok=tA)
ok("рӯйхати дигарон намоён нест", C not in ids(r.get("users")))

# ═══ 7. Сторис ба актуалии МАВҶУДА ═════════════════════════════════
st, s2 = call("POST", "/stories/", {"mediaUrl": IMG + "?2", "mediaType": "image"}, tA)
sid2 = s2.get("_id") or s2.get("id")
st, h = call("POST", "/highlights/", {"title": "Сафар", "storyIds": [sid],
             "items": [{"url": IMG, "type": "image", "storyId": sid}]}, tA)
hid = h.get("_id") or h.get("id")
st, r = call("POST", f"/highlights/{hid}/stories", {"storyId": sid2}, tA)
ok("сторис ба актуалии мавҷуда илова шуд", st == 200 and r.get("added") is True, (st, r))
st, r = call("GET", f"/highlights/{A}", tok=tA)
hh = next((e for e in r.get("highlights") or [] if e.get("_id") == hid), {})
ok("актуалӣ акнун 2 унсур дорад", len(hh.get("items") or []) == 2 and sid2 in (hh.get("storyIds") or []), hh)
st, r = call("POST", f"/highlights/{hid}/stories", {"storyId": sid2}, tA)
st, r = call("GET", f"/highlights/{A}", tok=tA)
hh = next((e for e in r.get("highlights") or [] if e.get("_id") == hid), {})
ok("такрор илова намешавад", len(hh.get("items") or []) == 2, len(hh.get("items") or []))
st, sB = call("POST", "/stories/", {"mediaUrl": IMG, "mediaType": "image"}, tB)
st, r = call("POST", f"/highlights/{hid}/stories", {"storyId": sB.get("_id") or sB.get("id")}, tA)
ok("сториси бегона илова намешавад", st == 404, (st, r))
st, r = call("POST", f"/highlights/{hid}/stories", {"storyId": sid2}, tB)
ok("ба актуалии бегона илова намешавад", st == 404, (st, r))

passed = sum(1 for p, _, _ in res if p)
for p, n, d in res:
    print(("  ✅ " if p else "  ❌ ") + n + ("" if p else "  → " + d))
print(f"\n{passed}/{len(res)} гузашт")
sys.exit(0 if passed == len(res) else 1)
