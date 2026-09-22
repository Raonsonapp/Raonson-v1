#!/usr/bin/env python3
"""Бахшҳои чуқур: дӯстони наздик, Reels, калимаҳои пинҳон, папкаҳо, гурӯҳ.

═══════════════════════════════════════════════════════════════════
 `api_smoke.py` мепурсад «роҳ ҷавоб медиҳад?». Ин файл мепурсад
 «оё он чи ваъда шудааст, ВОҚЕАН мешавад?»:

   • стории «дӯстони наздик» ба каси БЕГОНА нарасад;
   • шарҳи дорои калимаи пинҳон ба соҳиб НАнамояд — вале
     НАВИСАНДА онро бинад (вагарна мефаҳмад ва роҳи гузаштан
     меҷӯяд);
   • паёми гурӯҳ ба ғайри аъзо нарасад;
   • Reel сохта, лайк, шарҳ, тамошо ва нигоҳ дошта шавад;
   • пости ба папка иловашуда дар ҳамон папка бошад.

 Истифода:
   BASE=http://127.0.0.1:8099 python3 backend/testing/api_deep.py
═══════════════════════════════════════════════════════════════════
"""

import json, os, sys, time, urllib.request, urllib.error
B=os.environ.get("BASE","http://127.0.0.1:8099"); PW="Test12345!"
res=[]
# ⚠️ 429 — лимити дархост, на камбудӣ.
#
# Чор санҷиш пайдарпай кор мекунанд ва ҳар кадом корбари нав
# месозад. Роҳи `/auth` лимит дорад (ин дуруст аст — вагарна
# пароли касеро кофтан мумкин мебуд). Пас ин ҷо интизор мешавем,
# на ин ки санҷишро «афтид» ҳисоб кунем.
_RETRY_ON = (429,)


def _call_once(m,p,body=None,tok=None):
    req=urllib.request.Request(B+p,data=json.dumps(body).encode() if body is not None else None,method=m)
    req.add_header('Content-Type','application/json')
    if tok: req.add_header('Authorization','Bearer '+tok)
    try:
        with urllib.request.urlopen(req,timeout=30) as r:
            raw=r.read().decode(); return r.status,(json.loads(raw) if raw else {})
    except urllib.error.HTTPError as e:
        raw=e.read().decode()
        try: return e.code,json.loads(raw)
        except Exception: return e.code,raw
    except Exception as e: return 0,str(e)
def reg(u,e,p):
    st,_=call("POST","/auth/register",{"username":u,"email":e,"password":PW,"fullName":u,"phone":p}); return st in (200,201,409)
def login(u):
    st,r=call("POST","/auth/login",{"email":u,"password":PW})
    return (r.get("accessToken") if isinstance(r,dict) else None),(r.get("user") or {} if isinstance(r,dict) else {})
def ok(n,c,d=""): res.append((bool(c),n,d))


def call(m, p, body=None, tok=None):
    """Дархост бо интизории худкор ҳангоми лимит."""
    for attempt in range(4):
        st, resp = _call_once(m, p, body, tok)
        if st not in _RETRY_ON:
            return st, resp
        time.sleep(4 * (attempt + 1))
    return st, resp

S=os.environ.get("SUFFIX","deep")
A,Bu,C=f"da{S}",f"db{S}",f"dc{S}"
for i,(u,) in enumerate([(A,),(Bu,),(C,)]):
    reg(u,f"{u}@example.com",f"+99290040000{i}")
tA,uA=login(A); tB,uB=login(Bu); tC,uC=login(C)
idA=uA.get("id") or uA.get("_id"); idB=uB.get("id") or uB.get("_id"); idC=uC.get("id") or uC.get("_id")
if not (tA and tB and tC): print("!! вуруд нашуд"); sys.exit(1)

# ҳама ба A обуна мешаванд (то стори бинанд)
call("POST",f"/follow/{idA}",tok=tB); call("POST",f"/follow/{idA}",tok=tC)

# ── ДӮСТОНИ НАЗДИК: B дӯсти наздик, C не ──
st,_=call("POST",f"/close-friends/{idB}",tok=tA)
ok("илова ба дӯстони наздик", st in (200,201), st)
st,ids=call("GET","/close-friends/ids",tok=tA)
lst=ids.get("ids") if isinstance(ids,dict) else ids
ok("B дар рӯйхати дӯстони наздик аст", idB in (lst or []), lst)

st,s=call("POST","/stories/",{"mediaUrl":"https://example.com/cf.jpg","mediaType":"image",
                              "audience":"close"},tA)
sid=s.get("id") or s.get("_id") or (s.get("story") or {}).get("id") if isinstance(s,dict) else None
ok("стори барои дӯстони наздик сохта шуд", sid, s)

def sees(tok):
    st,r=call("GET","/stories/",tok=tok)
    groups=r.get("stories") if isinstance(r,dict) else r
    txt=json.dumps(groups,ensure_ascii=False)
    return sid and sid in txt
ok("дӯсти НАЗДИК сторийро мебинад", sees(tB), "")
ok("ғайри дӯсти наздик сторийро НАМЕБИНАД", not sees(tC), "")

# ── REELS ──
st,r=call("POST","/reels/",{"videoUrl":"https://example.com/v.mp4",
                           "thumbnailUrl":"https://example.com/t.jpg","caption":"reel"},tA)
rid=r.get("id") or r.get("_id") or (r.get("reel") or {}).get("id") if isinstance(r,dict) else None
ok("Reel сохта шуд", rid, r)
if rid:
    st,_=call("POST",f"/reels/{rid}/like",tok=tB); ok("лайки Reel", st in (200,201), st)
    st,cm=call("POST",f"/reels/{rid}/comments",{"text":"шарҳи reel"},tB)
    ok("шарҳи Reel", st in (200,201), cm)
    st,_=call("POST",f"/reels/{rid}/view",tok=tB); ok("ҳисоби тамошои Reel", st in (200,201), st)
    st,_=call("POST",f"/reels/{rid}/save",tok=tB); ok("нигоҳ доштани Reel", st in (200,201), st)
    st,g=call("GET",f"/reels/{rid}",tok=tB)
    ok("Reel хонда мешавад", st==200, st)

# ── КАЛИМАҲОИ ПИНҲОН ──
st,_=call("PUT","/profile/hidden-words",{"words":["бадгап"]},tA)
ok("калимаи пинҳон сабт шуд", st in (200,201), st)
st,p=call("POST","/posts/",{"media":[{"url":"https://example.com/h.jpg","type":"image"}],
                            "caption":"пост"},tA)
pid=p.get("id") or p.get("_id") or (p.get("post") or {}).get("id") if isinstance(p,dict) else None
if pid:
    call("POST",f"/comments/{pid}",{"text":"ту бадгап ҳастӣ"},tB)
    call("POST",f"/comments/{pid}",{"text":"шарҳи хуб"},tC)
    st,cm=call("GET",f"/comments/{pid}",tok=tA)
    txt=json.dumps(cm,ensure_ascii=False)
    ok("шарҳи бо калимаи пинҳон ба СОҲИБ намоён НЕСТ", "бадгап" not in txt, txt[:150])
    ok("шарҳи муқаррарӣ намоён аст", "шарҳи хуб" in txt, txt[:150])
    st,cmB=call("GET",f"/comments/{pid}",tok=tB)
    ok("НАВИСАНДА шарҳи худро мебинад (намедонад пинҳон аст)",
       "бадгап" in json.dumps(cmB,ensure_ascii=False), "")

# ── КОЛЛЕКСИЯ ──
st,col=call("POST","/collections",{"name":"Санҷиш"},tA)
cid=col.get("id") or col.get("_id") if isinstance(col,dict) else None
ok("коллексия сохта шуд", cid, col)
if cid and pid:
    call("POST",f"/posts/{pid}/save",tok=tA)   # папка танҳо аз НИГОҲДОШТАҲО
    st,_=call("POST",f"/collections/{cid}/posts",{"postId":pid},tA)
    ok("пост ба коллексия илова шуд", st in (200,201), st)
    # Роҳи ҳақиқӣ — ҳамон, ки барнома истифода мебарад.
    st,c2=call("GET",f"/profile/saved?collection={cid}",tok=tA)
    ok("пост дар коллексия ҳаст", pid in json.dumps(c2,ensure_ascii=False), str(c2)[:150])

# ── ГУРӮҲ ──
st,g=call("POST","/groups/",{"name":"Гурӯҳи санҷишӣ","memberIds":[idB]},tA)
gid=g.get("id") or g.get("_id") or (g.get("group") or {}).get("id") if isinstance(g,dict) else None
ok("гурӯҳ сохта шуд", gid, g)
if gid:
    st,_=call("POST",f"/groups/{gid}/messages",{"text":"салом гурӯҳ","clientId":"g1"},tA)
    ok("паём ба гурӯҳ", st in (200,201), st)
    st,ms=call("GET",f"/groups/{gid}/messages",tok=tB)
    ok("аъзо паёми гурӯҳро мебинад", "салом гурӯҳ" in json.dumps(ms,ensure_ascii=False), str(ms)[:120])
    st,_=call("GET",f"/groups/{gid}/messages",tok=tC)
    ok("ғайри аъзо паёми гурӯҳро НАМЕБИНАД", st in (403,404), f"HTTP {st}")

n=sum(1 for r in res if r[0])
print(f"\n{'='*72}\n  {n}/{len(res)} гузашт\n{'='*72}")
for good,name,d in res:
    print(f"{'OK  ' if good else 'FAIL'} {name}{'' if good else '  '+str(d)[:140]}")

sys.exit(0 if n == len(res) else 1)
