#!/usr/bin/env python3
"""Ёддошт (Notes): вокуниш, лайк ва ҷавоб — мисли Instagram.
 Корбар: «касе ёддошт мегузорад, дигарон мебинанд, вале на эмодзи
 гузошта метавонанд, на лайк, на ҷавоб».
 ⚠️ Ба сервери МАҲАЛЛӢ мезанад (BASE, SUFFIX).
"""
import json, os, sys, time, urllib.request, urllib.error
B = os.environ.get("BASE", "http://127.0.0.1:8099"); PW = "Test12345!"; res = []
def call(m, p, body=None, tok=None):
    req = urllib.request.Request(B + p, data=json.dumps(body).encode() if body is not None else None, method=m)
    req.add_header('Content-Type', 'application/json')
    if tok: req.add_header('Authorization', 'Bearer ' + tok)
    for a in range(4):
        try:
            with urllib.request.urlopen(req, timeout=30) as r:
                raw = r.read().decode(); return r.status, (json.loads(raw) if raw else {})
        except urllib.error.HTTPError as e:
            if e.code == 429: time.sleep(4 * (a + 1)); continue
            raw = e.read().decode()
            try: return e.code, json.loads(raw)
            except Exception: return e.code, raw
    return 429, {}
def user(u, ph):
    call("POST", "/auth/register", {"username": u, "email": f"{u}@example.com", "password": PW, "fullName": u, "phone": ph})
    st, r = call("POST", "/auth/login", {"email": u, "password": PW})
    return r.get("accessToken"), (r.get("user") or {}).get("id") or (r.get("user") or {}).get("_id")
def ok(n, c, d=""): res.append((bool(c), n, str(d)[:200]))
def reactions(tok):
    st, r = call("GET", "/profile/note/reactions", tok=tok)
    return st, (r.get("reactions") if isinstance(r, dict) else None) or []
def friend_note(tok, owner):
    time.sleep(3.2)  # /notes/friends 3с кэш дорад
    st, r = call("GET", "/profile/notes/friends", tok=tok)
    return next((n for n in (r.get("notes") or []) if n.get("_id") == owner), None)

S = os.environ.get("SUFFIX", "nr")
tA, A = user(f"noa{S}", "+992900970001")   # соҳиби ёддошт
tB, Bb = user(f"nob{S}", "+992900970002")  # обуначӣ
tC, C = user(f"noc{S}", "+992900970003")   # бегона (обуна нест)
call("POST", f"/follow/{A}", tok=tB)

st, r = call("POST", "/profile/note", {"note": "Салом ҷаҳон"}, tA)
ok("ёддошт гузошта шуд (+ noteExpiresAt бармегардад)", st == 200 and r.get("noteExpiresAt"), r)

# ── Вокуниш ─────────────────────────────────────────────────────
st, r = call("POST", f"/profile/notes/{A}/react", {"emoji": "🔥"}, tB)
ok("обуначӣ эмодзи гузошт", st == 200 and r.get("emoji") == "🔥", (st, r))
st, r = call("POST", f"/profile/notes/{A}/react", {"emoji": "like"}, tB)
ok("лайк = ❤️ (вокуниши пешинаро иваз мекунад)", st == 200 and r.get("emoji") == "❤️", (st, r))
st, r = call("POST", f"/profile/notes/{A}/react", {"emoji": "spam text"}, tB)
ok("эмодзии ношинос → 400", st == 400, (st, r))
st, r = call("POST", f"/profile/notes/{A}/react", {"emoji": "😂"}, tC)
ok("бегона (обуна нест) вокуниш карда наметавонад → 404", st == 404, (st, r))
st, r = call("POST", f"/profile/notes/{A}/react", {"emoji": "😂"}, tA)
ok("ба ёддошти худ вокуниш нест → 404", st == 404, (st, r))

st, lst = reactions(tA)
ok("соҳиб рӯйхати вокунишҳоро мебинад (1 нафар, ❤️)",
   st == 200 and len(lst) == 1 and lst[0]["user"]["_id"] == Bb and lst[0]["emoji"] == "❤️", lst)
n = friend_note(tB, A)
ok("дар /notes/friends myReaction = ❤️", n and n.get("myReaction") == "❤️", n)

time.sleep(0.5)
st, r = call("GET", "/notifications/", tok=tA)
items = r if isinstance(r, list) else (r.get("notifications") or r.get("data") or [])
nr = [x for x in items if x.get("type") == "note_reaction"]
ok("соҳиб огоҳинома гирифт (як сатр, на ду)", len(nr) == 1, [x.get("type") for x in items])

# ── Бекор кардан ────────────────────────────────────────────────
st, r = call("DELETE", f"/profile/notes/{A}/react", tok=tB)
st2, lst = reactions(tA)
ok("unreact → рӯйхат холӣ", st == 200 and lst == [], lst)

# ── Ёддошти нав вокунишҳоро пок мекунад ─────────────────────────
call("POST", f"/profile/notes/{A}/react", {"emoji": "😮"}, tB)
call("POST", "/profile/note", {"note": "Ёддошти нав"}, tA)
st, lst = reactions(tA)
ok("ёддошти нав → вокунишҳои кӯҳна нест", lst == [], lst)

# ── Ҷавоб ба DM ─────────────────────────────────────────────────
st, r = call("POST", f"/profile/notes/{A}/reply", {"text": "Олӣ!"}, tB)
ok("ҷавоб ба ёддошт фиристода шуд (201)", st == 201, (st, r))
ok("ҷавоб корти note дорад (shareKind/shareThumb)",
   r.get("shareKind") == "note" and r.get("shareThumb") == "Ёддошти нав", r)
chat = r.get("chatId", "")
st, m = call("GET", f"/chat/{chat}/messages", tok=tA)
msgs = m.get("messages") or []
last = msgs[-1] if msgs else {}
ok("соҳиб ҷавобро дар чат мебинад (бо иқтибоси ёддошт)",
   last.get("text") == "Олӣ!" and last.get("shareKind") == "note" and last.get("shareUser") == f"noa{S}", last)
st, r = call("POST", f"/profile/notes/{A}/reply", {"text": "  "}, tB)
ok("ҷавоби холӣ → 400", st == 400, (st, r))
st, r = call("POST", f"/profile/notes/{A}/reply", {"text": "hi"}, tC)
ok("бегона ҷавоб дода наметавонад → 404", st == 404, (st, r))

# ── Блок ────────────────────────────────────────────────────────
call("POST", f"/profile/notes/{A}/react", {"emoji": "👏"}, tB)
call("POST", f"/users/{Bb}/block", tok=tA)
st, r = call("POST", f"/profile/notes/{A}/react", {"emoji": "🔥"}, tB)
ok("басташуда вокуниш карда наметавонад → 404", st == 404, (st, r))
st, r = call("POST", f"/profile/notes/{A}/reply", {"text": "hi"}, tB)
ok("басташуда ҷавоб дода наметавонад → 404", st == 404, (st, r))
st, lst = reactions(tA)
ok("вокуниши басташуда дар рӯйхати соҳиб нест", lst == [], lst)
n = friend_note(tB, A)
ok("басташуда ёддоштро дар /notes/friends намебинад", n is None, n)

# ── Тоза кардани ёддошт ─────────────────────────────────────────
call("POST", f"/users/{Bb}/unblock", tok=tA)
call("POST", "/profile/note", {"note": ""}, tA)
st, r = call("POST", f"/profile/notes/{A}/react", {"emoji": "🔥"}, tB)
ok("ёддошти тозашуда → вокуниш 404", st == 404, (st, r))

bad = [x for x in res if not x[0]]
print()
for g, n, d in res: print(("  ✅ " if g else "  ❌ ") + n + ("" if g else f"\n       → {d}"))
print(f"\n{len(res) - len(bad)}/{len(res)} гузашт")
sys.exit(1 if bad else 0)
