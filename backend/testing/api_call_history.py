#!/usr/bin/env python3
"""Таърихи зангҳо: сабт аз ҳодисаҳои сокет ва GET /calls/history.

 Корбар: «зангро аз барнома баромада ҳам набояд қатъ шавад … ва функсияҳои
 бештари занг» — таърихи воридотӣ/содиротӣ/аздастрафта бо давомнокӣ.

 Санҷида мешавад:
   • call:offer → call:answer → call:end — «completed» барои ҳарду бо давомнокӣ;
   • call:offer → call:end-и зангзананда — «cancelled» / ба гиранда «missed»;
   • call:decline — «declined» барои ҳарду;
   • call:switch (accept video) → videoUsed; call:switch-и нодуруст намерасад;
   • саҳифабандӣ (limit + nextCursor, бе такрор), курсори вайрон — 400;
   • бастан сатрҳоро аз ҳарду тараф пинҳон мекунад, кушодан — бармегардонад;
   • «аз таърих нест кардан» танҳо барои худ; бе вуруд — 401.

 Мизоҷи WebSocket — бо китобхонаи стандартӣ (бе pip).
 ⚠️ Ба сервери МАҲАЛЛӢ мезанад.
"""
import base64, hashlib, json, os, socket, struct, sys, time, urllib.error, urllib.parse, urllib.request

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


def ok(n, c, d=""): res.append((bool(c), n, str(d)[:300]))


# ── Мизоҷи хурди WebSocket (RFC 6455, танҳо матн) ─────────────────
class WS:
    def __init__(self, token):
        u = urllib.parse.urlparse(B)
        self.s = socket.create_connection((u.hostname, u.port or 80), timeout=10)
        key = base64.b64encode(os.urandom(16)).decode()
        path = "/ws?token=" + urllib.parse.quote(token)
        self.s.sendall((f"GET {path} HTTP/1.1\r\nHost: {u.hostname}:{u.port}\r\n"
                        "Upgrade: websocket\r\nConnection: Upgrade\r\n"
                        f"Sec-WebSocket-Key: {key}\r\nSec-WebSocket-Version: 13\r\n\r\n").encode())
        head = b""
        while b"\r\n\r\n" not in head:
            chunk = self.s.recv(1)
            if not chunk: raise RuntimeError("ws handshake closed")
            head += chunk
        if b" 101 " not in head.split(b"\r\n")[0]:
            raise RuntimeError("ws handshake: " + head.decode(errors="replace"))
        self.buf = b""
        self.wait("socket:ready", 5)

    def _recv(self, n):
        while len(self.buf) < n:
            chunk = self.s.recv(4096)
            if not chunk: raise RuntimeError("ws closed")
            self.buf += chunk
        out, self.buf = self.buf[:n], self.buf[n:]
        return out

    def _frame(self):
        b1, b2 = self._recv(2)
        op, ln = b1 & 0x0F, b2 & 0x7F
        if ln == 126: ln = struct.unpack(">H", self._recv(2))[0]
        elif ln == 127: ln = struct.unpack(">Q", self._recv(8))[0]
        if b2 & 0x80: self._recv(4)  # сервер ниқоб намекунад
        return op, self._recv(ln)

    def send(self, event, data):
        payload = json.dumps({"event": event, "data": data}).encode()
        mask = os.urandom(4)
        hdr = bytes([0x81])
        n = len(payload)
        if n < 126: hdr += bytes([0x80 | n])
        elif n < 65536: hdr += bytes([0x80 | 126]) + struct.pack(">H", n)
        else: hdr += bytes([0x80 | 127]) + struct.pack(">Q", n)
        self.s.sendall(hdr + mask + bytes(c ^ mask[i % 4] for i, c in enumerate(payload)))

    def wait(self, event, timeout=3.0):
        """Ҳодисаи [event]-ро интизор мешавад; None — агар наомад."""
        end = time.time() + timeout
        while time.time() < end:
            self.s.settimeout(max(0.05, end - time.time()))
            try:
                op, data = self._frame()
            except (socket.timeout, TimeoutError):
                return None
            if op == 0x9:  # ping → pong
                mask = os.urandom(4)
                self.s.sendall(bytes([0x8A, 0x80 | len(data)]) + mask + bytes(c ^ mask[i % 4] for i, c in enumerate(data)))
                continue
            if op == 0x8: raise RuntimeError("ws closed by server")
            if op != 0x1: continue
            try: m = json.loads(data.decode())
            except Exception: continue
            if m.get("event") == event: return m.get("data")
        return None

    def close(self):
        try: self.s.close()
        except Exception: pass


S = os.environ.get("SUFFIX", "ch")
h = int(hashlib.sha1(S.encode()).hexdigest(), 16) % 200
ph = lambda i: f"+992900973{(h * 4 + i) % 1000:03d}"
tA, A = user(f"kha{S}", ph(0)); tB, Bb = user(f"khb{S}", ph(1))
tC, C = user(f"khc{S}", ph(2)); tD, D = user(f"khd{S}", ph(3))
ok("4 корбар сохта шуд", all([tA, tB, tC, tD]), (A, Bb, C, D))

wA, wB, wC = WS(tA), WS(tB), WS(tC)


def hist(tok, q=""):
    st, r = call("GET", "/calls/history" + q, tok=tok)
    return st, (r.get("items") if isinstance(r, dict) else None) or [], r


def first_with(tok, peer_id):
    _, items, _ = hist(tok)
    for it in items:
        if (it.get("peer") or {}).get("id") == peer_id: return it
    return None


# 1) Гуфтугӯи пурра: A → B, B қабул, 2с, A қатъ.
wA.send("call:offer", {"to": Bb, "callType": "voice", "offer": {}})
inc = wB.wait("call:incoming")
ok("B call:incoming гирифт", inc and inc.get("from") == A, inc)
st, items, _ = hist(tB)
ring = first_with(tB, A)
ok("ҳангоми занг сатр «ringing» аст", ring and ring.get("status") == "ringing" and ring.get("direction") == "incoming", ring)
wB.send("call:answer", {"to": A, "answer": {}})
ok("A call:answered гирифт", wA.wait("call:answered") is not None)
time.sleep(2.2)
wA.send("call:end", {"to": Bb})
ok("B call:ended гирифт", wB.wait("call:ended") is not None)
ea, eb = first_with(tA, Bb), first_with(tB, A)
ok("A: содиротӣ, completed", ea and ea["direction"] == "outgoing" and ea["status"] == "completed", ea)
ok("B: воридотӣ, completed", eb and eb["direction"] == "incoming" and eb["status"] == "completed", eb)
ok("давомнокӣ ≈ 2с (аз қабул, на аз занг)", ea and 1 <= ea.get("durationSec", 0) <= 6, ea)
ok("намуд voice, ҳамсӯҳбат бо ном/аватар", ea and ea.get("type") == "voice" and ea["peer"].get("username") == f"khb{S}", ea)
ok("answeredAt ва endedAt ҳаст", ea and ea.get("answeredAt") and ea.get("endedAt"), ea)

# 2) Аздастрафта: A → B (видео), A пеш аз ҷавоб қатъ мекунад.
wA.send("call:offer", {"to": Bb, "callType": "video", "offer": {}})
wB.wait("call:incoming")
wA.send("call:end", {"to": Bb}); wB.wait("call:ended")
ea, eb = first_with(tA, Bb), first_with(tB, A)
ok("A: cancelled (видео)", ea and ea["status"] == "cancelled" and ea["type"] == "video", ea)
ok("B: missed", eb and eb["status"] == "missed" and eb["direction"] == "incoming" and eb["durationSec"] == 0, eb)

# 3) Рад: C → A, A рад мекунад.
wC.send("call:offer", {"to": A, "callType": "voice", "offer": {}})
wA.wait("call:incoming")
wA.send("call:decline", {"to": C})
ok("C call:declined гирифт", wC.wait("call:declined") is not None)
ok("C: declined", (first_with(tC, A) or {}).get("status") == "declined", first_with(tC, A))
ok("A: declined", (first_with(tA, C) or {}).get("status") == "declined", first_with(tA, C))

# 4) Гузариш ба видео бо розигӣ → videoUsed.
wA.send("call:offer", {"to": Bb, "callType": "voice", "offer": {}})
wB.wait("call:incoming"); wB.send("call:answer", {"to": A, "answer": {}}); wA.wait("call:answered")
wA.send("call:switch", {"to": Bb, "mode": "video", "action": "request"})
sw = wB.wait("call:switch")
ok("B дархости видео гирифт", sw and sw.get("action") == "request" and sw.get("mode") == "video" and sw.get("from") == A, sw)
wB.send("call:switch", {"to": A, "mode": "video", "action": "accept"})
sw = wA.wait("call:switch")
ok("A розигиро гирифт", sw and sw.get("action") == "accept", sw)
wA.send("call:switch", {"to": Bb, "mode": "video", "action": "<script>"})
ok("call:switch-и нодуруст намерасад", wB.wait("call:switch", 1.0) is None)
wB.send("call:end", {"to": A}); wA.wait("call:ended")
ea = first_with(tA, Bb)
ok("videoUsed=true пас аз розигӣ", ea and ea.get("videoUsed") is True and ea["status"] == "completed", ea)

# 5) Саҳифабандӣ: A ҳоло 4 сатр дорад (B×3, C×1).
st, p1, r1 = hist(tA, "?limit=2")
ok("саҳифаи 1: 2 сатр + nextCursor", st == 200 and len(p1) == 2 and r1.get("nextCursor"), r1)
st, p2, r2 = hist(tA, "?limit=2&cursor=" + urllib.parse.quote(r1.get("nextCursor") or ""))
ok("саҳифаи 2: 2 сатр", st == 200 and len(p2) == 2, r2)
ids = [x["id"] for x in p1 + p2]
ok("бе такрор", len(set(ids)) == 4, ids)
ok("тартиб: навтарин аввал", [x["startedAt"] for x in p1 + p2] == sorted([x["startedAt"] for x in p1 + p2], reverse=True), [x["startedAt"] for x in p1 + p2])
st, p3, r3 = hist(tA, "?limit=2&cursor=" + urllib.parse.quote(r2.get("nextCursor") or ""))
ok("саҳифаи охир холӣ ва nextCursor=null", (st == 200 and len(p3) == 0 and r3.get("nextCursor") is None) or (r2.get("nextCursor") is None), (r2, r3))
st, _, _ = hist(tA, "?cursor=" + urllib.parse.quote("!!!вайрон"))
ok("курсори вайрон — 400", st == 400, st)
st, _ = call("GET", "/calls/history")
ok("бе вуруд — 401", st == 401, st)
st, _, rd = hist(tD)
ok("корбари бе занг — рӯйхати холӣ", st == 200 and rd.get("items") == [] and rd.get("nextCursor") is None, rd)

# 6) Бастан: A C-ро мебандад → сатрҳои A↔C аз ҳарду тараф пинҳон.
call("POST", f"/users/{C}/block", tok=tA)
ok("A: сатри C пинҳон (A баст)", first_with(tA, C) is None, first_with(tA, C))
ok("C: сатри A пинҳон (C басташуда)", first_with(tC, A) is None, first_with(tC, A))
wC.send("call:offer", {"to": A, "callType": "voice", "offer": {}})
ok("басташуда занг зада наметавонад", wA.wait("call:incoming", 1.0) is None)
call("POST", f"/users/{C}/unblock", tok=tA)
ok("пас аз кушодан сатр бармегардад", (first_with(tA, C) or {}).get("status") == "declined", first_with(tA, C))
ok("занги басташуда сабт нашуд", len([x for x in hist(tC)[1] if x["peer"]["id"] == A]) == 1, hist(tC)[1])

# 7) Нест кардан аз таърих — танҳо барои худ.
eb = first_with(tB, A)
st, _ = call("DELETE", f"/calls/history/{eb['id']}", tok=tB)
ok("B сатрро нест кард — 200", st == 200, st)
ok("B дигар онро намебинад", all(x["id"] != eb["id"] for x in hist(tB)[1]))
ok("A онро ҳанӯз мебинад", any(x["id"] == eb["id"] for x in hist(tA)[1]))
st, _ = call("DELETE", f"/calls/history/{eb['id']}", tok=tD)
ok("бегона сатри дигаронро нест карда наметавонад — 404", st == 404, st)
st, _ = call("DELETE", "/calls/history", tok=tB)
ok("B ҳамаи таърихро тоза кард", st == 200 and hist(tB)[1] == [], hist(tB)[1])
ok("таърихи A бетағйир", len(hist(tA)[1]) == 4, len(hist(tA)[1]))

for w in (wA, wB, wC): w.close()

bad = [x for x in res if not x[0]]
print()
for g, n, d in res: print(("  ✅ " if g else "  ❌ ") + n + ("" if g else f"\n       → {d}"))
print(f"\n{len(res) - len(bad)}/{len(res)} гузашт")
sys.exit(1 if bad else 0)
