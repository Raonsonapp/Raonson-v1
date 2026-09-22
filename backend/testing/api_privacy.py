#!/usr/bin/env python3
"""Махфият: бастан ва ҳисоби пӯшида.

═══════════════════════════════════════════════════════════════════
 Ин санҷиш ШАШ камбудии ҷиддӣ ёфт. Бастан амалан танҳо ороиш буд:

   • корбари басташуда постҳои маро МЕДИД;
   • пости маро лайк карда МЕТАВОНИСТ;
   • шарҳ навишта МЕТАВОНИСТ;
   • обуна шуда МЕТАВОНИСТ;
   • ба ман паём фиристода МЕТАВОНИСТ ва огоҳинома мерафт.

 Ва ҳисоби ПӮШИДА постҳои худро ба ҳар бегона нишон медод — қулфи
 дар профил ҳеҷ маъно надошт.

 Сабаб: лентаи умумӣ ва Reels бастанро месанҷиданд, вале роҳҳои
 МУСТАҚИМ (`/users/:id/posts`, `/posts/:id/like`, `/comments/:id`,
 `/follow/:id`, `/chat/…`) — не.

 Истифода:
   BASE=http://127.0.0.1:8099 python3 backend/testing/api_privacy.py
═══════════════════════════════════════════════════════════════════
"""

import json
import os
import sys
import urllib.error
import urllib.request

BASE = os.environ.get("BASE", "http://127.0.0.1:8099")
PW = "Test12345!"
results = []


def call(method, path, body=None, token=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(BASE + path, data=data, method=method)
    req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", "Bearer " + token)
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            raw = r.read().decode()
            return r.status, (json.loads(raw) if raw else {})
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
        try:
            return e.code, json.loads(raw)
        except Exception:
            return e.code, raw
    except Exception as e:
        return 0, str(e)


def register(u, email, phone):
    st, _ = call("POST", "/auth/register", {
        "username": u, "email": email, "password": PW,
        "fullName": u, "phone": phone,
    })
    return st in (200, 201, 409)


def login(u):
    st, r = call("POST", "/auth/login", {"email": u, "password": PW})
    if not isinstance(r, dict):
        return None, {}
    return r.get("accessToken"), (r.get("user") or {})


def ok(name, condition, detail=""):
    results.append((bool(condition), name, detail))


def posts_of(resp):
    """Рӯйхати постҳо аз ҷавоб, ба ҳар шакл."""
    if isinstance(resp, dict):
        return resp.get("posts") or []
    return resp if isinstance(resp, list) else []


def main():
    s = os.environ.get("SUFFIX", "priv")
    a, b = f"pa{s}", f"pb{s}"
    register(a, f"{a}@example.com", "+992900300001")
    register(b, f"{b}@example.com", "+992900300002")

    ta, ua = login(a)
    tb, ub = login(b)
    if not (ta and tb):
        print("!! вуруд нашуд")
        return 1
    ida = ua.get("id") or ua.get("_id")
    idb = ub.get("id") or ub.get("_id")

    st, p = call("POST", "/posts/", {
        "media": [{"url": "https://example.com/p.jpg", "type": "image"}],
        "caption": "пости A",
    }, ta)
    pid = p.get("id") or p.get("_id") or (p.get("post") or {}).get("id") \
        if isinstance(p, dict) else None
    ok("пост сохта шуд", pid, p)

    # ── ҲИСОБИ ПӮШИДА ─────────────────────────────────────────────
    st, _ = call("PUT", "/profile/", {"isPrivate": True}, ta)
    ok("ҳисоб пӯшида шуд", st == 200, st)

    st, resp = call("GET", f"/users/{ida}/posts", token=tb)
    ok("ҳисоби ПӮШИДА постҳоро ба бегона НАМЕДИҲАД",
       st in (403, 404) or not posts_of(resp),
       f"HTTP {st}: {json.dumps(resp, ensure_ascii=False)[:140]}")

    # Худи соҳиб бояд постҳои худро БИНАД — вагарна ҳимоя аз ҳад
    # гузашта, барномаро мешиканад.
    st, mine = call("GET", f"/users/{ida}/posts", token=ta)
    ok("соҳиб постҳои ХУДро мебинад", st == 200 and posts_of(mine),
       f"HTTP {st}")

    st, fr = call("POST", f"/follow/{ida}", token=tb)
    st2, reqs = call("GET", "/follow/requests", token=ta)
    lst = reqs.get("requests") if isinstance(reqs, dict) else reqs
    ok("обуна ба ҳисоби пӯшида ДАРХОСТ мешавад, на фаврӣ", bool(lst),
       f"HTTP {st}/{st2}: {json.dumps(reqs, ensure_ascii=False)[:140]}")

    call("PUT", "/profile/", {"isPrivate": False}, ta)

    # ── БАСТАН ────────────────────────────────────────────────────
    st, _ = call("POST", f"/users/{idb}/block", token=ta)
    ok("бастан кор мекунад", st in (200, 201), st)

    st, resp = call("GET", f"/users/{ida}/posts", token=tb)
    ok("басташуда постҳои маро НАМЕБИНАД",
       st in (403, 404) or not posts_of(resp),
       f"HTTP {st}: {json.dumps(resp, ensure_ascii=False)[:140]}")

    if pid:
        st, _ = call("POST", f"/posts/{pid}/like", token=tb)
        ok("басташуда лайк карда НАМЕТАВОНАД", st in (403, 404), f"HTTP {st}")
        st, _ = call("POST", f"/comments/{pid}", {"text": "шарҳ"}, tb)
        ok("басташуда шарҳ навишта НАМЕТАВОНАД", st in (403, 404), f"HTTP {st}")

    st, _ = call("POST", f"/follow/{ida}", token=tb)
    ok("басташуда обуна шуда НАМЕТАВОНАД", st in (403, 404), f"HTTP {st}")

    st, h = call("GET", f"/chat/with/{ida}", token=tb)
    ok("басташуда чат кушода НАМЕТАВОНАД", st in (403, 404), f"HTTP {st}")

    # Ҳатто агар chatID-ро худаш созад, паём набояд равад.
    cid = "_".join(sorted([ida or "", idb or ""]))
    st, _ = call("POST", f"/chat/{cid}/messages",
                 {"text": "паём", "clientId": "blk-1"}, tb)
    ok("басташуда паём фиристода НАМЕТАВОНАД, ҳатто бо chatID-и дастӣ",
       st in (403, 404), f"HTTP {st}")

    # ── КУШОДАН ───────────────────────────────────────────────────
    call("POST", f"/users/{idb}/unblock", token=ta)
    st, resp = call("GET", f"/users/{ida}/posts", token=tb)
    ok("баъди кушодан постҳо боз намоён мешаванд",
       st == 200 and posts_of(resp), f"HTTP {st}")
    st, _ = call("GET", f"/chat/with/{ida}", token=tb)
    ok("баъди кушодан чат боз кушода мешавад", st == 200, f"HTTP {st}")

    n = sum(1 for r in results if r[0])
    print()
    print("=" * 72)
    print(f"  {n}/{len(results)} гузашт")
    print("=" * 72)
    for good, name, detail in results:
        extra = "" if good else "  " + str(detail)[:150]
        print(f"{'OK  ' if good else 'FAIL'} {name}{extra}")
    return 0 if n == len(results) else 1


if __name__ == "__main__":
    sys.exit(main())
