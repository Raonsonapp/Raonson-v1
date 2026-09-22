#!/usr/bin/env python3
"""Ҷараёнҳои амиқ: стори, «Актуальный», танзимот, бойгонӣ, ҳаштаг.

═══════════════════════════════════════════════════════════════════
 Ин санҷиш камбудиеро ёфт, ки ҳеҷ кас намедид: «АКТУАЛЬНЫЙ»
 (highlights) УМУМАН СОХТА НАМЕШУД.

 Дар барнома тугма буд, зер мешуд — ва ҳеҷ чиз намешуд. Сервер 500
 медод, вале сабаб дар log НАБУД, пас ташхис ғайриимкон буд.

 Сабаби аслӣ: `json.Marshal` `[]byte` медиҳад, ва pgx онро БАЙТ
 мешуморад, на матн. Postgres мегуфт:

     invalid input syntax for type json (SQLSTATE 22P02)

 Танҳо каст (`::jsonb`) кифоя набуд — масъала дар ШАКЛИ фиристодани
 қимат буд, на дар навъи сутун.

 Истифода:
   BASE=http://127.0.0.1:8099 python3 backend/testing/api_flows.py
═══════════════════════════════════════════════════════════════════
"""

import json, os, sys, time, urllib.parse, urllib.request, urllib.error
B=os.environ.get("BASE","http://127.0.0.1:8099"); PW="Test12345!"
res=[]
_RETRY=(429,)
def _once(m,p,body=None,tok=None):
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
def call(m,p,body=None,tok=None):
    for a in range(4):
        st,r=_once(m,p,body,tok)
        if st not in _RETRY: return st,r
        time.sleep(4*(a+1))
    return st,r
def reg(u,e,ph):
    st,_=call("POST","/auth/register",{"username":u,"email":e,"password":PW,"fullName":u,"phone":ph}); return st in (200,201,409)
def login(u):
    st,r=call("POST","/auth/login",{"email":u,"password":PW})
    return (r.get("accessToken") if isinstance(r,dict) else None),(r.get("user") or {} if isinstance(r,dict) else {})
def ok(n,c,d=""): res.append((bool(c),n,d))

S=os.environ.get("SUFFIX","fl")
A,Bu=f"fa{S}",f"fb{S}"
reg(A,f"{A}@example.com","+992900500001"); reg(Bu,f"{Bu}@example.com","+992900500002")
tA,uA=login(A); tB,uB=login(Bu)
idA=uA.get("id") or uA.get("_id"); idB=uB.get("id") or uB.get("_id")
if not (tA and tB): print("!! вуруд нашуд"); sys.exit(1)

# ── ДАРХОСТИ ОБУНА: қабул ва рад ──
call("PUT","/profile/",{"isPrivate":True},tA)
call("POST",f"/follow/{idA}",tok=tB)
st,r=call("POST",f"/follow/request/{idB}/accept",tok=tA)
ok("қабули дархости обуна", st in (200,201), f"HTTP {st}: {r}")
st,f=call("GET",f"/users/{idA}/followers",tok=tA)
ok("баъди қабул обунашаванда пайдо шуд",
   idB in json.dumps(f,ensure_ascii=False), str(f)[:120])
call("PUT","/profile/",{"isPrivate":False},tA)

# ── СТОРИ: лайк, ҷавоб, пурсиш ──
st,s=call("POST","/stories/",{"mediaUrl":"https://example.com/s.jpg","mediaType":"image",
    "poll":{"question":"Кадомаш?","optionA":"Як","optionB":"Ду","x":0.5,"y":0.5}},tA)
sid=s.get("id") or s.get("_id") or (s.get("story") or {}).get("id") if isinstance(s,dict) else None
ok("стори бо пурсиш сохта шуд", sid, s)
if sid:
    st,_=call("POST",f"/stories/{sid}/like",tok=tB); ok("лайки стори", st in (200,201), st)
    st,_=call("POST",f"/stories/{sid}/reply",{"text":"ҷавоб"},tB); ok("ҷавоб ба стори", st in (200,201), st)
    st,pv=call("POST",f"/stories/{sid}/poll/vote",{"choice":0},tB)
    ok("овоз ба пурсиши стори", st in (200,201), f"HTTP {st}: {pv}")
    st,v=call("GET",f"/stories/{sid}/viewers",tok=tA); ok("тамошобинон", st==200, st)
    st,my=call("GET","/stories/my",tok=tA)
    ok("сторихои ман", st==200 and sid in json.dumps(my,ensure_ascii=False), str(my)[:120])

# ── HIGHLIGHTS ──
st,h=call("POST","/highlights/",{"title":"Санҷиш","storyIds":[sid] if sid else []},tA)
hid=h.get("id") or h.get("_id") if isinstance(h,dict) else None
ok("highlight сохта шуд", hid, h)
if hid:
    st,g=call("GET",f"/highlights/{idA}",tok=tA)
    ok("highlight хонда мешавад", st==200 and "Санҷиш" in json.dumps(g,ensure_ascii=False), str(g)[:140])
    st,_=call("PATCH",f"/highlights/{hid}",{"title":"Нав"},tA)
    ok("highlight иваз мешавад", st in (200,201), st)
    st,_=call("DELETE",f"/highlights/{hid}",tok=tA)
    ok("highlight нест мешавад", st in (200,204), st)

# ── ОГОҲИНОМА: хонда шуд ──
st,n=call("GET","/notifications",tok=tA)
items=n.get("notifications") if isinstance(n,dict) else n
nid=(items or [{}])[0].get("_id") or (items or [{}])[0].get("id") if items else None
if nid:
    st,_=call("POST",f"/notifications/{nid}/read",tok=tA); ok("огоҳинома хонда шуд", st in (200,201), st)
st,_=call("POST","/notifications/read-all",tok=tA)
ok("ҳама огоҳинома хонда шуд", st in (200,201), st)

# ── ТАНЗИМОТИ ҲИСОБ ──
st,_=call("PUT","/profile/username",{"username":f"{A}x"},tA)
ok("иваз кардани номи корбар", st in (200,201), st)
call("PUT","/profile/username",{"username":A},tA)
st,_=call("PUT","/profile/settings",{"theme":"dark"},tA)
ok("нигоҳ доштани танзимот", st in (200,201), st)
st,np=call("GET","/profile/notifications",tok=tA)
ok("танзимоти огоҳинома хонда мешавад", st==200, st)
st,_=call("PUT","/profile/notifications",{"likes":False},tA)
ok("танзимоти огоҳинома сабт мешавад", st in (200,201), st)

# ── БОЙГОНӢ ВА НИГОҲДОРӢ ──
st,p=call("POST","/posts/",{"media":[{"url":"https://example.com/a.jpg","type":"image"}],"caption":"б"},tA)
pid=p.get("id") or p.get("_id") or (p.get("post") or {}).get("id") if isinstance(p,dict) else None
if pid:
    st,_=call("POST",f"/posts/{pid}/archive",tok=tA); ok("бойгонии пост", st in (200,201), st)
    st,_=call("POST",f"/posts/{pid}/archive",tok=tA)  # бармегардонем
    st,_=call("POST",f"/posts/{pid}/pin",{"pin":True},tA); ok("санҷондани пост", st in (200,201), st)
    st,_=call("POST",f"/posts/{pid}/save",tok=tA)
    st,sv=call("GET","/profile/saved",tok=tA)
    ok("пости нигоҳдошта дар рӯйхат", pid in json.dumps(sv,ensure_ascii=False), str(sv)[:120])

# ── ҶУСТУҶӮИ ҲАШТАГ ──
st,_=call("POST","/posts/",{"media":[{"url":"https://example.com/h.jpg","type":"image"}],
                            "caption":"санҷиш #раонсонтест"},tA)
tag = urllib.parse.quote("раонсонтест")
st,hp=call("GET",f"/posts/hashtag/{tag}",tok=tA)
ok("ҷустуҷӯи ҳаштаг", st==200 and "раонсонтест" in json.dumps(hp,ensure_ascii=False), f"HTTP {st}: {str(hp)[:120]}")

# ── РЕФЕРАЛ ВА ДИГАР ──
for name,path in [("реферал","/referral/me"),("дастовардҳо","/creator/achievements"),
                  ("ғояҳои муаллиф","/creator/ideas"),("ҷамъбасти ҳафта","/creator/recap/week"),
                  ("фармоишҳо","/orders"),("танзимоти лента","/feed/preferences")]:
    st,_=call("GET",path,tok=tA); ok(name, st in (200,404), f"HTTP {st}")

n=sum(1 for r in res if r[0])
print(f"\n{'='*72}\n  {n}/{len(res)} гузашт\n{'='*72}")
for good,name,d in res:
    print(f"{'OK  ' if good else 'FAIL'} {name}{'' if good else '  '+str(d)[:150]}")
sys.exit(0 if n==len(res) else 1)
