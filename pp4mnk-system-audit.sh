#!/bin/sh
# =========================================================
# pp4mnk SYSTEM AUDIT + SCORE v2.0
# Linux / EasyOS / Puppy / Debian-like / generic
# Muestra en pantalla + guarda informe + puntúa sistema
# =========================================================

OUTDIR="/tmp/pp4mnk-system-audit"
REPORT="$OUTDIR/report.txt"
mkdir -p "$OUTDIR"
: > "$REPORT"

# -----------------------------
# Utilidades
# -----------------------------
have_cmd() {
    command -v "$1" >/dev/null 2>&1
}

say() {
    printf '%s\n' "$1" | tee -a "$REPORT"
}

section() {
    say ""
    say "=================================================="
    say "$1"
    say "=================================================="
}

line() {
    say "--------------------------------------------------"
}

safe_read_first() {
    [ -r "$1" ] && head -n 1 "$1"
}

get_mem_kb() {
    awk -v k="$1" '$1==k":" {print $2}' /proc/meminfo 2>/dev/null
}

human_kb() {
    awk -v kb="$1" '
    BEGIN {
        if (kb < 1024) printf "%d KB", kb;
        else if (kb < 1048576) printf "%.1f MB", kb/1024;
        else printf "%.2f GB", kb/1048576;
    }'
}

human_bytes() {
    awk -v b="$1" '
    BEGIN {
        if (b < 1024) printf "%d B", b;
        else if (b < 1048576) printf "%.1f KB", b/1024;
        else if (b < 1073741824) printf "%.1f MB", b/1048576;
        else printf "%.2f GB", b/1073741824;
    }'
}

clamp_0_100() {
    n="$1"
    [ -z "$n" ] && n=0
    [ "$n" -lt 0 ] 2>/dev/null && n=0
    [ "$n" -gt 100 ] 2>/dev/null && n=100
    echo "$n"
}

bar() {
    val=$(clamp_0_100 "$1")
    filled=$((val / 5))
    empty=$((20 - filled))
    out="["
    i=0
    while [ "$i" -lt "$filled" ]; do
        out="${out}#"
        i=$((i + 1))
    done
    i=0
    while [ "$i" -lt "$empty" ]; do
        out="${out}-"
        i=$((i + 1))
    done
    out="${out}] ${val}/100"
    printf '%s\n' "$out"
}

judge() {
    s=$(clamp_0_100 "$1")
    if [ "$s" -ge 90 ]; then
        echo "EXCELENTE"
    elif [ "$s" -ge 75 ]; then
        echo "MUY BUENO"
    elif [ "$s" -ge 60 ]; then
        echo "BUENO"
    elif [ "$s" -ge 45 ]; then
        echo "ACEPTABLE"
    elif [ "$s" -ge 30 ]; then
        echo "MEJORABLE"
    else
        echo "DEFICIENTE"
    fi
}

avg_int() {
    # media entera de argumentos
    total=0
    count=0
    for x in "$@"; do
        total=$((total + x))
        count=$((count + 1))
    done
    [ "$count" -eq 0 ] && echo 0 || echo $((total / count))
}

# -----------------------------
# Recolección base
# -----------------------------
HOSTNAME="$(hostname 2>/dev/null)"
KERNEL="$(uname -srmo 2>/dev/null)"
ARCH="$(uname -m 2>/dev/null)"
UPTIME="$(awk '{
    s=int($1);
    d=int(s/86400); s%=86400;
    h=int(s/3600); s%=3600;
    m=int(s/60);
    printf "%dd %dh %dm", d,h,m
}' /proc/uptime 2>/dev/null)"

LOAD1="$(awk '{print $1}' /proc/loadavg 2>/dev/null)"
LOAD5="$(awk '{print $2}' /proc/loadavg 2>/dev/null)"
LOAD15="$(awk '{print $3}' /proc/loadavg 2>/dev/null)"

CPU_MODEL="$(awk -F: '/model name/ {gsub(/^[ \t]+/, "", $2); print $2; exit}' /proc/cpuinfo 2>/dev/null)"
CPU_CORES="$(awk '/^processor/ {n++} END{print n+0}' /proc/cpuinfo 2>/dev/null)"

MEM_TOTAL="$(get_mem_kb MemTotal)"
MEM_FREE="$(get_mem_kb MemFree)"
MEM_AVAIL="$(get_mem_kb MemAvailable)"
BUFFERS="$(get_mem_kb Buffers)"
CACHED="$(get_mem_kb Cached)"
SWAP_TOTAL="$(get_mem_kb SwapTotal)"
SWAP_FREE="$(get_mem_kb SwapFree)"

[ -n "$MEM_TOTAL" ] && [ -n "$MEM_AVAIL" ] && MEM_USED=$((MEM_TOTAL - MEM_AVAIL)) || MEM_USED=0
[ -n "$MEM_TOTAL" ] && [ "$MEM_TOTAL" -gt 0 ] && MEM_USED_PCT=$((MEM_USED * 100 / MEM_TOTAL)) || MEM_USED_PCT=0

[ -n "$SWAP_TOTAL" ] && [ -n "$SWAP_FREE" ] && SWAP_USED=$((SWAP_TOTAL - SWAP_FREE)) || SWAP_USED=0
[ -n "$SWAP_TOTAL" ] && [ "$SWAP_TOTAL" -gt 0 ] && SWAP_USED_PCT=$((SWAP_USED * 100 / SWAP_TOTAL)) || SWAP_USED_PCT=0

ROOT_USE="$(df / 2>/dev/null | awk 'NR==2 {gsub("%","",$5); print $5}')"
[ -z "$ROOT_USE" ] && ROOT_USE=0

# -----------------------------
# CPU governor / frecuencia
# -----------------------------
CPU_GOV_SUMMARY=""
CPU_FREQ_SUMMARY=""
cpu_freq_found=0
for cpu in /sys/devices/system/cpu/cpu[0-9]*; do
    [ -d "$cpu" ] || continue
    gov=$(safe_read_first "$cpu/cpufreq/scaling_governor")
    cur=$(safe_read_first "$cpu/cpufreq/scaling_cur_freq")
    min=$(safe_read_first "$cpu/cpufreq/scaling_min_freq")
    max=$(safe_read_first "$cpu/cpufreq/scaling_max_freq")
    if [ -n "$gov" ] || [ -n "$cur" ] || [ -n "$min" ] || [ -n "$max" ]; then
        cpu_freq_found=1
        cpun=$(basename "$cpu")
        [ -n "$cur" ] && cur_mhz="$(awk -v x="$cur" 'BEGIN{printf "%.0f", x/1000}')" || cur_mhz="N/A"
        [ -n "$min" ] && min_mhz="$(awk -v x="$min" 'BEGIN{printf "%.0f", x/1000}')" || min_mhz="N/A"
        [ -n "$max" ] && max_mhz="$(awk -v x="$max" 'BEGIN{printf "%.0f", x/1000}')" || max_mhz="N/A"
        CPU_GOV_SUMMARY="${CPU_GOV_SUMMARY}${cpun}: ${gov:-N/A}\n"
        CPU_FREQ_SUMMARY="${CPU_FREQ_SUMMARY}${cpun}: cur=${cur_mhz}MHz min=${min_mhz}MHz max=${max_mhz}MHz\n"
    fi
done

# gobernador dominante
MAIN_GOV="$(printf "%b" "$CPU_GOV_SUMMARY" | awk -F': ' 'NF>1 {print $2}' | sort | uniq -c | sort -nr | awk 'NR==1 {print $2}')"
[ -z "$MAIN_GOV" ] && MAIN_GOV="desconocido"

# -----------------------------
# Temperatura
# -----------------------------
MAX_TEMP_C=0
TEMP_INFO=""
for z in /sys/class/thermal/thermal_zone*; do
    [ -d "$z" ] || continue
    t=$(safe_read_first "$z/temp")
    typ=$(safe_read_first "$z/type")
    if [ -n "$t" ]; then
        if [ "$t" -gt 1000 ] 2>/dev/null; then
            tc=$((t / 1000))
        else
            tc=$t
        fi
        [ "$tc" -gt "$MAX_TEMP_C" ] 2>/dev/null && MAX_TEMP_C="$tc"
        TEMP_INFO="${TEMP_INFO}$(basename "$z"): ${typ:-unknown} ${tc}C\n"
    fi
done

if have_cmd sensors; then
    SENSORS_OUT="$(sensors 2>/dev/null)"
else
    SENSORS_OUT=""
fi

# -----------------------------
# zram
# -----------------------------
ZRAM_FOUND=0
ZRAM_INFO=""
for z in /sys/block/zram*; do
    [ -d "$z" ] || continue
    ZRAM_FOUND=1
    name=$(basename "$z")
    disksize=$(safe_read_first "$z/disksize")
    origsize=$(safe_read_first "$z/orig_data_size")
    compsize=$(safe_read_first "$z/compr_data_size")
    memused=$(safe_read_first "$z/mem_used_total")
    ZRAM_INFO="${ZRAM_INFO}${name}\n"
    [ -n "$disksize" ] && ZRAM_INFO="${ZRAM_INFO}  disk size: $(human_bytes "$disksize")\n"
    [ -n "$origsize" ] && ZRAM_INFO="${ZRAM_INFO}  original : $(human_bytes "$origsize")\n"
    [ -n "$compsize" ] && ZRAM_INFO="${ZRAM_INFO}  compr.   : $(human_bytes "$compsize")\n"
    [ -n "$memused" ] && ZRAM_INFO="${ZRAM_INFO}  RAM used : $(human_bytes "$memused")\n"
done

# -----------------------------
# Procesos top
# -----------------------------
TOP_CPU="$(ps -eo pid,comm,%cpu,%mem --sort=-%cpu 2>/dev/null | head -n 11)"
TOP_MEM="$(ps -eo pid,comm,%cpu,%mem,rss --sort=-%mem 2>/dev/null | head -n 11)"

BROWSER_COUNT="$(ps -eo comm,args 2>/dev/null | awk 'BEGIN{IGNORECASE=1} /firefox|chromium|chrome|slimjet|opera|brave/ && !/awk/ {n++} END{print n+0}')"

# -----------------------------
# Sysctl interesantes
# -----------------------------
get_sysctl_val() {
    key="$1"
    if have_cmd sysctl; then
        sysctl -n "$key" 2>/dev/null
    else
        f="/proc/sys/$(echo "$key" | tr . /)"
        [ -r "$f" ] && cat "$f"
    fi
}

VM_SWAPPINESS="$(get_sysctl_val vm.swappiness)"
VM_VFS_CACHE_PRESSURE="$(get_sysctl_val vm.vfs_cache_pressure)"
VM_DIRTY_RATIO="$(get_sysctl_val vm.dirty_ratio)"
VM_DIRTY_BG_RATIO="$(get_sysctl_val vm.dirty_background_ratio)"

# -----------------------------
# Disco / scheduler
# -----------------------------
SCHED_INFO=""
for d in /sys/block/*/queue/scheduler; do
    [ -r "$d" ] || continue
    dev=$(echo "$d" | awk -F/ '{print $4}')
    sched=$(cat "$d")
    SCHED_INFO="${SCHED_INFO}${dev}: ${sched}\n"
done

# -----------------------------
# Puntuaciones
# -----------------------------

# CPU score
CPU_SCORE=70
if [ -n "$CPU_CORES" ]; then
    if [ "$CPU_CORES" -ge 8 ] 2>/dev/null; then
        CPU_SCORE=$((CPU_SCORE + 20))
    elif [ "$CPU_CORES" -ge 4 ] 2>/dev/null; then
        CPU_SCORE=$((CPU_SCORE + 10))
    elif [ "$CPU_CORES" -ge 2 ] 2>/dev/null; then
        CPU_SCORE=$((CPU_SCORE + 0))
    else
        CPU_SCORE=$((CPU_SCORE - 15))
    fi
fi

case "$MAIN_GOV" in
    performance) CPU_SCORE=$((CPU_SCORE + 8)) ;;
    ondemand)    CPU_SCORE=$((CPU_SCORE + 10)) ;;
    schedutil)   CPU_SCORE=$((CPU_SCORE + 10)) ;;
    powersave)   CPU_SCORE=$((CPU_SCORE - 8)) ;;
esac
CPU_SCORE="$(clamp_0_100 "$CPU_SCORE")"

# RAM score
RAM_SCORE=90
if [ "$MEM_USED_PCT" -ge 90 ] 2>/dev/null; then
    RAM_SCORE=20
elif [ "$MEM_USED_PCT" -ge 80 ] 2>/dev/null; then
    RAM_SCORE=40
elif [ "$MEM_USED_PCT" -ge 70 ] 2>/dev/null; then
    RAM_SCORE=55
elif [ "$MEM_USED_PCT" -ge 60 ] 2>/dev/null; then
    RAM_SCORE=70
elif [ "$MEM_USED_PCT" -ge 50 ] 2>/dev/null; then
    RAM_SCORE=80
else
    RAM_SCORE=92
fi

if [ "$SWAP_TOTAL" -eq 0 ] 2>/dev/null; then
    RAM_SCORE=$((RAM_SCORE - 10))
else
    if [ "$SWAP_USED_PCT" -ge 60 ] 2>/dev/null; then
        RAM_SCORE=$((RAM_SCORE - 20))
    elif [ "$SWAP_USED_PCT" -ge 30 ] 2>/dev/null; then
        RAM_SCORE=$((RAM_SCORE - 10))
    fi
fi

[ "$ZRAM_FOUND" -eq 1 ] && RAM_SCORE=$((RAM_SCORE + 5))
RAM_SCORE="$(clamp_0_100 "$RAM_SCORE")"

# Temperatura score
TEMP_SCORE=80
if [ "$MAX_TEMP_C" -eq 0 ] 2>/dev/null; then
    TEMP_SCORE=60
elif [ "$MAX_TEMP_C" -lt 45 ] 2>/dev/null; then
    TEMP_SCORE=98
elif [ "$MAX_TEMP_C" -lt 55 ] 2>/dev/null; then
    TEMP_SCORE=90
elif [ "$MAX_TEMP_C" -lt 65 ] 2>/dev/null; then
    TEMP_SCORE=78
elif [ "$MAX_TEMP_C" -lt 75 ] 2>/dev/null; then
    TEMP_SCORE=60
elif [ "$MAX_TEMP_C" -lt 85 ] 2>/dev/null; then
    TEMP_SCORE=38
else
    TEMP_SCORE=20
fi
TEMP_SCORE="$(clamp_0_100 "$TEMP_SCORE")"

# Disco score
DISK_SCORE=90
if [ "$ROOT_USE" -ge 95 ] 2>/dev/null; then
    DISK_SCORE=15
elif [ "$ROOT_USE" -ge 90 ] 2>/dev/null; then
    DISK_SCORE=30
elif [ "$ROOT_USE" -ge 80 ] 2>/dev/null; then
    DISK_SCORE=55
elif [ "$ROOT_USE" -ge 70 ] 2>/dev/null; then
    DISK_SCORE=72
else
    DISK_SCORE=90
fi
DISK_SCORE="$(clamp_0_100 "$DISK_SCORE")"

# Carga score
LOAD_SCORE=80
if [ -n "$CPU_CORES" ] && [ "$CPU_CORES" -gt 0 ] 2>/dev/null; then
    LOAD_INT="$(printf '%s\n' "$LOAD1" | awk -F. '{print $1}')"
    [ -z "$LOAD_INT" ] && LOAD_INT=0
    if [ "$LOAD_INT" -ge "$CPU_CORES" ] 2>/dev/null; then
        LOAD_SCORE=35
    elif [ "$LOAD_INT" -ge $((CPU_CORES / 2 + 1)) ] 2>/dev/null; then
        LOAD_SCORE=60
    else
        LOAD_SCORE=88
    fi
fi
LOAD_SCORE="$(clamp_0_100 "$LOAD_SCORE")"

# Optimización score
OPT_SCORE=85
[ "$BROWSER_COUNT" -ge 20 ] 2>/dev/null && OPT_SCORE=$((OPT_SCORE - 20))
[ "$BROWSER_COUNT" -ge 10 ] 2>/dev/null && OPT_SCORE=$((OPT_SCORE - 10))
[ "$ROOT_USE" -ge 80 ] 2>/dev/null && OPT_SCORE=$((OPT_SCORE - 10))
[ "$MEM_USED_PCT" -ge 70 ] 2>/dev/null && OPT_SCORE=$((OPT_SCORE - 15))

case "$VM_SWAPPINESS" in
    10|20|30|40|50|60) OPT_SCORE=$((OPT_SCORE + 5)) ;;
    0|"") ;;
    *) OPT_SCORE=$((OPT_SCORE - 3)) ;;
esac

case "$VM_VFS_CACHE_PRESSURE" in
    25|50|75|100) OPT_SCORE=$((OPT_SCORE + 5)) ;;
    "") ;;
    *) OPT_SCORE=$((OPT_SCORE - 3)) ;;
esac
OPT_SCORE="$(clamp_0_100 "$OPT_SCORE")"

GLOBAL_SCORE="$(avg_int "$CPU_SCORE" "$RAM_SCORE" "$TEMP_SCORE" "$DISK_SCORE" "$LOAD_SCORE" "$OPT_SCORE")"
GLOBAL_SCORE="$(clamp_0_100 "$GLOBAL_SCORE")"

# -----------------------------
# Mostrar informe
# -----------------------------
section "PP4MNK SYSTEM AUDIT + SCORE"
say "Fecha: $(date 2>/dev/null)"
say "Host: ${HOSTNAME:-desconocido}"
say "Kernel: ${KERNEL:-desconocido}"
say "Arquitectura: ${ARCH:-desconocida}"
say "Uptime: ${UPTIME:-desconocido}"
say "Load average: ${LOAD1:-?} ${LOAD5:-?} ${LOAD15:-?}"

section "SISTEMA"
if [ -r /etc/os-release ]; then
    cat /etc/os-release 2>/dev/null | tee -a "$REPORT"
else
    say "No se pudo leer /etc/os-release"
fi

section "CPU"
say "Modelo: ${CPU_MODEL:-desconocido}"
say "Núcleos/hilos detectados: ${CPU_CORES:-desconocido}"
if [ "$cpu_freq_found" -eq 1 ]; then
    line
    say "Gobernadores:"
    printf "%b" "$CPU_GOV_SUMMARY" | tee -a "$REPORT"
    line
    say "Frecuencias:"
    printf "%b" "$CPU_FREQ_SUMMARY" | tee -a "$REPORT"
else
    say "No hay información cpufreq disponible."
fi

section "TEMPERATURA"
if [ -n "$TEMP_INFO" ]; then
    printf "%b" "$TEMP_INFO" | tee -a "$REPORT"
    say "Temperatura máxima detectada: ${MAX_TEMP_C}C"
else
    say "No se detectaron thermal_zone accesibles."
fi
if [ -n "$SENSORS_OUT" ]; then
    line
    say "Salida de sensors:"
    printf "%s\n" "$SENSORS_OUT" | tee -a "$REPORT"
fi

section "MEMORIA"
say "RAM total:        $(human_kb "${MEM_TOTAL:-0}")"
say "RAM usada real:   $(human_kb "${MEM_USED:-0}")"
say "RAM disponible:   $(human_kb "${MEM_AVAIL:-0}")"
say "RAM libre bruta:  $(human_kb "${MEM_FREE:-0}")"
say "Buffers:          $(human_kb "${BUFFERS:-0}")"
say "Cache:            $(human_kb "${CACHED:-0}")"
say "Uso RAM:          ${MEM_USED_PCT}%"
say "Swap total:       $(human_kb "${SWAP_TOTAL:-0}")"
say "Swap usada:       $(human_kb "${SWAP_USED:-0}")"
say "Uso swap:         ${SWAP_USED_PCT}%"

if [ "$ZRAM_FOUND" -eq 1 ]; then
    line
    say "zram detectada:"
    printf "%b" "$ZRAM_INFO" | tee -a "$REPORT"
else
    say "zram: no detectada"
fi

section "DISCO"
say "Uso de / : ${ROOT_USE}%"
line
if have_cmd lsblk; then
    lsblk -o NAME,SIZE,ROTA,TYPE,FSTYPE,MOUNTPOINT,MODEL 2>/dev/null | tee -a "$REPORT"
else
    say "lsblk no disponible"
fi
line
say "Schedulers:"
printf "%b" "$SCHED_INFO" | tee -a "$REPORT"

section "RED Y NAVEGADORES"
if have_cmd ip; then
    say "Interfaces:"
    ip -brief addr 2>/dev/null | tee -a "$REPORT"
else
    say "ip no disponible"
fi
line
say "Procesos navegador detectados: $BROWSER_COUNT"
ps -eo pid,comm,%cpu,%mem,args 2>/dev/null | \
awk 'BEGIN{IGNORECASE=1} /firefox|chromium|chrome|slimjet|opera|brave/ && !/awk/ {print}' | \
head -n 20 | tee -a "$REPORT"

section "TOP PROCESOS"
say "Top CPU:"
printf "%s\n" "$TOP_CPU" | tee -a "$REPORT"
line
say "Top RAM:"
printf "%s\n" "$TOP_MEM" | tee -a "$REPORT"

section "PARAMETROS CLAVE"
say "vm.swappiness = ${VM_SWAPPINESS:-N/A}"
say "vm.vfs_cache_pressure = ${VM_VFS_CACHE_PRESSURE:-N/A}"
say "vm.dirty_ratio = ${VM_DIRTY_RATIO:-N/A}"
say "vm.dirty_background_ratio = ${VM_DIRTY_BG_RATIO:-N/A}"

section "PUNTUACION DEL SISTEMA"
say "CPU:"
bar "$CPU_SCORE" | tee -a "$REPORT"
say "Estado: $(judge "$CPU_SCORE")"
line
say "RAM:"
bar "$RAM_SCORE" | tee -a "$REPORT"
say "Estado: $(judge "$RAM_SCORE")"
line
say "Temperatura:"
bar "$TEMP_SCORE" | tee -a "$REPORT"
say "Estado: $(judge "$TEMP_SCORE")"
line
say "Disco:"
bar "$DISK_SCORE" | tee -a "$REPORT"
say "Estado: $(judge "$DISK_SCORE")"
line
say "Carga del sistema:"
bar "$LOAD_SCORE" | tee -a "$REPORT"
say "Estado: $(judge "$LOAD_SCORE")"
line
say "Potencial de optimización:"
bar "$OPT_SCORE" | tee -a "$REPORT"
say "Estado: $(judge "$OPT_SCORE")"
line
say "PUNTUACION GLOBAL:"
bar "$GLOBAL_SCORE" | tee -a "$REPORT"
say "VALORACION FINAL: $(judge "$GLOBAL_SCORE")"

section "DIAGNOSTICO RAPIDO"
if [ "$GLOBAL_SCORE" -ge 85 ]; then
    say "Tu sistema está muy bien afinado. Solo harían falta microajustes."
elif [ "$GLOBAL_SCORE" -ge 70 ]; then
    say "Tu sistema está bien, pero aún tiene margen claro de mejora."
elif [ "$GLOBAL_SCORE" -ge 55 ]; then
    say "Tu sistema es funcional, aunque con varios puntos optimizables."
else
    say "Tu sistema necesita optimización seria para rendir mejor."
fi

line
say "Recomendaciones automáticas:"

if [ "$MEM_USED_PCT" -ge 70 ] 2>/dev/null; then
    say "- RAM alta: reduce pestañas, extensiones y procesos residentes."
fi

if [ "$SWAP_TOTAL" -eq 0 ] 2>/dev/null; then
    say "- No tienes swap: conviene valorar swap o zram para cargas pesadas."
fi

if [ "$MAX_TEMP_C" -ge 70 ] 2>/dev/null; then
    say "- Temperatura elevada: revisa gobernador CPU, ventilación y carga del navegador."
fi

if [ "$ROOT_USE" -ge 80 ] 2>/dev/null; then
    say "- Disco bastante lleno: libera espacio para mejorar fluidez general."
fi

case "$MAIN_GOV" in
    powersave)
        say "- Gobernador en powersave: ganarías respuesta con ondemand o schedutil."
        ;;
    desconocido)
        say "- No se pudo detectar bien cpufreq: quizá faltan módulos o no está expuesto."
        ;;
esac

if [ "$BROWSER_COUNT" -ge 10 ] 2>/dev/null; then
    say "- Hay bastantes procesos de navegador: seguramente es tu foco principal de consumo."
fi

if [ -n "$VM_VFS_CACHE_PRESSURE" ] && [ "$VM_VFS_CACHE_PRESSURE" -gt 100 ] 2>/dev/null; then
    say "- vm.vfs_cache_pressure alto: podrías probar 50 o 25 para más agilidad en disco/caché."
fi

if [ -n "$VM_SWAPPINESS" ] && [ "$VM_SWAPPINESS" -gt 60 ] 2>/dev/null; then
    say "- swappiness alto: en escritorio ligero suele ir mejor en 10-30 o 40 según RAM."
fi

section "INFORME GUARDADO"
say "Ruta: $REPORT"
say ""
say "Fin."

echo ""
echo "Press ENTER to exit..."
read dummy