#!/usr/bin/env python3
"""Ҳисоби пӯшида дар ҲАМАИ ҷойҳо, на танҳо дар профил.

 Санҷиши систематикии 26 дархост нишон дод, ки танҳо профил қулфи
 ҳисоби пӯшидаро риоя мекард. Лента, лентаи ҳушманд, explore,
 ҷустуҷӯ, Reels, кушодан аз рӯи ID, шарҳҳо, лайкҳо, Актуальный,
 постҳои қайдшуда, рӯйхати обунаҳо ва ҳатто пешнамоиши ОММАВИИ
 линк (бе вуруд!) — ҳама постҳои пӯшидаро нишон медоданд.

 A — ҳисоби пӯшида. B — бегона. C — обунаи тасдиқшуда.
 ⚠️ Ба сервери МАҲАЛЛӢ мезанад.
"""
import json, os, sys, time, urllib.request, urllib.error
B_ = os.environ.get("BASE", "http://127.0.0.1:8099"); PW = "Test12345!"; res = []
def _once(m, p, body=None, tok=None, raw=False):
    req = urllib.request.Request(B_ + p, data=json.dumps(body).encode() if body is not None else None, method=m)
    req.add_header('Content-Type', 'application/json')
    if tok: req.add_header('Authorization', 'Bearer ' + tok)
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            txt = r.read().decode()
            if raw: return r.status, txt
            return r.status, (json.loads(txt) if txt else {})
    except urllib.error.HTTPError as e:
        txt = e.read().decode()
        if raw: return e.code, txt
        try: return e.code, json.loads(txt)
        except Exception: return e.code, txt
    except Exception as e: return 0, str(e)
def call(m, p, body=None, tok=None, raw=False):
    for a in range(4):
        st, r = _once(m, p, body, tok, raw)
        if st != 429: return st, r
        time.sleep(4 * (a + 1))
    return st, r
def user(u, ph):
    call("POST", "/auth/register", {"username": u, "email": f"{u}@example.com", "password": PW, "fullName": u, "phone": ph})
    st, r = call("POST", "/auth/login", {"email": u, "password": PW})
    return r.get("accessToken"), (r.get("user") or {}).get("id") or (r.get("user") or {}).get("_id")
def ok(n, c, d=""): res.append((bool(c), n, str(d)[:200]))
def jd(x): return json.dumps(x, ensure_ascii=False)

S = os.environ.get("SUFFIX", "pv")
tA, A = user(f"pa{S}", "+992900940001")
tB, Bb = user(f"pb{S}", "+992900940002")
tC, C = user(f"pc{S}", "+992900940003")
if not (tA and tB and tC): print("!! вуруд нашуд"); sys.exit(1)

# C обуна мешавад, ПЕШ аз пӯшидан — обунаи тасдиқшуда.
call("POST", f"/follow/{A}", tok=tC)
MARK = f"махфӣ{S}"
st, p = call("POST", "/posts/", {"caption": f"{MARK} #пинҳон{S}",
    "media": [{"url": "https://example.com/secret.jpg", "type": "image"}]}, tA)
pid = p.get("_id") or p.get("id") or (p.get("post") or {}).get("_id")
st, r = call("POST", "/reels/", {"videoUrl": "https://example.com/secret.mp4", "caption": MARK}, tA)
rid = r.get("_id") or r.get("id") or (r.get("reel") or {}).get("_id")
call("POST", f"/posts/{pid}/like", tok=tC)
call("POST", f"/posts/{pid}/comments", {"text": f"шарҳ {MARK}"}, tC)
call("POST", "/highlights/", {"title": f"Акт{S}", "storyIds": []}, tA)
# Акнун ҳисоб ПӮШИДА мешавад.
st, r = call("PUT", "/profile/", {"isPrivate": True}, tA)
ok("ҳисоб пӯшида шуд", st in (200, 201), f"HTTP {st}")
ok("пост ва Reel сохта шуданд", pid and rid, f"{pid} {rid}")
time.sleep(3.5)  # кэши 3-сонияина

def leaks(tok, path):
    st, r = call("GET", path, tok=tok)
    return st, (MARK in jd(r) or (pid and pid in jd(r)) or (rid and rid in jd(r)))

checks = [
    ("лента", "/posts/feed?limit=50"),
    ("лентаи ҳушманд", "/posts/smart-feed?limit=50"),
    ("explore", "/explore"),
    ("ҷустуҷӯ", f"/search/?q={MARK}"),
    ("Reels", "/reels/?limit=50"),
    ("Reels-и ҳушманд", "/reels/smart?limit=50"),
    ("постҳои профил", f"/users/{A}/posts"),
    ("Reels-и профил", f"/users/{A}/reels"),
    ("пост аз рӯи ID", f"/posts/{pid}"),
    ("Reel аз рӯи ID", f"/reels/{rid}"),
    ("шарҳҳои пост", f"/posts/{pid}/comments"),
]
for name, path in checks:
    st, leak = leaks(tB, path)
    ok(f"БЕГОНА: {name} — пинҳон", not leak, f"HTTP {st}")

st, r = call("GET", f"/posts/{pid}/likes", tok=tB)
ok("БЕГОНА: лайккунандагон — пинҳон", C not in jd(r), r)
st, r = call("GET", f"/users/{A}/followers", tok=tB)
ok("БЕГОНА: рӯйхати обунаҳо — пинҳон", C not in jd(r), r)
st, r = call("GET", f"/highlights/{A}", tok=tB)
ok("БЕГОНА: Актуальный — пинҳон", f"Акт{S}" not in jd(r), r)

# Пешнамоиши оммавӣ — БЕ ВУРУД.
st, html = call("GET", f"/p/{pid}", raw=True)
ok("ИНТЕРНЕТ (бе вуруд): пешнамоиши пост — пинҳон", MARK not in html and "secret.jpg" not in html, f"HTTP {st}")
st, html = call("GET", f"/r/{rid}", raw=True)
ok("ИНТЕРНЕТ (бе вуруд): пешнамоиши Reel — пинҳон", MARK not in html and "secret.mp4" not in html, f"HTTP {st}")

# Обуна (C) ҳамаро мебинад.
for name, path in [("лента", "/posts/feed?limit=50"), ("постҳои профил", f"/users/{A}/posts"),
                   ("Reels-и профил", f"/users/{A}/reels"), ("пост аз рӯи ID", f"/posts/{pid}"),
                   ("шарҳҳо", f"/posts/{pid}/comments")]:
    st, leak = leaks(tC, path)
    ok(f"ОБУНА: {name} — дида мешавад", leak, f"HTTP {st}")

# Худам ҳамаро мебинам.
st, leak = leaks(tA, f"/posts/{pid}")
ok("СОҲИБ: пости худ — дида мешавад", leak, f"HTTP {st}")

# Мисли Instagram: дар explore/ҷустуҷӯ ҳатто обуна пости пӯшидаро намебинад.
st, leak = leaks(tC, "/explore")
ok("explore танҳо ҳисобҳои кушода (ҳатто барои обуна)", not leak, f"HTTP {st}")

# Ҳисоби кушода — ҳамон пост ба ҳама.
call("PUT", "/profile/", {"isPrivate": False}, tA); time.sleep(3.5)
st, leak = leaks(tB, f"/posts/{pid}")
ok("ҳисоби КУШОДА: бегона постро мебинад", leak, f"HTTP {st}")
st, html = call("GET", f"/p/{pid}", raw=True)
ok("ҳисоби КУШОДА: пешнамоиши линк кор мекунад", st == 200 and MARK in html, f"HTTP {st}")

bad = [x for x in res if not x[0]]
print()
for g, n, d in res: print(("  ✅ " if g else "  ❌ ") + n + ("" if g else f"\n       → {d}"))
print(f"\n{len(res) - len(bad)}/{len(res)} гузашт")
sys.exit(1 if bad else 0)
