#!/usr/bin/env python3
"""Панҷ имконияти нав — санҷиш бо сервери ҳақиқӣ.

 1. «Даъватнома»: сохтан, даъват, Меоям/Шояд/Намеоям + меҳмон, рӯйхати
    меҳмонон (танҳо мизбон), линк бо код, оммавӣ, албоми муштарак (пас аз
    оғоз, танҳо иштирокчиён), таҳрир/бекор, огоҳиномаҳо;
 2. Пурсиш/викторина дар пост: як овоз, натиҷа баъди овоз, овоздиҳандагон
    танҳо барои муаллиф, hasPoll дар рӯйхатҳо;
 3. «Савол ба ман»: танзим (обуначиён/ҳама/хомӯш), беном (ном ба соҳиб ва
    тамошобин нишон дода намешавад), ҷавоб, бастани пинҳонии савoлдиҳанда;
 4. «Мактуб ба оянда»: мӯҳр (матн то вақт ба ҳеҷ кас), таҳрир → 409,
    кушодан аз рӯи вақт ва огоҳиномаи кори вақтӣ;
 5. «Чаленҷ»: ҷадвал (як иштирок аз як нафар, бе ҳисоби пӯшида, бе
    худлайк), ғолибон ва нишон дар профил.
 Ҳар бахш: махфият (бегона/басташуда 404), модератсия (матни бад 403),
 ҳадди суръат (429).
 ⚠️ Ба сервери МАҲАЛЛӢ мезанад (GIN_MODE=debug: мактуб ақаллан 20 сония пеш).
 Ёдрасии чорабинӣ (1 рӯз / 2 соат) — дар тести Go бо база (featuredb).
"""
import datetime as dt, json, os, re, sys, time, urllib.parse, urllib.request, urllib.error
B = os.environ.get("BASE", "http://127.0.0.1:8099"); PW = "Test12345!"; res = []
def _once(m, p, body=None, tok=None):
    req = urllib.request.Request(B + p, data=json.dumps(body).encode() if body is not None else None, method=m)
    req.add_header('Content-Type', 'application/json')
    if tok: req.add_header('Authorization', 'Bearer ' + tok)
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            raw = r.read().decode(); return r.status, (json.loads(raw) if raw else {})
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
        try: return e.code, json.loads(raw)
        except Exception: return e.code, raw
    except Exception as e: return 0, str(e)
def call(m, p, body=None, tok=None):
    for a in range(4):
        st, r = _once(m, p, body, tok)
        if st != 429 or (isinstance(r, dict) and "Дархост аз ҳад зиёд" not in str(r.get("message", ""))): return st, r
        time.sleep(4 * (a + 1))
    return st, r
def user(u, ph):
    call("POST", "/auth/register", {"username": u, "email": f"{u}@example.com", "password": PW, "fullName": u, "phone": ph})
    st, r = call("POST", "/auth/login", {"email": u, "password": PW})
    return r.get("accessToken"), (r.get("user") or {}).get("id") or (r.get("user") or {}).get("_id")
def ok(n, c, d=""): res.append((bool(c), n, str(d)[:300]))
def iso(sec): return (dt.datetime.now(dt.timezone.utc) + dt.timedelta(seconds=sec)).strftime("%Y-%m-%dT%H:%M:%SZ")
def notifs(tok):
    st, r = call("GET", "/notifications?limit=100", tok=tok)
    return (r.get("notifications") or []) if isinstance(r, dict) else []
def got(tok, ntype, target=None):
    return [n for n in notifs(tok) if n.get("type") == ntype and (target is None or n.get("targetId") == target)]
def blocked(st, r): return st == 403 and isinstance(r, dict) and r.get("code") == "content_blocked"
BAD = "watch porn now"

S = os.environ.get("SUFFIX", "fa")
s = re.sub(r"[^0-9A-Za-z]", "", S).lower() or "fa"
tA, A = user(f"xfa{S}", "+992900600001")  # мизбон / муаллиф / соҳиб
tB, Bb = user(f"xfb{S}", "+992900600002")  # обуначии A, даъватшуда
tC, C = user(f"xfc{S}", "+992900600003")  # бегона
tD, D = user(f"xfd{S}", "+992900600004")  # A ӯро баст
tE, E = user(f"xfe{S}", "+992900600005")  # матни бад (1)
tF, F = user(f"xff{S}", "+992900600006")  # матни бад (2)
tG, G = user(f"xfg{S}", "+992900600007")  # ҳисоби пӯшида
tH, H = user(f"xfh{S}", "+992900600008")  # иштирокчии дигар
tI, I = user(f"xfi{S}", "+992900600009")  # матни бад (3)
ok("корбарон сохта шуданд", all([tA, tB, tC, tD, tE, tF, tG, tH, tI]), [A, Bb, C, D])
call("POST", f"/follow/{A}", tok=tB)
call("POST", f"/follow/{A}", tok=tH)
call("POST", f"/users/{D}/block", tok=tA)
call("PUT", "/profile/", {"isPrivate": True}, tG)

# ═══════════════════════════ 1. ДАЪВАТНОМА ═══════════════════════════
st, ev = call("POST", "/events", {"title": "Тӯйи Алӣ ва Мадина", "kind": "wedding",
    "description": "Ба тӯйи мо хуш омадед", "coverUrl": "https://example.com/tuy.jpg",
    "startsAt": iso(3 * 86400), "placeName": "Душанбе", "maxPlus": 3}, tA)
EV = ev.get("_id") if isinstance(ev, dict) else None
ok("чорабинӣ сохта шуд (201)", st == 201 and EV, (st, ev))
ok("пешфарз пӯшида, мизбон, коди линк", ev.get("isPublic") is False and ev.get("isHost") and ev.get("shareCode"), ev)
ok("ҳолат upcoming, албом баста", ev.get("status") == "upcoming" and ev.get("albumOpen") is False, ev)
st, r = call("POST", "/events", {"title": "Вохӯрӣ", "startsAt": iso(-3600)}, tA)
ok("вақти гузашта → 400", st == 400, (st, r))
st, r = call("POST", "/events", {"title": "x", "startsAt": iso(3600)}, tA)
ok("номи кӯтоҳ → 400", st == 400, (st, r))
st, r = call("POST", f"/events/{EV}/invite", {"userIds": [Bb, D, "nope"]}, tA)
ok("даъват: B ҳа, басташуда/номаълум не", st == 200 and r.get("invited") == 1 and r.get("skipped") == 2, (st, r))
st, r = call("POST", f"/events/{EV}/invite", {"userIds": [C]}, tB)
ok("меҳмон даъват карда наметавонад → 403", st == 403, (st, r))
st, r = call("GET", f"/events/{EV}", tok=tB)
ok("даъватшуда мебинад, коди линк надорад", st == 200 and r.get("invited") and "shareCode" not in r, (st, r))
st, r = call("GET", f"/events/{EV}", tok=tC)
ok("бегона → 404", st == 404, (st, r))
st, r = call("GET", f"/events/{EV}", tok=tD)
ok("басташуда → 404", st == 404, (st, r))
st, r = call("POST", f"/events/{EV}/rsvp", {"status": "going", "plus": 9}, tB)
ok("Меоям + меҳмон то ҳадди 3", st == 200 and r.get("myRsvp") == "going" and r.get("myPlus") == 3, (st, r))
ok("шумора: 1 меояд, 4 нафар", (r.get("counts") or {}).get("going") == 1 and (r.get("counts") or {}).get("guests") == 4, r.get("counts"))
st, r = call("POST", f"/events/{EV}/rsvp", {"status": "yes"}, tB)
ok("ҷавоби нодуруст → 400", st == 400, (st, r))
st, r = call("POST", f"/events/{EV}/rsvp", {"status": "going"}, tC)
ok("бегона ҷавоб дода наметавонад → 404", st == 404, (st, r))
st, r = call("POST", f"/events/{EV}/rsvp", {"status": "going"}, tA)
ok("мизбон RSVP намекунад → 400", st == 400, (st, r))
st, r = call("GET", f"/events/{EV}/guests", tok=tB)
ok("рӯйхати меҳмонон барои меҳмон → 403", st == 403, (st, r))
st, r = call("GET", f"/events/{EV}/guests", tok=tA)
g = {x["user"]["_id"]: x for x in (r.get("guests") or [])}
ok("мизбон рӯйхатро мебинад (B going, plus 3)", st == 200 and g.get(Bb, {}).get("rsvp") == "going" and g[Bb].get("plus") == 3, r)
time.sleep(1.5)
ok("B огоҳинома: event_invite", got(tB, "event_invite", EV), [n.get("type") for n in notifs(tB)][:8])
ok("A огоҳинома: event_rsvp", got(tA, "event_rsvp", EV), [n.get("type") for n in notifs(tA)][:8])
code = ev.get("shareCode")
st, r = call("GET", f"/events/{EV}?code=WRONG", tok=tC)
ok("коди нодуруст → 404", st == 404, (st, r))
st, r = call("GET", f"/events/{EV}?code={code}", tok=tC)
ok("бо линки мизбон → даъват мешавад", st == 200 and r.get("invited"), (st, r))
st, r = call("GET", f"/events/{EV}?code={code}", tok=tD)
ok("басташуда бо линк ҳам → 404", st == 404, (st, r))
st, r = call("POST", f"/events/{EV}/rsvp", {"status": "maybe", "plus": 1}, tC)
ok("C: Шояд", st == 200 and r.get("myRsvp") == "maybe", (st, r))
st, r = call("POST", f"/events/{EV}/photos", {"url": "https://example.com/a.jpg"}, tB)
ok("албом пеш аз оғоз → 409", st == 409, (st, r))
st, lst = call("GET", "/events?tab=upcoming", tok=tB)
ok("B: дар рӯйхати «Оянда»", EV in [x.get("_id") for x in lst.get("events") or []], lst)
st, lst = call("GET", "/events?tab=upcoming", tok=tD)
ok("D: дар рӯйхат нест", EV not in [x.get("_id") for x in lst.get("events") or []], lst)
st, r = call("POST", "/events", {"title": BAD, "startsAt": iso(86400)}, tE)
ok("модератсия: номи бад → 403", blocked(st, r), (st, r))
st, r = call("PUT", f"/events/{EV}", {"startsAt": iso(4 * 86400), "placeName": "Хуҷанд"}, tA)
ok("таҳрир: вақт ва ҷой", st == 200 and r.get("place", {}).get("name") == "Хуҷанд", (st, r))
st, r = call("PUT", f"/events/{EV}", {"title": "Нав"}, tB)
ok("меҳмон таҳрир намекунад → 403", st == 403, (st, r))
time.sleep(1.5)
ok("B огоҳинома: event_update", got(tB, "event_update", EV), [n.get("type") for n in notifs(tB)][:8])

# Оммавӣ ва аллакай оғозшуда: албом кушода.
st, pe = call("POST", "/events", {"title": "Вохӯрии китобхонҳо", "kind": "meetup",
    "startsAt": iso(-60), "endsAt": iso(4 * 3600), "isPublic": True}, tA)
PE = pe.get("_id") if isinstance(pe, dict) else None
ok("чорабинии оммавии оғозшуда", st == 201 and pe.get("status") == "live" and pe.get("albumOpen"), (st, pe))
st, r = call("GET", f"/events/{PE}", tok=tC)
ok("оммавӣ: бегона мебинад", st == 200, (st, r))
st, r = call("GET", f"/events/{PE}", tok=tD)
ok("оммавӣ: басташуда → 404", st == 404, (st, r))
st, lst = call("GET", "/events?tab=public", tok=tC)
ok("рӯйхати оммавӣ", PE in [x.get("_id") for x in lst.get("events") or []], lst)
st, r = call("POST", f"/events/{PE}/rsvp", {"status": "going"}, tC)
ok("оммавӣ: C Меоям (бедаъват)", st == 200 and r.get("canUpload"), (st, r))
st, ph = call("POST", f"/events/{PE}/photos", {"url": "https://example.com/c.jpg"}, tC)
ok("албом: иштирокчӣ акс гузошт", st == 201 and ph.get("_id"), (st, ph))
st, r = call("POST", f"/events/{PE}/photos", {"url": "https://example.com/h.jpg"}, tH)
ok("албом: ғайриштирокчӣ → 403", st == 403, (st, r))
st, pa = call("POST", f"/events/{PE}/photos", {"url": "https://example.com/a.jpg"}, tA)
ok("албом: мизбон", st == 201, (st, pa))
st, r = call("GET", f"/events/{PE}/photos", tok=tB)
ok("албом: 2 акс", st == 200 and len(r.get("photos") or []) == 2, r)
st, r = call("DELETE", f"/events/{PE}/photos/{pa.get('_id')}", tok=tC)
ok("акси бегонаро нест кардан → 404", st == 404, (st, r))
st, r = call("DELETE", f"/events/{PE}/photos/{ph.get('_id')}", tok=tA)
ok("мизбон акси меҳмонро нест мекунад", st == 200, (st, r))
st, r = call("DELETE", f"/events/{EV}", tok=tB)
ok("меҳмон бекор карда наметавонад → 403", st == 403, (st, r))
st, r = call("DELETE", f"/events/{EV}", tok=tA)
ok("мизбон бекор кард", st == 200 and r.get("cancelled"), (st, r))
st, r = call("POST", f"/events/{EV}/rsvp", {"status": "going"}, tB)
ok("бекоршуда: ҷавоб → 409", st == 409, (st, r))
codes = [call("POST", "/events", {"title": f"Чорабинӣ {i}", "startsAt": iso(86400 * 5)}, tH)[0] for i in range(11)]
ok("ҳадди суръат: 10 дар рӯз, 11-ум → 429", codes[:10] == [201] * 10 and codes[10] == 429, codes)

# ═══════════════════════════ 2. ПУРСИШ ДАР ПОСТ ══════════════════════
media = [{"url": "https://example.com/poll.jpg", "type": "image"}]
st, p = call("POST", "/posts/", {"caption": "Кадом шаҳр?", "media": media, "poll": {
    "question": "Пойтахти Тоҷикистон?", "options": ["Хуҷанд", "Душанбе", "Бохтар"],
    "correctIndex": 1, "endsAt": iso(86400)}}, tA)
PID = p.get("_id") if isinstance(p, dict) else None
ok("пост бо викторина (201, hasPoll)", st == 201 and PID and p.get("hasPoll") is True, (st, p))
st, r = call("POST", "/posts/", {"caption": "x", "media": media, "poll": {"options": ["танҳо"]}}, tA)
ok("1 ҷавоб → 400", st == 400, (st, r))
st, r = call("POST", "/posts/", {"caption": "x", "media": media, "poll": {"options": list("abcde")}}, tA)
ok("5 ҷавоб → 400", st == 400, (st, r))
st, r = call("GET", f"/posts/{PID}/poll", tok=tB)
ok("пеш аз овоз натиҷа пинҳон", st == 200 and r.get("resultsVisible") is False and "votes" not in r["options"][0] and "correctIndex" not in r, r)
ok("canVote", r.get("canVote") is True and r.get("isQuiz") is True, r)
st, r = call("POST", f"/posts/{PID}/poll/vote", {"option": 1}, tB)
ok("B овоз дод: дуруст, 100%", st == 200 and r.get("myVote") == 1 and r.get("myCorrect") is True and r["options"][1].get("percent") == 100, (st, r))
st, r = call("POST", f"/posts/{PID}/poll/vote", {"option": 0}, tB)
ok("овози дуюм → 409", st == 409 and (r.get("poll") or {}).get("myVote") == 1, (st, r))
st, r = call("POST", f"/posts/{PID}/poll/vote", {"option": 0}, tA)
ok("муаллиф овоз намедиҳад → 403", st == 403, (st, r))
st, r = call("POST", f"/posts/{PID}/poll/vote", {"option": 7}, tH)
ok("ҷавоби берун аз ҳад → 400", st == 400, (st, r))
st, r = call("POST", f"/posts/{PID}/poll/vote", {"option": 0}, tH)
pc = [o.get("percent") for o in r.get("options") or []]
ok("H: нодуруст; фоизҳо = 100", st == 200 and r.get("myCorrect") is False and sum(pc) == 100 and r.get("totalVotes") == 2, r)
st, r = call("GET", f"/posts/{PID}/poll", tok=tA)
ok("муаллиф натиҷаро мебинад", r.get("resultsVisible") and r.get("totalVotes") == 2, r)
st, r = call("GET", f"/posts/{PID}/poll/voters", tok=tA)
ok("овоздиҳандагон барои муаллиф (2)", st == 200 and len(r.get("voters") or []) == 2, r)
st, r = call("GET", f"/posts/{PID}/poll/voters?option=1", tok=tA)
ok("филтр аз рӯи ҷавоб (B)", [v["user"]["_id"] for v in r.get("voters") or []] == [Bb], r)
st, r = call("GET", f"/posts/{PID}/poll/voters", tok=tB)
ok("овоздиҳандагон барои дигарон → 403", st == 403, (st, r))
st, r = call("GET", f"/posts/{PID}/poll", tok=tD)
ok("басташуда → 404", st == 404, (st, r))
st, r = call("POST", f"/posts/{PID}/poll/vote", {"option": 1}, tD)
ok("басташуда овоз → 404", st == 404, (st, r))
st, gp = call("POST", "/posts/", {"caption": "пӯшида", "media": media, "poll": {"options": ["ҳа", "не"]}}, tG)
st, r = call("GET", f"/posts/{gp.get('_id')}/poll", tok=tC)
ok("ҳисоби пӯшида: бегона → 404", st == 404, (st, r))
st, r = call("POST", "/posts/", {"caption": "x", "media": media, "poll": {"options": ["хуб", BAD]}}, tF)
ok("модератсия: ҷавоби бад → 403", blocked(st, r), (st, r))
st, r = call("GET", f"/posts/{PID}", tok=tB)
ok("GET /posts/:id → hasPoll", r.get("hasPoll") is True, r.get("hasPoll"))
st, r = call("GET", f"/users/{A}/posts", tok=tB)
items = r.get("posts") if isinstance(r, dict) else r
mine = [x for x in (items or []) if x.get("_id") == PID]
ok("профил: hasPoll дар рӯйхат", mine and mine[0].get("hasPoll") is True, (items or [])[:1])
time.sleep(1.5)
ok("A огоҳинома: post_poll_vote", got(tA, "post_poll_vote", PID), [n.get("type") for n in notifs(tA)][:8])

# ═══════════════════════════ 3. САВОЛ БА МАН ═════════════════════════
st, r = call("GET", "/qa/settings", tok=tA)
ok("пешфарз: обуначиён", r.get("mode") == "followers", r)
st, r = call("POST", f"/users/{A}/questions", {"text": "Чӣ китоб мехонед?"}, tC)
ok("ғайриобуначӣ → 403", st == 403, (st, r))
st, q1 = call("POST", f"/users/{A}/questions", {"text": "Чӣ китоб мехонед?"}, tB)
ok("обуначӣ савол дод", st == 201 and q1.get("_id"), (st, q1))
st, q2 = call("POST", f"/users/{A}/questions", {"text": "Аз чӣ метарсед?", "anonymous": True}, tB)
ok("саволи беном", st == 201 and q2.get("anonymous") is True, (st, q2))
st, r = call("PUT", "/qa/settings", {"mode": "all"}, tA)
ok("танзими нодуруст → 400", st == 400, (st, r))
st, r = call("PUT", "/qa/settings", {"mode": "everyone"}, tA)
ok("танзим: ҳама", st == 200 and r.get("mode") == "everyone", r)
st, q3 = call("POST", f"/users/{A}/questions", {"text": "Шаҳри дӯстдошта?"}, tC)
ok("акнун бегона ҳам савол медиҳад", st == 201, (st, q3))
st, r = call("POST", f"/users/{A}/questions", {"text": "Салом чӣ хел?"}, tD)
ok("басташуда → 404", st == 404, (st, r))
st, r = call("POST", f"/users/{A}/questions", {"text": "ҳа"}, tC)
ok("саволи кӯтоҳ → 400", st == 400, (st, r))
st, r = call("POST", f"/users/{A}/questions", {"text": BAD}, tE)
ok("модератсия: саволи бад → 403", blocked(st, r), (st, r))
st, ib = call("GET", "/qa/inbox", tok=tA)
qs = {x["_id"]: x for x in ib.get("questions") or []}
ok("қуттӣ: 3 савол", len(qs) == 3 and q1["_id"] in qs, ib)
ok("беном: ном ба соҳиб нишон дода намешавад", "asker" not in qs.get(q2["_id"], {"asker": 1}), qs.get(q2["_id"]))
ok("бономӣ: савoлдиҳанда маълум", (qs.get(q1["_id"], {}).get("asker") or {}).get("_id") == Bb, qs.get(q1["_id"]))
time.sleep(1.5)
qn = got(tA, "qa_question")
ok("огоҳинома: qa_question бе муаллиф", qn and all("fromUser" not in n for n in qn), qn[:2])
st, r = call("POST", f"/questions/{q2['_id']}/answer", {"text": "Аз тарсидан 🙂"}, tB)
ok("бегона ҷавоб намедиҳад → 404", st == 404, (st, r))
st, r = call("POST", f"/questions/{q2['_id']}/answer", {"text": "Аз тарсидан 🙂"}, tA)
ok("соҳиб ҷавоб дод", st == 200 and r.get("status") == "answered", (st, r))
call("POST", f"/questions/{q1['_id']}/answer", {"text": "Шоҳнома"}, tA)
st, r = call("GET", f"/users/{A}/questions", tok=tC)
aq = {x["_id"]: x for x in r.get("questions") or []}
ok("таби «Ҷавобҳо»: 2 ҷавоб", st == 200 and len(aq) == 2, r)
ok("ҷавоби беном бе ном барои тамошобин", "asker" not in aq.get(q2["_id"], {"asker": 1}) and aq[q2["_id"]].get("answer"), aq.get(q2["_id"]))
ok("ҷавоби бономӣ бо ном", (aq.get(q1["_id"], {}).get("asker") or {}).get("_id") == Bb, aq.get(q1["_id"]))
st, r = call("GET", f"/users/{A}/questions", tok=tD)
ok("басташуда: рӯйхат холӣ", r.get("questions") == [], r)
time.sleep(1.5)
ok("B огоҳинома: qa_answer", got(tB, "qa_answer"), [n.get("type") for n in notifs(tB)][:8])
codes = [call("POST", f"/users/{A}/questions", {"text": f"Саволи рақами {i}"}, tH)[0] for i in range(6)]
ok("ҳадди суръат: 5 дар соат ба як нафар, 6-ум → 429", codes[:5] == [201] * 5 and codes[5] == 429, codes)
st, r = call("POST", f"/questions/{q3['_id']}/block-asker", tok=tA)
ok("бастани пинҳонии савoлдиҳанда", st == 200, (st, r))
st, r = call("GET", "/users/blocked", tok=tA)
ok("дар «Басташудагон» пайдо намешавад (номи беном фош намешавад)", C not in json.dumps(r), r)
st, r = call("POST", f"/users/{A}/questions", {"text": "Боз як савол?"}, tC)
st2, ib = call("GET", "/qa/inbox", tok=tA)
ok("баъди бастан: савол ба қуттӣ намерасад", st == 201 and all((x.get("asker") or {}).get("_id") != C for x in ib.get("questions") or []), ib)
st, r = call("DELETE", f"/questions/{q1['_id']}", tok=tC)
ok("бегона нест намекунад → 404", st == 404, (st, r))
st, r = call("DELETE", f"/questions/{q1['_id']}", tok=tA)
ok("соҳиб нест кард", st == 200, (st, r))
call("PUT", "/qa/settings", {"mode": "off"}, tA)
st, r = call("POST", f"/users/{A}/questions", {"text": "Ҳоло ҳам?"}, tB)
ok("хомӯш → 403", st == 403, (st, r))
st, r = call("POST", f"/users/{G}/questions", {"text": "Салом ба пӯшида"}, tC)
ok("ҳисоби пӯшида → 404", st == 404, (st, r))
st, r = call("GET", f"/admin/questions/{q2['_id']}", tok=tB)
ok("admin-роҳ барои корбари оддӣ → 403", st == 403, (st, r))

# ═══════════════════════════ 4. МАКТУБ БА ОЯНДА ══════════════════════
st, c1 = call("POST", "/capsules", {"audience": "self", "text": "Салом ба ояндаи ман", "note": "Барои 2027", "unlockAt": iso(25)}, tA)
CS = c1.get("_id") if isinstance(c1, dict) else None
ok("мактуб ба худ мӯҳр шуд", st == 201 and c1.get("sealed") and "text" not in c1, (st, c1))
st, c2 = call("POST", "/capsules", {"audience": "friend", "recipientId": Bb, "text": "Дӯсти азиз, ин аз гузашта", "unlockAt": iso(25)}, tA)
CF = c2.get("_id") if isinstance(c2, dict) else None
ok("мактуб ба дӯст", st == 201 and (c2.get("recipient") or {}).get("_id") == Bb, (st, c2))
st, c3 = call("POST", "/capsules", {"audience": "followers", "text": "Ба обуначиён", "unlockAt": iso(25)}, tA)
CO = c3.get("_id") if isinstance(c3, dict) else None
ok("мактуб ба обуначиён", st == 201, (st, c3))
st, r = call("POST", "/capsules", {"audience": "friend", "recipientId": C, "text": "x", "unlockAt": iso(3600)}, tA)
ok("ба бегонаи бепайванд → 404", st == 404, (st, r))
st, r = call("POST", "/capsules", {"audience": "self", "text": "x", "unlockAt": iso(5)}, tA)
ok("санаи хеле наздик → 400", st == 400, (st, r))
st, r = call("POST", "/capsules", {"audience": "world", "text": "x", "unlockAt": iso(3600)}, tA)
ok("audience нодуруст → 400", st == 400, (st, r))
st, r = call("POST", "/capsules", {"audience": "self", "text": " ", "unlockAt": iso(3600)}, tA)
ok("холӣ → 400", st == 400, (st, r))
st, r = call("POST", "/capsules", {"audience": "self", "text": BAD, "unlockAt": iso(3600)}, tF)
ok("модератсия: матни бад → 403", blocked(st, r), (st, r))
st, r = call("GET", f"/capsules/{CF}", tok=tB)
ok("гиранда: лифофа бе матн", st == 200 and r.get("sealed") and "text" not in r and r.get("secondsLeft", 0) > 0, (st, r))
st, r = call("GET", f"/capsules/{CS}", tok=tA)
ok("муаллиф ҳам то вақт матнро намебинад", st == 200 and "text" not in r, r)
st, r = call("GET", f"/capsules/{CF}", tok=tC)
ok("бегона → 404", st == 404, (st, r))
st, r = call("GET", f"/capsules/{CS}", tok=tB)
ok("мактуби «ба худ» барои дигарон → 404", st == 404, (st, r))
st, r = call("GET", f"/capsules/{CO}", tok=tD)
ok("басташуда → 404", st == 404, (st, r))
st, r = call("PUT", f"/capsules/{CS}", {"text": "иваз"}, tA)
ok("таҳрир → 409 (мӯҳр)", st == 409 and r.get("code") == "capsule_sealed", (st, r))
st, r = call("GET", "/capsules?box=inbox", tok=tB)
ids = [x["_id"] for x in r.get("capsules") or []]
ok("қуттии B: ба дӯст + ба обуначиён", CF in ids and CO in ids and CS not in ids, ids)
st, r = call("GET", f"/users/{A}/capsules", tok=tB)
ok("профил: лифофаи «ба обуначиён» барои обуначӣ", CO in [x["_id"] for x in r.get("capsules") or []], r)
st, r = call("GET", f"/users/{A}/capsules", tok=tC)
ok("профил: барои ғайриобуначӣ холӣ", r.get("capsules") == [], r)
time.sleep(1.5)
ok("B огоҳинома: capsule_sealed", got(tB, "capsule_sealed", CF), [n.get("type") for n in notifs(tB)][:8])
codes = [call("POST", "/capsules", {"audience": "self", "text": f"№{i}", "unlockAt": iso(86400)}, tH)[0] for i in range(11)]
ok("ҳадди суръат: 10 дар рӯз, 11-ум → 429", codes[:10] == [201] * 10 and codes[10] == 429, codes)

# ═══════════════════════════ 5. ЧАЛЕНҶ ═══════════════════════════════
T = f"рақс{s}"
st, ch = call("POST", "/challenges", {"tag": "#" + T.upper(), "title": "Рақси миллӣ", "rules": "Видеои рақсро бо хештег гузоред",
    "startsAt": iso(-5), "endsAt": iso(7 * 86400)}, tA)
CH = ch.get("_id") if isinstance(ch, dict) else None
ok("чаленҷ сохта шуд (хештег муқаррарӣ)", st == 201 and ch.get("tag") == T and ch.get("status") == "active", (st, ch))
st, r = call("POST", "/challenges", {"tag": T, "title": "Такрор", "endsAt": iso(86400)}, tB)
ok("хештеги такрорӣ → 409", st == 409, (st, r))
st, r = call("POST", "/challenges", {"tag": f"x{s}", "title": "Дароз", "endsAt": iso(90 * 86400)}, tB)
ok("давомнокии зиёд → 400", st == 400, (st, r))
st, r = call("POST", "/challenges", {"tag": f"bad{s}", "title": BAD, "endsAt": iso(86400)}, tI)
ok("модератсия: номи бад → 403", blocked(st, r), (st, r))
def post(tok, cap):
    st, p = call("POST", "/posts/", {"caption": cap, "media": media}, tok); return p.get("_id") if isinstance(p, dict) else None
pB = post(tB, f"Рақси ман #{T}")
pB2 = post(tB, f"Дуюм #{T}")
pG = post(tG, f"пӯшида #{T}")
pD = post(tD, f"басташуда #{T}")
st, rr = call("POST", "/reels/", {"videoUrl": "https://example.com/r.mp4", "caption": f"Reel #{T}"}, tH)
rH = rr.get("_id") if isinstance(rr, dict) else None
ok("иштирокҳо сохта шуданд", all([pB, pB2, pG, pD, rH]), [pB, pB2, pG, pD, rH])
call("POST", f"/posts/{pB}/like", tok=tC)
call("POST", f"/posts/{pB}/like", tok=tH)
call("POST", f"/posts/{pB}/like", tok=tB)  # худлайк — ҳисоб намешавад
call("POST", f"/reels/{rH}/like", tok=tB)
call("POST", f"/reels/{rH}/comments", {"text": "Офарин!"}, tA)
call("POST", f"/reels/{rH}/comments", {"text": "Боз ҳам офарин"}, tA)  # ҳамон шарҳнавис
st, r = call("GET", f"/challenges/{CH}", tok=tC)
lb = [(x["user"]["_id"], x["score"]) for x in r.get("leaderboard") or []]
ok("ҷадвал: H (1+2=3) боло, B (2) — як иштирок аз як нафар", lb[:2] == [(H, 3), (Bb, 2)], lb)
ok("ҳисоби пӯшида дар ҷадвал нест", G not in [u for u, _ in lb], lb)
ok("иштирокчиён барои C: 3 (B, H, D)", r.get("participantsCount") == 3, r.get("participantsCount"))
st, r = call("GET", f"/challenges/{CH}", tok=tA)
ok("барои A басташуда (D) нест: 2", r.get("participantsCount") == 2 and D not in [x["user"]["_id"] for x in r.get("leaderboard") or []], r.get("leaderboard"))
st, r = call("GET", f"/challenges/{CH}", tok=tB)
ok("иштироки ман: B ҷои 2", r.get("joined") is True and (r.get("myEntry") or {}).get("rank") == 2, r.get("myEntry"))
st, r = call("GET", "/challenges?status=active", tok=tC)
ok("Explore: «Чаленҷҳо» (фаъол)", CH in [x["_id"] for x in r.get("challenges") or []], r)
st, r = call("GET", "/challenges?status=active", tok=tD)
ok("басташуда аз созанда: дар рӯйхат нест", CH not in [x["_id"] for x in r.get("challenges") or []], r)
st, r = call("GET", f"/challenges/{CH}", tok=tD)
ok("басташуда → 404", st == 404, (st, r))
st, r = call("GET", f"/challenges/{CH}/leaderboard?limit=1", tok=tC)
ok("leaderboard?limit=1", len(r.get("leaderboard") or []) == 1, r)
# Чаленҷи кӯтоҳ барои ғолиб ва нишон.
T2 = f"ғолиб{s}"
st, ch2 = call("POST", "/challenges", {"tag": T2, "title": "Чаленҷи кӯтоҳ", "startsAt": iso(-1800), "endsAt": iso(20)}, tA)
CH2 = ch2.get("_id") if isinstance(ch2, dict) else None
ok("чаленҷи кӯтоҳ", st == 201, (st, ch2))
pW = post(tB, f"Ман ғолиб #{T2}")
call("POST", f"/posts/{pW}/like", tok=tC)
st, r = call("POST", "/challenges", {"tag": f"сеюм{s}", "title": "Сеюм", "endsAt": iso(86400)}, tA)
ok("3-юм чаленҷ дар рӯз", st == 201, (st, r))
st, r = call("POST", "/challenges", {"tag": f"чорум{s}", "title": "Чорум", "endsAt": iso(86400)}, tA)
ok("ҳадди суръат: 4-ум → 429", st == 429, (st, r))

# ── Интизорӣ: мактубҳо кушода мешаванд, чаленҷ тамом мешавад ─────────
time.sleep(26)
st, r = call("GET", f"/capsules/{CF}", tok=tB)
ok("вақт расид: гиранда матнро мехонад", st == 200 and r.get("opened") and r.get("text") == "Дӯсти азиз, ин аз гузашта", r)
st, r = call("GET", f"/capsules/{CS}", tok=tA)
ok("мактуб ба худ кушода шуд", r.get("text") == "Салом ба ояндаи ман", r)
st, r = call("GET", f"/capsules/{CO}", tok=tB)
ok("обуначӣ мактуби «ба обуначиён»-ро мехонад", r.get("text") == "Ба обуначиён", r)
st, r = call("GET", f"/capsules/{CO}", tok=tC)
ok("ғайриобуначӣ ҳатто баъди кушодан → 404", st == 404, (st, r))
unl = win = badges = None
for _ in range(25):  # кори вақтӣ ҳар дақиқа
    unl = got(tB, "capsule_unlocked", CF)
    win = got(tB, "challenge_win", CH2)
    if unl and win: break
    time.sleep(4)
ok("кори вақтӣ: огоҳиномаи capsule_unlocked", unl, [n.get("type") for n in notifs(tB)][:10])
ok("кори вақтӣ: огоҳиномаи challenge_win", win, [n.get("type") for n in notifs(tB)][:10])
st, r = call("GET", f"/users/{Bb}/challenge-badges", tok=tC)
bd = [x for x in r.get("badges") or [] if x.get("challengeId") == CH2]
ok("нишони ғолиб дар профил (ҷои 1)", bd and bd[0].get("rank") == 1 and bd[0].get("tag") == T2, r)
st, r = call("GET", f"/challenges/{CH2}", tok=tC)
ok("ғолибон дар чаленҷ", r.get("status") == "ended" and [w["user"]["_id"] for w in r.get("winners") or []] == [Bb], r.get("winners"))
st, r = call("DELETE", f"/capsules/{CF}", tok=tB)
ok("гиранда нест намекунад → 404", st == 404, (st, r))
st, r = call("DELETE", f"/capsules/{CF}", tok=tA)
ok("муаллиф нест кард", st == 200, (st, r))

bad = [x for x in res if not x[0]]
print()
for g_, n, d in res: print(("  ✅ " if g_ else "  ❌ ") + n + ("" if g_ else f"\n       → {d}"))
print(f"\n{len(res) - len(bad)}/{len(res)} гузашт")
sys.exit(1 if bad else 0)
