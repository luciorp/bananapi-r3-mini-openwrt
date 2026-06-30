#!/bin/sh
#
# fancontrol.sh — Controle de velocidade do fan para BananaPi BPI-R3 Mini
#
# Controla o fan via PWM sysfs (pwmchip0/pwm0).
# Lógica invertida: duty_cycle baixo = fan mais rápido
#   duty_cycle = PERIOD  → fan desligado
#   duty_cycle = 0       → fan velocidade máxima
#
# Thresholds (°C):
#   OFF < 42 → LOW 48 → MED 58 → HIGH 68 → CRITICAL 80
#
# Sysfs relevante:
#   /sys/class/pwm/pwmchip0/export        — exporta pwm0
#   /sys/class/pwm/pwmchip0/pwm0/period   — período PWM (ns)
#   /sys/class/pwm/pwmchip0/pwm0/duty_cycle — duty cycle (ns)
#   /sys/class/pwm/pwmchip0/pwm0/enable   — 1=ativo
#   /sys/class/thermal/thermal_zone0/temp — temperatura em mili-Celsius
#

TEMP_OFF=42
TEMP_LOW=48
TEMP_MED=58
TEMP_HIGH=68
TEMP_CRITICAL=80
HYSTERESIS=4
POLL_INTERVAL=5

PWM_CHIP=/sys/class/pwm/pwmchip0
PWM=$PWM_CHIP/pwm0
PERIOD=10000

# Duty cycle (ns): quanto menor, mais rápido o fan
DUTY_OFF=$PERIOD   # fan desligado
DUTY_LOW=7000      # ~30% velocidade
DUTY_MED=4000      # ~60% velocidade
DUTY_HIGH=1500     # ~85% velocidade
DUTY_CRITICAL=0    # 100% velocidade

THERMAL_ZONE=/sys/class/thermal/thermal_zone0

log() {
    logger -t fancontrol -p daemon.info -- "$*"
}

log_warn() {
    logger -t fancontrol -p daemon.warning -- "$*"
}

get_temp() {
    cat "$THERMAL_ZONE/temp" 2>/dev/null
}

set_duty() {
    echo "$1" > "$PWM/duty_cycle" 2>/dev/null
}

cleanup() {
    set_duty "$DUTY_OFF"
    echo 0 > "$PWM/enable" 2>/dev/null
    echo 0 > "$PWM_CHIP/unexport" 2>/dev/null
    log "Serviço encerrado — fan desligado"
    exit 0
}

init() {
    log "Iniciando controle de fan (thresholds: ${TEMP_OFF}/${TEMP_LOW}/${TEMP_MED}/${TEMP_HIGH}/${TEMP_CRITICAL}°C, histerese: ${HYSTERESIS}°C)"

    if [ ! -d "$PWM" ]; then
        echo 0 > "$PWM_CHIP/export" 2>/dev/null
        local retries=10
        while [ "$retries" -gt 0 ]; do
            [ -d "$PWM" ] && break
            sleep 1
            retries=$((retries - 1))
        done
    fi

    if [ ! -d "$PWM" ]; then
        log "ERRO: $PWM não apareceu após export — saindo"
        exit 1
    fi

    echo "$PERIOD"   > "$PWM/period"
    echo normal      > "$PWM/polarity" 2>/dev/null
    echo "$DUTY_OFF" > "$PWM/duty_cycle"
    echo 1           > "$PWM/enable"

    log "PWM inicializado: period=${PERIOD}ns, fan OFF"
}

stage_name() {
    case "$1" in
        0) echo "OFF"      ;;
        1) echo "LOW"      ;;
        2) echo "MED"      ;;
        3) echo "HIGH"     ;;
        4) echo "CRITICAL" ;;
        *) echo "?"        ;;
    esac
}

trap cleanup TERM INT

init

current_stage=0   # 0=off 1=low 2=med 3=high 4=critical

while true; do
    raw_temp=$(get_temp)
    if [ -z "$raw_temp" ]; then
        sleep "$POLL_INTERVAL"
        continue
    fi
    temp_c=$((raw_temp / 1000))

    prev_stage=$current_stage

    case "$current_stage" in
        0)
            [ "$temp_c" -ge "$TEMP_OFF" ] && { current_stage=1; set_duty "$DUTY_LOW"; }
            ;;
        1)
            if [ "$temp_c" -ge "$TEMP_MED" ]; then
                current_stage=2; set_duty "$DUTY_MED"
            elif [ "$temp_c" -lt $((TEMP_OFF - HYSTERESIS)) ]; then
                current_stage=0; set_duty "$DUTY_OFF"
            fi
            ;;
        2)
            if [ "$temp_c" -ge "$TEMP_HIGH" ]; then
                current_stage=3; set_duty "$DUTY_HIGH"
            elif [ "$temp_c" -lt $((TEMP_LOW - HYSTERESIS)) ]; then
                current_stage=1; set_duty "$DUTY_LOW"
            fi
            ;;
        3)
            if [ "$temp_c" -ge "$TEMP_CRITICAL" ]; then
                current_stage=4; set_duty "$DUTY_CRITICAL"
            elif [ "$temp_c" -lt $((TEMP_MED - HYSTERESIS)) ]; then
                current_stage=2; set_duty "$DUTY_MED"
            fi
            ;;
        4)
            [ "$temp_c" -lt $((TEMP_HIGH - HYSTERESIS)) ] && { current_stage=3; set_duty "$DUTY_HIGH"; }
            ;;
    esac

    if [ "$current_stage" != "$prev_stage" ]; then
        log "${temp_c}°C: fan $(stage_name $prev_stage) → $(stage_name $current_stage)"
    fi

    if [ "$current_stage" -eq 4 ]; then
        log_warn "TEMPERATURA CRÍTICA: ${temp_c}°C — fan em MÁXIMO"
    fi

    sleep "$POLL_INTERVAL"
done
