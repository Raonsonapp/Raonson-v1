#!/usr/bin/env python3
"""Барқарорсозии ҳисоб («Рамзро фаромӯш кардед?»).

 ёфтан (username / почта / телефон дар шаклҳои гуногун) → «Ин шумоед?» →
 рамз (60 с фосила) → 5 кӯшиши нодуруст қуфл → тасдиқ → token-и
 якдафъаина → рамзи нав → сессияҳои кӯҳна 401 → token-ҳои нав кор
 мекунанд → token дубора кор намекунад. «Кӯмак лозим» → admin тасдиқ →
 рамз ба почтаи тамос кор мекунад. Роҳҳои кӯҳна ҳам кор мекунанд.

 ⚠️ Танҳо сервери МАҲАЛЛӢ/CI бо OTP_ECHO=1 ва GIN_MODE=debug (рамз дар
 ҷавоб). Барои қисми admin DATABASE_URL ва psql лозим аст (корбари
 санҷиширо admin мекунад).
"""
import hashlib, json, os, subprocess, sys, time, urllib.request, urllib.error

B = os.environ.get("BASE", "http://127.0.0.1:8099")
S = os.environ.get("SUFFIX", "rc")
DB = os.environ.get("DATABASE_URL", "")
PW = "Test12345!"
res = []


def call(m, p, body=None, tok=None):
    """Бе такрор ҳангоми 429 — маҳз 429-ро месанҷем."""
    req = urllib.request.Request(B + p, data=json.dumps(body).encode() if body is not None else None, method=m)
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
    res.append((bool(c), n, str(d)[:220]))


# Рақамҳои телефон аз SUFFIX — бо дигар санҷишҳо ва давраҳои пешина
# такрор намешаванд (такрор = «якчанд ҳисоб» ва санҷиш вайрон мешуд).
N = int(hashlib.sha1(("recover-" + S).encode()).hexdigest(), 16) % 10**6


def phone(k):
    return f"+99293{N:06d}{k}"


def user(u, ph):
    call("POST", "/auth/register", {"username": u, "email": f"{u}@example.com",
                                    "password": PW, "fullName": "Full " + u, "phone": ph})
    st, r = call("POST", "/auth/login", {"email": u, "password": PW})
    return r.get("accessToken"), r.get("refreshToken"), (r.get("user") or {}).get("id")


A = f"rva{S}"; tA, rA, idA = user(A, phone(1))
Bu = f"rvb{S}"; user(Bu, phone(3))
C = f"rvc{S}"; user(C, phone(2))
D = f"rvd{S}"; user(D, phone(2).replace("+", ""))  # ҳамон рақам, шакли дигар
E = f"rve{S}"; user(E, phone(5))
E2 = f"rvx{S}"; user(E2, phone(6))
H = f"rvh{S}"; user(H, phone(7))
F = f"rvf{S}"; user(F, phone(8))
ADM = f"rvadm{S}"; tAdm, _, _ = user(ADM, phone(9))
ok("корбарон сохта шуданд", tA and idA and tAdm, (A, idA))

# ═══ 1. «Ёфтани ҳисоб» ════════════════════════════════════════════
local = phone(1)[4:]  # 93nnnnnn1 — 9 рақам
variants = [A, "@" + A.upper(), f"  {A.upper()}@EXAMPLE.COM ", phone(1),
            phone(1)[1:], "00" + phone(1)[1:],
            f"+992 {local[:2]} {local[2:5]} {local[5:7]} {local[7:]}", local]
for v in variants:
    st, r = call("POST", "/auth/recover/lookup", {"identifier": v})
    acc = (r.get("account") or {}) if isinstance(r, dict) else {}
    ch = [c.get("type") for c in (r.get("channels") or [])] if isinstance(r, dict) else []
    ok(f"lookup «{v.strip()}» → ҳамон ҳисоб", st == 200 and r.get("found") is True
       and acc.get("username", "").startswith(A[:2]) and "*" in acc.get("username", "")
       and "email" in ch, (st, r))
st, r = call("POST", "/auth/recover/lookup", {"identifier": A})
em = [c for c in r.get("channels", []) if c.get("type") == "email"]
ok("почта пӯшида: r***…@example.com", em and em[0]["to"].startswith("r***")
   and em[0]["to"].endswith("@example.com") and A not in em[0]["to"], em)
ok("номи корбари пурра ошкор намешавад", A not in json.dumps(r), r.get("account"))

st, miss = call("POST", "/auth/recover/lookup", {"identifier": f"nest{S}xyz"})
ok("ҳисоби нест: found=false", st == 200 and miss.get("found") is False, (st, miss))
ok("шакли ҷавоб як хел (ҳаст / нест)", set(miss.keys()) == set(r.keys()),
   (sorted(miss.keys()), sorted(r.keys())))

st, r = call("POST", "/auth/recover/lookup", {"identifier": phone(2)})
ok("як телефон — ду ҳисоб: номи корбар пурсида мешавад",
   st == 200 and r.get("needUsername") is True and r.get("found") is False, (st, r))
st, r = call("POST", "/auth/recover/send", {"identifier": phone(2), "channel": "email"})
ok("фиристодан ба телефони номуайян — 409 need_username",
   st == 409 and r.get("code") == "need_username", (st, r))
st, r = call("POST", "/auth/recover/lookup", {"identifier": C})
ok("бо номи корбар — ҳисоби аниқ", st == 200 and r.get("found") is True, (st, r))
st, r = call("POST", "/auth/recover/lookup", {"identifier": ""})
ok("идентификатори холӣ — 400", st == 400, (st, r))

# ═══ 2. Фиристодан ═════════════════════════════════════════════════
st, r = call("POST", "/auth/recover/send", {"identifier": A, "channel": "sms"})
ok("канали танзимнашуда (sms) — 400 channel_unavailable",
   st == 400 and r.get("code") == "channel_unavailable", (st, r))
st, s1 = call("POST", "/auth/recover/send", {"identifier": phone(1), "channel": "email"})
otpA = s1.get("otp")
ok("рамз фиристода шуд (бо телефон ёфт, ба почта)", st == 200 and s1.get("sent")
   and otpA and len(otpA) == 6 and s1.get("to", "").startswith("r***"), (st, s1))
ok("resendIn=60, expiresIn=600", s1.get("resendIn") == 60 and s1.get("expiresIn") == 600, s1)
st, r = call("POST", "/auth/recover/send", {"identifier": A, "channel": "email"})
ok("фиристодани такрорӣ дар 60 с — 429 cooldown", st == 429 and r.get("code") == "cooldown"
   and 0 < int(r.get("retryAfter", 0)) <= 60, (st, r))
st, r = call("POST", "/auth/recover/send", {"identifier": f"nest{S}xyz", "channel": "email"})
ok("ҳисоби нест: ҷавоби умумӣ (бе фош кардан)", st == 200 and r.get("sent") is True
   and "otp" not in r, (st, r))

# ═══ 3. Тасдиқ ═════════════════════════════════════════════════════
bad = "000000" if otpA != "000000" else "111111"
st, r = call("POST", "/auth/recover/verify", {"identifier": A, "code": bad})
ok("рамзи нодуруст — 400 «Рамз нодуруст», 4 кӯшиш монд",
   st == 400 and r.get("code") == "invalid_code" and r.get("attemptsLeft") == 4
   and "нодуруст" in r.get("message", ""), (st, r))
st, v = call("POST", "/auth/recover/verify", {"identifier": A.upper(), "code": otpA})
tok = v.get("resetToken", "")
ok("рамзи дуруст → resetToken (≥ 40 аломат, 15 дақ)", st == 200 and len(tok) >= 40
   and v.get("expiresIn") == 900, (st, v))
st, r = call("POST", "/auth/recover/verify", {"identifier": A, "code": otpA})
ok("рамз як бор кор мекунад — дафъаи дуюм 410", st == 410 and r.get("code") == "expired", (st, r))

# ═══ 4. Рамзи нав ══════════════════════════════════════════════════
st, r = call("POST", "/auth/recover/reset", {"token": tok, "newPassword": "short"})
ok("рамзи заиф — 400 weak_password", st == 400 and r.get("code") == "weak_password", (st, r))
st, r = call("GET", "/auth/recovery-status", tok=tA)
ok("пеш аз иваз: сессияи кӯҳна кор мекунад", st == 200, st)
NEWPW = "Nav0Ramz!2026"
st, rs = call("POST", "/auth/recover/reset", {"token": tok, "newPassword": NEWPW})
newTok = rs.get("accessToken")
ok("рамз иваз шуд ва token-ҳои нав омад (auto-login)", st == 200 and newTok
   and rs.get("refreshToken") and (rs.get("user") or {}).get("id") == idA, (st, rs))
st, r = call("GET", "/auth/recovery-status", tok=tA)
ok("сессияи кӯҳна (access) — 401", st == 401, (st, r))
st, r = call("POST", "/auth/refresh", {"refreshToken": rA})
ok("refresh-и кӯҳна бекор — 403", st in (401, 403), (st, r))
st, r = call("GET", "/auth/recovery-status", tok=newTok)
ok("token-и нав кор мекунад", st == 200 and "emailVerified" in r, (st, r))
st, r = call("POST", "/auth/refresh", {"refreshToken": rs.get("refreshToken")})
ok("refresh-и нав кор мекунад", st == 200 and r.get("accessToken"), st)
st, r = call("POST", "/auth/recover/reset", {"token": tok, "newPassword": "Boz12345!x"})
ok("token дубора кор намекунад — 400 invalid_token", st == 400 and r.get("code") == "invalid_token", (st, r))
st, r = call("POST", "/auth/login", {"email": A, "password": PW})
ok("рамзи кӯҳна дигар кор намекунад", st == 401, st)
st, r = call("POST", "/auth/login", {"email": A, "password": NEWPW})
ok("рамзи нав кор мекунад", st == 200 and r.get("accessToken"), st)
time.sleep(1)
st, r = call("GET", "/notifications/", tok=newTok)
types = [n.get("type") for n in (r.get("notifications") or [])] if isinstance(r, dict) else []
ok("огоҳинома: password_changed", "password_changed" in types, types[:5])
st, r = call("POST", "/auth/recover/reset", {"token": "sohta-token-" + "x" * 40, "newPassword": "Boz12345!x"})
ok("token-и сохта — 400", st == 400, (st, r))

# ═══ 5. 5 кӯшиши нодуруст → қуфл ═══════════════════════════════════
st, s2 = call("POST", "/auth/recover/send", {"identifier": Bu})
otpB = s2.get("otp")
ok("B: рамз (канали пешфарз — email)", st == 200 and otpB and s2.get("channel") == "email", (st, s2))
codes = []
for i in range(5):
    wrong = f"{(int(otpB) + 1 + i) % 1000000:06d}"
    st, r = call("POST", "/auth/recover/verify", {"identifier": Bu, "code": wrong})
    codes.append((st, r.get("code") if isinstance(r, dict) else r))
ok("4 нодуруст → 400, 5-ум → 429 locked", [c[0] for c in codes] == [400, 400, 400, 400, 429]
   and codes[-1][1] == "locked", codes)
st, r = call("POST", "/auth/recover/verify", {"identifier": Bu, "code": otpB})
ok("баъди қуфл рамзи дуруст ҳам кор намекунад (410 «нав фиристед»)",
   st == 410 and "нав" in r.get("message", ""), (st, r))

# ═══ 6. Роҳҳои кӯҳна (версияҳои пешинаи барнома) ═══════════════════
st, r = call("POST", "/auth/forgot-password", {"identifier": H, "channel": "telegram"})
otpH = r.get("otp")
ok("кӯҳна: /auth/forgot-password ба канали дастрас мегузарад", st == 200 and otpH, (st, r))
st, r = call("POST", "/auth/reset-password", {"identifier": H, "otp": otpH, "newPassword": "Kuhna12345!"})
ok("кӯҳна: /auth/reset-password кор мекунад", st == 200, (st, r))
st, r = call("POST", "/auth/login", {"email": H, "password": "Kuhna12345!"})
ok("кӯҳна: бо рамзи нав ворид мешавад", st == 200, st)
st, r = call("POST", "/auth/forgot-password", {"identifier": phone(2)})
ok("кӯҳна: телефони номуайян рамзро ба ягон ҳисоб НАМЕФИРИСТАД", st == 200 and "otp" not in r, (st, r))

# ═══ 7. Почта тасдиқ ва Танзимот → Амният ═════════════════════════
st, r = call("GET", "/auth/recovery-status", tok=newTok)
ok("recovery-status: почта тасдиқ нашудааст", st == 200 and r.get("emailVerified") is False
   and r.get("needsEmail") is True and r.get("hasPhone") is True, (st, r))
st, r = call("POST", "/auth/verify-email", {"email": f"{A}@example.com"}, newTok)
ok("рамзи тасдиқи почта фиристода шуд", st == 200 and r.get("otp"), (st, r))
st, r2 = call("POST", "/auth/verify-otp", {"email": f"{A}@example.com", "otp": r.get("otp")}, newTok)
ok("почта тасдиқ шуд", st == 200 and r2.get("verified") is True, (st, r2))
st, r = call("GET", "/auth/recovery-status", tok=newTok)
ok("recovery-status: emailVerified=true", r.get("emailVerified") is True and r.get("needsEmail") is False, r)

# ═══ 8. «Кӯмак лозим» → admin ══════════════════════════════════════
contact = f"help{S}@example.org"
st, r = call("POST", "/auth/recover/request", {"identifier": E, "contactEmail": "not-an-email",
                                               "fullName": "Full " + E, "message": "почтаро гум кардам"})
ok("почтаи тамоси нодуруст — 400", st == 400 and r.get("code") == "invalid_email", (st, r))
st, r = call("POST", "/auth/recover/request", {"identifier": E, "contactEmail": contact,
                                               "fullName": "Full " + E, "message": "почта ва телефонро гум кардам"})
ok("дархости кӯмак қабул шуд", st == 200 and r.get("submitted") is True and r.get("alreadyPending") is False, (st, r))
st, r = call("POST", "/auth/recover/request", {"identifier": E, "contactEmail": f"other{S}@example.org",
                                               "fullName": "Full " + E, "message": "боз"})
ok("дархости дуюм — такрор нест (alreadyPending)", st == 200 and r.get("alreadyPending") is True, (st, r))
st, r = call("POST", "/auth/recover/request", {"identifier": E2, "contactEmail": f"x{S}@example.org",
                                               "fullName": "Begona", "message": "ин ҳисоби ман"})
ok("дархости E2 қабул шуд", st == 200 and r.get("submitted"), (st, r))

st, r = call("GET", "/admin/recovery-requests", tok=newTok)
ok("корбари оддӣ рӯйхатро намебинад — 403", st == 403, st)

admin_ok = False
if DB:
    try:
        subprocess.run(["psql", DB, "-v", "ON_ERROR_STOP=1", "-qc",
                        f"UPDATE users SET role='admin' WHERE username='{ADM}'"],
                       check=True, capture_output=True, timeout=30)
        admin_ok = True
    except Exception as e:  # noqa: BLE001
        print("⚠️ psql дастрас нест:", e)
if not admin_ok:
    ok("admin: DATABASE_URL + psql лозим (қисми admin гузаронда нашуд)", False, "DATABASE_URL нест")
else:
    st, r = call("GET", "/admin/recovery-requests?status=pending", tok=tAdm)
    reqs = r.get("requests") or [] if isinstance(r, dict) else []
    mine = [q for q in reqs if (q.get("account") or {}).get("username") == E]
    other = [q for q in reqs if (q.get("account") or {}).get("username") == E2]
    ok("admin рӯйхати интизориро мебинад", st == 200 and len(mine) == 1 and len(other) == 1, (st, len(reqs)))
    q = mine[0] if mine else {}
    ok("дархост: почтаи тамос, ном, мувофиқати ном", q.get("contactEmail") == contact
       and q.get("nameMatches") is True and q.get("contactMatchesAccountEmail") is False, q)
    ok("почтаи ҳисоб ба admin пӯшида нишон дода мешавад",
       "*" in (q.get("account") or {}).get("email", ""), q.get("account"))
    ok("рамз ё парол дар рӯйхат нест", "password" not in json.dumps(r) and "code" not in json.dumps(q), "")
    st, ap = call("POST", f"/admin/recovery-requests/{q.get('id')}/approve", tok=tAdm)
    code = ap.get("code", "")
    ok("admin тасдиқ кард → рамз ба почтаи тамос (24 соат)", st == 200 and ap.get("status") == "approved"
       and len(code) == 14 and ap.get("sentTo", "").startswith("h***"), (st, ap))
    st, r = call("POST", f"/admin/recovery-requests/{q.get('id')}/approve", tok=tAdm)
    ok("тасдиқи дубора — 404", st == 404, (st, r))
    st, r = call("GET", "/admin/recovery-requests?status=approved", tok=tAdm)
    mine = [x for x in r.get("requests", []) if x.get("id") == q.get("id")]
    ok("кӣ тасдиқ кард — сабт шуд", mine and mine[0].get("reviewedBy") == ADM and mine[0].get("reviewedAt"), mine)
    st, tE = call("POST", "/auth/login", {"email": E, "password": PW})
    oldE = tE.get("accessToken")
    # Рамзро бе «-» ва бо ҳарфҳои хурд менависем — бояд кор кунад.
    st, r = call("POST", "/auth/recover/reset", {"token": code.replace("-", "").lower(), "newPassword": "Kumak12345!"})
    ok("рамзи почтаи тамос → рамзи нав + token-ҳо", st == 200 and r.get("accessToken"), (st, r))
    st, r2 = call("GET", "/auth/recovery-status", tok=oldE)
    ok("E: сессияи кӯҳна — 401", st == 401, st)
    st, r2 = call("POST", "/auth/recover/reset", {"token": code, "newPassword": "Boz12345!x"})
    ok("рамзи admin як бор кор мекунад", st == 400, (st, r2))
    st, r2 = call("POST", "/auth/login", {"email": E, "password": "Kumak12345!"})
    ok("E бо рамзи нав ворид мешавад", st == 200, st)
    # Рад кардан
    st, r = call("GET", "/admin/recovery-requests", tok=tAdm)
    q2 = [x for x in r.get("requests", []) if (x.get("account") or {}).get("username") == E2]
    st, rj = call("POST", f"/admin/recovery-requests/{q2[0]['id'] if q2 else 'x'}/reject",
                  {"note": "маълумот мувофиқ нест"}, tAdm)
    ok("admin рад кард", st == 200 and rj.get("status") == "rejected", (st, rj))
    st, r = call("GET", "/admin/recovery-requests?status=rejected", tok=tAdm)
    q2 = [x for x in r.get("requests", []) if (x.get("account") or {}).get("username") == E2]
    ok("радшуда: кӣ ва сабаб сабт шуд", q2 and q2[0].get("reviewedBy") == ADM
       and q2[0].get("reviewNote") == "маълумот мувофиқ нест", q2)
    st, r = call("POST", "/auth/login", {"email": E2, "password": PW})
    ok("радшуда: рамзи E2 тағйир наёфт", st == 200, st)
    st, r = call("POST", "/auth/recover/request", {"identifier": E2, "contactEmail": f"x{S}@example.org",
                                                   "fullName": "Begona", "message": "боз"})
    ok("баъди рад дархости нав мумкин аст", st == 200 and r.get("alreadyPending") is False, (st, r))

# ═══ 9. Лимитҳо ════════════════════════════════════════════════════
sts = [call("POST", "/auth/recover/lookup", {"identifier": F})[0] for _ in range(12)]
ok("lookup-и як идентификатор: зиёда аз 10 дар 15 дақ — 429", 429 in sts and sts[0] == 200, sts)
lim = f"lim{S}@example.org"
sts = [call("POST", "/auth/recover/request", {"identifier": f"nest{S}{i}", "contactEmail": lim,
                                              "fullName": "Kas", "message": "x"})[0] for i in range(4)]
ok("дархости кӯмак: як почтаи тамос то 3 дар рӯз", sts[:3] == [200, 200, 200] and sts[3] == 429, sts)

passed = sum(1 for r in res if r[0])
for good, n, d in res:
    print(("✅" if good else "❌"), n, "" if good else "→ " + d)
print(f"\n{passed}/{len(res)}")
sys.exit(0 if passed == len(res) else 1)
