#!/usr/bin/env python3
"""Як ҳисоб бо TajikShop (SSO).

 TajikShop-и ҚАЛБАКӢ дар худи ин санҷиш кушода мешавад (127.0.0.1:8095,
 /api/v1/sso/exchange, /auth/refresh, /sso/code, калиди шарик). Сервери
 санҷидашаванда бояд бо ин env оғоз шуда бошад:

   TAJIKSHOP_API=http://127.0.0.1:8095/api/v1   SSO_PARTNER_KEY=ci-test-key

 SSO_BASE — ҳамон сервер; BASE — сервери асосӣ БЕ калид (503 санҷида
 мешавад). Барои қисми «ҳисоби баста» DATABASE_URL + psql лозим.

 Санҷида мешавад: ҳисоби нав + «номи корбар», вуруди такрорӣ, коди
 якдафъаина, почтаи band → link_required (худкор пайваст НАМЕШАВАД) →
 тасдиқ баъди вуруд, пайванд ҳангоми ворид будан, linked_other,
 гузариш ба TajikShop (refresh + ротатсия + /sso/code), ҷудо кардан,
 ҳисоби баста, калиди нодуруст, нест кардани ҳисоб. Token-ҳои TajikShop
 ҳеҷ гоҳ ба барнома намерасанд.
"""
import http.server, json, os, subprocess, sys, threading, time, urllib.request, urllib.error

SB = os.environ.get("SSO_BASE", "http://127.0.0.1:8098")
B = os.environ.get("BASE", "http://127.0.0.1:8099")
S = os.environ.get("SUFFIX", "sso")
DB = os.environ.get("DATABASE_URL", "")
PORT = int(os.environ.get("FAKE_TS_PORT", "8095"))
KEY = "ci-test-key"
PW = "Test12345!"
res = []


def call(m, p, body=None, tok=None, base=None):
    req = urllib.request.Request((base or SB) + p, data=json.dumps(body).encode() if body is not None else None,
                                 method=m)
    req.add_header("Content-Type", "application/json")
    if tok:
        req.add_header("Authorization", "Bearer " + tok)
    try:
        with urllib.request.urlopen(req, timeout=40) as r:
            raw = r.read().decode()
            return r.status, (json.loads(raw) if raw else {})
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
        try:
            return e.code, json.loads(raw)
        except Exception:
            return e.code, raw


def ok(n, c, d=""):
    res.append((bool(c), n, str(d)[:240]))


# ═══ TajikShop-и қалбакӣ ══════════════════════════════════════════
class TS:
    lock = threading.Lock()
    key = KEY
    known_app = "raonson"
    rotate = False
    codes = {}      # код → user
    refresh = {}    # refresh → user id
    access = {}     # access → user id
    issued = []     # кодҳои /sso/code
    exchanges = 0
    n = 0

    @classmethod
    def code(cls, uid, name, email=""):
        with cls.lock:
            cls.n += 1
            c = ("S%s%s" % (S, "x" * 64))[:20] + "%023d" % cls.n
            c = "".join(ch if ch.isalnum() else "_" for ch in c)
            cls.codes[c] = {"id": uid, "name": name, "email": email, "role": "user",
                            "avatar_url": "", "is_seller": False, "is_verified": False}
            return c


class Fake(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def _send(self, st, body):
        out = json.dumps(body).encode()
        self.send_response(st)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(out)))
        self.end_headers()
        self.wfile.write(out)

    def do_POST(self):
        n = int(self.headers.get("Content-Length") or 0)
        try:
            data = json.loads(self.rfile.read(n) or b"{}")
        except Exception:
            data = {}
        fail = lambda st, msg: self._send(st, {"success": False, "error": msg})
        okd = lambda d, st=200: self._send(st, {"success": True, "data": d})
        with TS.lock:
            if self.path == "/api/v1/sso/exchange":
                TS.exchanges += 1
                if data.get("app") != TS.known_app:
                    return fail(400, "Барномаи номаълум")
                if self.headers.get("X-Partner-Key") != TS.key:
                    return fail(401, "Калиди шарик нодуруст")
                u = TS.codes.pop(data.get("code", ""), None)
                if not u:
                    return fail(401, "Код нодуруст ё мӯҳлаташ гузашт")
                TS.n += 1
                a, r = "tsacc-%d" % TS.n, "tsref-%d" % TS.n
                TS.access[a] = u["id"]
                TS.refresh[r] = u["id"]
                return okd({"access_token": a, "refresh_token": r, "user": u})
            if self.path == "/api/v1/auth/refresh":
                uid = TS.refresh.get(data.get("refresh_token", ""))
                if not uid:
                    return fail(401, "token mismatch")
                TS.n += 1
                a = "tsacc-%d" % TS.n
                TS.access[a] = uid
                out = {"access_token": a}
                if TS.rotate:
                    TS.refresh.pop(data["refresh_token"], None)
                    nr = "tsref-%d" % TS.n
                    TS.refresh[nr] = uid
                    out["refresh_token"] = nr
                return okd(out)
            if self.path == "/api/v1/sso/code":
                tok = (self.headers.get("Authorization") or "").replace("Bearer ", "")
                if tok not in TS.access:
                    return fail(401, "unauthorized")
                if data.get("target_app") != "tajikshop":
                    return fail(400, "Барномаи номаълум")
                TS.n += 1
                c = "T%042d" % TS.n
                TS.issued.append(c)
                return okd({"code": c, "expires_in": 120, "deep_link": "tajikshop://sso?code=" + c,
                            "fallback": "https://play.google.com/store/apps/details?id=com.tajikshop.app"}, 201)
        fail(404, "not found")


srv = http.server.ThreadingHTTPServer(("127.0.0.1", PORT), Fake)
threading.Thread(target=srv.serve_forever, daemon=True).start()


def no_ts_tokens(name, body):
    s = json.dumps(body)
    ok(name + ": token-ҳои TajikShop ба барнома намераванд", "tsref-" not in s and "tsacc-" not in s, s)


def raonson_user(u, email=None):
    call("POST", "/auth/register", {"username": u, "email": email or f"{u}@example.com",
                                    "password": PW, "fullName": "Full " + u})
    st, r = call("POST", "/auth/login", {"email": u, "password": PW})
    return r.get("accessToken"), (r.get("user") or {}).get("id")


def sso(code, tok=None, link=None, base=None):
    body = {"code": code}
    if link is not None:
        body["link"] = link
    return call("POST", "/auth/sso/tajikshop", body, tok=tok, base=base)


# ═══ 0. Танзим ва формати код ═════════════════════════════════════
if B.rstrip("/") != SB.rstrip("/"):
    st, r = sso(TS.code(f"ts0{S}", "No Key"), base=B)
    ok("сервер бе SSO_PARTNER_KEY → 503 «Пайвасти TajikShop танзим нашудааст»",
       st == 503 and r.get("message") == "Пайвасти TajikShop танзим нашудааст", (st, r))

before = TS.exchanges
for bad in ["", "short", "a" * 65, "bad code with spaces!", "abc/def+ghi=jklmnopq"]:
    st, r = sso(bad)
    ok(f"коди нодуруст «{bad[:12]}» → 400", st == 400 and r.get("code") == "invalid_code", (st, r))
ok("коди нодуруст ба TajikShop намеравад", TS.exchanges == before, TS.exchanges - before)
st, r = sso("Q" * 43)
ok("коди номаълум → 401 «Код нодуруст ё мӯҳлаташ гузашт»",
   st == 401 and r.get("message") == "Код нодуруст ё мӯҳлаташ гузашт", (st, r))

# ═══ 1. Ҳисоби нав ════════════════════════════════════════════════
TSA = f"tsa{S}"
codeA = TS.code(TSA, "Эҳсон Тест", f"tsa{S}@shop.example")
st, r = sso(codeA)
userA = r.get("user") or {}
tokA = r.get("accessToken")
ok("ҳисоби нав: 200, status=created, needsProfileSetup",
   st == 200 and r.get("status") == "created" and r.get("needsProfileSetup") is True and tokA, (st, r))
ok("номи корбар аз ном (транслит)", userA.get("username", "").startswith("ehson_test"), userA)
ok("refreshToken-и Raonson ҳаст", bool(r.get("refreshToken")), r.keys() if isinstance(r, dict) else r)
no_ts_tokens("ҳисоби нав", r)
st, r2 = sso(codeA)
ok("ҳамон код дубора → 401", st == 401 and r2.get("code") == "invalid_code", (st, r2))

st, me = call("GET", "/profile/me", tok=tokA)
ok("token-и SSO бо middleware кор мекунад (/profile/me)", st == 200, (st, str(me)[:120]))
newName = f"tsname{S}"[:30]
st, r = call("PUT", "/profile/username", {"username": newName}, tok=tokA)
ok("«Номи корбарро интихоб кунед» — PUT /profile/username", st == 200 and r.get("username") == newName, (st, r))

st, s = call("GET", "/sso/tajikshop/status", tok=tokA)
tsinfo = (s.get("tajikshop") or {}) if isinstance(s, dict) else {}
ok("status: linked, configured, бе рамз", st == 200 and s.get("linked") is True and s.get("configured") is True
   and s.get("hasPassword") is False, (st, s))
ok("status: почта пӯшида", "***" in tsinfo.get("email", "") and f"tsa{S}@" not in tsinfo.get("email", ""), tsinfo)
ok("status: ном пӯшида («Эҳсон Т.»)", tsinfo.get("name") == "Эҳсон Т.", tsinfo)
no_ts_tokens("status", s)

st, r = call("DELETE", "/sso/tajikshop/link", tok=tokA)
ok("ҷудо кардан бе рамз → 409 password_required", st == 409 and r.get("code") == "password_required", (st, r))

# ═══ 2. Вуруди такрорӣ ════════════════════════════════════════════
st, r = sso(TS.code(TSA, "Эҳсон Тест", f"tsa{S}@shop.example"))
ok("дафъаи дуюм: ҳамон корбар (logged_in)", st == 200 and r.get("status") == "logged_in"
   and (r.get("user") or {}).get("id") == userA.get("id") and r.get("needsProfileSetup") is False, (st, r))
no_ts_tokens("вуруди такрорӣ", r)

# ═══ 3. Гузариш ба TajikShop (handoff) ═════════════════════════════
TS.rotate = True
st, h = call("POST", "/sso/tajikshop/handoff", tok=tokA)
dl = h.get("deep_link", "") if isinstance(h, dict) else ""
ok("handoff: tajikshop://sso?code=<коди TajikShop>", st == 200 and h.get("handoff") is True
   and TS.issued and dl == "tajikshop://sso?code=" + TS.issued[-1], (st, h))
ok("handoff: fallback — Play Store", str(h.get("fallback", "")).startswith("https://play.google.com/"), h)
no_ts_tokens("handoff", h)
st, h2 = call("POST", "/sso/tajikshop/handoff", tok=tokA)
ok("handoff-и дуюм бо refresh-и ротатсияшуда (сабт шуд)", st == 200 and h2.get("handoff") is True
   and h2.get("deep_link") == "tajikshop://sso?code=" + TS.issued[-1], (st, h2))
TS.rotate = False

tokP, idP = raonson_user(f"tsp{S}")
st, h = call("POST", "/sso/tajikshop/handoff", tok=tokP)
ok("handoff бе пайванд: linked=false, tajikshop://", st == 200 and h.get("linked") is False
   and h.get("deep_link") == "tajikshop://" and h.get("fallback"), (st, h))
st, h = call("POST", "/sso/tajikshop/handoff")
ok("handoff бе ворид → 401", st == 401, st)

# Сессияи TajikShop бекор → TajikShop танҳо кушода мешавад.
with TS.lock:
    TS.refresh.clear()
st, h = call("POST", "/sso/tajikshop/handoff", tok=tokA)
ok("сессияи TajikShop гузашт → reason=session_expired, tajikshop://", st == 200 and h.get("handoff") is False
   and h.get("reason") == "session_expired" and h.get("deep_link") == "tajikshop://", (st, h))

# ═══ 4. Почтаи банд → link_required ═══════════════════════════════
V = f"tsv{S}"
vEmail = f"{V}@example.com"
tokV, idV = raonson_user(V, vEmail)
TSV = f"tsv{S}"
st, r = sso(TS.code(TSV, "Бегона", vEmail.upper()))
ok("почтаи ҳисоби мавҷуда → 409 link_required", st == 409 and r.get("code") == "link_required", (st, r))
ok("link_required: token-и Raonson дода НАШУД", "accessToken" not in r, r)
ok("link_required: почта пӯшида", "***" in r.get("email", "") and vEmail not in json.dumps(r), r.get("email"))
pending = r.get("pendingToken", "")
ok("link_required: pendingToken (43) ва expiresIn=600", len(pending) == 43 and r.get("expiresIn") == 600, r)
no_ts_tokens("link_required", r)

st, r = call("POST", "/auth/sso/tajikshop/link", {"pendingToken": pending})
ok("тасдиқ бе ворид → 401", st == 401, (st, r))
st, r = call("POST", "/auth/sso/tajikshop/link", {"pendingToken": pending}, tok=tokV)
ok("баъди вуруд бо рамзи Raonson — пайваст", st == 200 and r.get("linked") is True, (st, r))
st, r = call("POST", "/auth/sso/tajikshop/link", {"pendingToken": pending}, tok=tokV)
ok("pendingToken якдафъаина", st == 401 and r.get("code") == "link_expired", (st, r))
st, r = sso(TS.code(TSV, "Бегона", vEmail))
ok("акнун TajikShop → ҳамон ҳисоби Raonson", st == 200 and (r.get("user") or {}).get("id") == idV, (st, r))

# ═══ 5. Пайванд ҳангоми ворид будан ═══════════════════════════════
TSL = f"tsl{S}"
st, r = sso(TS.code(TSL, "Link Me"), tok=tokP)
ok("ворид + бе интихоб → confirm_link (бе token-и нав)", st == 200 and r.get("status") == "confirm_link"
   and len(r.get("pendingToken", "")) == 43 and "accessToken" not in r, (st, r))
st, r = call("POST", "/auth/sso/tajikshop/link", {"pendingToken": r.get("pendingToken")}, tok=tokP)
ok("тасдиқи confirm_link → пайваст", st == 200 and r.get("linked") is True, (st, r))
st, s = call("GET", "/sso/tajikshop/status", tok=tokP)
ok("status баъди пайванд: linked, рамз ҳаст", s.get("linked") is True and s.get("hasPassword") is True, s)

tokQ, idQ = raonson_user(f"tsq{S}")
st, r = sso(TS.code(TSL, "Link Me"), tok=tokQ, link=True)
ok("TajikShop-и пайвасти дигар → 409 linked_other", st == 409 and r.get("code") == "linked_other", (st, r))
TSQ = f"tsq{S}"
st, r = sso(TS.code(TSQ, "Q"), tok=tokQ, link=True)
ok("ворид + link:true → фавран пайваст", st == 200 and r.get("status") == "linked", (st, r))
st, r = call("POST", "/auth/sso/tajikshop/link", {"code": TS.code(f"tsq2{S}", "Q2")}, tok=tokQ)
ok("TajikShop-и дуюм ба ҳамон ҳисоб → 409 already_linked", st == 409 and r.get("code") == "already_linked", (st, r))

# ═══ 6. Ҷудо кардан ═══════════════════════════════════════════════
st, r = call("DELETE", "/sso/tajikshop/link", tok=tokQ)
ok("ҷудо кардан (рамз ҳаст) → linked=false", st == 200 and r.get("linked") is False, (st, r))
st, s = call("GET", "/sso/tajikshop/status", tok=tokQ)
ok("status баъди ҷудо: linked=false", s.get("linked") is False and s.get("tajikshop") is None, s)
st, h = call("POST", "/sso/tajikshop/handoff", tok=tokQ)
ok("handoff баъди ҷудо: linked=false", h.get("linked") is False, h)

# Ҳисоби SSO рамз мегузорад ва баъд ҷудо мешавад.
st, r = call("POST", "/auth/change-password", {"oldPassword": "", "newPassword": "NewPass123!"}, tok=tokA)
ok("ҳисоби SSO рамзи аввалро бе рамзи кӯҳна мегузорад", st == 200 and r.get("accessToken"), (st, r))
tokA = r.get("accessToken") or tokA
st, r = call("POST", "/auth/change-password", {"oldPassword": "", "newPassword": "Other123!"}, tok=tokA)
ok("баъд рамзи кӯҳна ҳатмӣ аст", st == 401, (st, r))
st, r = call("DELETE", "/sso/tajikshop/link", tok=tokA)
ok("баъди гузоштани рамз ҷудо мешавад", st == 200 and r.get("linked") is False, (st, r))
st, r = call("POST", "/auth/login", {"email": newName, "password": "NewPass123!"})
ok("бо рамзи нав ворид мешавад", st == 200 and r.get("accessToken"), (st, r))

# ═══ 7. Калиди нодуруст / барномаи номаълум ═══════════════════════
TS.key = "rotated-on-tajikshop"
st, r = sso(TS.code(f"tsk{S}", "K"))
ok("калиди шарик нодуруст → 503 (бе ошкор кардани калид)", st == 503
   and r.get("message") == "Пайвасти TajikShop танзим нашудааст" and KEY not in json.dumps(r), (st, r))
TS.key = KEY
TS.known_app = "other"
st, r = sso(TS.code(f"tsk{S}", "K"))
ok("TajikShop Raonson-ро намешиносад → 503", st == 503 and r.get("code") == "sso_not_configured", (st, r))
TS.known_app = "raonson"

# ═══ 8. Ҳисоби баста ═══════════════════════════════════════════════
TSB = f"tsb{S}"
st, r = sso(TS.code(TSB, "Ban Me"))
idB = (r.get("user") or {}).get("id")
ok("ҳисоби барои бастан сохта шуд", st == 200 and idB, (st, r))
banned = False
if DB and idB:
    try:
        subprocess.run(["psql", DB, "-v", "ON_ERROR_STOP=1", "-qc",
                        f"UPDATE users SET banned=TRUE WHERE id='{idB}'"],
                       check=True, capture_output=True, timeout=30)
        banned = True
    except Exception as e:
        print("⚠️ psql дастрас нест:", e)
if banned:
    time.sleep(0.2)
    st, r = sso(TS.code(TSB, "Ban Me"))
    ok("ҳисоби баста бо TajikShop ворид намешавад → 403", st == 403 and "accessToken" not in r, (st, r))
else:
    ok("ҳисоби баста: DATABASE_URL + psql лозим", False, "DATABASE_URL нест")

# ═══ 9. Нест кардани ҳисоб пайвандро пок мекунад ══════════════════
TSD = f"tsd{S}"
st, r = sso(TS.code(TSD, "Delete Me"))
tokD, idD = r.get("accessToken"), (r.get("user") or {}).get("id")
st, r = call("DELETE", "/users/", tok=tokD)
ok("ҳисоби SSO нест шуд", st == 200, (st, r))
st, r = sso(TS.code(TSD, "Delete Me"))
ok("баъди нест кардан ҳамон TajikShop ҳисоби НАВ месозад (пайванд пок шуд)",
   st == 200 and r.get("status") == "created" and (r.get("user") or {}).get("id") not in (None, idD), (st, r))

srv.shutdown()
passed = sum(1 for r in res if r[0])
for good, n, d in res:
    print(("✅" if good else "❌"), n, "" if good else "→ " + d)
print(f"\n{passed}/{len(res)}")
sys.exit(0 if passed == len(res) else 1)
