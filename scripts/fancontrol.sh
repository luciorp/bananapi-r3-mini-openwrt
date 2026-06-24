#!/bin/sh
#
# fancontrol.sh — Controle de velocidade do fan para BananaPi BPI-R3 Mini
#
# Contexto:
#   O BPI-R3 Mini tem um bug no OpenWrt: o fan para de funcionar logo após o
#   boot. Além disso, os trip points padrão do kernel (60°C, 85°C, 115°C) são
#   altos demais para o case fechado, fazendo a placa trabalhar acima de 70°C.
#
#   Este script:
#     1. Corrige o bug de boot do fan (pwm1_enable)
#     2. Redefine os trip points para valores seguros para o case
#     3. Roda em loop controlando o fan diretamente por temperatura
#
# Instalação:
#   Copie o script para o router e execute o instalador:
#     scp scripts/fancontrol.sh root@192.168.1.1:/usr/bin/fancontrol
#     ssh root@192.168.1.1 "chmod +x /usr/bin/fancontrol"
#   Depois instale o serviço procd:
#     scp scripts/fancontrol-init root@192.168.1.1:/etc/init.d/fancontrol
#     ssh root@192.168.1.1 "chmod +x /etc/init.d/fancontrol && /etc/init.d/fancontrol enable && /etc/init.d/fancontrol start"
#
# Sysfs relevante:
#   /sys/class/thermal/thermal_zone0/temp      — temperatura em mili-Celsius
#   /sys/class/thermal/cooling_device0/        — pwm-fan
#   /sys/class/thermal/cooling_device0/cur_state — estado atual (0-3)
#   /sys/class/thermal/cooling_device0/max_state — máximo (tipicamente 3)
#   /sys/class/thermal/thermal_zone0/trip_point_N_temp — thresholds do kernel
#   /sys/devices/platform/pwm-fan/hwmon/hwmon*/pwm1_enable — fix do bug de boot
#

# ── Thresholds de temperatura (°C) ───────────────────────────────────────────
# Ajuste conforme o ambiente (case fechado precisa de margens mais baixas)
TEMP_OFF=42        # abaixo disso → fan DESLIGADO
TEMP_LOW=48        # acima disso → fan BAIXO
TEMP_MED=58        # acima disso → fan MÉDIO
TEMP_HIGH=68       # acima disso → fan ALTO
TEMP_CRITICAL=80   # acima disso → fan MÁXIMO + alerta no log

# Histerese: quantos graus abaixo do limiar para DESCER a velocidade
# Evita o fan ligar/desligar repetidamente na borda do threshold
HYSTERESIS=4

# Intervalo de verificação (segundos)
POLL_INTERVAL=5

# ── Caminhos sysfs ───────────────────────────────────────────────────────────
THERMAL_ZONE="/sys/class/thermal/thermal_zone0"
COOLING_DEV="/sys/class/thermal/cooling_device0"
PWM_FAN_BASE="/sys/devices/platform/pwm-fan/hwmon"

# ── Funções auxiliares ────────────────────────────────────────────────────────

log() {
    logger -t fancontrol -p daemon.info -- "$*"
}

log_warn() {
    logger -t fancontrol -p daemon.warning -- "$*"
}

# Lê temperatura em °C (inteiro)
read_temp() {
    local raw
    raw=$(cat "${THERMAL_ZONE}/temp" 2>/dev/null) || { echo 0; return; }
    echo $((raw / 1000))
}

# Lê estado atual do fan (0=off 1=low 2=med 3=high)
read_fan_state() {
    cat "${COOLING_DEV}/cur_state" 2>/dev/null || echo 0
}

# Lê estado máximo suportado
read_fan_max() {
    cat "${COOLING_DEV}/max_state" 2>/dev/null || echo 3
}

# Define velocidade do fan: 0=off 1=low 2=med 3=high
set_fan() {
    local state="$1"
    local max
    max=$(read_fan_max)

    # Garante que não ultrapassa o máximo
    [ "$state" -gt "$max" ] && state="$max"
    [ "$state" -lt 0 ]       && state=0

    echo "$state" > "${COOLING_DEV}/cur_state" 2>/dev/null
}

# Corrige o bug do fan: escreve 0 em pwm1_enable para reativar controle
# Isso é necessário após o boot — o OpenWrt desativa o fan ao terminar o boot
fix_fan_boot_bug() {
    local hwmon_path
    hwmon_path=$(ls -d "${PWM_FAN_BASE}/hwmon"* 2>/dev/null | head -1)

    if [ -n "$hwmon_path" ] && [ -f "${hwmon_path}/pwm1_enable" ]; then
        local current
        current=$(cat "${hwmon_path}/pwm1_enable" 2>/dev/null)
        if [ "$current" != "0" ]; then
            echo 0 > "${hwmon_path}/pwm1_enable" 2>/dev/null
            log "Bug do boot corrigido: pwm1_enable=${current} → 0 (fan reativado)"
        fi
    else
        log "AVISO: ${PWM_FAN_BASE}/hwmon*/pwm1_enable não encontrado"
    fi
}

# Reconfigura trip points do kernel para valores seguros
# Os padrões (60k, 85k, 115k mC) são altos demais para case fechado
configure_trip_points() {
    local zone="${THERMAL_ZONE}"

    # Desativa o modo automático do kernel temporariamente
    # (o script assume controle manual via cur_state)
    if [ -f "${zone}/policy" ]; then
        local policy
        policy=$(cat "${zone}/policy")
        if [ "$policy" != "user_space" ]; then
            echo user_space > "${zone}/policy" 2>/dev/null && \
                log "Política thermal alterada: ${policy} → user_space (controle manual)"
        fi
    fi

    # Redefine trip points apenas se o sistema suportar escrita
    # trip_point_0 = critical (80°C = proteção de emergência)
    # Os demais podem ou não ser writable dependendo do kernel
    for i in 0 1 2 3 4; do
        local tp="${zone}/trip_point_${i}_temp"
        [ -w "$tp" ] || continue
        case "$i" in
            0) echo 80000 > "$tp" 2>/dev/null ;;   # critical — desliga o sistema
            1) echo 75000 > "$tp" 2>/dev/null ;;   # hot
            2) echo 65000 > "$tp" 2>/dev/null ;;   # active high
            3) echo 55000 > "$tp" 2>/dev/null ;;   # active med
            4) echo 45000 > "$tp" 2>/dev/null ;;   # active low
        esac
    done

    log "Trip points reconfigurados: 45/55/65/75/80°C"
}

# Determina o nível de fan desejado para uma temperatura
desired_fan_level() {
    local temp="$1"
    local current_level="$2"

    if [ "$temp" -ge "$TEMP_CRITICAL" ]; then
        echo 3  # máximo — emergência
    elif [ "$temp" -ge "$TEMP_HIGH" ]; then
        echo 3
    elif [ "$temp" -ge "$TEMP_MED" ]; then
        echo 2
    elif [ "$temp" -ge "$TEMP_LOW" ]; then
        echo 1
    else
        # Aplica histerese para descer a velocidade
        # Só desliga/reduz se estiver suficientemente abaixo do limiar
        if [ "$current_level" -ge 3 ] && [ "$temp" -lt $((TEMP_HIGH - HYSTERESIS)) ]; then
            echo 2
        elif [ "$current_level" -ge 2 ] && [ "$temp" -lt $((TEMP_MED - HYSTERESIS)) ]; then
            echo 1
        elif [ "$current_level" -ge 1 ] && [ "$temp" -lt $((TEMP_LOW - HYSTERESIS)) ]; then
            echo 0
        else
            echo "$current_level"  # mantém o nível atual
        fi
    fi
}

# ── Nomes dos estados para log ────────────────────────────────────────────────
level_name() {
    case "$1" in
        0) echo "OFF"  ;;
        1) echo "LOW"  ;;
        2) echo "MED"  ;;
        3) echo "HIGH" ;;
        *) echo "?"    ;;
    esac
}

# ── Inicialização ─────────────────────────────────────────────────────────────
init() {
    log "Iniciando controle de fan (thresholds: ${TEMP_OFF}/${TEMP_LOW}/${TEMP_MED}/${TEMP_HIGH}°C, histerese: ${HYSTERESIS}°C)"

    # Aguarda thermal zone e cooling device estarem disponíveis
    local retries=10
    while [ $retries -gt 0 ]; do
        if [ -f "${THERMAL_ZONE}/temp" ] && [ -f "${COOLING_DEV}/cur_state" ]; then
            break
        fi
        sleep 2
        retries=$((retries - 1))
    done

    if [ ! -f "${THERMAL_ZONE}/temp" ]; then
        log "ERRO: ${THERMAL_ZONE}/temp não encontrado — saindo"
        exit 1
    fi

    fix_fan_boot_bug
    configure_trip_points

    local temp
    temp=$(read_temp)
    local fan
    fan=$(desired_fan_level "$temp" 0)
    set_fan "$fan"
    log "Estado inicial: ${temp}°C → fan $(level_name $fan)"
}

# ── Loop principal ────────────────────────────────────────────────────────────
main_loop() {
    local prev_level=-1
    local prev_temp=0

    while true; do
        local temp
        temp=$(read_temp)

        local current_level
        current_level=$(read_fan_state)

        local desired
        desired=$(desired_fan_level "$temp" "$current_level")

        # Alerta de temperatura crítica
        if [ "$temp" -ge "$TEMP_CRITICAL" ]; then
            log_warn "TEMPERATURA CRÍTICA: ${temp}°C — fan em MÁXIMO"
        fi

        # Só atua e loga quando há mudança de estado
        if [ "$desired" != "$current_level" ]; then
            set_fan "$desired"
            log "${temp}°C: fan $(level_name $current_level) → $(level_name $desired)"
            prev_level="$desired"
        fi

        prev_temp="$temp"
        sleep "$POLL_INTERVAL"
    done
}

# ── Entrada ───────────────────────────────────────────────────────────────────
case "${1:-start}" in
    start)
        init
        main_loop
        ;;
    status)
        temp=$(read_temp)
        fan=$(read_fan_state)
        max=$(read_fan_max)
        echo "Temperatura : ${temp}°C"
        echo "Fan estado  : $(level_name $fan) (${fan}/${max})"
        ;;
    *)
        echo "Uso: $0 {start|status}"
        exit 1
        ;;
esac
