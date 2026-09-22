#!/usr/bin/env python3
"""Санҷиши ИҶОЗАТ: оё корбари бегона ба моли ман даст расонда метавонад?

═══════════════════════════════════════════════════════════════════
 Ин навъи камбудӣ аз ҳама хатарноктарин аст ва аз ҳама камтар дида
 мешавад: ҳама чиз «кор мекунад», то рӯзе ки касе кашф мекунад, ки
 пости бегонаро нест карда метавонад.

 Ду камбудӣ маҳз дар ин санҷиш ёфт шуданд:

   1. `POST /posts/:id/pin` аз корбари бегона 200 бармегардонд.
      Маълумот ҳимоя буд, вале ҶАВОБ дурӯғ мегуфт — барнома постро
      «санҷонида» нишон медод ва баъди навсозӣ он бармегашт.

   2. СОҲИБИ ПОСТ шарҳи нохушро дар зери пости ХУДАШ нест карда
      наметавонист — танҳо муаллифи шарҳ метавонист. Дар Instagram
      ҳарду метавонанд.

 Истифода:
   BASE=http://127.0.0.1:8099 python3 backend/testing/api_authz.py
═══════════════════════════════════════════════════════════════════
"""

import json
import os
import sys
import time
import urllib.error
import urllib.request

BASE = os.environ.get("BASE", "http://127.0.0.1:8099")
PW = "Test12345!"
results = []


# ⚠️ 429 — лимити дархост, на камбудӣ.
#
# Чор санҷиш пайдарпай кор мекунанд ва ҳар кадом корбари нав
# месозад. Роҳи `/auth` лимит дорад (ин дуруст аст — вагарна
# пароли касеро кофтан мумкин мебуд). Пас ин ҷо интизор мешавем,
# на ин ки санҷишро «афтид» ҳисоб кунем.
_RETRY_ON = (429,)


def _call_once(method, path, body=None, token=None):
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



def call(method, path, body=None, token=None):
    """Дархост бо интизории худкор ҳангоми лимит."""
    for attempt in range(4):
        st, resp = _call_once(method, path, body, token)
        if st not in _RETRY_ON:
            return st, resp
        time.sleep(4 * (attempt + 1))
    return st, resp

def register(username, email, phone):
    st, _ = call("POST", "/auth/register", {
        "username": username, "email": email, "password": PW,
        "fullName": username, "phone": phone,
    })
    return st in (200, 201, 409)


def login(username):
    st, r = call("POST", "/auth/login", {"email": username, "password": PW})
    if not isinstance(r, dict):
        return None, {}
    return r.get("accessToken"), (r.get("user") or {})


def deny(name, method, path, body=None, token=None):
    """Бояд РАД шавад. 200 ин ҷо камбудӣ аст."""
    st, r = call(method, path, body, token)
    results.append((st in (401, 403, 404), name, st, r))


def allow(name, method, path, body=None, token=None):
    st, r = call(method, path, body, token)
    results.append((st in (200, 201, 204), name, st, r))


def main():
    suffix = os.environ.get("SUFFIX", "authz")
    a, b = f"owner{suffix}", f"other{suffix}"
    register(a, f"{a}@example.com", "+992900200001")
    register(b, f"{b}@example.com", "+992900200002")

    t_owner, _ = login(a)
    t_other, _ = login(b)
    if not (t_owner and t_other):
        print("!! вуруд нашуд")
        return 1

    st, p = call("POST", "/posts/", {
        "media": [{"url": "https://example.com/z.jpg", "type": "image"}],
        "caption": "пости соҳиб",
    }, t_owner)
    pid = None
    if isinstance(p, dict):
        pid = p.get("id") or p.get("_id") or (p.get("post") or {}).get("id")
    results.append((bool(pid), "пост сохта шуд", st, p if not pid else ""))

    if pid:
        for name, method, path, body in [
            ("нест кардани пости бегона", "DELETE", f"/posts/{pid}", None),
            ("иваз кардани матни пости бегона", "PUT", f"/posts/{pid}/caption",
             {"caption": "вайрон"}),
            ("иваз кардани музикаи пости бегона", "PUT", f"/posts/{pid}/music",
             {"song": {"title": "x", "artist": "y"}}),
            ("санҷондани пости бегона (pin)", "POST", f"/posts/{pid}/pin", None),
            ("бойгонии пости бегона", "POST", f"/posts/{pid}/archive", None),
            ("пинҳон кардани лайкҳои бегона", "POST", f"/posts/{pid}/hide-likes",
             None),
            ("хомӯш кардани шарҳҳои бегона", "POST",
             f"/posts/{pid}/toggle-comments", None),
        ]:
            deny(name, method, path, body, t_other)

        # Баъди ҳамаи ин пост бояд бетағйир монад.
        st, g = call("GET", f"/posts/{pid}", token=t_owner)
        results.append((st == 200, "пост баъди ҳамлаҳо зинда аст", st,
                        g if st != 200 else ""))

    # Бе токен ё бо токени сохта
    deny("тағйири профил бе токен", "PUT", "/profile/", {"bio": "вайрон"})
    deny("сессияҳо бе токен", "GET", "/auth/sessions")
    deny("паём бе токен", "POST", "/chat/x/messages", {"text": "x"})
    deny("токени сохта", "GET", "/profile/me", None, "sohta.token.qalbaki")

    # Модератсияи шарҳ — маҳз мисли Instagram
    if pid:
        st, c = call("POST", f"/comments/{pid}", {"text": "шарҳи бегона"},
                     t_other)
        cid = None
        if isinstance(c, dict):
            cid = c.get("id") or c.get("_id") or (c.get("comment") or {}).get("id")
        if cid:
            deny("иваз кардани шарҳи бегона", "PUT", f"/comments/{cid}",
                 {"text": "вайрон"}, t_owner)
            allow("СОҲИБИ ПОСТ шарҳро нест карда метавонад", "DELETE",
                  f"/comments/{cid}", None, t_owner)

    ok = sum(1 for r in results if r[0])
    print()
    print("=" * 72)
    print(f"  {ok}/{len(results)} гузашт")
    print("=" * 72)
    for good, name, st, detail in results:
        extra = ""
        if not good:
            d = detail if isinstance(detail, str) else json.dumps(
                detail, ensure_ascii=False)
            extra = "  " + d[:150]
        print(f"{'OK  ' if good else 'FAIL'} [{st}] {name}{extra}")
    return 0 if ok == len(results) else 1


if __name__ == "__main__":
    sys.exit(main())
