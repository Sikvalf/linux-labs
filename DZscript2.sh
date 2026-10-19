#!/usr/bin/env bash
#
# Скрипт №2. Фоновый мониторинг системы.
# Использование: ./system_monitor.sh START|STOP|STATUS
#
# Раз в 10 минут пишет строку в system_report_YYYY-MM-DD.csv:
# timestamp;all_memory;free_memory;%memory_used;%cpu_used;%disk_used;load_average_1m
# Память - в мегабайтах.
#

SCRIPT_PATH="$(readlink -f "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
SCRIPT_NAME="$(basename "$SCRIPT_PATH")"

PID_FILE="$SCRIPT_DIR/.system_monitor.pid"
LOCK_FILE="$SCRIPT_DIR/.system_monitor.lock"
REPORT_DIR="${REPORT_DIR:-$SCRIPT_DIR}"
INTERVAL="${MONITOR_INTERVAL:-600}"   # 600 секунд = 10 минут (переменная - для тестов)


memory_stats() {
    # Выводит: всего_МБ свободно_МБ процент_занято
    # "Свободно" = MemAvailable (сколько реально доступно программам, с учётом кэша)
    awk '
        /^MemTotal:/     { total = $2 }
        /^MemAvailable:/ { avail = $2 }
        END {
            printf "%d %d %.1f", total / 1024, avail / 1024, (total - avail) * 100 / total
        }' /proc/meminfo
}

cpu_usage() {
    # Загрузка CPU за 1 секунду по разнице счётчиков из /proc/stat
    local user nice system idle iowait irq softirq steal
    read -r _ user nice system idle iowait irq softirq steal _ < /proc/stat
    local idle1=$((idle + iowait))
    local total1=$((user + nice + system + idle + iowait + irq + softirq + steal))

    sleep 1

    read -r _ user nice system idle iowait irq softirq steal _ < /proc/stat
    local idle2=$((idle + iowait))
    local total2=$((user + nice + system + idle + iowait + irq + softirq + steal))

    awk -v di=$((idle2 - idle1)) -v dt=$((total2 - total1)) \
        'BEGIN { if (dt > 0) printf "%.1f", (dt - di) * 100 / dt; else print "0.0" }'
}

disk_usage() {
    df -P / | awk 'NR == 2 { gsub("%", "", $5); print $5 }'
}

load_average() {
    cut -d ' ' -f 1 /proc/loadavg
}

write_report_line() {
    local report_file="$REPORT_DIR/system_report_$(date '+%Y-%m-%d').csv"

    # Новый файл (в том числе при смене даты) - сначала заголовок
    if [ ! -f "$report_file" ]; then
        echo "timestamp;all_memory;free_memory;%memory_used;%cpu_used;%disk_used;load_average_1m" > "$report_file"
    fi

    local mem_total mem_free mem_used_pct
    read -r mem_total mem_free mem_used_pct <<< "$(memory_stats)"

    echo "$(date '+%Y-%m-%d %H:%M:%S');$mem_total;$mem_free;$mem_used_pct;$(cpu_usage);$(disk_usage);$(load_average)" >> "$report_file"
}


get_pid() {
    [ -f "$PID_FILE" ] && cat "$PID_FILE"
}

is_running() {
    local pid
    pid="$(get_pid)"
    [ -n "$pid" ] || return 1
    kill -0 "$pid" 2>/dev/null || return 1
    # Убеждаемся, что это именно наш скрипт, а не чужой процесс с тем же PID
    tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null | grep -q "$SCRIPT_NAME"
}

run_loop() {
    # Защита от второго экземпляра: эксклюзивная блокировка на всё время работы
    exec 9> "$LOCK_FILE"
    if ! flock -n 9; then
        echo "Другой экземпляр уже работает" >&2
        exit 1
    fi

    echo $$ > "$PID_FILE"

    local sleep_pid=""
    trap 'kill "$sleep_pid" 2>/dev/null; rm -f "$PID_FILE"; exit 0' TERM INT

    while true; do
        write_report_line
        sleep "$INTERVAL" &
        sleep_pid=$!
        wait "$sleep_pid"
    done
}

start() {
    if is_running; then
        echo "Мониторинг уже запущен, PID $(get_pid)"
        exit 1
    fi
    rm -f "$PID_FILE"   # на случай, если остался от упавшего процесса

    nohup "$SCRIPT_PATH" __run > /dev/null 2>&1 &

    # Ждём, пока фоновый процесс возьмёт блокировку и запишет PID
    for _ in 1 2 3 4 5 6 7 8 9 10; do
        if is_running; then
            echo "Мониторинг запущен, PID $(get_pid)"
            exit 0
        fi
        sleep 0.2
    done

    echo "Не удалось запустить мониторинг" >&2
    exit 1
}

stop() {
    if ! is_running; then
        echo "Мониторинг не запущен"
        rm -f "$PID_FILE"
        exit 0
    fi

    local pid
    pid="$(get_pid)"
    kill "$pid"

    for _ in 1 2 3 4 5 6 7 8 9 10; do
        if ! kill -0 "$pid" 2>/dev/null; then
            rm -f "$PID_FILE"
            echo "Мониторинг остановлен (PID $pid)"
            exit 0
        fi
        sleep 0.5
    done

    kill -9 "$pid" 2>/dev/null
    rm -f "$PID_FILE"
    echo "Мониторинг остановлен принудительно (PID $pid)"
}

status() {
    if is_running; then
        echo "Мониторинг запущен, PID $(get_pid)"
    else
        echo "Мониторинг не запущен"
    fi
}

case "${1:-}" in
    START)  start ;;
    STOP)   stop ;;
    STATUS) status ;;
    __run)  run_loop ;;   # внутренний режим, вызывается из START
    *)
        echo "Использование: $0 START|STOP|STATUS" >&2
        exit 1
        ;;
esac
