# Лаба 2 — Docker

**Киселев Валерий Алексеевич, М13-601**

Spring Boot приложение в оптимизированном Docker-образе (Docker #1) и многоконтейнерный стек
nginx + app + PostgreSQL (+ adminer) на docker-compose (Docker #2).


## Приложение

| Эндпоинт | Что делает |
|---|---|
| `GET /health` | liveness: `{"status":"UP"}`, 200. БД не трогает, поэтому работает и без PostgreSQL |
| `GET /health/db` | доступность PostgreSQL: 200 / 503 |
| `GET /` | версия, hostname контейнера, список эндпоинтов |
| `GET /api/notes` | заметки из PostgreSQL |
| `POST /api/notes` | добавить заметку `{"text":"..."}` — для проверки сохранности данных |

Таблица `notes` создаётся при первом обращении к API.

## Docker 1 — образ приложения

Что сделано в `app/Dockerfile`:

- **multi-stage build**: `builder` (`maven:3.9.11-eclipse-temurin-21`) собирает jar, `runtime` содержит только JRE;
- **фиксированные теги** базовых образов (`eclipse-temurin:21.0.8_9-jre-alpine`), не `latest`;
- **runtime на Alpine** — в образе нет Maven, JDK и исходников;
- **слои Spring Boot** (`-Djarmode=tools extract --layers`): зависимости лежат отдельным слоем
  и не перекачиваются при изменении кода; `pom.xml` копируется до `src`, чтобы кэшировалась загрузка зависимостей;
- **non-root**: пользователь `app` с UID/GID 10001;
- `ENV`, `EXPOSE 8080`, `HEALTHCHECK` (wget на `/health`), `ENTRYPOINT` в exec-форме
  (JVM-флаги передаются через `JAVA_TOOL_OPTIONS`, чтобы не нужна была shell-форма);
- `.dockerignore` пропускает в контекст сборки только `pom.xml` и `src`.

### Сборка и запуск одного контейнера

```bash
cd lab2
docker build -t lab2-app:1.0.0 ./app

docker run -d --name lab2-app -p 8080:8080 -e APP_VERSION=1.0.0 lab2-app:1.0.0

curl -i localhost:8080/health          # HTTP/1.1 200, {"status":"UP"}
docker ps                              # STATUS: Up ... (healthy) — примерно через 40 секунд
docker exec lab2-app id                # uid=10001(app) — не root

docker rm -f lab2-app
```

### Выгрузка в registry

```bash
cp .env.example .env                   # указать APP_IMAGE=docker.io/<логин>/lab2-app
docker login
./scripts/build-and-push.sh            # собрать и запушить ${APP_IMAGE}:${APP_TAG}
./scripts/build-and-push.sh --no-push  # только собрать
```

## Docker 2 — стек на docker-compose

| Сервис | Образ | Сети | Наружу |
|---|---|---|---|
| nginx | `nginx:1.28.0-alpine` | frontend | **80** |
| app | собирается из `./app` | frontend, backend | нет (`expose 8080`) |
| db | `postgres:17.6-alpine` | backend | нет |
| adminer (опционально) | `adminer:5.3.0` | frontend, backend | нет, через nginx `/adminer/` |

- Сеть `backend` помечена `internal: true` — у БД нет выхода в интернет, nginx до неё не достаёт.
- Данные PostgreSQL лежат в именованном томе `pgdata`.
- Порядок старта через `depends_on: condition: service_healthy`: db → app → nginx.
- Пароль БД только в `.env`; если он не задан, compose остановится с понятной ошибкой.
- Контейнер app запускается с `read_only: true` и `no-new-privileges`.

### Запуск

```bash
cd lab2
cp .env.example .env                   
docker compose up -d --build
docker compose ps                      
```

С adminer: `docker compose --profile tools up -d`, затем открыть http://localhost/adminer/
(сервер `db`, пользователь и пароль из `.env`).

### Проверка

Автоматически — все критерии приёмки одной командой:

```bash
./scripts/smoke-test.sh
```

Вручную:

```bash
# приложение доступно через nginx
curl -i localhost/health
curl localhost/

# данные сохраняются между перезапусками
curl -X POST localhost/api/notes -H 'Content-Type: application/json' -d '{"text":"hello"}'
docker compose down                    # без -v, том pgdata остаётся
docker compose up -d
curl localhost/api/notes               # заметка "hello" на месте

# наружу открыт только nginx
docker compose ps                      # порт 0.0.0.0:80->80 есть только у nginx
curl -m 3 localhost:8080/health        # не отвечает: app наружу не опубликован
curl -m 3 localhost:5432               # не отвечает: БД наружу не опубликована
```

Остановить и удалить вместе с данными: `docker compose down -v`.

## Запуск на другой машине

Нужны Docker с Compose v2 и папка `lab2` (или только `docker-compose.yml`, `nginx/`, `.env.example`
плюс опубликованный образ):

```bash
cp .env.example .env                   # APP_IMAGE / APP_TAG — опубликованный образ
docker compose pull nginx db           # сторонние образы
docker pull "$(grep ^APP_IMAGE .env | cut -d= -f2):$(grep ^APP_TAG .env | cut -d= -f2)"
docker compose up -d --no-build
```

Без registry: `docker compose up -d --build` соберёт образ из исходников на месте.

## Скриншоты

См. [`docs/screenshots`](docs/screenshots).

## Замечания

- `version: "3.8"` указана по требованию задания; Compose v2 её игнорирует и может написать
  предупреждение `version is obsolete`.
- Если какой-то фиксированный тег базового образа недоступен в вашем registry, его можно переопределить:
  `docker build --build-arg RUNTIME_IMAGE=eclipse-temurin:21-jre-alpine ./app`.
