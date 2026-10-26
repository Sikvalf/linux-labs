# Скриншоты

| Файл | Что на нём |
|---|---|
| `01-docker-build.png` | `docker image ls` — образ собран, сжатый размер 94 МБ |
| `02-docker-run-health.png` | `docker run -p 8080:8080`: `curl /health` - 200, статус `healthy`, non-root `uid=10001(app)` |
| `03-compose-ps.png` | `docker compose ps` — все сервисы `healthy`, порт наружу только у nginx (80) |
| `04-smoke-test.png` | `./scripts/smoke-test.sh` — все критерии приёмки Docker 2 пройдены |
| `05-browser-root.png` | `http://localhost/` через nginx — версия и hostname контейнера |
| `05-browser-notes.png` | `http://localhost/api/notes` через nginx — данные из PostgreSQL |
| `06-push.png` | `./scripts/build-and-push.sh` — образ `docker.io/sikvalf/lab2-app:1.0.0` в Docker Hub |
