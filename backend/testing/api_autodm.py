#!/usr/bin/env python3
"""Паёми худкор ба Direct аз рӯи калимаи шарҳ (мисли ManyChat).
 Муаллиф калима ва паём/пайванд мегузорад; шарҳнавис бо калима — паём мегирад.
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
S = os.environ.get("SUFFIX", "adm")
tA, A = user(f"da{S}", "+992900970001")   # муаллиф
tB, Bb = user(f"db{S}", "+992900970002")  # шарҳнавис
tC, C = user(f"dc{S}", "+992900970003")   # бегона
if not (tA and tB and tC): print("!! вуруд нашуд"); sys.exit(1)
def chat(tok, peer):
    st, r = call("GET", f"/chat/with/{peer}", tok=tok)
    return r.get("chatId") or r.get("id") or r.get("_id")
def msgs(tok, cid):
    st, r = call("GET", f"/chat/{cid}/messages", tok=tok)
    return r if isinstance(r, list) else (r.get("messages") or [])
def sender(m):
    s = m.get("sender"); return (s.get("_id") or s.get("id")) if isinstance(s, dict) else s
def autos(tok, peer, needle):
    return [x for x in msgs(tok, chat(tok, peer)) if needle in (x.get("text") or "")]

st, p = call("POST", "/posts/", {"caption": "автодм", "media": [{"url": "https://example.com/a.jpg", "type": "image"}]}, tA)
pid = p.get("_id"); ok("пост сохта шуд", st in (200, 201) and pid, (st, p))
st, r = call("POST", "/reels/", {"videoUrl": "https://example.com/v.mp4", "caption": "автодм"}, tA)
rid = r.get("_id"); ok("рилс сохта шуд", st in (200, 201) and rid, (st, r))

# Ҳуқуқ ва эътибор
st, _ = call("PUT", f"/auto-dm/post/{pid}", {"keywords": ["1"], "message": "x"}, tB)
ok("бегона қоида гузошта наметавонад", st == 404, st)
st, _ = call("GET", f"/auto-dm/post/{pid}", tok=tB)
ok("бегона қоидаро намебинад", st == 404, st)
st, _ = call("PUT", f"/auto-dm/post/{pid}", {"keywords": ["1"], "link": "http://evil.example"}, tA)
ok("пайванди http рад", st == 400, st)
st, _ = call("PUT", f"/auto-dm/post/{pid}", {"keywords": ["1"], "link": "javascript:alert(1)"}, tA)
ok("javascript: рад", st == 400, st)
st, _ = call("PUT", f"/auto-dm/post/{pid}", {"keywords": [], "message": "x"}, tA)
ok("бе калима ва бе «ҳар шарҳ» рад", st == 400, st)
st, _ = call("PUT", f"/auto-dm/story/{pid}", {"keywords": ["1"], "message": "x"}, tA)
ok("навъи номаълум рад", st == 400, st)

st, g = call("PUT", f"/auto-dm/post/{pid}", {"keywords": ["1", "Салом", "салом"], "message": "Ташаккур! Инак пайванд:", "link": "https://raonson.example/guide"}, tA)
ok("қоида сабт шуд", st == 200 and g.get("keywords") == ["1", "Салом"], (st, g))
st, g = call("GET", f"/auto-dm/post/{pid}", tok=tA)
ok("соҳиб қоидаро мебинад", st == 200 and g.get("exists") and g.get("link", "").startswith("https://"), g)

# Калимаи нодуруст — паём нест
call("POST", f"/posts/{pid}/comments", {"text": "10 бисёр хуб"}, tB); time.sleep(1.5)
ok("«10» ба «1» мувофиқ нест", len(autos(tB, A, "Инак пайванд")) == 0)
call("POST", f"/posts/{pid}/comments", {"text": "саломат бошед"}, tB); time.sleep(1.5)
ok("«саломат» ба «салом» мувофиқ нест", len(autos(tB, A, "Инак пайванд")) == 0)

# Калимаи дуруст
call("POST", f"/posts/{pid}/comments", {"text": "САЛОМ!"}, tB); time.sleep(1.5)
got = autos(tB, A, "Инак пайванд")
ok("шарҳ бо калима → паём ба Direct", len(got) == 1, len(got))
ok("паём аз номи муаллиф", got and sender(got[0]) == A, got)
ok("пайванд дар паём", got and "https://raonson.example/guide" in got[0].get("text", ""), got)
st, lst = call("GET", "/chat", tok=tB)
row = [x for x in (lst if isinstance(lst, list) else lst.get("chats") or []) if json.dumps(x).find(A) >= 0]
ok("чат дар рӯйхати асосӣ (на дархост)", row and not row[0].get("isRequest", False), row[:1])

call("POST", f"/posts/{pid}/comments", {"text": "1"}, tB); time.sleep(1.5)
ok("як бор барои ҳар шарҳнавис", len(autos(tB, A, "Инак пайванд")) == 1)


# Хомӯш
call("PUT", f"/auto-dm/post/{pid}", {"keywords": ["1"], "message": "Инак пайванд", "enabled": False}, tA)
call("POST", f"/posts/{pid}/comments", {"text": "1"}, tC); time.sleep(1.5)
ok("қоидаи хомӯш кор намекунад", len(autos(tC, A, "Инак пайванд")) == 0)

# Рилс: «ҳар шарҳ»
st, _ = call("PUT", f"/auto-dm/reel/{rid}", {"anyWord": True, "message": "Рилс: ташаккур барои шарҳ"}, tA)
ok("қоидаи рилс сабт шуд", st == 200, st)
call("POST", f"/reels/{rid}/comments", {"text": "зебо"}, tC); time.sleep(1.5)
ok("рилс: ҳар шарҳ → паём", len(autos(tC, A, "Рилс: ташаккур")) == 1)

st, _ = call("DELETE", f"/auto-dm/reel/{rid}", tok=tA)
st, g = call("GET", f"/auto-dm/reel/{rid}", tok=tA)
ok("қоида нест карда шуд", not g.get("exists"), g)
st, g = call("GET", f"/auto-dm/post/{pid}", tok=tA)
ok("ҳисобкунаки фиристодашуда = 1", g.get("sentCount") == 1, g)

# Ҳангоми нашр
st, p2 = call("POST", "/posts/", {"caption": "нашр бо autoDm", "media": [{"url": "https://example.com/b.jpg", "type": "image"}],
    "autoDm": {"keywords": ["нарх"], "message": "Нарх: 100 сомонӣ"}}, tA)
ok("пост бо autoDm сохта шуд", st in (200, 201), (st, p2))
call("POST", f"/posts/{p2.get('_id')}/comments", {"text": "нарх?"}, tC); time.sleep(1.5)
ok("autoDm-и ҳангоми нашр кор мекунад", len(autos(tC, A, "Нарх: 100")) == 1)
st, _ = call("POST", "/reels/", {"videoUrl": "https://example.com/v2.mp4", "autoDm": {"keywords": ["1"], "link": "http://x.y"}}, tA)
ok("рилс бо autoDm-и нодуруст рад", st == 400, st)

bad = [x for x in res if not x[0]]
print()
for g, n, d in res: print(("  ✅ " if g else "  ❌ ") + n + ("" if g else f"\n       → {d}"))
print(f"\n{len(res) - len(bad)}/{len(res)} гузашт")
sys.exit(1 if bad else 0)
