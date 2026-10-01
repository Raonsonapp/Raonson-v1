#!/usr/bin/env python3
"""Ҳисоби паёмҳои хонданашуда — мисли WhatsApp/Instagram.

   • POST /chat/:id/read {upTo} — танҳо то паёми дидашуда (тадриҷӣ)
   • GET /chat → unreadCount-и ҳар чат ва totalUnread (бе дархост/хомӯш)
   • GET /chat/unread-count — бейҷи навбари поён

 ⚠️ Ба сервери МАҲАЛЛӢ мезанад. Ба продакшн чизе навишта намешавад.
"""
import json, os, sys, time, urllib.request, urllib.error

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

def ok(n, c, d=""): res.append((bool(c), n, str(d)[:180]))

S = os.environ.get("SUFFIX", "ur")
tA, A = user(f"ura{S}", "+992900985001")   # фиристанда
tB, Bb = user(f"urb{S}", "+992900985002")  # хонанда
tC, C = user(f"urc{S}", "+992900985003")   # чати дигар (баъд хомӯш)
tD, D = user(f"urd{S}", "+992900985004")   # бегона → дархост
if not (tA and tB and tC and tD): print("!! вуруд нашуд"); sys.exit(1)

# B ба A ва C обуна аст — чатҳояшон «асосӣ», на дархост.
call("POST", f"/follow/{A}", tok=tB)
call("POST", f"/follow/{C}", tok=tB)

def chat(tok, peer):
    st, r = call("GET", f"/chat/with/{peer}", tok=tok)
    return r.get("chatId")

def inbox(tok):
    st, r = call("GET", "/chat", tok=tok)
    return r

def row(tok, peer):
    r = inbox(tok)
    rows = [c for c in (r.get("chats") or []) if (c.get("peer") or {}).get("_id") == peer]
    return rows[0] if rows else {}

def total(tok):
    st, r = call("GET", "/chat/unread-count", tok=tok)
    return r.get("totalUnread") if st == 200 else None

ab = chat(tA, Bb)
for i in range(10):
    st, m = call("POST", f"/chat/{ab}/messages", {"text": f"паём {i}"}, tA)
    if st not in (200, 201): ok(f"паём {i} фиристода шуд", False, (st, m))
    time.sleep(0.02)

r = row(tB, A)
ok("10 паёми нав → бейҷи чат 10", r.get("unreadCount") == 10, r)
ok("GET /chat totalUnread = 10", inbox(tB).get("totalUnread") == 10, inbox(tB).get("totalUnread"))
ok("GET /chat/unread-count = 10", total(tB) == 10, total(tB))

st, ms = call("GET", f"/chat/{ab}/messages", tok=tB)
msgs = [m for m in (ms.get("messages") or []) if (m.get("sender") or {}).get("_id") == A]
ok("10 паём ба хонанда расид", len(msgs) == 10, len(msgs))

# 4 паём дар экран → 6 мемонад (тадриҷӣ, мисли WhatsApp).
st, rr = call("POST", f"/chat/{ab}/read", {"upTo": msgs[3]["_id"]}, tB)
ok("upTo: 4 паём хонда шуд", st == 200 and rr.get("marked") == 4, (st, rr))
ok("upTo: 6 мемонад дар ҷавоб", rr.get("unreadCount") == 6 and rr.get("totalUnread") == 6, rr)
ok("GET /chat пас аз хондан 6 (кэш/кӯҳна не)", row(tB, A).get("unreadCount") == 6, row(tB, A))
ok("бейҷи умумӣ 6", total(tB) == 6, total(tB))

st, ms = call("GET", f"/chat/{ab}/messages", tok=tA)
mine = [m for m in (ms.get("messages") or []) if (m.get("sender") or {}).get("_id") == A]
ok("фиристанда: 4-тои аввал «хонда шуд», боқӣ не",
   [m.get("read") for m in mine] == [True] * 4 + [False] * 6, [m.get("read") for m in mine])

# Такрори ҳамон upTo — ҳеҷ чиз (ва сигнали такрорӣ не).
st, rr = call("POST", f"/chat/{ab}/read", {"upTo": msgs[3]["_id"]}, tB)
ok("такрори upTo: 0 нав", rr.get("marked") == 0 and rr.get("unreadCount") == 6, rr)

# upTo-и бегона/нодуруст ҲАМАРО хонда намекунад.
st, rr = call("POST", f"/chat/{ab}/read", {"upTo": "00000000-0000-0000-0000-000000000000"}, tB)
ok("upTo-и нодуруст: ҳеҷ чиз хонда намешавад", st == 200 and rr.get("marked") == 0 and rr.get("unreadCount") == 6, (st, rr))
cb = chat(tC, Bb)
st, mc = call("POST", f"/chat/{cb}/messages", {"text": "аз C"}, tC)
st, rr = call("POST", f"/chat/{ab}/read", {"upTo": mc.get("_id")}, tB)
ok("upTo аз чати дигар: ҳеҷ чиз", rr.get("marked") == 0 and rr.get("unreadCount") == 6, rr)

# Бегона паёмҳои B-ро хонда карда наметавонад.
st, rr = call("POST", f"/chat/{ab}/read", {}, tC)
ok("бегона: 0 хонда шуд", rr.get("marked") == 0, rr)
ok("бегона ба шумора даст нарасонд", row(tB, A).get("unreadCount") == 6, row(tB, A))

# То поён → 0.
st, rr = call("POST", f"/chat/{ab}/read", {"upTo": msgs[9]["_id"]}, tB)
ok("то поён: 6 хонда шуд, 0 мемонад", rr.get("marked") == 6 and rr.get("unreadCount") == 0, rr)
ok("GET /chat: бейҷи чат 0", row(tB, A).get("unreadCount") == 0, row(tB, A))

# Бейҷи умумӣ: чати C (1 паём) ҳисоб мешавад, хомӯш — не; дархост — не.
ok("бейҷи умумӣ = 1 (паёми C)", total(tB) == 1, total(tB))
dd = chat(tD, Bb)
call("POST", f"/chat/{dd}/messages", {"text": "салом аз бегона"}, tD)
rd = row(tB, D)
ok("паёми бегона дар «Дархостҳо» бо бейҷи худ", rd.get("isRequest") is True and rd.get("unreadCount") == 1, rd)
ok("дархост ба бейҷи умумӣ намедарояд", total(tB) == 1, total(tB))
st, _ = call("POST", f"/chat/mute/{C}", {"muted": True}, tB)
ok("чати C хомӯш шуд", st == 200, st)
ok("чати хомӯш ба бейҷи умумӣ намедарояд", total(tB) == 0, total(tB))
ok("вале бейҷи худи чат мемонад", row(tB, C).get("unreadCount") == 1, row(tB, C))

# Бе upTo — рафтори кӯҳна: ҳама.
for i in range(3):
    call("POST", f"/chat/{ab}/messages", {"text": f"боз {i}"}, tA)
st, rr = call("POST", f"/chat/{ab}/read", None, tB)
ok("бе body: ҳамаи 3 хонда шуд", st == 200 and rr.get("marked") == 3 and rr.get("unreadCount") == 0, (st, rr))

bad = [x for x in res if not x[0]]
print()
for g, n, d in res: print(("  ✅ " if g else "  ❌ ") + n + ("" if g else f"\n       → {d}"))
print(f"\n{len(res) - len(bad)}/{len(res)} гузашт")
sys.exit(1 if bad else 0)
