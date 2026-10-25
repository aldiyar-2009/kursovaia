# Подключение backend к Supabase

Проект Supabase: `studyplan` (ref `ncqwycbtfxboqyhmzbjr`, регион eu-central-1).

## Состояние базы

Схема **уже создана** (все таблицы из `src/db/migrations/`, RLS включён на всех таблицах,
служебные таблицы Knex `knex_migrations` / `knex_migrations_lock` заполнены).
Поэтому `npm run migrate` сообщит, что применять нечего.

> **Не запускайте `npm run seed` (и `npm run setup` / `npm run db:reset`) против Supabase** —
> это зальёт демо-данные (или удалит схему) в рабочую базу.

RLS без политик — это намеренно: таблицы недоступны через REST API Supabase (anon key),
а backend подключается ролью `postgres` и работает без ограничений.
Уведомления «RLS Enabled No Policy» в Security Advisor ожидаемы.

## Настройка

1. **Строка подключения.** Dashboard → кнопка **Connect** → вкладка **Session pooler**
   (порт **5432**). Скопируйте URI и подставьте пароль базы вместо `[YOUR-PASSWORD]`:

   ```
   postgresql://postgres.ncqwycbtfxboqyhmzbjr:[YOUR-PASSWORD]@aws-0-eu-central-1.pooler.supabase.com:5432/postgres
   ```

   Пароль можно сбросить в Database Settings → Reset database password.

2. **CA-сертификат.** Database Settings → **SSL Configuration** → **Download certificate**.
   Сохраните файл как `backend/certs/supabase-ca.crt` (папка `backend/certs/` в `.gitignore`).

3. **`backend/.env`** (скопировать из `.env.example`, если файла ещё нет):

   ```
   DB_CLIENT=pg
   DATABASE_URL=postgresql://postgres.ncqwycbtfxboqyhmzbjr:<пароль>@aws-0-eu-central-1.pooler.supabase.com:5432/postgres
   PG_SSL_CA=./certs/supabase-ca.crt
   JWT_SECRET=<длинная случайная строка>
   ```

   `DB_CLIENT=pg` обязателен — без него backend использует локальный SQLite.
   При заданном `DATABASE_URL` SSL включается автоматически, сертификат сервера проверяется.
   Параметры `sslmode=` / `sslrootcert=` в `DATABASE_URL` игнорируются (вырезаются), чтобы не
   отменить проверку сертификата через `PG_SSL_CA`.

   **JWT_SECRET обязателен**, сгенерируйте:
   `node -e "console.log(require('crypto').randomBytes(48).toString('hex'))"`.
   При `DB_CLIENT=pg` или `NODE_ENV=production` сервер без него не запустится (заглушка
   `change-me-to-a-long-random-secret` тоже не принимается).

4. **Проверка:**

   ```
   npm run migrate   # Already up to date
   npm start
   ```

Файл `.env` с паролем не коммитить (он уже в `.gitignore`).
