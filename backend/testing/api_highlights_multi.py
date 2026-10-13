#!/usr/bin/env python3
"""Актуалӣ аз якчанд сторис (экрани «Илова ба актуалӣ»).

 Санҷида мешавад:
  • POST /highlights/ бо якчанд storyIds — ҳамаашон унсур мешаванд,
    суроға аз сервер, тартиб нигоҳ дошта мешавад;
  • сториси бегона дар storyIds ба актуалӣ намеафтад;
  • POST /highlights/:id/stories {storyIds: [...]} — якчанд сторис
    якбора; такрор илова намешавад;
  • ҳама ё ҳеҷ: як сториси бегона дар рӯйхат → 404 ва ҳеҷ чиз илова
    намешавад;
  • рӯйхати холӣ → 400; актуалии бегона → 404;
  • storyId-и ягона (барномаҳои кӯҳна) ҳанӯз кор мекунад;
  • сторисҳои гузашта (бойгонӣ) низ илова мешаванд.
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
def ok(n, c, d=""): res.append((bool(c), n, str(d)[:240]))
def sid(r): return (r or {}).get("_id") or (r or {}).get("id") if isinstance(r, dict) else None
def story(tok, url, kind="image"):
    st, r = call("POST", "/stories/", {"mediaUrl": url, "mediaType": kind}, tok)
    return sid(r)
def hl(tok, owner, hid):
    st, r = call("GET", f"/highlights/{owner}", tok=tok)
    return next((e for e in (r.get("highlights") or []) if e.get("_id") == hid), {}) if isinstance(r, dict) else {}

S = os.environ.get("SUFFIX", "hm").lower()
IMG = "https://example.com/hm{}.jpg"; VID = "https://example.com/hm.mp4"
tA, A = user(f"hma{S}", "+992900664001")   # соҳиби актуалӣ
tB, Bb = user(f"hmb{S}", "+992900664002")  # бегона
ok("корбарон сохта шуданд", all([tA, tB]), [A, Bb])

s1, s2, s3 = story(tA, IMG.format(1)), story(tA, IMG.format(2)), story(tA, VID, "video")
s4, s5 = story(tA, IMG.format(4)), story(tA, IMG.format(5))
foreign = story(tB, IMG.format(9))
ok("сторисҳо сохта шуданд", all([s1, s2, s3, s4, s5, foreign]), [s1, s2, s3, s4, s5, foreign])

# ═══ 1. Сохтан бо якчанд сторис ════════════════════════════════════
st, h = call("POST", "/highlights/", {"title": "Сафар", "coverUrl": IMG.format(2),
             "storyIds": [s1, s2, s3, foreign]}, tA)
hid = sid(h)
ok("актуалӣ аз якчанд сторис сохта шуд", st == 200 and hid, (st, h))
items = (h or {}).get("items") or []
ok("ҳар сториси худам унсур шуд (бо тартиб)", [i.get("storyId") for i in items] == [s1, s2, s3], items)
ok("сториси бегона ба актуалӣ наафтод", foreign not in ((h or {}).get("storyIds") or []), h)
ok("суроға ва навъ аз сервер", items and items[2].get("type") == "video" and items[0].get("url") == IMG.format(1), items)
ok("муқова — яке аз унсурҳо", (h or {}).get("coverUrl") == IMG.format(2), (h or {}).get("coverUrl"))

# ═══ 2. Илова ба актуалии мавҷуда — якбора ═════════════════════════
st, r = call("POST", f"/highlights/{hid}/stories", {"storyIds": [s4, s5, s1]}, tA)
ok("якчанд сторис якбора илова шуд", st == 200 and r.get("added") is True and r.get("count") == 2, (st, r))
hh = hl(tA, A, hid)
ok("актуалӣ акнун 5 унсур дорад", [i.get("storyId") for i in hh.get("items") or []] == [s1, s2, s3, s4, s5], hh)
ok("storyIds ҳам нав шуд", set(hh.get("storyIds") or []) == {s1, s2, s3, s4, s5}, hh.get("storyIds"))

st, r = call("POST", f"/highlights/{hid}/stories", {"storyIds": [s4, s5]}, tA)
ok("такрор илова намешавад", st == 200 and r.get("added") is False, (st, r))
ok("баъди такрор ҳам 5 унсур", len(hl(tA, A, hid).get("items") or []) == 5)

# ═══ 3. Ҳама ё ҳеҷ ═══════════════════════════════════════════════════
s6 = story(tA, IMG.format(6))
st, r = call("POST", f"/highlights/{hid}/stories", {"storyIds": [s6, foreign]}, tA)
ok("сториси бегона дар рӯйхат → 404", st == 404, (st, r))
ok("ҳеҷ чиз илова нашуд (s6 ҳам не)", s6 not in [i.get("storyId") for i in hl(tA, A, hid).get("items") or []])
st, r = call("POST", f"/highlights/{hid}/stories", {"storyIds": [s6, "nonexistent-id"]}, tA)
ok("сториси нест → 404", st == 404, (st, r))
st, r = call("POST", f"/highlights/{hid}/stories", {"storyIds": []}, tA)
ok("рӯйхати холӣ → 400", st == 400, (st, r))
st, r = call("POST", f"/highlights/{hid}/stories", {"storyIds": ["", "  "]}, tA)
ok("id-ҳои холӣ → 400", st == 400, (st, r))
st, r = call("POST", f"/highlights/{hid}/stories", {"storyIds": [foreign]}, tB)
ok("ба актуалии бегона илова намешавад", st == 404, (st, r))

# ═══ 4. Мувофиқат бо барномаҳои кӯҳна ══════════════════════════════
st, r = call("POST", f"/highlights/{hid}/stories", {"storyId": s6}, tA)
ok("storyId-и ягона кор мекунад", st == 200 and r.get("added") is True and r.get("count") == 1, (st, r))

# ═══ 5. Сторисҳои бойгонӣ (рӯйхати экрани интихоб) ══════════════════
st, r = call("GET", "/archive/stories?limit=100", tok=tA)
mine = [sid(x) for x in (r.get("stories") or [])] if isinstance(r, dict) else []
ok("/archive/stories ҳамаи сторисҳои маро медиҳад", st == 200 and {s1, s2, s3, s4, s5, s6} <= set(mine), (st, len(mine)))
ok("/archive/stories сториси бегонаро намедиҳад", foreign not in mine)
call("POST", f"/stories/{s6}/archive", tok=tA)
st, h2 = call("POST", "/highlights/", {"title": "Бойгонӣ", "storyIds": [s6]}, tA)
ok("сториси бойгонишуда ба актуалии нав меравад", st == 200 and (h2.get("storyIds") or []) == [s6], (st, h2))

passed = sum(1 for p, _, _ in res if p)
for p, n, d in res:
    print(("  ✅ " if p else "  ❌ ") + n + ("" if p else "  → " + d))
print(f"\n{passed}/{len(res)} гузашт")
sys.exit(0 if passed == len(res) else 1)
