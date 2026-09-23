#!/usr/bin/env python3
"""Ҷонишинҳо дар профил ва Alt text-и расм — мисли Instagram.
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
def ok(n, c, d=""): res.append((bool(c), n, str(d)[:200]))
S = os.environ.get("SUFFIX", "pa")
tA, A = user(f"ya{S}", "+992900960001"); tB, Bb = user(f"yb{S}", "+992900960002")

st, r = call("PUT", "/profile/", {"pronouns": "she / her, she"}, tA)
ok("ҷонишин нигоҳ дошта шуд ва тоза шуд", (r.get("user") or {}).get("pronouns") == "she/her", r.get("user", {}).get("pronouns") if isinstance(r, dict) else r)
time.sleep(3.5)
st, r = call("GET", f"/users/{A}", tok=tB)
ok("бегона ҷонишинро дар профил мебинад", r.get("pronouns") == "she/her", r.get("pronouns"))
st, r = call("PUT", "/profile/", {"bio": "бе ҷонишин"}, tA)
ok("иваз кардани био ҷонишинро пок НАМЕКУНАД", (r.get("user") or {}).get("pronouns") == "she/her", r)
st, r = call("PUT", "/profile/", {"pronouns": ""}, tA)
ok("ҷонишин хориҷ мешавад", (r.get("user") or {}).get("pronouns") == "", r)

st, p = call("POST", "/posts/", {"caption": "бо alt", "media": [
    {"url": "https://example.com/1.jpg", "type": "image", "alt": "Ду кас дар боғ, шом"},
    {"url": "https://example.com/2.jpg", "type": "image"}]}, tA)
pid = p.get("_id") or p.get("id")
st, r = call("GET", f"/posts/{pid}", tok=tA)
media = r.get("media") or (r.get("post") or {}).get("media") or []
ok("alt text ба пост сабт шуд", media and media[0].get("alt") == "Ду кас дар боғ, шом", media)
ok("расми бе alt — холӣ, на хато", len(media) > 1 and media[1].get("alt") == "", media)
st, r = call("GET", "/posts/feed?limit=30", tok=tA)
fm = next((x for x in r.get("posts", []) if x.get("_id") == pid), {}).get("media", [])
ok("alt дар лента низ меояд", fm and fm[0].get("alt") == "Ду кас дар боғ, шом", fm)
st, p2 = call("POST", "/posts/", {"caption": "x", "media": [{"url": "https://example.com/3.jpg", "type": "image", "alt": "а" * 300}]}, tA)
st, r = call("GET", f"/posts/{p2.get('_id') or p2.get('id')}", tok=tA)
m2 = (r.get("media") or [{}])[0]
ok("alt аз 100 ҳарф дарозтар бурида мешавад", len(m2.get("alt", "")) == 100, len(m2.get("alt", "")))

bad = [x for x in res if not x[0]]
print()
for g, n, d in res: print(("  ✅ " if g else "  ❌ ") + n + ("" if g else f"\n       → {d}"))
print(f"\n{len(res) - len(bad)}/{len(res)} гузашт")
sys.exit(1 if bad else 0)
