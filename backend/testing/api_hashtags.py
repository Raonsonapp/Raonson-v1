#!/usr/bin/env python3
"""Хештегҳо — мисли Instagram.

 Санҷида мешавад:
  • пост ВА Reel бо хештег → шумора (постҳо + Reels), ҳарфҳои тоҷикӣ,
    ҳарфи калон/хурд якхела, «#» дар дохили URL хештег нест, то 30 хештег;
  • «Беҳтарин» / «Нав» (омехта, саҳифа-саҳифа), шакли кӯҳнаи /posts/hashtag;
  • ҳисоби пӯшида ва бастшуда ПИНҲОН; хештегҳои алоқаманд;
  • ҷустуҷӯ (пешванд, бо шумора) ва /search;
  • обуна / бекор, рӯйхати обунаҳо, тақвият дар лентаи «Барои шумо»;
  • таҳрир ва ҳазф индексро нав мекунанд;
  • хештеги манъшуда (рӯйхати модератсия) → саҳифаи холӣ бо огоҳӣ;
  • тренд.
 ⚠️ Ба сервери МАҲАЛЛӢ мезанад.
"""
import json, os, re, sys, time, urllib.parse, urllib.request, urllib.error
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
def ok(n, c, d=""): res.append((bool(c), n, str(d)[:260]))
def q(s): return urllib.parse.quote(s)
def ids(r, key="items"): return [x.get("_id") for x in (r.get(key) or [])] if isinstance(r, dict) else []
def tagq(t): return "/hashtags/" + q(t)

S = os.environ.get("SUFFIX", "ht")
s = re.sub(r"[^0-9A-Za-z]", "", S).lower() or "ht"
tA, A = user(f"hta{S}", "+992900989001")   # муаллифи кушода
tB, Bb = user(f"htb{S}", "+992900989002")  # тамошобин
tC, C = user(f"htc{S}", "+992900989003")   # ҳисоби пӯшида
tD, D = user(f"htd{S}", "+992900989004")   # тамошобинро баст
tE, E = user(f"hte{S}", "+992900989005")   # ба хештег обуна мешавад
ok("корбарон сохта шуданд", all([tA, tB, tC, tD, tE]), [A, Bb, C, D, E])

T = f"Ҳисор{s}"          # бо ҳарфи калони тоҷикӣ
t = T.lower()
K = f"қаср{s}"
media = [{"url": "https://example.com/ht.jpg", "type": "image"}]
VID = "https://example.com/ht.mp4"

def post(tok, caption):
    st, p = call("POST", "/posts/", {"caption": caption, "media": media}, tok)
    return (p.get("_id") if isinstance(p, dict) else None), st, p

pid1, st, p = post(tA, f"Салом #{T}, #{K}! https://x.tj/page#notag{s}")
ok("пост бо хештеги тоҷикӣ сохта шуд", pid1 and st in (200, 201), f"HTTP {st} {p}")
st, r = call("POST", "/reels/", {"videoUrl": VID, "caption": f"Reel #{T.upper()} ва #{K.upper()}"}, tA)
rid1 = r.get("_id") if isinstance(r, dict) else None
ok("Reel бо хештег сохта шуд", rid1 and st in (200, 201), f"HTTP {st} {r}")
call("PUT", "/profile/", {"isPrivate": True}, tC)
pidC, _, _ = post(tC, f"пӯшида #{t}")
pidD, _, _ = post(tD, f"бастшуда #{t}")
call("POST", f"/users/{Bb}/block", tok=tD)
time.sleep(1.1)
pid2, _, _ = post(tA, f"дуюм\n#{t}")
ok("ҳамаи постҳо сохта шуданд", all([pidC, pidD, pid2]), [pidC, pidD, pid2])

# ── Сарлавҳа ────────────────────────────────────────────────────
st, h = call("GET", tagq(t), tok=tB)
ok("GET /hashtags/:tag → 200", st == 200 and h.get("tag") == t, f"HTTP {st} {h}")
ok("шумора = постҳо + Reels (бе пӯшида/бастшуда) = 3", h.get("postsCount") == 3, h.get("postsCount"))
ok("обуна нест", h.get("following") is False, h.get("following"))
rel = [x.get("tag") for x in h.get("related") or []]
ok("хештегҳои алоқаманд: «қаср…»", K in rel, rel)
ok("алоқаманд худи хештегро надорад", t not in rel, rel)
ok("алоқаманд — то 8", len(rel) <= 8, len(rel))
st, h2 = call("GET", tagq("#" + T.upper()), tok=tB)
ok("ҳарфи калон ва «#» → ҳамон хештег", st == 200 and h2.get("tag") == t and h2.get("postsCount") == 3, h2)
st, hk = call("GET", tagq(K.upper()), tok=tB)
ok("«ҚАСР» (тоҷикӣ, калон) → пост + Reel", hk.get("postsCount") == 2, hk)
st, hu = call("GET", tagq(f"notag{s}"), tok=tB)
ok("«#» дар дохили URL хештег нест", hu.get("postsCount") == 0, hu)
st, ha = call("GET", tagq(t), tok=tA)
ok("барои A бастшуда намоён аст (4), пӯшида не", ha.get("postsCount") == 4, ha.get("postsCount"))
st, hc = call("GET", tagq(t), tok=tC)
ok("муаллифи пӯшида пости худро мебинад (ҳамаи 5)", hc.get("postsCount") == 5, hc.get("postsCount"))
st, r = call("GET", "/hashtags/" + q("a b"), tok=tB)
ok("хештеги нодуруст → 400", st == 400, f"HTTP {st}")
st, r = call("GET", tagq(t))
ok("бе воридшавӣ → 401", st == 401, f"HTTP {st}")

# ── «Беҳтарин» / «Нав» ──────────────────────────────────────────
call("POST", f"/posts/{pid1}/like", tok=tB)
call("POST", f"/posts/{pid1}/like", tok=tE)
st, top = call("GET", tagq(t) + "/top", tok=tB)
got = ids(top)
ok("«Беҳтарин»: 200", st == 200, f"HTTP {st}")
ok("«Беҳтарин»: пост + Reel ҳарду ҳаст", pid1 in got and rid1 in got and pid2 in got, got)
ok("«Беҳтарин»: пӯшида ва бастшуда ПИНҲОН", pidC not in got and pidD not in got, got)
kinds = {x.get("_id"): x.get("kind") for x in top.get("items") or []}
ok("ҳар унсур kind дорад (post/reel)", kinds.get(pid1) == "post" and kinds.get(rid1) == "reel", kinds)
rr = next((x for x in top.get("items") or [] if x.get("_id") == rid1), {})
ok("Reel videoUrl ва user дорад", rr.get("videoUrl") == VID and (rr.get("user") or {}).get("username") == f"hta{S}", rr)
ok("«Беҳтарин»: пости лайкдор аввал", got[:1] == [pid1], got)
st, rec = call("GET", tagq(t) + "/recent", tok=tB)
got = ids(rec)
ok("«Нав»: навтарин аввал", got[:1] == [pid2], got)
ok("«Нав»: ҳамон 3 унсур", sorted(got) == sorted([pid1, rid1, pid2]), got)
st, p1 = call("GET", tagq(t) + "/recent?page=1&limit=2", tok=tB)
st, p2 = call("GET", tagq(t) + "/recent?page=2&limit=2", tok=tB)
ok("саҳифа 1: 2 унсур, hasMore", len(ids(p1)) == 2 and p1.get("hasMore") is True, p1.get("hasMore"))
ok("саҳифа 2: боқимонда, бе такрор", len(ids(p2)) == 1 and not set(ids(p1)) & set(ids(p2)) and p2.get("hasMore") is False, (ids(p1), ids(p2)))
st, old = call("GET", "/posts/hashtag/" + q(T), tok=tB)
got = ids(old, "posts")
ok("шакли кӯҳна /posts/hashtag: постҳо (ҳарфи тоҷикӣ)", pid1 in got and pid2 in got, got)
ok("шакли кӯҳна: пӯшида ва бастшуда ПИНҲОН", pidC not in got and pidD not in got, got)

# ── Ҳадди 30 хештег ─────────────────────────────────────────────
many = " ".join(f"#m{i}x{s}" for i in range(35))
pidM, _, _ = post(tA, many)
st, m29 = call("GET", tagq(f"m29x{s}"), tok=tB)
st, m30 = call("GET", tagq(f"m30x{s}"), tok=tB)
ok("то 30 хештег индекс мешавад (30-ум ҳаст)", m29.get("postsCount") == 1, m29)
ok("31-ум ва баъд — не", m30.get("postsCount") == 0, m30)

# ── Ҷустуҷӯ ─────────────────────────────────────────────────────
st, sr = call("GET", "/hashtags/search?q=" + q(T[:-1].upper()), tok=tB)
row = next((x for x in sr.get("hashtags") or [] if x.get("tag") == t), None)
ok("ҷустуҷӯи пешванд (калон) → хештег", st == 200 and row is not None, sr)
ok("ҷустуҷӯ шумораро медиҳад (3)", (row or {}).get("postsCount") == 3, row)
st, sr = call("GET", "/hashtags/search?q=" + q("#" + t), tok=tB)
ok("ҷустуҷӯ бо «#» → аввал худи хештег", ((sr.get("hashtags") or [{}])[0]).get("tag") == t, sr.get("hashtags", [])[:2])
st, sr = call("GET", "/hashtags/search?q=" + q("a%"), tok=tB)
ok("аломати бегона → рӯйхати холӣ", st == 200 and sr.get("hashtags") == [], sr)
st, gs = call("GET", "/search?q=" + q("#" + t), tok=tB)
row = next((x for x in gs.get("hashtags") or [] if x.get("tag") == t), None) if isinstance(gs, dict) else None
ok("/search → хештег бо postsCount", row is not None and row.get("postsCount") == 3, gs.get("hashtags") if isinstance(gs, dict) else gs)

# ── Обуна ва лентаи «Барои шумо» ────────────────────────────────
def in_smart(tok, pid):
    for page in range(1, 16):
        st, r = call("GET", f"/posts/smart-feed?page={page}&limit=2", tok=tok)
        if not isinstance(r, dict) or r.get("algo") != "smart":
            return False
        if pid in ids(r, "posts"):
            return True
        if len(r.get("posts") or []) < 2:
            return False
    return False
ok("бе обуна пост дар «Барои шумо» нест", not in_smart(tE, pid1))
st, r = call("POST", tagq(T) + "/follow", tok=tE)
ok("обуна → following:true", st == 200 and r.get("following") is True and r.get("tag") == t, f"HTTP {st} {r}")
st, h = call("GET", tagq(t), tok=tE)
ok("сарлавҳа: following:true", h.get("following") is True, h)
st, fl = call("GET", "/hashtags/following", tok=tE)
row = next((x for x in fl.get("hashtags") or [] if x.get("tag") == t), None)
# E-ро касе набаст: пости D намоён, пӯшидаи C не → 4.
ok("рӯйхати обунаҳо хештегро бо шумора дорад", row is not None and row.get("postsCount") == 4, fl)
ok("пости маъмули хештег дар «Барои шумо»", in_smart(tE, pid1))
st, r = call("POST", tagq(T) + "/follow", tok=tE)
ok("обунаи такрорӣ — бехатар", st == 200 and r.get("following") is True, r)
st, r = call("DELETE", tagq(T) + "/follow", tok=tE)
ok("бекор → following:false", st == 200 and r.get("following") is False, r)
st, fl = call("GET", "/hashtags/following", tok=tE)
ok("рӯйхати обунаҳо холӣ шуд", t not in [x.get("tag") for x in fl.get("hashtags") or []], fl)
ok("баъди бекор пост аз «Барои шумо» рафт", not in_smart(tE, pid1))

# ── Таҳрир ва ҳазф ──────────────────────────────────────────────
st, r = call("PUT", f"/posts/{pid2}/caption", {"caption": f"бе хештег, вале #нав{s}"}, tA)
ok("таҳрири тавсиф", st == 200, f"HTTP {st} {r}")
st, h = call("GET", tagq(t), tok=tB)
ok("таҳрир: хештеги кӯҳна рафт (2)", h.get("postsCount") == 2, h.get("postsCount"))
st, h = call("GET", tagq(f"нав{s}"), tok=tB)
ok("таҳрир: хештеги нав илова шуд", h.get("postsCount") == 1, h)
st, r = call("PUT", f"/reels/{rid1}/caption", {"caption": f"#{K}"}, tA)
st, h = call("GET", tagq(t), tok=tB)
ok("таҳрири Reel: хештег рафт (1)", h.get("postsCount") == 1, h.get("postsCount"))
st, r = call("DELETE", f"/reels/{rid1}", tok=tA)
st, h = call("GET", tagq(K), tok=tB)
ok("ҳазфи Reel: шумора кам шуд", h.get("postsCount") == 1, h)

# ── Хештеги манъшуда (модератсия) ───────────────────────────────
NOTICE = "Постҳо барои ин хештег пинҳон карда шудаанд"
bad = f"pornvideo{s}"
st, h = call("GET", tagq(bad), tok=tB)
ok("манъшуда: hidden + огоҳии тоҷикӣ", st == 200 and h.get("hidden") is True and h.get("notice") == NOTICE and h.get("postsCount") == 0, h)
st, r = call("GET", tagq(bad) + "/top", tok=tB)
ok("манъшуда: «Беҳтарин» холӣ бо огоҳӣ", r.get("items") == [] and r.get("notice") == NOTICE, r)
st, r = call("GET", tagq(bad) + "/recent", tok=tB)
ok("манъшуда: «Нав» холӣ", r.get("items") == [] and r.get("hidden") is True, r)
st, r = call("GET", "/posts/hashtag/" + q(bad), tok=tB)
ok("манъшуда: шакли кӯҳна холӣ", r.get("posts") == [], r)
st, r = call("POST", tagq(bad) + "/follow", tok=tE)
ok("ба манъшуда обуна намешавад (400)", st == 400, f"HTTP {st} {r}")
st, sr = call("GET", "/hashtags/search?q=porn", tok=tB)
ok("манъшуда дар ҷустуҷӯ нест", st == 200 and not [x for x in sr.get("hashtags") or [] if "porn" in x.get("tag", "")], sr)
pidX, st, r = post(tA, f"#porn{s} видео")
ok("тавсиф бо хештеги 18+ ҳамоно рад мешавад (модератсия)", st not in (200, 201), f"HTTP {st} {r}")

# ── Тренд ───────────────────────────────────────────────────────
st, tr = call("GET", "/hashtags/trending", tok=tB)
lst = tr.get("trending") if isinstance(tr, dict) else None
ok("тренд: 200 ва рӯйхат", st == 200 and isinstance(lst, list), f"HTTP {st} {tr}")
ok("тренд: то 20", len(lst or []) <= 20, len(lst or []))
ok("тренд: шакл {tag, postsCount}", all(isinstance(x.get("tag"), str) and isinstance(x.get("postsCount"), int) for x in lst or []), (lst or [])[:2])
ok("тренд: хештеги нав ҳаст (ё рӯйхат пур аст)", K in [x.get("tag") for x in lst or []] or len(lst or []) == 20, [x.get("tag") for x in (lst or [])][:20])
ok("тренд: манъшуда нест", not [x for x in lst or [] if "porn" in x.get("tag", "")], lst)

bad = [x for x in res if not x[0]]
print()
for g, n, d in res: print(("  ✅ " if g else "  ❌ ") + n + ("" if g else f"\n       → {d}"))
print(f"\n{len(res) - len(bad)}/{len(res)} гузашт")
sys.exit(1 if bad else 0)
