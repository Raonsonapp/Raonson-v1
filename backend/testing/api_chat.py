#!/usr/bin/env python3
"""Функсияҳои нави чат — мисли Instagram.

   • таҳрири паём (танҳо фиристанда, танҳо матн, 15 дақиқа)
   • Forward — «Фиристода шуд»
   • пин кардани чат (то 3, дар боло)
   • хомӯш кардани чат (паём мерасад, огоҳинома не)

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
def jd(x): return json.dumps(x, ensure_ascii=False)

S = os.environ.get("SUFFIX", "ch")
tA, A = user(f"ca{S}", "+992900910001")
tB, Bb = user(f"cb{S}", "+992900910002")
tC, C = user(f"cc{S}", "+992900910003")
if not (tA and tB and tC): print("!! вуруд нашуд"); sys.exit(1)

def chat(tok, peer):
    st, r = call("GET", f"/chat/with/{peer}", tok=tok)
    return r.get("chatId") or r.get("id") or r.get("_id")

ab = chat(tA, Bb)
st, m = call("POST", f"/chat/{ab}/messages", {"text": "салом, хато навиштам"}, tA)
mid = m.get("_id") or m.get("id")
ok("паём фиристода шуд", mid, m)

# ── ТАҲРИР ──
st, r = call("PUT", f"/chat/messages/{mid}", {"text": "салом, дуруст навиштам"}, tA)
ok("фиристанда паёмро таҳрир мекунад", st == 200 and r.get("editedAt"), f"HTTP {st}: {r}")
st, lst = call("GET", f"/chat/{ab}/messages", tok=tB)
msgs = lst.get("messages", []) if isinstance(lst, dict) else []
mm = next((x for x in msgs if x.get("_id") == mid), {})
ok("гиранда матни НАВро мебинад", mm.get("text") == "салом, дуруст навиштам", mm)
ok("паём ҳамчун «таҳриршуда» қайд шудааст", bool(mm.get("editedAt")), mm)
st, r = call("PUT", f"/chat/messages/{mid}", {"text": "аз номи бегона"}, tB)
ok("гиранда паёми фиристандаро таҳрир карда НАМЕТАВОНАД", st == 404, f"HTTP {st}: {r}")
st, r = call("PUT", f"/chat/messages/{mid}", {"text": "аз номи сеюм"}, tC)
ok("шахси сеюм таҳрир карда НАМЕТАВОНАД", st == 404, f"HTTP {st}: {r}")
st, r = call("PUT", f"/chat/messages/{mid}", {"text": "   "}, tA)
ok("матни холӣ рад мешавад", st == 400, f"HTTP {st}: {r}")
st, r = call("PUT", "/chat/messages/nest-id", {"text": "x"}, tA)
ok("паёми нобуд — 404", st == 404, f"HTTP {st}")
st, r = call("PUT", f"/chat/messages/{mid}", {"text": "x"})
ok("бе токен — рад", st in (401, 403), f"HTTP {st}")

# ── FORWARD ──
ac = chat(tA, C)
st, f = call("POST", f"/chat/{ac}/messages", {"text": "салом, дуруст навиштам", "forwarded": True}, tA)
ok("паём ба чати дигар фиристода шуд (forward)", st in (200, 201) and f.get("forwarded") is True, f)
st, lst = call("GET", f"/chat/{ac}/messages", tok=tC)
fm = (lst.get("messages") or [{}])[-1] if isinstance(lst, dict) else {}
ok("гиранда «Фиристода шуд»-ро мебинад", fm.get("forwarded") is True, fm)

# ── ПИН ──
st, r = call("POST", f"/chat/pin/{C}", {"pinned": True}, tA)
ok("чат пин шуд", st == 200 and r.get("pinned") is True, f"HTTP {st}: {r}")
st, lst = call("GET", "/chat/", tok=tA)
chats = lst.get("chats", []) if isinstance(lst, dict) else []
ok("чати пиншуда дар БОЛОИ рӯйхат аст",
   chats and chats[0].get("peer", {}).get("_id") == C and chats[0].get("pinned") is True,
   [(x.get("peer", {}).get("username"), x.get("pinned")) for x in chats[:3]])
# Ҳадди 3
peers = []
for i in range(3):
    t, pid = user(f"cp{i}{S}", f"+99290092000{i}")
    c = chat(tA, pid); call("POST", f"/chat/{c}/messages", {"text": "x"}, tA)
    peers.append(pid)
call("POST", f"/chat/pin/{peers[0]}", {"pinned": True}, tA)
call("POST", f"/chat/pin/{peers[1]}", {"pinned": True}, tA)
st, r = call("POST", f"/chat/pin/{peers[2]}", {"pinned": True}, tA)
ok("чати чорум пин НАМЕШАВАД (ҳадди 3)", st == 409, f"HTTP {st}: {r}")
st, r = call("POST", f"/chat/pin/{C}", {"pinned": False}, tA)
ok("пин бекор шуд", st == 200 and r.get("pinned") is False, r)
st, r = call("POST", f"/chat/pin/{peers[2]}", {"pinned": True}, tA)
ok("баъди бекор кардан ҷой холӣ шуд", st == 200, f"HTTP {st}: {r}")
st, lst = call("GET", "/chat/", tok=tB)
bc = next((x for x in lst.get("chats", []) if x.get("peer", {}).get("_id") == A), {})
ok("пини A ба ҳамсӯҳбат НАМОЁН НЕСТ", bc.get("pinned") is False, bc)

# ── ХОМӮШ ──
st, r = call("POST", f"/chat/mute/{A}", {"muted": True}, tB)
ok("чат хомӯш шуд", st == 200 and r.get("muted") is True, f"HTTP {st}: {r}")
st, m2 = call("POST", f"/chat/{ab}/messages", {"text": "паём ба чати хомӯш"}, tA)
ok("паём ба чати хомӯш ҳамоно мерасад", st in (200, 201), f"HTTP {st}")
st, lst = call("GET", "/chat/", tok=tB)
bc = next((x for x in lst.get("chats", []) if x.get("peer", {}).get("_id") == A), {})
ok("дар рӯйхат ҳамчун хомӯш нишон дода мешавад", bc.get("muted") is True, bc)
st, r = call("POST", f"/chat/mute/{A}", {"muted": False}, tB)
ok("хомӯшӣ бекор шуд", st == 200 and r.get("muted") is False, r)
st, r = call("POST", f"/chat/pin/{A}", {"pinned": True}, tA)
st2, r2 = call("POST", f"/chat/mute/{A}", {"muted": True}, tA)
ok("бо худ пин/хомӯш — рад", st == 400 and st2 == 400, f"{st} {st2}")

# ── VANISH MODE ──
st, v1 = call("POST", f"/chat/{ab}/messages", {"text": "паёми нопадид", "vanish": True}, tA)
vid = v1.get("_id") or v1.get("id")
ok("паёми vanish фиристода шуд", st in (200, 201) and v1.get("vanish") is True, v1)
st, r = call("POST", f"/chat/{ab}/vanish-close", tok=tB)
ok("надида — баъди бастан НАМЕРАВАД", r.get("removed") == 0, r)
call("POST", f"/chat/{ab}/read", tok=tB)
st, lst = call("GET", f"/chat/{ab}/messages", tok=tB)
ok("гиранда паёмро мебинад", any(m.get("_id") == vid for m in lst.get("messages", [])), "")
st, r = call("POST", f"/chat/{ab}/vanish-close", tok=tB)
ok("дид ва баст — паём нопадид шуд", (r.get("removed") or 0) >= 1, r)
st, lst = call("GET", f"/chat/{ab}/messages", tok=tA)
ok("барои ФИРИСТАНДА ҳам нопадид", not any(m.get("_id") == vid for m in lst.get("messages", [])), "")
st, lst = call("GET", f"/chat/{ab}/messages", tok=tB)
ok("паёмҳои оддӣ боқӣ монданд", any("дуруст навиштам" in (m.get("text") or "") for m in lst.get("messages", [])), "")
st, r = call("POST", f"/chat/{ab}/vanish-close", tok=tC)
ok("шахси сеюм паёми бегонаро нест карда НАМЕТАВОНАД", r.get("removed") == 0, r)

# ── ПАЁМИ ВАҚТБАНДИШУДА (Instagram надорад) ──
import datetime as _dt
soon = (_dt.datetime.now(_dt.timezone.utc) + _dt.timedelta(seconds=45)).strftime("%Y-%m-%dT%H:%M:%SZ")
st, sm = call("POST", f"/chat/{ab}/messages", {"text": "табрик дар вақташ", "sendAt": soon}, tA)
smid = sm.get("_id") or sm.get("id")
ok("паём вақтбандӣ шуд", st in (200, 201) and sm.get("scheduledAt"), sm)
st, lst = call("GET", f"/chat/{ab}/messages", tok=tB)
ok("гиранда то вақташ НАМЕБИНАД", not any(m.get("_id") == smid for m in lst.get("messages", [])), "")
st, lst = call("GET", f"/chat/{ab}/messages", tok=tA)
mine = next((m for m in lst.get("messages", []) if m.get("_id") == smid), {})
ok("фиристанда онро бо вақташ мебинад", mine.get("scheduledAt"), mine)
past = (_dt.datetime.now(_dt.timezone.utc) - _dt.timedelta(minutes=1)).strftime("%Y-%m-%dT%H:%M:%SZ")
st, r = call("POST", f"/chat/{ab}/messages", {"text": "x", "sendAt": past}, tA)
ok("вақти гузашта рад мешавад", st == 400, f"HTTP {st}")
time.sleep(70)
st, lst = call("GET", f"/chat/{ab}/messages", tok=tB)
got = next((m for m in lst.get("messages", []) if m.get("_id") == smid), None)
ok("дар вақташ ба гиранда расид", got is not None and not got.get("scheduledAt"), got)

bad = [x for x in res if not x[0]]
print()
for g, n, d in res: print(("  ✅ " if g else "  ❌ ") + n + ("" if g else f"\n       → {d}"))
print(f"\n{len(res) - len(bad)}/{len(res)} гузашт")
sys.exit(1 if bad else 0)
