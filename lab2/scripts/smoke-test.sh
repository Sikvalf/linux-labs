set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

PORT="$(grep -E '^NGINX_PORT=' .env 2>/dev/null | cut -d= -f2-)"
BASE="http://localhost:${PORT:-80}"
FAILED=0

ok()   { echo "  [OK]   $*"; }
fail() { echo "  [FAIL] $*"; FAILED=1; }

wait_healthy() {
    for _ in $(seq 1 60); do
        if curl -fs "$BASE/health" >/dev/null 2>&1; then return 0; fi
        sleep 2
    done
    return 1
}

echo "==> 1. Поднимаем стек"
docker compose up -d --build
if wait_healthy; then ok "стек поднялся"; else fail "приложение не ответило за 120 секунд"; fi
docker compose ps

echo "==> 2. Приложение доступно через nginx"
code="$(curl -s -o /dev/null -w '%{http_code}' "$BASE/health")"
[[ "$code" == "200" ]] && ok "GET $BASE/health -> $code" || fail "GET $BASE/health -> $code"
code="$(curl -s -o /dev/null -w '%{http_code}' "$BASE/health/db")"
[[ "$code" == "200" ]] && ok "GET $BASE/health/db -> $code" || fail "GET $BASE/health/db -> $code"

echo "==> 3. Данные PostgreSQL переживают перезапуск"
marker="smoke-$(date +%s)"
curl -s -X POST "$BASE/api/notes" -H 'Content-Type: application/json' \
     -d "{\"text\":\"$marker\"}" && echo
docker compose down              
docker compose up -d
wait_healthy || fail "после перезапуска приложение не поднялось"
if curl -s "$BASE/api/notes?limit=100" | grep -q "$marker"; then
    ok "заметка '$marker' на месте после down/up"
else
    fail "заметка '$marker' пропала после перезапуска"
fi

echo "==> 4. Наружу опубликован только nginx"
published="$(docker compose ps --format '{{.Service}} {{.Publishers}}' | grep -E '0\.0\.0\.0|\[::\]' || true)"
echo "$published" | sed 's/^/    /'
if [[ -n "$published" ]] && ! echo "$published" | grep -qv '^nginx '; then
    ok "опубликованные порты есть только у nginx"
else
    fail "порты опубликованы не только у nginx"
fi

echo
if [[ "$FAILED" == 0 ]]; then echo "ВСЕ ПРОВЕРКИ ПРОЙДЕНЫ"; else echo "ЕСТЬ ОШИБКИ"; exit 1; fi
