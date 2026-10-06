#!/usr/bin/env python3
"""Модератсияи пеш аз нашр — 18+, порнография, дашном, линкҳо.

 • матни бад (тавсиф, шарҳ, паём, bio, Reel, сторис) → 403 бо матни
   «Ин мӯҳтаво қоидаҳои Raonson-ро вайрон мекунад»;
 • линки сайти 18+ → 403; линки бегуноҳ → OK;
 • «шубҳанок» (калимаи суст) → пост пинҳон то тасдиқи admin;
 • 3 огоҳӣ дар 30 рӯз → маҳдудкунии худкор → нашр 403 account_suspended;
 • admin: навбат, тасдиқ, огоҳиҳо, барқарорсозӣ, бани доимӣ;
 • (ихтиёрӣ) расм тавассути provider-и қалбакии маҳаллӣ: IMG_BASE —
   сервери дуюм бо MODERATION_IMAGE_URL=http://127.0.0.1:<MOD_STUB_PORT>/hf,
   MEDIA_ALLOWED_HOSTS=127.0.0.1:<MOD_STUB_PORT>, MEDIA_ALLOW_HTTP=1.
   Ин скрипт худаш stub-ро дар MOD_STUB_PORT мекушояд.

 ⚠️ Танҳо сервери МАҲАЛЛӢ/CI. Қисми admin DATABASE_URL + psql мехоҳад
 (корбари санҷиширо admin мекунад).
"""
import hashlib, http.server, json, os, subprocess, sys, threading, time
import urllib.request, urllib.error

B = os.environ.get("BASE", "http://127.0.0.1:8099")
IMG = os.environ.get("IMG_BASE", "")
STUB_PORT = int(os.environ.get("MOD_STUB_PORT", "8098"))
S = os.environ.get("SUFFIX", "md")
DB = os.environ.get("DATABASE_URL", "")
PW = "Test12345!"
BLOCKED = "Ин мӯҳтаво қоидаҳои Raonson-ро вайрон мекунад"
res = []


def _once(base, m, p, body=None, tok=None):
    req = urllib.request.Request(base + p, data=json.dumps(body).encode() if body is not None else None, method=m)
    req.add_header("Content-Type", "application/json")
    if tok:
        req.add_header("Authorization", "Bearer " + tok)
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
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


def call(m, p, body=None, tok=None, base=None):
    for a in range(4):
        st, r = _once(base or B, m, p, body, tok)
        if st != 429:
            return st, r
        time.sleep(4 * (a + 1))
    return st, r


def ok(n, c, d=""):
    res.append((bool(c), n, str(d)[:220]))


N = int(hashlib.sha1(("moderation-" + S).encode()).hexdigest(), 16) % 10**6


def phone(k):
    return f"+99294{N:06d}{k}"


def user(u, k):
    call("POST", "/auth/register", {"username": u, "email": f"{u}@example.com",
                                    "password": PW, "fullName": "Full " + u, "phone": phone(k)})
    st, r = call("POST", "/auth/login", {"email": u, "password": PW})
    usr = r.get("user") or {} if isinstance(r, dict) else {}
    return (r.get("accessToken") if isinstance(r, dict) else None), (usr.get("id") or usr.get("_id"))


def blocked(st, r):
    return st == 403 and isinstance(r, dict) and r.get("message") == BLOCKED and r.get("code") == "content_blocked"


def img(name="a"):
    return [{"url": f"https://example.com/{name}.jpg", "type": "image"}]


A = f"mda{S}"; tA, idA = user(A, 1)
Bn = f"mdb{S}"; tB, idB = user(Bn, 2)
C = f"mdc{S}"; tC, idC = user(C, 3)
D = f"mdd{S}"; tD, idD = user(D, 4)
ADM = f"mdadm{S}"; tAdm, idAdm = user(ADM, 5)
E = f"mde{S}"; tE, idE = user(E, 7)
# Ҳар корбар на бештар аз 2 огоҳӣ мегирад (3 → маҳдуд), ба ғайр аз C.
ok("корбарон сохта шуданд", all([tA, tB, tC, tD, tAdm, tE]), (A, idA, idB, idC, idD, idE))
if not all([tA, tB, tC, tD, tAdm, tE]):
    print("!! вуруд нашуд"); sys.exit(1)

# ═══ 1. Мӯҳтавои тоза ═══════════════════════════════════════════
st, p = call("POST", "/posts/", {"caption": "Салом дӯстон! Ҳаво имрӯз зебост 🌞 https://raonson.tj",
                                 "media": img("clean")}, tA)
clean_post = p.get("_id") if isinstance(p, dict) else None
ok("пости тоза нашр шуд", st == 201 and clean_post and not p.get("pendingReview"), (st, p))
st, r = call("GET", f"/posts/{clean_post}", tok=tB)
ok("пости тозаро дигарон мебинанд", st == 200, st)
st, r = call("POST", f"/comments/{clean_post}", {"text": "Аъло! Essex ва sextant — калимаҳои бегуноҳ"}, tB)
ok("шарҳи тоза (Essex, sextant) қабул шуд", st in (200, 201), (st, r))

# ═══ 2. Матни бад ═══════════════════════════════════════════════
st, r = call("POST", "/posts/", {"caption": "free p0rn videos here", "media": img("x")}, tA)
ok("тавсифи 18+ (leet: p0rn) → 403 бо матни тоҷикӣ", blocked(st, r), (st, r))
st, r = call("POST", "/posts/", {"caption": "линк: https://stripchat.com/girls", "media": img("y")}, tA)
ok("линки сайти 18+ дар тавсиф → 403", blocked(st, r) and "adult_link" in (r.get("categories") or []), (st, r))
st, r = call("POST", f"/comments/{clean_post}", {"text": "иди нахуй"}, tB)
ok("шарҳи дашном → 403", blocked(st, r), (st, r))
st, r = call("POST", f"/comments/{clean_post}", {"text": "смотри порно тут"}, tD)
ok("шарҳи 18+ (кириллӣ) → 403", blocked(st, r), (st, r))

st, ch = call("GET", f"/chat/with/{idB}", tok=tA)
chat_ab = (ch.get("chatId") or ch.get("id") or ch.get("_id")) if isinstance(ch, dict) else None
st, r = call("POST", f"/chat/{chat_ab}/messages", {"text": "салом! https://raonson.tj"}, tA)
ok("паёми тоза бо линки бегуноҳ фиристода шуд", st == 201, (st, r))
st, ch = call("GET", f"/chat/with/{idB}", tok=tE)
chat_eb = (ch.get("chatId") or ch.get("id") or ch.get("_id")) if isinstance(ch, dict) else None
st, r = call("POST", f"/chat/{chat_eb}/messages", {"text": "бин: pornhub dot com/xyz"}, tE)
ok("паём бо линки 18+ (pornhub dot com) → 403", blocked(st, r), (st, r))
st, r = call("POST", f"/chat/{chat_ab}/messages",
             {"text": "", "mediaUrl": "https://example.com/pic.jpg", "type": "image"}, tA)
ok("паём бо расм (provider нест → иҷозат + навбат)", st == 201, (st, r))

st, r = call("PUT", "/profile/", {"bio": "Бизнес ва сафар", "website": "onlyfans.com/me"}, tB)
ok("bio бо линки 18+ → 403", blocked(st, r), (st, r))
st, r = call("PUT", "/profile/", {"bio": "Бизнес ва сафар ✈️", "website": "raonson.tj"}, tB)
ok("bio-и тоза сабт шуд", st == 200, (st, r))
st, r = call("PUT", "/profile/", {"isPrivate": False}, tB)
ok("танзими профил бе матн — бе санҷиш", st == 200, (st, r))

st, r = call("POST", "/reels/", {"videoUrl": "https://example.com/v.mp4", "caption": "секс видео бесплатно"}, tB)
ok("Reel бо тавсифи 18+ → 403", blocked(st, r), (st, r))
st, r = call("POST", "/reels/", {"videoUrl": "https://example.com/v.mp4", "caption": "Табиати Тоҷикистон"}, tD)
ok("Reel-и тоза нашр шуд", st == 201 and not r.get("pendingReview"), (st, r))
st, r = call("POST", "/stories/", {"mediaUrl": "https://example.com/s.jpg", "mediaType": "image",
                                   "caption": "xnxx"}, tD)
ok("сторис бо тавсифи 18+ → 403", blocked(st, r), (st, r))
st, r = call("POST", "/stories/", {"mediaUrl": "https://example.com/s.jpg", "mediaType": "image",
                                   "caption": "Субҳ ба хайр"}, tD)
ok("сториси тоза нашр шуд", st == 201, (st, r))

# Таҳрир ҳам санҷида мешавад.
st, p = call("POST", "/posts/", {"caption": "Китоб", "media": img("book")}, tE)
st, r = call("PUT", f"/posts/{p.get('_id')}/caption", {"caption": "porn"}, tE)
ok("таҳрири тавсиф ба 18+ → 403", blocked(st, r), (st, r))
st, r = call("GET", f"/posts/{p.get('_id')}", tok=tB)
ok("тавсифи кӯҳна боқӣ монд", st == 200 and r.get("caption") == "Китоб", (st, r.get("caption") if isinstance(r, dict) else r))

# ═══ 3. Шубҳанок → пинҳон то тасдиқ ═════════════════════════════
st, p = call("POST", "/posts/", {"caption": "My new sexy dress", "media": img("dress")}, tD)
held_post = p.get("_id") if isinstance(p, dict) else None
ok("пости шубҳанок қабул шуд, вале пинҳон (pendingReview)", st == 201 and p.get("pendingReview") is True, (st, p))
st, r = call("GET", f"/posts/{held_post}", tok=tB)
ok("пости пинҳонро дигарон НАМЕБИНАНД", st == 404, st)
st, r = call("GET", f"/posts/{held_post}", tok=tD)
ok("муаллиф пости пинҳони худро мебинад", st == 200, st)

# ═══ 4. Огоҳиҳо → маҳдудкунӣ ════════════════════════════════════
bad = ["watch porn now", "смотри порно", "видеои урён"]
last = None
for i, t in enumerate(bad):
    st, r = call("POST", "/posts/", {"caption": t, "media": img(f"c{i}")}, tC)
    last = (st, r)
    ok(f"огоҳии {i + 1}: 403", blocked(st, r), (st, r))
ok("огоҳии сеюм → маҳдудкунии худкор (suspendedUntil)", isinstance(last[1], dict) and last[1].get("suspendedUntil"), last)
st, r = call("POST", "/posts/", {"caption": "Салом", "media": img("ok")}, tC)
ok("корбари маҳдуд пост гузошта наметавонад (account_suspended)",
   st == 403 and isinstance(r, dict) and r.get("code") == "account_suspended", (st, r))
st, ch = call("GET", f"/chat/with/{idA}", tok=tC)
chat_ca = (ch.get("chatId") or ch.get("id") or ch.get("_id")) if isinstance(ch, dict) else None
st, r = call("POST", f"/chat/{chat_ca}/messages", {"text": "салом"}, tC)
ok("корбари маҳдуд паём фиристода наметавонад", st == 403, (st, r))
st, r = call("GET", "/profile/me", tok=tC)
ok("корбари маҳдуд ворид мешавад ва мехонад", st == 200, st)

# ═══ 5. Admin ═══════════════════════════════════════════════════
st, r = call("GET", "/admin/moderation/queue", tok=tA)
ok("корбари оддӣ навбати модератсияро намебинад", st == 403, st)

admin_ok = False
if DB:
    try:
        subprocess.run(["psql", DB, "-v", "ON_ERROR_STOP=1", "-qc",
                        f"UPDATE users SET role='admin' WHERE username='{ADM}'"],
                       check=True, capture_output=True, timeout=30)
        admin_ok = True
    except Exception as e:
        print("⚠️ psql дастрас нест:", e)
if not admin_ok:
    ok("admin: DATABASE_URL + psql лозим (қисми admin гузаронда нашуд)", False, "DATABASE_URL нест")
else:
    st, q = call("GET", "/admin/moderation/queue?status=pending", tok=tAdm)
    items = q.get("items", []) if isinstance(q, dict) else []
    susp = [x for x in items if x.get("action") == "suspension" and (x.get("user") or {}).get("id") == idC]
    ok("admin маҳдудкунии худкорро дар навбат мебинад", st == 200 and len(susp) == 1, (st, len(items)))
    rev = [x for x in items if x.get("targetId") == held_post]
    ok("пости шубҳанок дар навбат (held, категория, хол)",
       len(rev) == 1 and rev[0].get("held") is True and "suspicious" not in rev[0].get("categories", ["x"]) and
       rev[0].get("user", {}).get("username") == D, rev[:1])
    uns = [x for x in items if x.get("action") == "unscanned" and x.get("targetId") == clean_post]
    ok("расми санҷиданашуда (provider нест) дар навбат", len(uns) == 1, len(uns))

    st, s = call("GET", f"/admin/moderation/users/{idC}/strikes", tok=tAdm)
    ok("admin огоҳиҳои корбарро мебинад (3)", st == 200 and s.get("recentStrikes") == 3 and s.get("suspendedUntil"), (st, s))

    if rev:
        st, r = call("POST", f"/admin/moderation/queue/{rev[0]['id']}/approve", tok=tAdm)
        ok("admin тасдиқ кард", st == 200, (st, r))
        st, r = call("GET", f"/posts/{held_post}", tok=tB)
        ok("баъди тасдиқ пост ба ҳама намоён", st == 200, st)

    st, r = call("POST", f"/admin/moderation/users/{idC}/restore", tok=tAdm)
    ok("admin корбарро барқарор кард", st == 200 and r.get("restored"), (st, r))
    st, r = call("POST", "/posts/", {"caption": "Бозгашт 🙂", "media": img("back")}, tC)
    ok("баъди барқарорсозӣ корбар боз пост мегузорад", st == 201, (st, r))

    # Нест кардан: шубҳанок → admin «Remove».
    st, p = call("POST", "/posts/", {"caption": "naked truth", "media": img("n")}, tD)
    rp = p.get("_id") if isinstance(p, dict) else None
    st, q = call("GET", "/admin/moderation/queue?status=pending&action=review", tok=tAdm)
    it = [x for x in (q.get("items") or []) if x.get("targetId") == rp]
    st, r = call("POST", f"/admin/moderation/queue/{it[0]['id'] if it else 0}/remove", tok=tAdm)
    ok("admin мӯҳтаворо нест кард (+огоҳӣ)", st == 200 and r.get("status") == "removed", (st, r))
    st, r = call("GET", f"/posts/{rp}", tok=tB)
    ok("пости несткарда намоён нест", st == 404, st)

    # Бани доимӣ — танҳо admin.
    st, r = call("POST", f"/admin/moderation/users/{idC}/ban", tok=tAdm)
    ok("admin бани доимӣ гузошт", st == 200 and r.get("banned"), (st, r))
    time.sleep(1)
    st, r = call("POST", "/posts/", {"caption": "салом", "media": img("z")}, tC)
    ok("корбари бандор пост гузошта наметавонад", st in (401, 403), (st, r))
    st, r = call("POST", f"/admin/moderation/users/{idC}/restore", tok=tAdm)
    ok("admin бани доимиро бекор кард", st == 200, (st, r))

# ═══ 6. Расм тавассути provider-и қалбакӣ (ихтиёрӣ) ═════════════
VIDEO = {}      # номи файл → байтҳо (бо ffmpeg сохта мешавад)
JPEG_FRAMES = [0]  # чанд кадри JPEG ба classifier омад

PNG = b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x02\x00\x00\x00"


class Stub(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def do_GET(self):
        # /img/<marker>.png — «расм» дар «анбори мо».
        if self.path.startswith("/img/"):
            marker = self.path[5:].split(".")[0].upper().encode()
            body = PNG + marker
            self.send_response(200)
            self.send_header("Content-Type", "image/png")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        if self.path.startswith("/vid/") and self.path[5:] in VIDEO:
            body = VIDEO[self.path[5:]]
            self.send_response(200)
            self.send_header("Content-Type", "video/mp4")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        self.send_response(404); self.end_headers()

    def do_POST(self):
        n = int(self.headers.get("Content-Length") or 0)
        data = self.rfile.read(n)
        if self.path.startswith("/hf"):
            if data[:2] == b"\xff\xd8":
                JPEG_FRAMES[0] += 1
            s = 0.01
            if b"NSFW" in data:
                s = 0.98
            elif b"MAYBE" in data:
                s = 0.6
            out = json.dumps([{"label": "nsfw", "score": s}, {"label": "normal", "score": 1 - s}]).encode()
        elif self.path.startswith("/sb"):
            out = b'{"matches":[{"threatType":"MALWARE"}]}' if b"malware" in data else b"{}"
        else:
            self.send_response(404); self.end_headers(); return
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(out)))
        self.end_headers()
        self.wfile.write(out)


if IMG:
    srv = http.server.ThreadingHTTPServer(("127.0.0.1", STUB_PORT), Stub)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    base = f"http://127.0.0.1:{STUB_PORT}/img"
    I = f"mdi{S}"; tI, idI = user(I, 6)
    st, h = call("GET", "/health", base=IMG)
    prov = ((h.get("ready") or {}).get("moderation") or {}).get("imageProvider") if isinstance(h, dict) else None
    ok("сервери дуюм provider-и расм дорад", prov == "huggingface", h)
    st, r = call("POST", "/posts/", {"caption": "Сурат", "media": [{"url": f"{base}/nsfw.png", "type": "image"}]}, tI, base=IMG)
    ok("расми NSFW → 403 (classifier)", blocked(st, r) and "nudity" in (r.get("categories") or []), (st, r))
    st, r = call("POST", "/posts/", {"caption": "Сурат", "media": [{"url": f"{base}/maybe.png", "type": "image"}]}, tI, base=IMG)
    ok("расми норавшан (0.6) → пинҳон то тасдиқ", st == 201 and r.get("pendingReview") is True, (st, r))
    st, r = call("POST", "/posts/", {"caption": "Сурат", "media": [{"url": f"{base}/clean.png", "type": "image"}]}, tI, base=IMG)
    ok("расми тоза → нашр", st == 201 and not r.get("pendingReview"), (st, r))
    st, r = call("POST", "/posts/", {"caption": "Сурат", "media": [{"url": "http://169.254.169.254/latest/meta-data", "type": "image"}]}, tI, base=IMG)
    ok("суроғаи бегона кушода намешавад → пинҳон (SSRF)", st == 201 and r.get("pendingReview") is True, (st, r))
    st, ch = call("GET", f"/chat/with/{idA}", tok=tI, base=IMG)
    chat_ia = (ch.get("chatId") or ch.get("id") or ch.get("_id")) if isinstance(ch, dict) else None
    # Паёми чат бояд https бошад — расми stub http аст, бинобар ин
    # ин ҷо танҳо Safe Browsing-и қалбакӣ санҷида мешавад.
    st, r = call("POST", f"/chat/{chat_ia}/messages", {"text": "http://malware-test.example/x"}, tI, base=IMG)
    ok("Safe Browsing (stub): линки зараровар → 403", blocked(st, r) and "malicious_link" in (r.get("categories") or []), (st, r))
    # Видео: кадрҳо бо ffmpeg (дар сервер) → classifier.
    try:
        import tempfile
        with tempfile.TemporaryDirectory() as d:
            subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "lavfi", "-i",
                            "testsrc=duration=6:size=160x120:rate=10", "-pix_fmt", "yuv420p",
                            os.path.join(d, "v.mp4")], check=True, timeout=60)
            VIDEO["clean.mp4"] = open(os.path.join(d, "v.mp4"), "rb").read()
    except Exception as e:
        print("ℹ️ ffmpeg нест — санҷиши видео гузаронда шуд:", e)
    if VIDEO:
        JPEG_FRAMES[0] = 0
        st, r = call("POST", "/reels/", {"videoUrl": f"http://127.0.0.1:{STUB_PORT}/vid/clean.mp4",
                                         "caption": "Кӯҳҳо"}, tI, base=IMG)
        ok("Reel: кадрҳои видео (1с/25/50/75%) ба classifier рафтанд",
           st == 201 and not r.get("pendingReview") and JPEG_FRAMES[0] == 4, (st, JPEG_FRAMES[0], r))
    srv.shutdown()
else:
    print("ℹ️ IMG_BASE нест — санҷиши расм бо provider гузаронда шуд (unit-тестҳо онро мепӯшонанд)")

# ═══ натиҷа ═════════════════════════════════════════════════════
passed = sum(1 for r in res if r[0])
for good, name, det in res:
    print(("✅ " if good else "❌ ") + name + ("" if good else f"  → {det}"))
print(f"\n{passed}/{len(res)}")
sys.exit(0 if passed == len(res) else 1)
