#!/usr/bin/env bash
# Скрипт №3. Поиск ключевого слова в лог-файле.
set -euo pipefail

if [ "$#" -ne 2 ]; then
    echo "Использование: $0 <лог-файл> <ключевое_слово>" >&2
    exit 1
fi

LOG_FILE="$1"
KEYWORD="$2"

if [ ! -f "$LOG_FILE" ]; then
    echo "Ошибка: файл '$LOG_FILE' не найден" >&2
    exit 1
fi
if [ ! -r "$LOG_FILE" ]; then
    echo "Ошибка: нет прав на чтение '$LOG_FILE'" >&2
    exit 1
fi

# Имена выходных файлов: без пути и с безопасными символами в ключевом слове
LOG_BASE="$(basename "$LOG_FILE")"
LOG_BASE="${LOG_BASE%.*}"
SAFE_KEYWORD="$(printf '%s' "$KEYWORD" | tr -c 'A-Za-z0-9_-' '_')"

MATCHES_FILE="${LOG_BASE}_${SAFE_KEYWORD}_matches.txt"
COUNT_FILE="${LOG_BASE}_${SAFE_KEYWORD}_count.txt"

# -F: искать слово как обычный текст, а не как регулярное выражение
# -n: добавить номер строки в логе
# grep возвращает код 1, если ничего не найдено
grep -nF -- "$KEYWORD" "$LOG_FILE" > "$MATCHES_FILE" || true

COUNT="$(wc -l < "$MATCHES_FILE")"

{
    echo "Лог-файл: $LOG_FILE"
    echo "Ключевое слово: $KEYWORD"
    echo "Дата проверки: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Найдено строк: $COUNT"
} > "$COUNT_FILE"

echo "Найдено строк с '$KEYWORD': $COUNT"
echo "Сводка: $COUNT_FILE"
echo "Найденные строки: $MATCHES_FILE"
