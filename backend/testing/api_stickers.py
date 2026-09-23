#!/usr/bin/env python3
"""Стикерҳои сторис — мисли Instagram: савол, викторина, слайдер, ҳисоби баръакс.
 ⚠️ Ба сервери МАҲАЛЛӢ мезанад.
"""
import json, os, sys, time, datetime, urllib.request, urllib.error
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
def ok(n, c, d=""): res.append((bool(c), n, str(d)[:200]))

S = os.environ.get("SUFFIX", "st")
tA, A = user(f"sa{S}", "+992900930001")
tB, Bb = user(f"sb{S}", "+992900930002")
tC, C = user(f"sc{S}", "+992900930003")
if not (tA and tB and tC): print("!! вуруд нашуд"); sys.exit(1)
call("POST", f"/follow/{A}", tok=tB); call("POST", f"/follow/{A}", tok=tC)

def story(sticker):
    return call("POST", "/stories/", {"mediaUrl": "https://example.com/s.jpg", "mediaType": "image", "sticker": sticker}, tA)
def sid_of(r): return r.get("_id") or r.get("id") or (r.get("story") or {}).get("_id") if isinstance(r, dict) else None
def view(sid, tok):
    st, r = call("GET", f"/stories/?userId={A}", tok=tok)
    lst = r if isinstance(r, list) else (r.get("stories") or [])
    return next((x for x in lst if x.get("_id") == sid), {})

# ── ВИКТОРИНА ──
st, r = story({"kind": "quiz", "prompt": "Пойтахти Тоҷикистон?", "options": ["Хуҷанд", "Душанбе", "Бохтар"], "correct": 1})
qid = sid_of(r); ok("стори бо викторина сохта шуд", st in (200, 201) and qid, r)
v = view(qid, tB).get("sticker", {})
ok("тамошобин викторинаро мебинад", v.get("kind") == "quiz" and len(v.get("options", [])) == 3, v)
ok("ҷавоби дуруст ПЕШ аз ҷавоб додан пинҳон аст", "correct" not in v, v)
st, r = call("POST", f"/stories/{qid}/sticker/respond", {"choice": 0}, tB)
ok("ҷавоби нодуруст қабул шуд ва дуруст нишон дода шуд",
   st == 200 and r.get("isCorrect") is False and r.get("correct") == 1, r)
st, r = call("POST", f"/stories/{qid}/sticker/respond", {"choice": 1}, tB)
ok("ҷавобро ИВАЗ кардан мумкин нест", r.get("myChoice") == 0 and r.get("locked") is True, r)
st, r = call("POST", f"/stories/{qid}/sticker/respond", {"choice": 1}, tC)
ok("ҷавоби дуруст", r.get("isCorrect") is True and r.get("counts") == [1, 1, 0], r)
st, r = call("POST", f"/stories/{qid}/sticker/respond", {"choice": 9}, tC)
ok("варианти нобуд рад мешавад", st == 400, f"HTTP {st}")
st, r = call("POST", f"/stories/{qid}/sticker/respond", {"choice": 1}, tA)
ok("соҳиб ба стикери худ ҷавоб дода НАМЕТАВОНАД", st == 403, f"HTTP {st}")
v = view(qid, tA).get("sticker", {})
ok("соҳиб натиҷаро мебинад", v.get("correct") == 1 and v.get("counts") == [1, 1, 0], v)

# ── СЛАЙДЕР ──
st, r = story({"kind": "slider", "prompt": "Чӣ қадар маъқул?", "emoji": "🔥"})
sl = sid_of(r); ok("стори бо слайдер", sl, r)
st, r = call("POST", f"/stories/{sl}/sticker/respond", {"value": 80}, tB)
st, r = call("POST", f"/stories/{sl}/sticker/respond", {"value": 40}, tC)
ok("миёнаи слайдер", r.get("average") == 60 and r.get("responses") == 2, r)
st, r = call("POST", f"/stories/{sl}/sticker/respond", {"value": 150}, tB)
ok("қимати берун аз 0–100 рад мешавад", st == 400, f"HTTP {st}")
v = view(sl, tA).get("sticker", {})
ok("эмодзии слайдер нигоҳ дошта шуд", v.get("emoji") == "🔥", v)

# ── САВОЛ ──
st, r = story({"kind": "question", "prompt": "Аз ман пурсед"})
qs = sid_of(r); ok("стори бо савол", qs, r)
st, r = call("POST", f"/stories/{qs}/sticker/respond", {"answer": "Кай концерт?"}, tB)
ok("ҷавоб ба савол", st == 200, f"HTTP {st}: {r}")
st, r = call("POST", f"/stories/{qs}/sticker/respond", {"answer": "   "}, tC)
ok("ҷавоби холӣ рад мешавад", st == 400, f"HTTP {st}")
st, r = call("GET", f"/stories/{qs}/sticker/answers", tok=tA)
ans = r.get("answers", []) if isinstance(r, dict) else []
ok("соҳиб ҷавобҳоро мебинад", len(ans) == 1 and ans[0].get("answer") == "Кай концерт?", r)
st, r = call("GET", f"/stories/{qs}/sticker/answers", tok=tC)
ok("БЕГОНА ҷавобҳои дигаронро намебинад", st == 404, f"HTTP {st}")

# ── ҲИСОБИ БАРЪАКС ──
end = (datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(days=3)).strftime("%Y-%m-%dT%H:%M:%SZ")
st, r = story({"kind": "countdown", "prompt": "Зодрӯзи ман", "endsAt": end})
cd = sid_of(r); ok("стори бо ҳисоби баръакс", cd, r)
v = view(cd, tB).get("sticker", {})
ok("вақти анҷом ба тамошобин мерасад", v.get("kind") == "countdown" and v.get("endsAt"), v)
past = (datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(hours=1)).strftime("%Y-%m-%dT%H:%M:%SZ")
st, r = story({"kind": "countdown", "prompt": "x", "endsAt": past})
ok("ҳисоби баръакс ба гузашта рад мешавад", st == 400, f"HTTP {st}")

# ── ЛИНК ──
st, r = story({"kind": "link", "url": "https://raonson.app/help", "prompt": "Ёрдам"})
lk = sid_of(r); ok("стори бо стикери линк", st in (200, 201) and lk, r)
v = view(lk, tB).get("sticker", {})
ok("линк ба тамошобин мерасад", v.get("kind") == "link" and v.get("url") == "https://raonson.app/help", v)
for bad in ["http://raonson.app", "javascript:alert(1)", "https://localhost", "не-линк"]:
    st, r = story({"kind": "link", "url": bad})
    ok(f"линки нодуруст рад мешавад: {bad}", st == 400, f"HTTP {st}")

# ── УПОМИНАНИЕ ──
st, r = call("POST", "/stories/", {"mediaUrl": "https://example.com/m.jpg", "mediaType": "image",
    "mentions": [{"username": f"@sb{S}", "x": 0.3, "y": 0.4}, {"username": "hech_kas_nest_999"},
                 {"username": f"sa{S}"}]}, tA)
mn = sid_of(r); ok("стори бо упоминание", mn, r)
ms = view(mn, tC).get("mentions", [])
ok("танҳо корбари ВОҚЕӢ зикр шуд (на нобуд, на худам)", [m.get("username") for m in ms] == [f"sb{S}"], ms)
ok("ҷойгиршавӣ нигоҳ дошта шуд", ms and abs(ms[0].get("x", 0) - 0.3) < 0.01, ms)
st, r = call("GET", "/notifications/", tok=tB)
ok("шахси зикршуда огоҳинома гирифт", "story_mention" in json.dumps(r), str(r)[:200])

# ── Ҳимоя ──
st, r = story({"kind": "quiz", "prompt": "?", "options": ["танҳо"], "correct": 0})
ok("викторинаи нодуруст — 400, стори сохта НАМЕШАВАД", st == 400, f"HTTP {st}")
st, r = call("POST", f"/stories/{qid}/sticker/respond", {"choice": 1})
ok("бе токен — рад", st in (401, 403), f"HTTP {st}")

bad = [x for x in res if not x[0]]
print()
for g, n, d in res: print(("  ✅ " if g else "  ❌ ") + n + ("" if g else f"\n       → {d}"))
print(f"\n{len(res) - len(bad)}/{len(res)} гузашт")
sys.exit(1 if bad else 0)
