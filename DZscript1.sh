#!/usr/bin/env bash
#
# Скрипт №1. Отчёт о различиях между двумя ветками удалённого репозитория.

set -euo pipefail

if [ "$#" -ne 3 ]; then
    echo "Использование: $0 <ссылка_на_репозиторий> <ветка_1> <ветка_2>" >&2
    exit 1
fi

REPO_URL="$1"
BRANCH_1="$2"
BRANCH_2="$3"

# Временная папка для клона, удаляется при любом выходе из скрипта
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
REPO_DIR="$TMP_DIR/repo"

echo "Клонирую $REPO_URL ..."
if ! git clone --quiet --no-checkout "$REPO_URL" "$REPO_DIR"; then
    echo "Ошибка: не удалось клонировать репозиторий $REPO_URL" >&2
    exit 1
fi

# Проверяем, что обе ветки существуют
for branch in "$BRANCH_1" "$BRANCH_2"; do
    if ! git -C "$REPO_DIR" rev-parse --verify --quiet "origin/$branch" >/dev/null; then
        echo "Ошибка: ветка '$branch' не найдена в репозитории" >&2
        exit 1
    fi
done

# Список изменённых файлов: "СТАТУС<TAB>путь"
# --no-renames: переименование показывается как D + A, чтобы были только статусы A/M/D
DIFF="$(git -C "$REPO_DIR" diff --name-status --no-renames "origin/$BRANCH_1" "origin/$BRANCH_2")"

count_status() {
    # $1 - статус (A, M, D); пустой аргумент - все строки
    printf '%s\n' "$DIFF" | awk -v s="$1" 'NF && (s == "" || $1 == s) { c++ } END { print c + 0 }'
}

TOTAL="$(count_status "")"
ADDED="$(count_status A)"
DELETED="$(count_status D)"
MODIFIED="$(count_status M)"

# "/" в имени ветки (feature/x) недопустим в имени файла - меняем на "_"
SAFE_B1="${BRANCH_1//\//_}"
SAFE_B2="${BRANCH_2//\//_}"
REPORT_FILE="diff_report_${SAFE_B1}_vs_${SAFE_B2}.txt"

{
    echo "Отчет о различиях между ветками"
    echo
    echo "================================"
    echo "Репозиторий: $REPO_URL"
    echo "Ветка 1: $BRANCH_1"
    echo "Ветка 2: $BRANCH_2"
    echo "Дата генерации: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "================================"
    echo
    echo "СПИСОК ИЗМЕНЕННЫХ ФАЙЛОВ:"
    if [ "$TOTAL" -eq 0 ]; then
        echo "(различий нет)"
    else
        printf '%s\n' "$DIFF" | sed $'s/\t/ /'
    fi
    echo
    echo "СТАТИСТИКА:"
    echo "Всего измененных файлов: $TOTAL"
    echo "Добавлено (A): $ADDED"
    echo "Удалено (D): $DELETED"
    echo "Изменено (M): $MODIFIED"
} > "$REPORT_FILE"

echo "Отчёт сохранён в $REPORT_FILE"
