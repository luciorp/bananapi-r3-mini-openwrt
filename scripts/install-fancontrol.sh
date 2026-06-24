#!/bin/sh
#
# install-fancontrol.sh — Instala o controle de fan no BPI-R3 Mini
#
# Execute a partir do seu PC (requer SSH e scp):
#   sh scripts/install-fancontrol.sh 192.168.1.1
#
# Ou dentro do próprio router:
#   sh /tmp/install-fancontrol.sh
#

ROUTER="${1:-192.168.1.1}"
SCRIPT_DIR="$(dirname "$0")"

if [ "$(uname -m)" != "aarch64" ] && [ "$(uname -m)" != "mips" ]; then
    # Rodando no PC — copia via SCP e instala remotamente
    echo "→ Copiando arquivos para ${ROUTER}..."
    scp "${SCRIPT_DIR}/fancontrol.sh"   "root@${ROUTER}:/usr/bin/fancontrol"
    scp "${SCRIPT_DIR}/fancontrol-init" "root@${ROUTER}:/etc/init.d/fancontrol"

    echo "→ Configurando permissões e habilitando serviço..."
    ssh "root@${ROUTER}" 'sh -s' << 'EOF'
chmod +x /usr/bin/fancontrol
chmod +x /etc/init.d/fancontrol
/etc/init.d/fancontrol enable
/etc/init.d/fancontrol start
echo "---"
echo "Status do fan:"
/usr/bin/fancontrol status
EOF
else
    # Rodando no próprio router
    echo "→ Instalando localmente..."
    install -m 755 "${SCRIPT_DIR}/fancontrol.sh"   /usr/bin/fancontrol
    install -m 755 "${SCRIPT_DIR}/fancontrol-init" /etc/init.d/fancontrol
    /etc/init.d/fancontrol enable
    /etc/init.d/fancontrol start
    echo "Status:"
    fancontrol status
fi

echo ""
echo "Pronto. O serviço fancontrol está ativo e inicia automaticamente no boot."
echo ""
echo "Comandos úteis no router:"
echo "  /etc/init.d/fancontrol status   — temperatura e estado do fan"
echo "  /etc/init.d/fancontrol restart  — reinicia o controle"
echo "  logread | grep fancontrol       — histórico de mudanças de velocidade"
