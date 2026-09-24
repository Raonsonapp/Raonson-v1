#!/usr/bin/env python3
"""Ҷавоби худкор (мисли «ҷавобҳои фаврӣ»-и Instagram).
 Корбар: «ба Raonson салом менависам — ҷавоби автоматӣ кор намекунад».
 Пеш танҳо ба АВВАЛИН паёми тамоми таърихи чат ҷавоб медод.
 ⚠️ Ба сервери МАҲАЛЛӢ мезанад.
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
def jd(x): return json.dumps(x, ensure_ascii=False)
S = os.environ.get("SUFFIX", "ar")
tA, A = user(f"ra{S}", "+992900960001")   # мағоза (ҷавоби худкор дорад)
tB, Bb = user(f"rb{S}", "+992900960002")  # харидор
if not (tA and tB): print("!! вуруд нашуд"); sys.exit(1)
def chat(tok, peer):
    st, r = call("GET", f"/chat/with/{peer}", tok=tok)
    return r.get("chatId") or r.get("id") or r.get("_id")
def msgs(tok, cid):
    st, r = call("GET", f"/chat/{cid}/messages", tok=tok)
    return r if isinstance(r, list) else (r.get("messages") or [])
def sender(m):
    s = m.get("sender"); return (s.get("_id") or s.get("id")) if isinstance(s, dict) else s
ab = chat(tB, A)

# Харидор ПЕШ аз танзими ҷавоби худкор навишта буд (ҳолати корбар).
call("POST", f"/chat/{ab}/messages", {"text": "салом, пештар"}, tB)
call("PUT", "/profile/auto-reply", {"text": "Ташаккур! Ба зудӣ ҷавоб медиҳем."}, tA)

st, m = call("POST", f"/chat/{ab}/messages", {"text": "салом алейкум"}, tB)
ok("паём фиристода шуд", st in (200, 201), (st, m))
ok("фиристанда = харидор (на мағоза)", sender(m) == Bb, m)
time.sleep(1.5)
auto = [x for x in msgs(tB, ab) if "Ба зудӣ ҷавоб" in (x.get("text") or "")]
ok("ҷавоби худкор омад, гарчанде чат таърих дошт", len(auto) == 1, len(auto))
ok("ҷавоби худкор аз номи мағоза", auto and sender(auto[0]) == A, auto)

call("POST", f"/chat/{ab}/messages", {"text": "боз як савол"}, tB); time.sleep(1.5)
auto = [x for x in msgs(tB, ab) if "Ба зудӣ ҷавоб" in (x.get("text") or "")]
ok("такрор намешавад (як бор дар 24 соат)", len(auto) == 1, len(auto))

call("PUT", "/profile/auto-reply", {"text": ""}, tA)
bad = [x for x in res if not x[0]]
print()
for g, n, d in res: print(("  ✅ " if g else "  ❌ ") + n + ("" if g else f"\n       → {d}"))
print(f"\n{len(res) - len(bad)}/{len(res)} гузашт")
sys.exit(1 if bad else 0)
