#!/bin/sh
#
# install-fancontrol.sh — Instala o controle de fan no BPI-R3 Mini
#
# Execute a partir do seu PC (requer SSH):
#   sh scripts/install-fancontrol.sh [IP_DO_ROUTER]
#   sh scripts/install-fancontrol.sh 192.168.1.1   (padrão se omitido)
#
# Ou copie os arquivos manualmente e execute no próprio router:
#   sh /tmp/install-fancontrol.sh --local
#

ROUTER="${1:-192.168.1.1}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

remote_install() {
    echo "→ Copiando arquivos para root@${ROUTER}..."
    scp "${SCRIPT_DIR}/fancontrol.sh"   "root@${ROUTER}:/usr/bin/fancontrol" || exit 1
    scp "${SCRIPT_DIR}/fancontrol-init" "root@${ROUTER}:/etc/init.d/fancontrol" || exit 1

    echo "→ Configurando permissões e habilitando serviço..."
    ssh "root@${ROUTER}" 'sh -s' << 'EOF'
set -e
chmod +x /usr/bin/fancontrol
chmod +x /etc/init.d/fancontrol

# Para instância anterior se existir
/etc/init.d/fancontrol stop 2>/dev/null || true

# Habilita no boot e inicia agora
/etc/init.d/fancontrol enable
/etc/init.d/fancontrol start

sleep 2
echo ""
echo "=== Status do fan ==="
/etc/init.d/fancontrol status
echo ""
echo "=== Log recente ==="
logread | grep fancontrol | tail -5
EOF
}

local_install() {
    echo "→ Instalando localmente..."
    install -m 755 "${SCRIPT_DIR}/fancontrol.sh"   /usr/bin/fancontrol
    install -m 755 "${SCRIPT_DIR}/fancontrol-init" /etc/init.d/fancontrol

    /etc/init.d/fancontrol stop 2>/dev/null || true
    /etc/init.d/fancontrol enable
    /etc/init.d/fancontrol start

    sleep 2
    echo ""
    echo "=== Status do fan ==="
    /etc/init.d/fancontrol status
    echo ""
    echo "=== Log recente ==="
    logread | grep fancontrol | tail -5
}

# ── Detecta onde está rodando ─────────────────────────────────────────────────
if [ "$1" = "--local" ]; then
    local_install
elif [ "$(uname -m)" = "aarch64" ] || [ "$(uname -m)" = "mips" ]; then
    local_install
else
    remote_install
fi

echo ""
echo "Pronto. O serviço fancontrol está ativo e sobe automaticamente no boot."
echo ""
echo "Comandos úteis no router:"
echo "  /etc/init.d/fancontrol status   — temperatura e estado do fan"
echo "  /etc/init.d/fancontrol restart  — reinicia o controle"
echo "  /etc/init.d/fancontrol stop     — para (fan vai a OFF)"
echo "  logread | grep fancontrol       — histórico de mudanças de velocidade"
