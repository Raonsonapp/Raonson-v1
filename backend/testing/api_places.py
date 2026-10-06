#!/usr/bin/env python3
"""«Ҷой»-и пост — мисли Instagram: рӯйхати ҷойҳо, «Ҷойи ҳозираи ман»
 ва саҳифаи ҷой.

 Санҷида мешавад:
  • ҷустуҷӯ дар тоҷикӣ / русӣ / лотинӣ («Хуҷанд» = «Худжанд» = «Khujand»);
  • ҷойи наздиктарин аз координатаҳои Душанбе → Душанбе;
  • пост бо locationId дар /places/:id/posts пайдо мешавад;
  • пости кӯҳна (танҳо матн) низ дар саҳифаи ҷой аст;
  • ҳисоби пӯшида ва бастшуда дар саҳифаи ҷой ПИНҲОН.
 ⚠️ Ба сервери МАҲАЛЛӢ мезанад.
"""
import json, os, sys, time, urllib.parse, urllib.request, urllib.error
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
def ok(n, c, d=""): res.append((bool(c), n, str(d)[:220]))
def q(s): return urllib.parse.quote(s)
def ids(r, key="places"): return [x.get("id") or x.get("_id") for x in (r.get(key) or [])] if isinstance(r, dict) else []

S = os.environ.get("SUFFIX", "pl")
tA, A = user(f"pla{S}", "+992900988001")   # муаллифи кушода
tB, Bb = user(f"plb{S}", "+992900988002")  # тамошобин
tC, C = user(f"plc{S}", "+992900988003")   # ҳисоби пӯшида
tD, D = user(f"pld{S}", "+992900988004")   # тамошобинро баст
ok("корбарон сохта шуданд", all([tA, tB, tC, tD]), [A, Bb, C, D])

# ── Ҷустуҷӯ: се хат, як ҷой ─────────────────────────────────────
for s in ("Хуҷанд", "Khujand", "Худжанд", "хуҷ", "Ходжент"):
    st, r = call("GET", "/places/search?q=" + q(s), tok=tB)
    ok(f"ҷустуҷӯи «{s}» → Хуҷанд аввал", st == 200 and ids(r)[:1] == ["tj-khujand"], f"HTTP {st} {ids(r)[:3]}")
for s in ("Варзоб", "Varzob", "Варзобский"):
    st, r = call("GET", "/places/search?q=" + q(s), tok=tB)
    ok(f"ҷустуҷӯи «{s}» → Варзоб аввал", ids(r)[:1] == ["tj-varzob"], ids(r)[:3])
for s in ("Душанбе", "dushanbe", "ДУШАНБЕ"):
    st, r = call("GET", "/places/search?q=" + q(s), tok=tB)
    ok(f"ҷустуҷӯи «{s}» → Душанбе аввал", ids(r)[:1] == ["tj-dushanbe"], ids(r)[:3])
st, r = call("GET", "/places/search?q=" + q("Хуҷанд"), tok=tB)
top = (r.get("places") or [{}])[0] if isinstance(r, dict) else {}
ok("натиҷа ном ва минтақа дорад", top.get("name") == "Хуҷанд" and "Суғд" in (top.get("region") or ""), top)
ok("натиҷа координатаҳои ҷой дорад", isinstance(top.get("lat"), (int, float)) and isinstance(top.get("lon"), (int, float)), top)
st, r = call("GET", "/places/search?q=" + q("Khujand") + "&lang=ru", tok=tB)
ok("lang=ru → номи русӣ", ((r.get("places") or [{}])[0]).get("name") == "Худжанд", r.get("places", [])[:1])
st, r = call("GET", "/places/search?q=" + q("Маскав"), tok=tB)
ok("шаҳрҳои ҷаҳон: «Маскав» → Москва", ids(r)[:1] == ["w-ru-moscow"], ids(r)[:3])
st, r = call("GET", "/places/search?q=", tok=tB)
ok("ҷустуҷӯи холӣ → шаҳрҳои калон (Душанбе аввал)", st == 200 and ids(r)[:1] == ["tj-dushanbe"], ids(r)[:3])
st, r = call("GET", "/places/search?q=" + q("zzzqqqxx"), tok=tB)
ok("ҷустуҷӯи бемаъно → рӯйхати холӣ, на хато", st == 200 and r.get("places") == [], f"HTTP {st} {r}")
st, r = call("GET", "/places/search?q=" + q("Бӯстон") + "&lat=40.52&lon=69.33", tok=tB)
ok("наздикӣ: «Бӯстон» дар назди Мастчоҳ → деҳаи Мастчоҳ аввал", ids(r)[:1] == ["tj-mastchoh-buston"], ids(r)[:3])
st, r = call("GET", "/places/search?q=" + q("Хуҷанд"))
ok("бе воридшавӣ — 401", st == 401, f"HTTP {st}")

# ── Ҷойи наздиктарин ────────────────────────────────────────────
st, r = call("GET", "/places/nearest?lat=38.5598&lon=68.7870", tok=tB)
ok("наздиктарин аз маркази Душанбе → Душанбе", st == 200 and (r.get("place") or {}).get("id") == "tj-dushanbe", f"HTTP {st} {r.get('place') if isinstance(r, dict) else r}")
ok("наздиктарин: рӯйхати ҷойҳои наздик ҳаст", len(r.get("nearby") or []) >= 3, len(r.get("nearby") or []))
st, r = call("GET", "/places/nearest?lat=38.58&lon=68.73", tok=tB)
ok("ноҳияи Сино ҳам → Душанбе (на ноҳия)", (r.get("place") or {}).get("id") == "tj-dushanbe", r.get("place"))
st, r = call("GET", "/places/nearest?lat=40.28&lon=69.62", tok=tB)
ok("наздиктарин аз Хуҷанд → Хуҷанд", (r.get("place") or {}).get("id") == "tj-khujand", r.get("place"))
st, r = call("GET", "/places/nearest?lat=-40&lon=-140", tok=tB)
ok("мобайни уқёнус → place: null", st == 200 and r.get("place") is None, r)
st, r = call("GET", "/places/nearest?lat=abc&lon=1", tok=tB)
ok("координатаи нодуруст → 400", st == 400, f"HTTP {st}")
st, r = call("GET", "/places/nearest?lat=95&lon=10", tok=tB)
ok("lat > 90 → 400", st == 400, f"HTTP {st}")
st, r = call("GET", "/places/tj-varzob", tok=tB)
ok("GET /places/:id", st == 200 and (r.get("place") or {}).get("name") == "Варзоб", r)
st, r = call("GET", "/places/nope-123", tok=tB)
ok("ҷойи нест → 404", st == 404, f"HTTP {st}")

# ── Пост бо ҷой ─────────────────────────────────────────────────
media = [{"url": "https://example.com/pl.jpg", "type": "image"}]
st, p = call("POST", "/posts/", {"caption": f"Варзоб {S}", "media": media, "location": "Варзоб", "locationId": "tj-varzob"}, tA)
pid = p.get("_id") if isinstance(p, dict) else None
ok("пост бо locationId сохта шуд", st in (200, 201) and pid, f"HTTP {st} {p}")
ok("ҷавоби эҷод locationId дорад", isinstance(p, dict) and p.get("locationId") == "tj-varzob", p)
# Барномаи кӯҳна: танҳо матн (ном айнан ба ҷой мувофиқ).
st, p2 = call("POST", "/posts/", {"caption": f"кӯҳна {S}", "media": media, "location": "Varzob"}, tA)
pid2 = p2.get("_id") if isinstance(p2, dict) else None
ok("пости кӯҳна (танҳо матн) ҳам ба ҷой баста шуд", isinstance(p2, dict) and p2.get("locationId") == "tj-varzob", p2)
# Ҷойи дастӣ (берун аз рӯйхат).
custom = f"Чойхонаи Роҳат {S}"
st, p3 = call("POST", "/posts/", {"caption": f"дастӣ {S}", "media": media, "location": custom}, tA)
pid3 = p3.get("_id") if isinstance(p3, dict) else None
ok("ҷойи дастӣ: матн боқӣ, id холӣ", isinstance(p3, dict) and p3.get("location") == custom and not p3.get("locationId"), p3)
# id-и бофта қабул намешавад.
st, p4 = call("POST", "/posts/", {"caption": f"бад {S}", "media": media, "location": "Ҷое", "locationId": "fake-id"}, tA)
ok("locationId-и бофта рад мешавад (матн мемонад)", isinstance(p4, dict) and not p4.get("locationId") and p4.get("location") == "Ҷое", p4)
# Пости ҳисоби пӯшида ва ҳисобе, ки тамошобинро баст.
call("PUT", "/profile/", {"isPrivate": True}, tC)
st, pc = call("POST", "/posts/", {"caption": f"пӯшида {S}", "media": media, "location": "Варзоб", "locationId": "tj-varzob"}, tC)
pidC = pc.get("_id") if isinstance(pc, dict) else None
st, pd = call("POST", "/posts/", {"caption": f"баст {S}", "media": media, "location": "Варзоб", "locationId": "tj-varzob"}, tD)
pidD = pd.get("_id") if isinstance(pd, dict) else None
call("POST", f"/users/{Bb}/block", tok=tD)
time.sleep(3.5)

st, r = call("GET", "/places/tj-varzob/posts?limit=60", tok=tB)
got = ids(r, "posts")
ok("саҳифаи ҷой: 200 ва place", st == 200 and (r.get("place") or {}).get("id") == "tj-varzob", f"HTTP {st}")
ok("саҳифаи ҷой: пост бо locationId ҳаст", pid in got, got[:5])
ok("саҳифаи ҷой: пости кӯҳна (матн) ҳаст", pid2 in got, got[:5])
ok("саҳифаи ҷой: ҳисоби пӯшида ПИНҲОН", pidC and pidC not in got, got[:5])
ok("саҳифаи ҷой: бастшуда ПИНҲОН", pidD and pidD not in got, got[:5])
ok("саҳифаи ҷой: ҷойи дастӣ дар ин ҷо нест", pid3 not in got, got[:5])
x = next((y for y in (r.get("posts") or []) if y.get("_id") == pid), {})
ok("пост дар саҳифа locationId ва location дорад", x.get("locationId") == "tj-varzob" and x.get("location") == "Варзоб", {k: x.get(k) for k in ("location", "locationId")})
st, r = call("GET", "/places/tj-khujand/posts", tok=tB)
ok("ҷойи дигар — пости Варзоб нест", pid not in ids(r, "posts"), ids(r, "posts")[:3])
st, r = call("GET", "/places/nope-123/posts", tok=tB)
ok("саҳифаи ҷойи нест → 404", st == 404, f"HTTP {st}")

# Ҷойи дастӣ — аз рӯи матн.
st, r = call("GET", "/places/text/posts?name=" + q(custom), tok=tB)
ok("ҷойи дастӣ: постҳо аз рӯи матн", st == 200 and pid3 in ids(r, "posts"), f"HTTP {st} {ids(r, 'posts')[:3]}")
ok("ҷойи дастӣ: place нест", isinstance(r, dict) and r.get("place") is None, r.get("place") if isinstance(r, dict) else r)
st, r = call("GET", "/places/text/posts?name=" + q("Худжанд"), tok=tB)
ok("матн ба ҷойи рӯйхат мувофиқ → place бармегардад", (r.get("place") or {}).get("id") == "tj-khujand", r.get("place"))
st, r = call("GET", "/places/text/posts?name=", tok=tB)
ok("матни холӣ → 400", st == 400, f"HTTP {st}")

# Пост аз рӯи ID ва лента ҳам locationId доранд.
st, r = call("GET", f"/posts/{pid}", tok=tB)
ok("GET /posts/:id → locationId", isinstance(r, dict) and r.get("locationId") == "tj-varzob", {k: r.get(k) for k in ("location", "locationId")} if isinstance(r, dict) else r)
st, r = call("GET", f"/users/{A}/posts", tok=tB)
x = next((y for y in (r.get("posts") if isinstance(r, dict) else r) or [] if y.get("_id") == pid), {})
ok("профил → locationId", x.get("locationId") == "tj-varzob", {k: x.get(k) for k in ("location", "locationId")})

bad = [x for x in res if not x[0]]
print()
for g, n, d in res: print(("  ✅ " if g else "  ❌ ") + n + ("" if g else f"\n       → {d}"))
print(f"\n{len(res) - len(bad)}/{len(res)} гузашт")
sys.exit(1 if bad else 0)
