#!/usr/bin/env python3
"""Чор функсия: «Кӯмаки фаврӣ», пости овозӣ, «Тарҷума», профили тиҷоратӣ.

 Кӯмаки фаврӣ: эътимод (ҳисоби нав → 403), донорҳо (махфӣ), дархости хун
   танҳо донорҳои МУВОФИҚИ ҲАМОН шаҳрро огоҳ мекунад (на шаҳри дигар, на
   басташуда), муаллиф танҳо шумораро мебинад; ҳадди донор (cooldown),
   ҳадди рӯзона, рақами телефон дар матн манъ, модератсия, ҷавоб → огоҳинома
   ба муаллиф, шикоят → пинҳон → admin бармегардонад, «Ҳал шуд», мӯҳлат.
 Овоз: пости audio бо давомнокӣ ва мавҷ, ҳадди 60 сония, тавсиф аз
   модератсия, басташуда намебинад.
 Тарҷума: бе провайдер — парчам false ва 503; бо провайдери қалбакӣ
   (AI_BASE + stub дар AI_STUB_PORT) — тарҷума, кэш, ҳадди дарозӣ ва
   ҳадди соатии корбар, роҳи кӯҳнаи /ai/translate.
 Тиҷоратӣ: категория, соатҳо, «Кушода ҳозир», профил, боздид ва пахш
   (як бор дар рӯз), омор танҳо барои соҳиб, басташуда, ҷустуҷӯ, ҳисоби
   пӯшида, модератсияи суроға, бозгашт ба ҳисоби шахсӣ.

 ⚠️ Танҳо сервери МАҲАЛЛӢ/CI. Барои эътимод ва мӯҳлат DATABASE_URL + psql лозим.
   BASE=http://127.0.0.1:8099 AI_BASE=http://127.0.0.1:8094 AI_STUB_PORT=8093 \\
   DATABASE_URL=... python3 backend/testing/api_features_b.py
"""
import hashlib, json, os, subprocess, sys, threading, time, urllib.request, urllib.error
from http.server import BaseHTTPRequestHandler, HTTPServer

B = os.environ.get("BASE", "http://127.0.0.1:8099")
AI = os.environ.get("AI_BASE", "")
STUB_PORT = int(os.environ.get("AI_STUB_PORT", "8093"))
S = os.environ.get("SUFFIX", "xb")
DB = os.environ.get("DATABASE_URL", "")
PW = "Test12345!"
res = []


def _once(m, p, body=None, tok=None, base=None):
    req = urllib.request.Request((base or B) + p,
                                 data=json.dumps(body).encode() if body is not None else None, method=m)
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


def call(m, p, body=None, tok=None, base=None, retry429=True):
    for a in range(4):
        st, r = _once(m, p, body, tok, base)
        if st != 429 or not retry429:
            return st, r
        # Ҳадди умумии сервер (на ҳадди худи функсия) — интизор.
        if isinstance(r, dict) and str(r.get("code", "")).startswith(("help_", "translate_")):
            return st, r
        time.sleep(4 * (a + 1))
    return st, r


def ok(n, c, d=""):
    res.append((bool(c), n, str(d)[:240]))


N = int(hashlib.sha1(("featb-" + S).encode()).hexdigest(), 16) % 10**6


def user(u, k, base=None):
    call("POST", "/auth/register", {"username": u, "email": f"{u}@example.com", "password": PW,
                                    "fullName": "Full " + u, "phone": f"+99298{N:06d}{k}"}, base=base)
    st, r = call("POST", "/auth/login", {"email": u, "password": PW}, base=base)
    usr = (r.get("user") or {}) if isinstance(r, dict) else {}
    return (r.get("accessToken") if isinstance(r, dict) else None), (usr.get("id") or usr.get("_id"))


def psql(sql):
    if not DB:
        return False
    try:
        subprocess.run(["psql", DB, "-v", "ON_ERROR_STOP=1", "-qc", sql], check=True,
                       capture_output=True, timeout=30)
        return True
    except Exception as e:
        print("⚠️ psql:", e)
        return False


def notifs(tok):
    st, r = call("GET", "/notifications?limit=100", tok=tok)
    return r.get("notifications") or [] if isinstance(r, dict) else []


def has_notif(tok, ntype, target=None, frm=None, wait=6.0):
    end = time.time() + wait
    while True:
        for n in notifs(tok):
            if n.get("type") != ntype:
                continue
            if target is not None and n.get("targetId") != target:
                continue
            if frm is not None and (n.get("fromUser") or {}).get("_id") != frm:
                continue
            return True
        if time.time() > end:
            return False
        time.sleep(0.5)


def ids(lst):
    return [x.get("_id") for x in (lst or []) if isinstance(x, dict)]


DUSHANBE, KHUJAND = "tj-dushanbe", "tj-khujand"

tA, A = user(f"xba{S}", 1)    # муаллифи дархостҳо
tB, Bb = user(f"xbb{S}", 2)   # донор O- Душанбе
tC, C = user(f"xbc{S}", 3)    # донор A+ Душанбе
tD, D = user(f"xbd{S}", 4)    # донор A+ Хуҷанд (шаҳри дигар)
tE, E = user(f"xbe{S}", 5)    # донор A+ Душанбе, вале A-ро бастааст
tG, G = user(f"xbg{S}", 6)    # модератсия (огоҳӣ ба ҳисоби ӯ)
tH, H = user(f"xbh{S}", 7)    # тиҷорат
ADM = f"xbadm{S}"
tAdm, Adm = user(ADM, 8)
ok("корбарон сохта шуданд", all([tA, tB, tC, tD, tE, tG, tH, tAdm]), (A, Bb, C, D, E, G, H, Adm))
if not all([tA, tB, tC, tD, tE, tG, tH, tAdm]):
    print("!! вуруд нашуд")
    sys.exit(1)
UNAME = {A: f"xba{S}", H: f"xbh{S}"}

# Санҷиш аз нав: қаблан сохташударо пок мекунем (SUFFIX-и якхела).
psql(f"DELETE FROM help_requests WHERE user_id IN ('{A}','{G}')")
psql(f"DELETE FROM help_donors WHERE user_id IN ('{Bb}','{C}','{D}','{E}')")
psql(f"UPDATE users SET phone_verified_at=NULL, created_at=NOW() WHERE id IN ('{A}','{G}')")
psql(f"DELETE FROM business_events WHERE business_id='{H}'")

# ═══ 1. «Кӯмаки фаврӣ» ═════════════════════════════════════════════
blood = {"kind": "blood", "title": "Ба бемор хуни A+ лозим аст", "body": "Ҷарроҳӣ пагоҳ субҳ.",
         "bloodGroup": "A+", "units": 2, "hospital": "Маркази тиббии Шифобахш", "cityId": DUSHANBE}
st, r = call("POST", "/help", blood, tA)
ok("ҳисоби нав бе тасдиқ нашр карда наметавонад (403 help_trust_required)",
   st == 403 and isinstance(r, dict) and r.get("code") == "help_trust_required", (st, r))
trusted = psql(f"UPDATE users SET phone_verified_at=NOW() WHERE id IN ('{A}','{G}')")
ok("телефони тасдиқшуда (psql)", trusted)

# Донорҳо.
st, r = call("PUT", "/help/donor/me", {"enabled": True, "bloodGroup": "Z+", "cityId": DUSHANBE}, tB)
ok("гурӯҳи хуни нодуруст → 400", st == 400 and r.get("code") == "help_bad_donor", (st, r))
st, r = call("PUT", "/help/donor/me", {"enabled": True, "bloodGroup": "A+", "cityId": "tj"}, tB)
ok("кишвар ба ҷои шаҳр → 400", st == 400, (st, r))
for tok, g, city in [(tB, "o-", DUSHANBE), (tC, "A+", DUSHANBE), (tD, "A+", KHUJAND), (tE, "A+", DUSHANBE)]:
    st, r = call("PUT", "/help/donor/me", {"enabled": True, "bloodGroup": g, "cityId": city}, tok)
    ok(f"донор {g} сабт шуд", st == 200 and r.get("enabled") is True, (st, r))
st, r = call("GET", "/help/donor/me", tok=tB)
ok("донор маълумоти ХУДРО мебинад (O-, Душанбе)",
   r.get("bloodGroup") == "O-" and (r.get("city") or {}).get("id") == DUSHANBE, r)
call("POST", f"/users/{A}/block", {}, tE)

st, r = call("POST", "/help", dict(blood, body="Занг занед: +992 93 555 12 34"), tA)
ok("рақами телефон дар матн → 400 help_no_contacts", st == 400 and r.get("code") == "help_no_contacts", (st, r))
st, r = call("POST", "/help", dict(blood, cityId="tj-sughd"), tA)
ok("вилоят ба ҷои шаҳр → 400", st == 400 and r.get("code") == "help_bad_city", (st, r))

st, h1 = call("POST", "/help", blood, tA)
H1 = (h1 or {}).get("_id") if isinstance(h1, dict) else None
ok("дархости хун сохта шуд", st == 201 and H1, (st, h1))
ok("танҳо донорҳои мувофиқи Душанбе огоҳ шуданд (O- ва A+, на Хуҷанд, на басташуда)",
   (h1 or {}).get("notifiedCount") == 2, h1)
ok("гурӯҳи хун муқаррарӣ, шаҳр бо ном", h1.get("bloodGroup") == "A+" and (h1.get("city") or {}).get("name"), h1)
ok("донори O- огоҳинома гирифт", has_notif(tB, "help_blood", H1, A), H1)
ok("донори A+ огоҳинома гирифт", has_notif(tC, "help_blood", H1), H1)
ok("донори шаҳри дигар огоҳинома НАГИРИФТ", not has_notif(tD, "help_blood", wait=1), "")
ok("донори басташуда огоҳинома НАГИРИФТ", not has_notif(tE, "help_blood", wait=1), "")
st, v = call("GET", f"/help/{H1}", tok=tB)
ok("бегона шумораи огоҳшудагонро намебинад", st == 200 and "notifiedCount" not in v, v)
ok("дар ҷавоб ҳеҷ номи донор нест", Bb not in json.dumps(h1) and C not in json.dumps(h1), "")

st, h2 = call("POST", "/help", dict(blood, title="Боз хуни A+ лозим аст"), tA)
H2 = (h2 or {}).get("_id")
ok("дархости дуюм: донорҳо дар 24 соат дубора огоҳ намешаванд (cooldown)",
   st == 201 and h2.get("notifiedCount") == 0, (st, h2))
st, h3 = call("POST", "/help", {"kind": "lost_pet", "title": "Гурбаи сафед гум шуд", "cityId": DUSHANBE,
                                "body": "Дар назди бозори Шоҳмансур.", "expiresInHours": 9999}, tA)
H3 = (h3 or {}).get("_id")
ok("эълони гумшуда сохта шуд", st == 201 and H3, (st, h3))
ok("мӯҳлат то 30 рӯз маҳдуд", h3.get("expiresAt", "") < time.strftime("%Y-%m-%dT", time.gmtime(time.time() + 31 * 86400)), h3)
st, r = call("POST", "/help", {"kind": "urgent", "title": "Кӯмак барои кӯчонидан", "cityId": DUSHANBE}, tA)
ok("ҳадди рӯзона: дархости 4-ум → 429 help_daily_cap", st == 429 and r.get("code") == "help_daily_cap", (st, r))

st, r = call("GET", f"/help?city={DUSHANBE}", tok=tB)
lst = ids(r.get("items"))
ok("рӯйхати шаҳр дархостҳоро дорад", H1 in lst and H3 in lst, lst)
st, r = call("GET", f"/help?city={KHUJAND}", tok=tB)
ok("шаҳри дигар — дархости Душанбе нест", H1 not in ids(r.get("items")), r)
st, r = call("GET", f"/help?city={DUSHANBE}&kind=lost", tok=tB)
ok("филтри «гумшуда»", ids(r.get("items")) == [H3] or (H3 in ids(r.get("items")) and H1 not in ids(r.get("items"))), r)
st, r = call("GET", f"/help?city={DUSHANBE}", tok=tE)
ok("басташуда дархостҳои муаллифро намебинад", H1 not in ids(r.get("items")), r)
st, r = call("GET", f"/help/{H1}", tok=tE)
ok("басташуда: GET → 404", st == 404, (st, r))
st, r = call("GET", "/help?mine=1", tok=tA)
ok("«Дархостҳои ман»", set([H1, H2, H3]) <= set(ids(r.get("items"))), r)

st, r = call("POST", f"/help/{H1}/respond", {}, tB)
ok("донор ҷавоб дод → муаллиф маълум (барои чат)", st == 200 and (r.get("author") or {}).get("_id") == A, (st, r))
ok("муаллиф огоҳинома гирифт (help_response аз донор)", has_notif(tA, "help_response", H1, Bb), "")
call("POST", f"/help/{H1}/respond", {}, tB)
st, v = call("GET", f"/help/{H1}", tok=tA)
ok("ҷавоби такрорӣ ҳисоб намешавад", v.get("responsesCount") == 1, v)
st, r = call("POST", f"/help/{H1}/respond", {}, tA)
ok("ба дархости худ ҷавоб → 400", st == 400, (st, r))
st, r = call("POST", f"/help/{H1}/respond", {}, tE)
ok("басташуда ҷавоб дода наметавонад (404)", st == 404, (st, r))

# Модератсия.
st, r = call("POST", "/help", {"kind": "urgent", "title": "porn videos here free", "cityId": DUSHANBE}, tG)
ok("матни 18+ → 403 content_blocked", st == 403 and r.get("code") == "content_blocked", (st, r))

# Шикоят → пинҳон → admin.
for tok in (tB, tC, tD):
    call("POST", f"/help/{H3}/report", {"reason": "spam"}, tok)
st, r = call("GET", f"/help?city={DUSHANBE}", tok=tB)
ok("3 шикоят → аз тахта пинҳон", H3 not in ids(r.get("items")), ids(r.get("items")))
st, v = call("GET", f"/help/{H3}", tok=tA)
ok("муаллиф мебинад: «интизори санҷиш»", st == 200 and v.get("pendingReview") is True, v)
st, r = call("POST", f"/help/{H3}/report", {}, tA)
ok("ба худ шикоят → 400", st == 400, (st, r))
admin_ok = psql(f"UPDATE users SET role='admin' WHERE username='{ADM}'")
if admin_ok:
    st, q = call("GET", "/admin/moderation/queue?status=pending", tok=tAdm)
    item = next((i for i in (q.get("items") or []) if i.get("surface") == "help" and i.get("targetId") == H3), None)
    ok("дархост дар навбати admin", item is not None, q.get("items", [])[:3])
    if item:
        st, r = call("POST", f"/admin/moderation/queue/{item['id']}/approve", {}, tAdm)
        st, r = call("GET", f"/help?city={DUSHANBE}", tok=tB)
        ok("admin тасдиқ кард → боз дар тахта", H3 in ids(r.get("items")), ids(r.get("items")))
else:
    ok("admin (psql) лозим", False, "")

st, r = call("POST", f"/help/{H1}/resolve", {}, tB)
ok("бегона «Ҳал шуд» гузошта наметавонад", st == 404, (st, r))
st, r = call("POST", f"/help/{H1}/resolve", {}, tA)
ok("муаллиф: «Ҳал шуд»", st == 200, (st, r))
st, r = call("GET", f"/help?city={DUSHANBE}", tok=tB)
ok("ҳалшуда аз тахта мебарояд", H1 not in ids(r.get("items")), r)
st, r = call("POST", f"/help/{H1}/respond", {}, tC)
ok("ба ҳалшуда ҷавоб → 409 help_closed", st == 409 and r.get("code") == "help_closed", (st, r))
if psql(f"UPDATE help_requests SET expires_at=NOW()-INTERVAL '1 minute' WHERE id='{H2}'"):
    st, r = call("GET", f"/help?city={DUSHANBE}", tok=tB)
    ok("мӯҳлат гузашт → аз тахта мебарояд", H2 not in ids(r.get("items")), r)
    st, v = call("GET", f"/help/{H2}", tok=tA)
    ok("ҳолат «expired»", v.get("status") == "expired", v)
st, r = call("DELETE", f"/help/{H3}", tok=tB)
ok("бегона нест карда наметавонад", st == 404, (st, r))
st, r = call("DELETE", f"/help/{H3}", tok=tA)
st, r = call("GET", f"/help/{H3}", tok=tB)
ok("несткарда → 404", st == 404, (st, r))
st, r = call("PUT", "/help/donor/me", {"enabled": False}, tC)
st, r = call("GET", "/help/donor/me", tok=tC)
ok("донор хомӯш кард", r.get("enabled") is False, r)
st, r = call("DELETE", "/help/donor/me", tok=tD)
st, r = call("GET", "/help/donor/me", tok=tD)
ok("маълумоти донор нест шуд", r.get("enabled") is False and not r.get("bloodGroup"), r)

# ═══ 2. «Овоз» ═════════════════════════════════════════════════════
wave = [(i * 7) % 101 for i in range(80)]
voice = {"caption": "Шеъри Рӯдакӣ 🎙", "media": [{"url": "https://example.com/v.m4a", "type": "audio",
                                                 "durationMs": 12000, "waveform": wave,
                                                 "cover": "https://example.com/cover.jpg"}]}
st, p = call("POST", "/posts/", voice, tA)
VP = (p or {}).get("_id") if isinstance(p, dict) else None
ok("пости овозӣ сохта шуд", st == 201 and VP, (st, p))
st, post = call("GET", f"/posts/{VP}", tok=tB)
m0 = ((post or {}).get("media") or [{}])[0] if isinstance(post, dict) else {}
ok("медиа: audio, 12 сония, мавҷи 64 нуқта, муқова",
   m0.get("type") == "audio" and m0.get("durationMs") == 12000 and
   len(str(m0.get("waveform", "")).split(",")) == 64 and m0.get("cover", "").endswith("cover.jpg"), m0)
st, r = call("GET", f"/users/{A}/posts", tok=tB)
plist = r.get("posts") if isinstance(r, dict) else r
ok("дар гриди профил", VP in ids(plist), (st, str(r)[:200]))
st, r = call("POST", "/posts/", {"media": [dict(voice["media"][0], durationMs=90000)]}, tA)
ok("зиёда аз 60 сония → 400 voice_invalid", st == 400 and r.get("code") == "voice_invalid", (st, r))
st, r = call("POST", "/posts/", {"media": [voice["media"][0], {"url": "https://example.com/a.jpg", "type": "image"}]}, tA)
ok("садо + расм якҷоя → 400", st == 400, (st, r))
st, r = call("POST", "/posts/", {"caption": "porn sex video", "media": voice["media"]}, tG)
ok("тавсифи 18+ → 403", st == 403, (st, r))
st, r = call("GET", f"/posts/{VP}", tok=tE)
ok("басташуда пости овозиро намебинад", st in (403, 404), (st, str(r)[:120]))

# ═══ 3. «Тарҷума» ══════════════════════════════════════════════════
st, f = call("GET", "/features")
ok("/features бе калид: translate=false", st == 200 and f.get("translate") is False and f.get("voicePosts"), f)
st, r = call("POST", "/translate", {"text": "Салом", "target": "en"}, tA)
ok("бе провайдер /translate → 503 translate_disabled", st == 503 and r.get("code") == "translate_disabled", (st, r))

if AI:
    hits = []

    class Stub(BaseHTTPRequestHandler):
        def do_POST(self):
            body = json.loads(self.rfile.read(int(self.headers.get("Content-Length", 0))) or b"{}")
            text = body["messages"][-1]["content"]
            hits.append(text)
            text = text.replace("<text>", "").replace("</text>", "")
            out = json.dumps({"choices": [{"message": {"content": "[EN] " + text}}]}).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(out)))
            self.end_headers()
            self.wfile.write(out)

        def log_message(self, *a):
            pass

    srv = HTTPServer(("127.0.0.1", STUB_PORT), Stub)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    tT, T = user(f"xbt{S}", 9, base=AI)
    st, f = call("GET", "/features", base=AI)
    ok("бо провайдер: translate=true", f.get("translate") is True, f)
    txt = f"Салом, дӯстон {S}!"
    st, r = call("POST", "/translate", {"text": txt, "target": "en"}, tT, base=AI)
    ok("тарҷума аз провайдер", st == 200 and r.get("translated") == "[EN] " + txt and r.get("cached") is False, (st, r))
    n0 = len(hits)
    st, r = call("POST", "/translate", {"text": "  " + txt + " ", "target": "en"}, tT, base=AI)
    ok("бори дуюм аз кэш (провайдер даъват нашуд)", r.get("cached") is True and len(hits) == n0, (r, len(hits)))
    st, r = call("POST", "/ai/translate", {"text": txt, "targetLang": "en"}, tT, base=AI)
    ok("роҳи кӯҳнаи /ai/translate ҳамон натиҷа", st == 200 and r.get("translated") == "[EN] " + txt, (st, r))
    st, r = call("POST", "/translate", {"text": "x" * 2001, "target": "en"}, tT, base=AI)
    ok("матни дароз → 413", st == 413, (st, r))
    st, r = call("POST", "/translate", {"text": "салом", "target": "de"}, tT, base=AI)
    ok("забони номаълум → 400", st == 400, (st, r))
    st, r = call("POST", "/translate", {"text": f"Ташаккур {S}", "target": "fa"}, tT, base=AI)
    ok("форсӣ ҳамчун забони мақсад", st == 200 and r.get("target") == "fa", (st, r))
    codes = []
    for i in range(5):
        st, r = call("POST", "/translate", {"text": f"матни нав {i} {S} {time.time()}", "target": "ru"},
                     tT, base=AI, retry429=False)
        codes.append((st, r.get("code") if isinstance(r, dict) else None))
    ok("ҳадди соатии корбар → 429 translate_rate_limited",
       (429, "translate_rate_limited") in codes, codes)
    st, r = call("POST", "/translate", {"text": txt, "target": "en"}, tT, base=AI)
    ok("аз кэш ҳатто пас аз ҳад", st == 200 and r.get("cached") is True, (st, r))
    srv.shutdown()
else:
    print("ℹ️  AI_BASE нест — санҷиши провайдери қалбакӣ партофта шуд")

# ═══ 4. Профили тиҷоратӣ ═══════════════════════════════════════════
all_day = {d: [["00:00", "24:00"]] for d in ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]}
biz = {"category": "cafe", "hours": all_day, "address": "кӯчаи Рӯдакӣ 45", "placeId": DUSHANBE,
       "phone": "+992 93 111 22 33", "whatsapp": "+992931112233", "priceRange": 2}
st, r = call("PUT", "/business/me", dict(biz, category="casino"), tH)
ok("категорияи номаълум → 400", st == 400, (st, r))
st, r = call("PUT", "/business/me", dict(biz, hours={"mon": [["9:00", "18:00"]]}), tH)
ok("вақти нодуруст → 400", st == 400, (st, r))
call("PUT", "/profile/", {"isPrivate": True}, tH)
st, r = call("PUT", "/business/me", biz, tH)
ok("ҳисоби пӯшида тиҷоратӣ намешавад → 409", st == 409 and r.get("code") == "business_private", (st, r))
call("PUT", "/profile/", {"isPrivate": False}, tH)
st, r = call("PUT", "/business/me", dict(biz, address="porn shop xxx"), tH)
ok("суроғаи 18+ → 403", st == 403, (st, r))
st, r = call("PUT", "/business/me", biz, tH)
ok("ба тиҷоратӣ гузашт", st == 200 and r.get("category") == "cafe" and r.get("phone") == "+992931112233", (st, r))
ok("шабонарӯзӣ → «Кушода ҳозир»", r.get("openNow") is True and r.get("hoursKnown") is True, r)
st, prof = call("GET", f"/profile/{UNAME[H]}", tok=tB)
pu = prof.get("user", prof) if isinstance(prof, dict) else {}
ok("профил: isBusiness ва категория", pu.get("isBusiness") is True and pu.get("businessCategory") == "cafe", str(prof)[:200])
st, v = call("GET", f"/business/{H}?lang=ru", tok=tB)
ok("сарлавҳаи тиҷорат барои бинанда (ru)", st == 200 and v.get("categoryLabel") == "Кафе" and v.get("isMine") is False, v)
call("GET", f"/business/{H}", tok=tB)              # такрор — ҳамон рӯз
call("GET", f"/business/{H}", tok=tC)
call("GET", f"/business/{H}", tok=tH)              # соҳиб — ҳисоб намешавад
call("POST", f"/business/{H}/tap", {"action": "call"}, tB)
call("POST", f"/business/{H}/tap", {"action": "call"}, tB)
call("POST", f"/business/{H}/tap", {"action": "whatsapp"}, tC)
st, r = call("POST", f"/business/{H}/tap", {"action": "hack"}, tB)
ok("амали номаълум → 400", st == 400, (st, r))
st, ins = call("GET", "/business/me/insights", tok=tH)
ok("омор: 2 боздид (як одам — як бор, соҳиб ҳисоб нест)",
   ins.get("visits") == 2 and ins.get("uniqueVisitors") == 2, ins)
ok("омор: занг 1, WhatsApp 1", (ins.get("taps") or {}).get("call") == 1 and
   (ins.get("taps") or {}).get("whatsapp") == 1 and len(ins.get("daily") or []) == 7, ins)
st, r = call("GET", "/business/me/insights", tok=tB)
ok("омори бегона — холӣ (танҳо маълумоти худ)", r.get("visits") == 0, r)
st, r = call("GET", f"/business/search?category=cafe&city={DUSHANBE}", tok=tB)
ok("ҷустуҷӯ аз рӯи категория ва шаҳр", H in [i.get("userId") for i in r.get("items") or []], r)
st, r = call("GET", "/business/search?category=barber", tok=tB)
ok("категорияи дигар — нест", H not in [i.get("userId") for i in r.get("items") or []], r)
call("POST", f"/users/{E}/block", {}, tH)
st, r = call("GET", f"/business/{H}", tok=tE)
ok("басташуда профили тиҷоратиро намебинад", st == 404, (st, r))
st, r = call("POST", f"/business/{H}/tap", {"action": "call"}, tE)
ok("басташуда пахш сабт карда наметавонад", st == 404, (st, r))
st, r = call("GET", "/business/search?category=cafe", tok=tE)
ok("басташуда дар ҷустуҷӯ намеёбад", H not in [i.get("userId") for i in r.get("items") or []], r)
closed = {"mon": [], "tue": [], "wed": [], "thu": [], "fri": [], "sat": [], "sun": [["10:00", "10:01"]]}
st, r = call("PUT", "/business/me", dict(biz, hours=closed), tH)
ok("соатҳои кам → «Пӯшида», бо вақти кушодан", r.get("openNow") is False or r.get("closesAt") == "10:01", r)
st, r = call("PUT", "/business/me", dict(biz, hours={}), tH)
ok("бе соатҳо → hoursKnown=false", r.get("hoursKnown") is False, r)
st, r = call("GET", f"/shop?seller={H}", tok=tB)
ok("«Маҳсулот»-и фурӯшанда (TajikShop) — филтри seller", st == 200, (st, str(r)[:120]))
st, r = call("DELETE", "/business/me", tok=tH)
st, r = call("GET", f"/business/{H}", tok=tB)
ok("бозгашт ба шахсӣ → профили тиҷоратӣ нест", st == 404, (st, r))
st, prof = call("GET", f"/profile/{UNAME[H]}", tok=tB)
pu = prof.get("user", prof) if isinstance(prof, dict) else {}
ok("профил: isBusiness=false", pu.get("isBusiness") is False, str(prof)[:160])

# ═══ Натиҷа ═══════════════════════════════════════════════════════
bad = [r for r in res if not r[0]]
for good, name, d in res:
    print(("✅ " if good else "❌ ") + name + ("" if good else "  → " + d))
print(f"\n{len(res) - len(bad)}/{len(res)} гузашт")
sys.exit(1 if bad else 0)
