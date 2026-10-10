#!/usr/bin/env python3
"""Аудити амиқ — хатоҳои ёфтшуда ва ислоҳи онҳо + се камбуди Instagram.

 Хатоҳо (пеш аз ислоҳ ҳар кадом «❌» медод):
  1. Актуалӣ модератсияро мегузаронд: сториси интизори санҷиш ё аз
     ҷониби admin несткарда ба актуалӣ илова мешуд ва ба ҳама намоён буд;
     номи дашномдор ва сториси бегона (storyIds) қабул мешуданд.
  2. Паёми худкор (Auto-DM) бе модератсия сабт мешуд — матни 18+ ба ДМ-и
     ҳар касе, ки шарҳ навишт, мерафт.
  3. Шарҳҳои корбари басташуда (ҳар ду тараф) зери пост ва Reel мемонданд.
  4. «Захирашуда»: пости бойгонии муаллиф ва пости несткардаи модератсия
     намоён буданд; аз захира баровардан постро дар папка «ятим»
     мегузошт (шумора ва муқова).
  5. Даъвати ҳамкорӣ ба пости баъдтар несткардаи модератсия тавсиф ва
     расмашро нишон медод.
 Камбудҳои Instagram (анҷом дода шуданд):
  A. Папкаи захира: иваз кардани ном (PATCH), баровардан аз папка.
  B. Шарҳҳои часпонидашуда (pin): то 3, танҳо соҳиб, танҳо шарҳи асосӣ.

 ⚠️ Танҳо сервери МАҲАЛЛӢ/CI. Қисми admin DATABASE_URL + psql мехоҳад.
"""
import hashlib, json, os, subprocess, sys, time, urllib.request, urllib.error

B = os.environ.get("BASE", "http://127.0.0.1:8099")
S = os.environ.get("SUFFIX", "au")
DB = os.environ.get("DATABASE_URL", "")
PW = "Test12345!"
IMG = "https://example.com/audit.jpg"
res = []


def _once(m, p, body=None, tok=None):
    req = urllib.request.Request(B + p, data=json.dumps(body).encode() if body is not None else None, method=m)
    req.add_header("Content-Type", "application/json")
    if tok:
        req.add_header("Authorization", "Bearer " + tok)
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
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


def call(m, p, body=None, tok=None):
    for a in range(4):
        st, r = _once(m, p, body, tok)
        if st != 429:
            return st, r
        time.sleep(4 * (a + 1))
    return st, r


def ok(n, c, d=""):
    res.append((bool(c), n, str(d)[:240]))


N = int(hashlib.sha1(("audit-" + S).encode()).hexdigest(), 16) % 10**6


def user(u, k):
    call("POST", "/auth/register", {"username": u, "email": f"{u}@example.com", "password": PW,
                                    "fullName": "Full " + u, "phone": f"+99295{N:06d}{k}"})
    st, r = call("POST", "/auth/login", {"email": u, "password": PW})
    usr = (r.get("user") or {}) if isinstance(r, dict) else {}
    return (r.get("accessToken") if isinstance(r, dict) else None), (usr.get("id") or usr.get("_id"))


def oid(r):
    if not isinstance(r, dict):
        return None
    return r.get("_id") or r.get("id") or (r.get("post") or {}).get("_id") or (r.get("reel") or {}).get("_id")


def ids(lst):
    return [x.get("_id") or x.get("id") for x in (lst or []) if isinstance(x, dict)]


def psql(sql):
    if not DB:
        return False
    try:
        subprocess.run(["psql", DB, "-v", "ON_ERROR_STOP=1", "-qc", sql], check=True,
                       capture_output=True, timeout=30)
        return True
    except Exception as e:
        print("⚠️ psql:", e)
        return False


tA, A = user(f"aua{S}", 1)
tB, Bb = user(f"aub{S}", 2)
tC, C = user(f"auc{S}", 3)
ADM = f"auadm{S}"
tAdm, Adm = user(ADM, 4)
# Ҳар санҷиши модератсия огоҳӣ (strike) медиҳад; 3 огоҳӣ → маҳдудкунӣ.
# Барои ҳамин ҳар қисм корбари худро дорад.
tE, E = user(f"aue{S}", 5)   # сторисҳои несткардаи admin
tF, F = user(f"auf{S}", 6)   # Auto-DM
tG, G = user(f"aug{S}", 7)   # постҳои тоза: шарҳ, захира, pin
tH, H = user(f"auh{S}", 8)   # пости шубҳанок бо ҳамкор
ok("корбарон сохта шуданд", all([tA, tB, tC, tAdm, tE, tF, tG, tH]), (A, Bb, C, Adm, E, F, G, H))
if not all([tA, tB, tC, tAdm, tE, tF, tG, tH]):
    print("!! вуруд нашуд"); sys.exit(1)
admin_ok = psql(f"UPDATE users SET role='admin' WHERE username='{ADM}'")


def highlight(uid, hid, tok):
    st, r = call("GET", f"/highlights/{uid}", tok=tok)
    return next((h for h in (r.get("highlights") or []) if h.get("_id") == hid), None)


# ═══ 1. Актуалӣ ва модератсия ═══════════════════════════════════════
st, s1 = call("POST", "/stories/", {"mediaUrl": IMG + "?ok", "mediaType": "image", "caption": "Субҳ"}, tA)
clean_sid = oid(s1)
st, s2 = call("POST", "/stories/", {"mediaUrl": IMG + "?held", "mediaType": "image",
                                    "caption": "My new sexy dress"}, tA)
held_sid = oid(s2)
ok("сториси шубҳанок пинҳон сабт шуд", st == 201 and held_sid, (st, s2))
st, sB = call("POST", "/stories/", {"mediaUrl": IMG + "?b", "mediaType": "image"}, tB)
foreign_sid = oid(sB)

st, h = call("POST", "/highlights/", {"title": "Сафар", "storyIds": [clean_sid, held_sid, foreign_sid],
                                      "items": [{"url": IMG + "?ok", "type": "image", "storyId": clean_sid},
                                                {"url": IMG + "?held", "type": "image", "storyId": held_sid},
                                                {"url": "https://evil.example/x.jpg", "type": "image",
                                                 "storyId": foreign_sid}]}, tA)
hid = oid(h)
ok("актуалӣ сохта шуд", st == 200 and hid, (st, h))
hh = highlight(A, hid, tB) or {}
got = [it.get("storyId") for it in hh.get("items") or []]
ok("сториси пинҳон ва бегона ба актуалӣ НАМЕАФТАНД (танҳо сториси тоза)",
   got == [clean_sid] and set(hh.get("storyIds") or []) == {clean_sid}, hh)
ok("суроғаи унсур аз худи сторис, на аз барнома",
   [it.get("url") for it in hh.get("items") or []] == [IMG + "?ok"], hh.get("items"))
st, r = call("POST", f"/highlights/{hid}/stories", {"storyId": held_sid}, tA)
ok("сториси интизори санҷиш ба актуалии мавҷуда илова намешавад (404)", st == 404, (st, r))
st, r = call("PATCH", f"/highlights/{hid}", {"items": [{"url": IMG + "?ok", "type": "image", "storyId": clean_sid},
                                                     {"url": "x", "type": "image", "storyId": held_sid}]}, tA)
hh = highlight(A, hid, tB) or {}
ok("PATCH низ сториси пинҳонро намегузорад", st == 200 and
   [it.get("storyId") for it in hh.get("items") or []] == [clean_sid], (st, hh))
st, r = call("POST", "/highlights/", {"title": "porn", "storyIds": [clean_sid]}, tA)
ok("номи 18+ → 403 content_blocked", st == 403 and isinstance(r, dict) and r.get("code") == "content_blocked", (st, r))
st, r = call("PATCH", f"/highlights/{hid}", {"title": "смотри порно"}, tA)
ok("иваз ба номи 18+ → 403", st == 403, (st, r))
hh = highlight(A, hid, tA) or {}
ok("номи кӯҳна боқӣ монд", hh.get("title") == "Сафар", hh.get("title"))
st, r = call("PATCH", f"/highlights/{hid}", {"coverUrl": "https://evil.example/cover.jpg"}, tA)
hh = highlight(A, hid, tA) or {}
ok("муқова танҳо аз унсурҳои худи актуалӣ", hh.get("coverUrl") == IMG + "?ok", hh.get("coverUrl"))

if admin_ok:
    # Admin сториси шубҳанокро тасдиқ кард → акнун илова мешавад; сториси
    # тозаро нест кард → аз актуалӣ ҳам бардошта мешавад.
    st, q = call("GET", "/admin/moderation/queue?status=pending&action=review", tok=tAdm)
    it = [x for x in (q.get("items") or []) if x.get("targetId") == held_sid]
    st, r = call("POST", f"/admin/moderation/queue/{it[0]['id'] if it else 0}/approve", tok=tAdm)
    ok("admin сториси шубҳанокро тасдиқ кард", st == 200, (st, r))
    st, r = call("POST", f"/highlights/{hid}/stories", {"storyId": held_sid}, tA)
    ok("баъди тасдиқ сторис ба актуалӣ илова мешавад", st == 200 and r.get("added") is True, (st, r))
    st, s0 = call("POST", "/stories/", {"mediaUrl": IMG + "?e", "mediaType": "image"}, tE)
    st, hE = call("POST", "/highlights/", {"title": "E", "storyIds": [oid(s0)]}, tE)
    hidE = oid(hE)
    st, s3 = call("POST", "/stories/", {"mediaUrl": IMG + "?rm", "mediaType": "image",
                                        "caption": "naked truth"}, tE)
    rm_sid = oid(s3)
    st, q = call("GET", "/admin/moderation/queue?status=pending&action=review", tok=tAdm)
    it = [x for x in (q.get("items") or []) if x.get("targetId") == rm_sid]
    st, r = call("POST", f"/admin/moderation/queue/{it[0]['id'] if it else 0}/remove", tok=tAdm)
    ok("admin сторисро нест кард", st == 200, (st, r))
    st, r = call("POST", f"/highlights/{hidE}/stories", {"storyId": rm_sid}, tE)
    ok("сториси несткардаи admin ба актуалӣ илова намешавад", st == 404, (st, r))
    # Сторисе, ки аллакай дар актуалӣ буд, баъд аз «Нест кардан»-и admin.
    st, s4 = call("POST", "/stories/", {"mediaUrl": IMG + "?later", "mediaType": "image"}, tE)
    later_sid = oid(s4)
    call("POST", f"/highlights/{hidE}/stories", {"storyId": later_sid}, tE)
    st, q = call("GET", "/admin/moderation/queue?status=pending", tok=tAdm)
    psql(f"INSERT INTO moderation_queue(user_id, surface, target_id, action, status) "
         f"VALUES('{E}','story','{later_sid}','review','pending')")
    st, q = call("GET", "/admin/moderation/queue?status=pending", tok=tAdm)
    it = [x for x in (q.get("items") or []) if x.get("targetId") == later_sid]
    st, r = call("POST", f"/admin/moderation/queue/{it[0]['id'] if it else 0}/remove", tok=tAdm)
    hh = highlight(E, hidE, tB) or {}
    ok("сториси дар актуалӣ буда баъди «Нест кардан» аз актуалӣ ҳам рафт",
       st == 200 and later_sid not in [x.get("storyId") for x in hh.get("items") or []]
       and later_sid not in (hh.get("storyIds") or []), (st, hh))
else:
    ok("admin: DATABASE_URL + psql лозим", False, "DATABASE_URL нест")

# ═══ 2. Auto-DM ва модератсия ═══════════════════════════════════════
st, p = call("POST", "/posts/", {"caption": "Китоби нав", "media": [{"url": IMG, "type": "image"}]}, tF)
fpid = oid(p)
st, r = call("PUT", f"/auto-dm/post/{fpid}", {"anyWord": True, "message": "watch porn now"}, tF)
ok("паёми худкори 18+ → 403 content_blocked", st == 403 and isinstance(r, dict)
   and r.get("code") == "content_blocked", (st, r))
st, r = call("PUT", f"/auto-dm/post/{fpid}", {"anyWord": True, "message": "Салом", "link": "https://onlyfans.com/me"}, tF)
ok("линки 18+ дар паёми худкор → 403", st == 403, (st, r))
st, r = call("PUT", f"/auto-dm/post/{fpid}", {"anyWord": True, "message": "Ташаккур! Нархнома:",
                                             "link": "https://raonson.tj"}, tF)
ok("паёми худкори тоза сабт шуд", st == 200 and r.get("exists") is True, (st, r))

st, p = call("POST", "/posts/", {"caption": "Китоби нав", "media": [{"url": IMG, "type": "image"}]}, tG)
pid = oid(p)
# ═══ 3. Шарҳҳои корбари басташуда ═══════════════════════════════════
st, r = call("POST", f"/comments/{pid}", {"text": f"шарҳи B {S}"}, tB)
cB = oid(r) or (r.get("comment") or {}).get("_id") if isinstance(r, dict) else None
st, r = call("POST", f"/comments/{pid}", {"text": f"шарҳи C {S}"}, tC)
st, rv = call("POST", "/reels/", {"videoUrl": "https://example.com/a.mp4", "caption": "Табиат"}, tG)
rid = oid(rv)
call("POST", f"/reels/{rid}/comments", {"text": f"шарҳи reel B {S}"}, tB)
call("POST", f"/users/{Bb}/block", tok=tG)
time.sleep(3.2)
st, r = call("GET", f"/comments/{pid}", tok=tG)
texts = [x.get("text") for x in r.get("comments") or []]
ok("G B-ро баст → шарҳи B зери пости G ба G намоён нест",
   f"шарҳи B {S}" not in texts and f"шарҳи C {S}" in texts, texts)
st, r = call("GET", f"/reels/{rid}/comments", tok=tG)
ok("… ва зери Reel ҳам", f"шарҳи reel B {S}" not in [x.get("text") for x in r.get("comments") or []],
   r.get("comments"))
call("POST", f"/users/{Bb}/unblock", tok=tG)

# ═══ 4. «Захирашуда» ва папкаҳо ═════════════════════════════════════
st, p2 = call("POST", "/posts/", {"caption": "Барои захира 1", "media": [{"url": IMG + "?s1", "type": "image"}]}, tG)
st, p3 = call("POST", "/posts/", {"caption": "Барои захира 2", "media": [{"url": IMG + "?s2", "type": "image"}]}, tG)
sp1, sp2 = oid(p2), oid(p3)
call("POST", f"/posts/{sp1}/save", tok=tB)
call("POST", f"/posts/{sp2}/save", tok=tB)
st, col = call("POST", "/collections", {"name": "Китобҳо"}, tB)
cid = oid(col)
call("POST", f"/collections/{cid}/posts", {"postId": sp1}, tB)
call("POST", f"/collections/{cid}/posts", {"postId": sp2}, tB)
st, r = call("POST", f"/posts/{sp1}/archive", tok=tG)
ok("муаллиф постро бойгонӣ кард", st == 200 and r.get("archived") is True, (st, r))
time.sleep(3.2)
st, r = call("GET", "/profile/saved", tok=tB)
saved = ids(r.get("posts"))
ok("пости бойгонии муаллиф дар «Захирашуда»-и дигарон нест", sp1 not in saved and sp2 in saved, saved)
st, r = call("GET", "/collections", tok=tB)
cc = next((x for x in r.get("collections") or [] if x.get("_id") == cid), {})
ok("шумораи папка пости бойгониро ҳисоб намекунад", cc.get("count") == 1, cc)
call("POST", f"/posts/{sp1}/archive", tok=tG)  # барқарор
if admin_ok:
    psql(f"UPDATE posts SET hidden=TRUE WHERE id='{sp2}'")
    time.sleep(3.2)
    st, r = call("GET", "/profile/saved", tok=tB)
    ok("пости несткардаи модератсия дар «Захирашуда» нест", sp2 not in ids(r.get("posts")), ids(r.get("posts")))
    psql(f"UPDATE posts SET hidden=FALSE WHERE id='{sp2}'")

st, r = call("POST", f"/posts/{sp2}/save", tok=tB)
ok("аз захира баровардан", st == 200 and r.get("saved") is False, (st, r))
st, r = call("GET", "/collections", tok=tB)
cc = next((x for x in r.get("collections") or [] if x.get("_id") == cid), {})
ok("пост аз папка ҳам баромад (шумора 1)", cc.get("count") == 1, cc)
call("POST", f"/posts/{sp2}/save", tok=tB)
st, r = call("GET", f"/profile/saved?collection={cid}", tok=tB)
ok("дубора захира — ба папка худ ба худ барнамегардад (мисли Instagram)",
   sp2 not in ids(r.get("posts")) and sp1 in ids(r.get("posts")), ids(r.get("posts")))

# A. Иваз кардани ном ва баровардан аз папка.
st, r = call("PATCH", f"/collections/{cid}", {"name": "  Китобҳои хуб  "}, tB)
ok("номи папка иваз шуд", st == 200 and r.get("name") == "Китобҳои хуб", (st, r))
st, r = call("PATCH", f"/collections/{cid}", {"name": "дуздӣ"}, tG)
ok("папкаи бегонаро иваз кардан мумкин нест (404)", st == 404, (st, r))
st, r = call("PATCH", f"/collections/{cid}", {"name": "   "}, tB)
ok("номи холӣ → 400", st == 400, (st, r))
st, r = call("GET", "/collections", tok=tB)
cc = next((x for x in r.get("collections") or [] if x.get("_id") == cid), {})
ok("номи нав дар рӯйхат", cc.get("name") == "Китобҳои хуб", cc)
st, r = call("DELETE", f"/collections/{cid}/posts/{sp1}", tok=tB)
ok("пост аз папка баромад", st == 200, (st, r))
st, r = call("GET", f"/profile/saved?collection={cid}", tok=tB)
ok("папка холӣ шуд, пост дар «Захирашуда» мемонад",
   ids(r.get("posts")) == [] and sp1 in ids(call("GET", "/profile/saved", tok=tB)[1].get("posts")), r)
st, r = call("DELETE", f"/collections/{cid}/posts/{sp1}", tok=tG)
ok("аз папкаи бегона баровардан мумкин нест (403)", st == 403, (st, r))

# ═══ 5. Даъвати ҳамкорӣ ба пости баъдтар несткардаи модератсия ══════
st, hp = call("POST", "/posts/", {"caption": "Сафари мо", "media": [{"url": IMG + "?h", "type": "image"}],
                                  "collaborators": [f"auc{S}"]}, tH)
inv_pid = oid(hp)
time.sleep(1.5)
st, r = call("GET", "/collabs/pending", tok=tC)
ok("даъвати ҳамкорӣ омад", inv_pid in [x.get("postId") for x in r.get("invites") or []], r)
if admin_ok:
    psql(f"UPDATE posts SET hidden=TRUE WHERE id='{inv_pid}'")  # admin «Нест кардан»
    st, r = call("GET", "/collabs/pending", tok=tC)
    ok("даъват ба пости несткарда тавсиф/расмашро дигар нишон намедиҳад",
       inv_pid not in [x.get("postId") for x in r.get("invites") or []], r)

# ═══ B. Шарҳҳои часпонидашуда ══════════════════════════════════════
st, pp = call("POST", "/posts/", {"caption": "Пин", "media": [{"url": IMG + "?pin", "type": "image"}]}, tG)
ppid = oid(pp)
cids = []
for i in range(5):
    st, r = call("POST", f"/comments/{ppid}", {"text": f"шарҳ {i}"}, tB if i % 2 else tC)
    cids.append(oid(r) or ((r.get("comment") or {}).get("_id") if isinstance(r, dict) else None))
ok("шарҳҳо навишта шуданд", all(cids), cids)
st, r = call("POST", f"/comments/{cids[0]}/pin", tok=tB)
ok("танҳо соҳиби пост мечаспонад (бегона → 404)", st == 404, (st, r))
st, r = call("POST", f"/comments/{cids[0]}/pin", tok=tG)
ok("соҳиб шарҳро часпонд", st == 200 and r.get("pinned") is True, (st, r))
time.sleep(3.2)
st, r = call("GET", f"/comments/{ppid}", tok=tB)
lst = r.get("comments") or []
ok("часпонидашуда аввал ва pinned:true", lst and lst[0].get("_id") == cids[0] and lst[0].get("pinned") is True
   and all(x.get("pinned") is False for x in lst[1:]), [(x.get("text"), x.get("pinned")) for x in lst])
call("POST", f"/comments/{cids[1]}/pin", tok=tG)
call("POST", f"/comments/{cids[2]}/pin", tok=tG)
st, r = call("POST", f"/comments/{cids[3]}/pin", tok=tG)
ok("шарҳи чорум → 409 (то 3)", st == 409 and r.get("code") == "pin_limit", (st, r))
st, r = call("POST", f"/comments/{cids[0]}/pin", tok=tG)
ok("бардоштани часп", st == 200 and r.get("pinned") is False, (st, r))
st, r = call("POST", f"/comments/{cids[3]}/pin", tok=tG)
ok("баъди бардоштан боз мечаспонад", st == 200 and r.get("pinned") is True, (st, r))
st, rep = call("POST", f"/comments/{ppid}", {"text": "ҷавоб", "parentId": cids[4]}, tC)
rep_id = oid(rep) or ((rep.get("comment") or {}).get("_id") if isinstance(rep, dict) else None)
if rep_id:
    st, r = call("POST", f"/comments/{rep_id}/pin", tok=tG)
    ok("ҷавобро часпондан мумкин нест (400)", st == 400, (st, r))
st, r = call("POST", f"/reels/{rid}/comments", {"text": "reel шарҳ"}, tC)
rcid = oid(r) or ((r.get("comment") or {}).get("_id") if isinstance(r, dict) else None)
st, r = call("POST", f"/reels/{rid}/comments/{rcid}/pin", tok=tC)
ok("Reel: бегона намечаспонад", st == 404, (st, r))
st, r = call("POST", f"/reels/{rid}/comments/{rcid}/pin", tok=tG)
ok("Reel: соҳиб мечаспонад", st == 200 and r.get("pinned") is True, (st, r))
time.sleep(3.2)
st, r = call("GET", f"/reels/{rid}/comments", tok=tB)
lst = r.get("comments") or []
ok("Reel: часпонидашуда аввал", lst and lst[0].get("_id") == rcid and lst[0].get("pinned") is True,
   [(x.get("text"), x.get("pinned")) for x in lst])
st, r = call("POST", f"/reels/{rid}/comments/{cids[1]}/pin", tok=tG)
ok("Reel: шарҳи пост бо id-и Reel → 404", st == 404, (st, r))

passed = sum(1 for p, _, _ in res if p)
for p, n, d in res:
    print(("  ✅ " if p else "  ❌ ") + n + ("" if p else "  → " + d))
print(f"\n{passed}/{len(res)} гузашт")
sys.exit(0 if passed == len(res) else 1)
