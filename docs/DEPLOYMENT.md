# Ҷойгиркунӣ ва бозгашт

## Пеш аз ҷойгиркунӣ

```bash
cd backend
gofmt -l .            # файлҳои НАВ бояд тоза бошанд
go vet ./...
go test ./...
go test -race ./...   # нажоди маълумот

cd ..
flutter analyze lib test
flutter test
```

Ҳамаи ин бояд тоза гузаранд. `deploy.yml` танҳо ҳангоми push ба
`main` бо тағйири `backend/**` кор мекунад.

## Миграцияҳо

Схема ҳангоми оғози барнома (`db.migrate()`) татбиқ мешавад ва
**илова мекунад, вале нест намекунад**:

- `CREATE TABLE IF NOT EXISTS`
- `ALTER TABLE ... ADD COLUMN IF NOT EXISTS`
- `CREATE INDEX IF NOT EXISTS`

Ҳеҷ `DROP TABLE`, `DROP COLUMN` ё `DELETE` дар роҳи миграция нест.
Ин маънои онро дорад, ки версияи КӮҲНА бо схемаи НАВ низ кор мекунад
— ва маҳз ин бозгаштро бехатар мекунад.

⚠️ Агар рӯзе сутун ё ҷадвал нест кардан лозим шавад, онро дар як
ҷойгиркунӣ бо код НАКУНЕД: аввал кодро партоед, баъд аз тасдиқи
устуворӣ схемаро тоза кунед.

## Пас аз ҷойгиркунӣ — санҷиши солимӣ

```bash
curl -s $BASE/health
curl -s $BASE/admin/system/health        -H "Authorization: Bearer $ADMIN"
curl -s $BASE/admin/notifications/health -H "Authorization: Bearer $ADMIN"
curl -s $BASE/admin/ai/health            -H "Authorization: Bearer $ADMIN"
```

Дар `/admin/system/health` тафтиш кунед:

| Майдон | Интизор |
|---|---|
| `database.ok` | `true` |
| `database.timeoutsEnforced` | `true` |
| `database.pool.emptyAcquireCount` | набояд зуд калон шавад |
| `push.configured` | `true` дар production |
| `ai.configured` | `true` дар production |

## Бозгашт

Ҷойгиркунӣ ба HuggingFace Space аз `main` мегузарад, бинобар ин
бозгашт = ҷойгиркунии commit-и қаблӣ:

```bash
git revert <commit>        # таърих нигоҳ дошта мешавад
git push origin main
```

`git push --force` ба `main` НАКУНЕД: он таърихро мешиканад ва
бозгашти навбатиро душвор мекунад.

**Маълумот нест карда намешавад.** Азбаски миграция танҳо илова
мекунад, версияи кӯҳна бо базаи нав кор мекунад — барқарорсозии
база лозим нест.

Агар ҷойгиркунӣ нокомӣ хӯрад, Space-и қаблӣ то ҷойгиркунии
муваффақи навбатӣ кор карда меистад.

## Танзимоти production

Ниг. `backend/.env.example`. Ҳеҷ сир ба анбор гузошта намешавад —
ҳама ҳамчун secret дар GitHub/HuggingFace.
