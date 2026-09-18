# Instagram 2026 — UX/UI + Functions + Animations Master Specification

Тавсифи дуюм (85 бахш). Ин рӯйхати хусусиятҳо НЕСТ — он барои ҲАР
экран ва ҲАР амал рафторро муайян мекунад: зада, дарозфишорӣ,
кашидан, аниматсия, боршавӣ, интернети суст, офлайн, нокомӣ, такрор,
кэш, паснамо, бозгашт, ҳолат, гузариши аккаунт.

Бахшҳо:

```
01 App launch / splash        44 Notes
02 Login                      45 Calls
03 Sign up                    46 Live
04 Account switcher           47 Repost
05 Home screen                48 Share sheet
06 Home feed behavior         49 Audio page
07 Home post animation        50 Settings
08 Home post menu             51 Privacy
09 Comments screen            52 Security
10 Story tray                 53 Notification settings
11 Story viewer               54 Content preferences
12 Story creator              55 Media / data settings
13 Story stickers             56 Language
14 Reels home                 57 Accessibility
15 Reels network behavior     58 Account status
16 Create screen              59 Report system
17 Post creator               60 Block / restrict / mute
18 Carousel                   61 Weak internet engine
19 Reels creator              62 Offline engine
20 Reels audio                63 Cache
21 Audio editor               64 Global loading system
22 Reels editor               65 Global error system
23 Reels text                 66 Animation system
24 Reels captions             67 Core micro-animations
25 Reels effects              68 Gesture system
26 Reels templates            69 Back navigation
27 Reels voiceover            70 Background / foreground
28 Reels share                71 Push notifications
29 Reels drafts               72 Realtime
30 Search screen              73 Upload engine
31 Explore                    74 Video processing
32 Profile                    75 Search performance
33 Profile grid               76 Memory management
34 Edit profile               77 Frame rate / smoothness
35 Followers                  78 Design system
36 Saved                      79 Visual hierarchy
37 Archive                    80 UI states
38 Activity / notifications   81 Data consistency
39 Direct messages            82 Security / account isolation
40 Message send states        83 Empty states
41 Message long press         84 Error recovery
42 Chat media viewer          85 Final UX principle
43 Chat search
```

## Принсипи асосӣ (бахши 85)

Экранҳо ҳамчун саҳифаҳои ҷудогона сохта нашаванд. Ҳар хусусияти
муҳим бояд ҳамин занҷирро иҷро кунад:

```
АМАЛИ КОРБАР
  ↓
ҶАВОБИ ФАВРИИ ЭКРАН
  ↓
АНИМАТСИЯ
  ↓
ҲОЛАТИ МАҲАЛЛӢ
  ↓
ДАРХОСТИ ШАБАКА
  ↓
ҲОЛАТИ СЕРВЕР
  ↓
МУВАФФАҚИЯТ / ХАТО
  ↓
МУВОФИҚКУНӢ
  ↓
ҲОЛАТИ ДОИМӢ
```

## Ҳудудҳои аниматсия (бахши 66)

| Намуд | Вақт |
|---|---|
| Микро (тугма, лайк) | 120–220мс |
| Оддӣ (гузариш) | 200–350мс |
| Варақаи поён | spring |
| Modal | fade + scale |
| Зеркунии тугма | 0.96 → 1.0 |

## Ҳолатҳои ҳатмии ҳар компонент (бахши 80)

```
default · pressed · selected · disabled
loading · success · error · offline
```

Мисоли тугмаи «Обуна»:

```
Обуна → зеркунӣ → боршавӣ → Обунашуда
нокомӣ: Обунашуда → бозгашт → Обуна
```

## Ҳолатҳои паём (бахши 40)

```
Менависад → Фиристода мешавад → Фиристода шуд
          → Расид → Хонда шуд

Нокомӣ:  Нашуд → Такрор
Офлайн:  Дар навбат
Интернет баргашт: худкор такрор, БЕ такроршавӣ
```

---

Матни пурраи ҳарду тавсиф ҳамчун сарчашмаи ҳақиқат истифода мешавад.
Вазъи ҳозираи барнома дар `docs/INSTAGRAM_PARITY.md` аст.
