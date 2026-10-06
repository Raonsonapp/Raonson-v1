#!/usr/bin/env python3
"""Огоҳиномаҳо (мисли Instagram/TikTok), «мухотибон ҳамроҳ шуданд»,
«Обуначиён аз ин пост» ва «Раҳмат».

 Ҳар ҳодиса → ДАҚИҚАН ЯК огоҳинома ба гирандаи дуруст, бо навъ ва
 объекти дуруст; ба худ ва ба басташуда — ҳеҷ.

 ⚠️ Ба сервери МАҲАЛЛӢ мезанад (BASE). SUFFIX — пасванди ягона.
"""
import hashlib, json, os, sys, time, urllib.request, urllib.error

B = os.environ.get("BASE", "http://127.0.0.1:8099"); PW = "Test12345!"; res = []
S = os.environ.get("SUFFIX", "ntf")


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


def phone(role):
    """Рақами ягона барои ҳар нақш ва ҳар SUFFIX (+99293…)."""
    d = int(hashlib.sha256((S + ":" + role).encode()).hexdigest(), 16) % 10**7
    return "+99293" + str(d).zfill(7)


def user(u, ph=""):
    body = {"username": u, "email": f"{u}@example.com", "password": PW, "fullName": u}
    if ph: body["phone"] = ph
    call("POST", "/auth/register", body)
    st, r = call("POST", "/auth/login", {"email": u, "password": PW})
    usr = r.get("user") or {} if isinstance(r, dict) else {}
    return r.get("accessToken") if isinstance(r, dict) else None, usr.get("id") or usr.get("_id")


def ok(n, c, d=""): res.append((bool(c), n, str(d)[:220]))


def notifs(tok):
    st, r = call("GET", "/notifications?limit=100", tok=tok)
    return r.get("notifications") or [] if isinstance(r, dict) else []


def got(tok, ntype, frm=None, target=None):
    out = []
    for n in notifs(tok):
        if n.get("type") != ntype: continue
        if frm is not None and (n.get("fromUser") or {}).get("_id") != frm: continue
        if target is not None and n.get("targetId") != target: continue
        out.append(n)
    return out


def wait(): time.sleep(1.3)


nm = lambda r: f"nt{r}{S}".lower()
tA, A = user(nm("a"), phone("a"))   # муаллиф
tB, Bb = user(nm("b"), phone("b"))  # амалкунанда
tC, C = user(nm("c"), phone("c"))   # A-ро бастааст
tD, D = user(nm("d"), phone("d"))   # сеюм (ҷавоб, зикр)
tP, P = user(nm("p"), phone("p"))   # ҳисоби пӯшида
if not all([tA, tB, tC, tD, tP]): print("!! вуруд нашуд"); sys.exit(1)

st, _ = call("POST", f"/users/{A}/block", tok=tC); ok("C A-ро баст", st in (200, 201), st)

# ══ 1. Обуна ══════════════════════════════════════════════════════
st, r = call("POST", f"/follow/{A}", tok=tB); ok("B ба A обуна шуд", st == 200 and r.get("following"), (st, r))
wait()
f = got(tA, "follow", Bb)
ok("A ДАҚИҚАН як «follow» аз B гирифт", len(f) == 1, notifs(tA))
ok("объекти follow — профили B", f and f[0].get("targetId") == Bb, f)
ok("огоҳинома бо isFollowing (тугмаи «Пайравии мутақобил»)", f and (f[0].get("fromUser") or {}).get("isFollowing") is False, f)
ok("B ба худ огоҳинома нагирифт", not got(tB, "follow"), got(tB, "follow"))
st, c = call("GET", "/notifications/unread-count", tok=tA); ok("бейҷи A ≥ 1", (c or {}).get("count", 0) >= 1, c)
call("POST", "/notifications/read-all", tok=tA)
call("DELETE", f"/follow/{A}", tok=tB); call("POST", f"/follow/{A}", tok=tB); wait()
f = got(tA, "follow", Bb)
ok("обунаи дубора: боз як сатр (на ду)", len(f) == 1, f)
ok("обунаи дубора: огоҳинома боз нахондашуда", f and f[0].get("read") is False, f)
st, r = call("POST", f"/follow/{A}", tok=tC); ok("басташуда обуна шуда наметавонад", st in (403, 404), (st, r))
st, r = call("POST", f"/follow/{A}", tok=tA); ok("ба худ обуна — 400", st == 400, st)

# ══ 2. Дархост ва қабул (ҳисоби пӯшида) ═════════════════════════════
call("PUT", "/profile/", {"isPrivate": True}, tP)
st, r = call("POST", f"/follow/{P}", tok=tB); ok("ба ҳисоби пӯшида — дархост", r.get("requested") is True, (st, r))
wait()
ok("P як «follow_request» аз B гирифт", len(got(tP, "follow_request", Bb, Bb)) == 1, notifs(tP))
ok("ҳанӯз «follow» нест", not got(tP, "follow", Bb), got(tP, "follow"))
st, _ = call("POST", f"/follow/request/{Bb}/accept", tok=tP); ok("P қабул кард", st == 200, st)
wait()
ok("B «follow_accepted» аз P гирифт", len(got(tB, "follow_accepted", P, P)) == 1, notifs(tB))
ok("дар рӯйхати P дархост ба «follow» табдил ёфт", len(got(tP, "follow", Bb)) == 1 and not got(tP, "follow_request", Bb), notifs(tP))
st, r = call("POST", f"/follow/{P}", tok=tD); wait()
st, _ = call("POST", f"/follow/request/{D}/reject", tok=tP)
ok("дархости радшуда аз рӯйхат рафт", not got(tP, "follow_request", D), got(tP, "follow_request"))

# ══ 3. Пост: лайк, шарҳ, ҷавоб, зикр, лайки шарҳ ═══════════════════
IMG = [{"url": "https://example.com/n.jpg", "type": "image"}]
st, p = call("POST", "/posts/", {"caption": "пости санҷиш", "media": IMG}, tA); pid = p.get("_id")
ok("A пост сохт", pid, (st, p))
call("POST", f"/posts/{pid}/like", tok=tB); wait()
ok("лайк: як «like» бо объекти пост", len(got(tA, "like", Bb, pid)) == 1, notifs(tA)[:3])
call("POST", f"/posts/{pid}/like", tok=tB); call("POST", f"/posts/{pid}/like", tok=tB); wait()
ok("лайк/бекор/лайк — боз як сатр", len(got(tA, "like", Bb, pid)) == 1, got(tA, "like"))
call("POST", f"/posts/{pid}/like", tok=tA); wait()
ok("лайки пости худ — огоҳинома нест", not got(tA, "like", A), got(tA, "like"))
st, cm = call("POST", f"/posts/{pid}/comments", {"text": "зебо!"}, tB); bcid = cm.get("_id")
ok("B шарҳ навишт", st == 201 and bcid, (st, cm))
wait()
ok("шарҳ: як «comment» бо объекти пост", len(got(tA, "comment", Bb, pid)) == 1, notifs(tA)[:3])
st, dc = call("POST", f"/posts/{pid}/comments", {"text": "ман ҳам"}, tD); dcid = dc.get("_id")
st, rp = call("POST", f"/posts/{pid}/comments", {"text": "раҳмат", "parentId": dcid}, tB); wait()
ok("ҷавоб: D як «reply» гирифт", len(got(tD, "reply", Bb, pid)) == 1, notifs(tD)[:3])
st, _ = call("POST", f"/comments/{bcid}/like", tok=tA); wait()
ok("лайки шарҳ: B як «comment_like» гирифт (объект — пост)", len(got(tB, "comment_like", A, pid)) == 1, notifs(tB)[:3])
st, _ = call("POST", f"/comments/{bcid}/like", tok=tB); wait()
ok("лайки шарҳи худ — огоҳинома нест", not got(tB, "comment_like", Bb), got(tB, "comment_like"))
st, bp = call("POST", "/posts/", {"caption": f"бо @{nm('d')} ва @{nm('c')}", "media": IMG}, tB); bpid = bp.get("_id")
wait()
ok("зикр: D як «mention» бо объекти пост гирифт", len(got(tD, "mention", Bb, bpid)) == 1, notifs(tD)[:3])

# ══ 4. Reels ════════════════════════════════════════════════════
st, rl = call("POST", "/reels/", {"videoUrl": "https://example.com/n.mp4", "caption": "рилс"}, tA); rid = rl.get("_id")
ok("A рилс сохт", rid, (st, rl))
call("POST", f"/reels/{rid}/like", tok=tB); wait()
ok("лайки рилс: як «reel_like»", len(got(tA, "reel_like", Bb, rid)) == 1, notifs(tA)[:3])
st, rc = call("POST", f"/reels/{rid}/comments", {"text": "олӣ"}, tB); rcid = rc.get("_id"); wait()
ok("шарҳи рилс: як «reel_comment»", len(got(tA, "reel_comment", Bb, rid)) == 1, notifs(tA)[:3])
st, _ = call("POST", f"/reels/{rid}/comments/{rcid}/reply", {"text": "рост"}, tD); wait()
ok("ҷавоб ба шарҳи рилс: B як «reel_reply»", len(got(tB, "reel_reply", D, rid)) == 1, notifs(tB)[:3])
st, _ = call("POST", f"/reels/{rid}/comments/{rcid}/like", tok=tA); wait()
ok("лайки шарҳи рилс: B як «reel_comment_like»", len(got(tB, "reel_comment_like", A, rid)) == 1, notifs(tB)[:3])

# ══ 5. Сторис ════════════════════════════════════════════════════
st, sto = call("POST", "/stories/", {"mediaUrl": "https://example.com/s.jpg", "mediaType": "image"}, tA)
sid = (sto or {}).get("_id") or (sto or {}).get("id"); ok("A сторис гузошт", sid, (st, sto))
call("POST", f"/stories/{sid}/like", tok=tB); wait()
ok("лайки сторис: як «story_like»", len(got(tA, "story_like", Bb, sid)) == 1, notifs(tA)[:3])
call("POST", f"/stories/{sid}/reply", {"text": "зӯр"}, tB); wait()
ok("ҷавоби сторис: як «story_reply»", len(got(tA, "story_reply", Bb, sid)) == 1, notifs(tA)[:3])

# ══ 6. Ҳамкорӣ ══════════════════════════════════════════════════
st, cp = call("POST", "/posts/", {"caption": "ҳамкорӣ", "media": IMG, "collaborators": [nm("b")]}, tA); cpid = cp.get("_id")
wait()
ok("даъвати ҳамкорӣ: B як «collab_invite»", len(got(tB, "collab_invite", A, cpid)) == 1, notifs(tB)[:3])
call("POST", f"/posts/{cpid}/collab/accept", tok=tB); wait()
ok("қабули ҳамкорӣ: A як «collab_accepted»", len(got(tA, "collab_accepted", Bb, cpid)) == 1, notifs(tA)[:3])

# ══ 7. Паём — ба Direct, на ба «Огоҳиномаҳо» (мисли Instagram) ═══════
st, ch = call("GET", f"/chat/with/{A}", tok=tB); cid = ch.get("chatId") or ch.get("id") or ch.get("_id")
st, m = call("POST", f"/chat/{cid}/messages", {"text": "салом"}, tB)
ok("B ба A паём фиристод", st in (200, 201), (st, m))
wait()
ok("паём дар рӯйхати огоҳиномаҳо такрор намешавад", not got(tA, "message"), got(tA, "message"))

# ══ 8. Басташуда ва ба худ ════════════════════════════════════════
call("POST", f"/posts/{pid}/like", tok=tC); call("POST", f"/posts/{pid}/comments", {"text": "x"}, tC); wait()
ok("аз басташуда ягон огоҳинома нест", not [n for n in notifs(tA) if (n.get("fromUser") or {}).get("_id") == C], notifs(tA)[:3])
call("POST", f"/posts/{pid}/comments", {"text": f"@{nm('c')} инро бин"}, tA); wait()
ok("зикр аз басташуда намеояд", not got(tC, "mention", A), got(tC, "mention"))
ok("ба худ ҳеҷ огоҳинома нест", not [n for n in notifs(tA) if (n.get("fromUser") or {}).get("_id") == A])
before = [n for n in notifs(tA) if (n.get("fromUser") or {}).get("_id") == D]
call("POST", f"/posts/{pid}/like", tok=tD); wait()
ok("D лайк кард — A огоҳинома дорад", got(tA, "like", D, pid))
call("POST", f"/users/{D}/block", tok=tA); wait()
ok("баъди бастан огоҳиномаҳои кӯҳнаи D аз рӯйхат рафтанд", not [n for n in notifs(tA) if (n.get("fromUser") or {}).get("_id") == D], before)
call("POST", f"/users/{D}/unblock", tok=tA); call("DELETE", f"/users/{D}/block", tok=tA)

# ══ 9. «Обуначиён аз ин пост» ═════════════════════════════════════
tE, E = user(nm("e")); tF, F = user(nm("f")); tG, G = user(nm("g")); tH, H = user(nm("h"))
def pstats(tok, i): return call("GET", f"/posts/{i}/stats", tok=tok)
def rstats(tok, i): return call("GET", f"/reels/{i}/stats", tok=tok)
st, s0 = pstats(tA, pid); ok("омори пост «follows» дорад (0)", st == 200 and s0.get("follows") == 0, s0)
call("POST", f"/follow/{A}", {"sourceKind": "post", "sourceId": pid}, tE)
call("POST", f"/follow/{A}", {"sourceKind": "reel", "sourceId": rid}, tF)
call("POST", f"/follow/{A}", {"sourceKind": "post", "sourceId": bpid}, tG)  # пости бегона — ҳисоб намешавад
st, s1 = pstats(tA, pid); ok("E аз пост обуна шуд → follows=1", s1.get("follows") == 1, s1)
st, r1 = rstats(tA, rid); ok("F аз рилс обуна шуд → рилс follows=1", r1.get("follows") == 1, r1)
st, sb = pstats(tB, bpid); ok("манбаи бегона ба пости B ҳисоб нашуд", sb.get("follows") == 0, sb)
st, x = pstats(tB, pid); ok("омори пости бегона — 403", st == 403, st)
st, x = rstats(tB, rid); ok("омори рилси бегона — 403", st == 403, st)
call("DELETE", f"/follow/{A}", tok=tE)
st, s2 = pstats(tA, pid); ok("E обунаро бекор кард → follows=0", s2.get("follows") == 0, s2)
call("POST", f"/follow/{A}", tok=tE)
st, s3 = pstats(tA, pid); ok("обунаи дубора бе манбаъ → боз 0", s3.get("follows") == 0, s3)
st, pp = call("POST", "/posts/", {"caption": "пӯшида", "media": IMG}, tP); ppid = pp.get("_id")
call("POST", f"/follow/{P}", {"sourceKind": "post", "sourceId": ppid}, tH)
st, q0 = pstats(tP, ppid); ok("то қабули дархост ҳисоб нест", q0.get("follows") == 0, q0)
call("POST", f"/follow/request/{H}/accept", tok=tP)
st, q1 = pstats(tP, ppid); ok("баъди қабул → follows=1", q1.get("follows") == 1, q1)

# ══ 10. Мухотибон ҳамроҳ шуданд ═══════════════════════════════════
PX, PY = phone("x"), phone("y")
tO1, O1 = user(nm("o1")); tO2, O2 = user(nm("o2")); tO3, O3 = user(nm("o3")); tO4, O4 = user(nm("o4"))
st, cs = call("GET", "/contacts/settings", tok=tO1)
ok("бе розигӣ: consent=false", st == 200 and cs.get("consent") is False and cs.get("stored") == 0, cs)
st, r = call("PUT", "/contacts/settings", {"notifyJoined": True}, tO1)
ok("бе розигӣ фаъол кардан мумкин нест (409)", st == 409, (st, r))
book = [PX, PY, "0" + PX[-9:], "+992 00 000 0001", phone("a")]
st, r = call("POST", "/users/find-by-contacts", {"phones": book, "consent": True}, tO1)
ok("O1 мухотибонро бо розигӣ фиристод", st == 200, (st, r))
ok("ҷавоб рақами касеро ошкор намекунад", "phone" not in json.dumps(r) and PX[-9:] not in json.dumps(r), r)
ok("A (дар мухотибон) ёфт шуд", A in [u.get("_id") for u in r.get("users", [])], r)
st, cs = call("GET", "/contacts/settings", tok=tO1)
ok("розигӣ → хабар худ аз худ фаъол", cs.get("consent") is True and cs.get("notifyJoined") is True, cs)
ok("рақамҳо такрор нашуданд (4 хеш)", cs.get("stored") == 4, cs)
call("POST", "/users/find-by-contacts", {"phones": [PX], "consent": True}, tO2)
st, r = call("PUT", "/contacts/settings", {"notifyJoined": False}, tO2); ok("O2 хабарро хомӯш кард", st == 200, (st, r))
call("POST", "/users/find-by-contacts", {"phones": [PX]}, tO3)  # бе розигӣ
st, cs = call("GET", "/contacts/settings", tok=tO3); ok("бе розигӣ ҳеҷ хеш нигоҳ дошта нашуд", cs.get("stored") == 0, cs)
tX, X = user(nm("x"), PX); wait()
cj = got(tO1, "contact_joined", X, X)
ok("O1 ДАҚИҚАН як «contact_joined» аз X гирифт", len(cj) == 1, notifs(tO1))
ok("O2 (хомӯш) хабар нагирифт", not got(tO2, "contact_joined"), got(tO2, "contact_joined"))
ok("O3 (бе розигӣ) хабар нагирифт", not got(tO3, "contact_joined"), got(tO3, "contact_joined"))
call("PUT", "/profile/phone", {"phone": phone("x2")}, tX); call("PUT", "/profile/phone", {"phone": PX}, tX); wait()
ok("ивази рақам эълони дуюм намедиҳад", len(got(tO1, "contact_joined", X)) == 1, got(tO1, "contact_joined"))
call("POST", "/users/find-by-contacts", {"phones": [PY], "consent": True}, tO4)
tY, Y = user(nm("y"))  # бе рақам
call("POST", f"/users/{Y}/block", tok=tO4)
st, r = call("PUT", "/profile/phone", {"phone": PY}, tY); ok("Y рақам илова кард", st == 200, (st, r))
wait()
ok("O1 «contact_joined» аз Y гирифт", len(got(tO1, "contact_joined", Y, Y)) == 1, notifs(tO1)[:3])
ok("O4 (Y-ро бастааст) хабар нагирифт", not got(tO4, "contact_joined"), got(tO4, "contact_joined"))
st, r = call("DELETE", "/contacts", tok=tO1)
st, cs = call("GET", "/contacts/settings", tok=tO1)
ok("розигӣ бозпас гирифта шуд — ҳама хешҳо нест", cs.get("stored") == 0 and cs.get("consent") is False, cs)
tR, R = user(nm("r"))
codes = [call("POST", "/users/find-by-contacts", {"phones": [phone("z")], "consent": True}, tR)[0] for _ in range(6)]
ok("маҳдудият: аз 5 дар соат зиёд — 429", codes[-1] == 429 and codes[0] == 200, codes)

# ══ 11. «Раҳмат» ══════════════════════════════════════════════════
st, r = call("POST", f"/users/{A}/thanks", {"text": "Раҳмат барои маслиҳат!"}, tB)
ok("B ба A «Раҳмат» гуфт", st == 201 and r.get("new") is True, (st, r))
wait()
ok("A як «thanks» аз B гирифт", len(got(tA, "thanks", Bb, A)) == 1, notifs(tA)[:3])
st, t = call("GET", f"/users/{A}/thanks", tok=tD)
ok("дар профили A: 1 раҳмат бо номи B", t.get("count") == 1 and (t.get("thanks") or [{}])[0].get("fromUser", {}).get("_id") == Bb, t)
st, r = call("POST", f"/users/{A}/thanks", {"text": "Боз раҳмат"}, tB); wait()
st, t = call("GET", f"/users/{A}/thanks", tok=tB)
ok("такрор — матн нав, рӯйхат дароз нашуд", t.get("count") == 1 and t.get("mine", {}).get("text") == "Боз раҳмат", t)
ok("огоҳинома ҳам як", len(got(tA, "thanks", Bb)) == 1, got(tA, "thanks"))
st, _ = call("POST", f"/users/{A}/thanks", {"text": "худам"}, tA); ok("ба худ — 400", st == 400, st)
st, _ = call("POST", f"/users/{A}/thanks", {"text": "салом"}, tC); ok("басташуда — 403", st == 403, st)
st, _ = call("POST", f"/users/{A}/thanks", {"text": "x" * 141}, tD); ok("аз 140 зиёд — 400", st == 400, st)
st, _ = call("POST", f"/users/{P}/thanks", {"text": "салом"}, tD); ok("ҳисоби пӯшидаи бегона — 403", st == 403, st)
st, r = call("POST", f"/users/{A}/thanks", {"text": "Раҳмат, устод"}, tD); did = r.get("_id")
st, t = call("GET", f"/users/{A}/thanks", tok=tA); ok("ду раҳмат", t.get("count") == 2, t)
st, _ = call("DELETE", f"/thanks/{did}", tok=tD)
st, t = call("GET", f"/users/{A}/thanks", tok=tA); ok("фиристанда бозпас гирифт → 1", t.get("count") == 1, t)
bid = (t.get("thanks") or [{}])[0].get("_id")
st, r = call("DELETE", f"/thanks/{bid}", tok=tA); ok("гиранда пинҳон кард", r.get("hidden") is True, (st, r))
call("POST", f"/users/{A}/thanks", {"text": "боз"}, tB)
st, t = call("GET", f"/users/{A}/thanks", tok=tA); ok("фиристодани дубора пинҳонро барнагардонд", t.get("count") == 0, t)
st, _ = call("DELETE", f"/thanks/{bid}", tok=tD); ok("бегона нест карда наметавонад — 404", st == 404, st)

bad = [x for x in res if not x[0]]
print()
for g, n, d in res: print(("  ✅ " if g else "  ❌ ") + n + ("" if g else f"\n       → {d}"))
print(f"\n{len(res) - len(bad)}/{len(res)} гузашт")
sys.exit(1 if bad else 0)
