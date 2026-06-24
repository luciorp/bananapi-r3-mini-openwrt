# BananaPi BPI-R3 Mini — Guia Completo: OpenWrt + Modem 5G (Telit FN920C04)

> **O que este guia cobre:** ligar a placa pela primeira vez, atualizar o firmware, configurar o Wi-Fi, instalar o controle de fan e conectar um modem 5G via M.2.

---

## ⚠️ LEIA ANTES DE LIGAR

**O fan do BPI-R3 Mini para de funcionar logo após o boot** — é um bug do OpenWrt. Dentro do case oficial a placa pode passar de 70 °C em idle. **Instale o controle de fan assim que tiver acesso SSH**, antes de qualquer outra coisa. As instruções estão na [Etapa 3](#etapa-3--instalar-o-controle-de-fan-faça-isso-primeiro).

---

## Hardware resumido

| | |
|---|---|
| SoC | MediaTek MT7986A (Filogic 830) — 4× Cortex-A53 @ 2 GHz |
| RAM / Flash | 2 GB DDR4 / 8 GB eMMC + 128 MB SPI-NAND |
| Wi-Fi | Wi-Fi 6 dual-band (2.4 GHz + 5 GHz) |
| Ethernet | 2× 2.5 GbE |
| M.2 Key-M | NVMe SSD (PCIe 2.0 x2) |
| **M.2 Key-B** | **Modem celular** (USB 2.0/3.0 + slot SIM) |
| Chave de boot | 1 chave: posição **NAND** ou **eMMC** |
| USB | 1× USB Type-A |

---

## Etapa 1 — Primeiro boot (firmware de fábrica)

A placa sai de fábrica com o OpenWrt do fabricante gravado no **NAND**. Não precisa gravar nada para começar.

1. Coloque a chave **SW1 na posição NAND**
2. Ligue a placa pelo USB-C
3. Aguarde ~30 segundos

A placa está no ar como roteador. IP padrão: **`192.168.1.1`**

---

## Etapa 2 — Conectar à placa

Você pode conectar de duas formas:

### Opção A — Cabo Ethernet (mais simples)

Conecte um cabo direto entre seu computador e **qualquer porta Ethernet** do BPI-R3 Mini. Seu computador receberá um IP via DHCP no range `192.168.1.x`.

### Opção B — Wi-Fi

O firmware de fábrica pode criar uma rede Wi-Fi aberta ou com SSID padrão. Procure uma rede com nome **`OpenWrt`** ou similar. Conecte e acesse `192.168.1.1`.

> Se não aparecer rede Wi-Fi, use o cabo na primeira vez.

### Acessar via SSH

```bash
ssh root@192.168.1.1
```

Senha: em branco (pressione Enter) ou `admin`, dependendo da versão de fábrica.

### Acessar via interface web (LuCI)

Abra no navegador: **`http://192.168.1.1`**

---

## Etapa 3 — Instalar o controle de fan (faça isso primeiro!)

Enquanto ainda está conectado via Ethernet, instale o controle de fan antes de qualquer outra coisa.

No seu computador (onde você clonou este repositório):

```bash
# Copia os scripts para a placa
scp scripts/fancontrol.sh   root@192.168.1.1:/usr/bin/fancontrol
scp scripts/fancontrol-init root@192.168.1.1:/etc/init.d/fancontrol

# Ativa e inicia o serviço
ssh root@192.168.1.1 "chmod +x /usr/bin/fancontrol /etc/init.d/fancontrol && \
    /etc/init.d/fancontrol enable && \
    /etc/init.d/fancontrol start"
```

Verifique:

```bash
ssh root@192.168.1.1 "/etc/init.d/fancontrol status"
# Saída esperada:
# Temperatura : 48°C
# Fan estado  : LOW (1/3)
```

A partir deste momento o fan funciona automaticamente e sobrevive a reboots.

---

## Etapa 4 — Atualizar para o OpenWrt oficial (sysupgrade)

O firmware de fábrica é o OpenWrt 21.02 do fabricante. Atualize para o OpenWrt 24.10 oficial.

### 4.1 Baixar a imagem de atualização

No seu computador, baixe o arquivo de sysupgrade:

```
https://downloads.openwrt.org/releases/24.10.0/targets/mediatek/filogic/
```

Arquivo: **`openwrt-24.10.0-mediatek-filogic-bananapi_bpi-r3-mini-squashfs-sysupgrade.itb`**

Ou use o [firmware selector](https://firmware-selector.openwrt.org/?target=mediatek%2Ffilogic&id=bananapi_bpi-r3-mini) e clique em **Attended Sysupgrade**.

### 4.2 Enviar para a placa e atualizar

```bash
# Copia a imagem para a placa
scp openwrt-24.10.0-*-sysupgrade.itb root@192.168.1.1:/tmp/

# Aplica o sysupgrade (a placa reinicia automaticamente)
ssh root@192.168.1.1 "sysupgrade -v /tmp/openwrt-24.10.0-*-sysupgrade.itb"
```

Aguarde ~2 minutos. A placa reinicia com o OpenWrt 24.10 oficial.

> **Alternativa pelo LuCI:** System → Backup/Flash Firmware → Flash new firmware image → selecione o `.itb` → Continue.

### 4.3 Reinstalar o controle de fan após o sysupgrade

O sysupgrade apaga arquivos em `/usr/bin` e `/etc/init.d`. Reinstale o fan control:

```bash
scp scripts/fancontrol.sh   root@192.168.1.1:/usr/bin/fancontrol
scp scripts/fancontrol-init root@192.168.1.1:/etc/init.d/fancontrol
ssh root@192.168.1.1 "chmod +x /usr/bin/fancontrol /etc/init.d/fancontrol && \
    /etc/init.d/fancontrol enable && \
    /etc/init.d/fancontrol start"
```

---

## Etapa 5 — Configurar o Wi-Fi (BPI como access point)

No OpenWrt 24.10 o Wi-Fi vem **desativado por padrão**. Ative pelo terminal (via Ethernet):

```bash
ssh root@192.168.1.1
```

```bash
# Define a rede Wi-Fi (mude o SSID e a senha)
uci set wireless.radio0.disabled='0'
uci set wireless.radio0.country='BR'
uci set wireless.default_radio0.ssid='Minha-Rede'
uci set wireless.default_radio0.encryption='psk2'
uci set wireless.default_radio0.key='suasenha123'

# Faz o mesmo para o rádio 2.4 GHz
uci set wireless.radio1.disabled='0'
uci set wireless.radio1.country='BR'
uci set wireless.default_radio1.ssid='Minha-Rede'
uci set wireless.default_radio1.encryption='psk2'
uci set wireless.default_radio1.key='suasenha123'

uci commit wireless
wifi up
```

Em 10–15 segundos a rede `Minha-Rede` aparece no seu celular/computador.

> **Pelo LuCI:** Network → Wireless → Edit em cada rádio → defina SSID, WPA2, senha → Save & Apply.

### Conectar ao Wi-Fi e acessar via SSH

1. Conecte seu celular ou computador à rede `Minha-Rede`
2. Você receberá um IP `192.168.1.x` via DHCP
3. SSH normalmente:

```bash
ssh root@192.168.1.1
```

4. Interface web: `http://192.168.1.1`

| Rádio | Frequência | Padrão |
|---|---|---|
| `radio0` | 5 GHz | Wi-Fi 6 (802.11ax) 3×3 |
| `radio1` | 2.4 GHz | Wi-Fi 6 (802.11ax) 2×2 |

---

## Etapa 6 — Montar o modem Telit FN920C04

### Hardware

1. **Desligue a placa** completamente
2. Encaixe o FN920C04 no slot **M.2 Key-B**
3. Fixe com o parafuso M2
4. Insira o **nano-SIM** no slot da placa (não no modem) — chip para baixo
5. Conecte as antenas 5G nos conectores U.FL (mínimo 2 antenas)
6. Ligue a placa

### Sobre o FN920C04

| Campo | Detalhe |
|---|---|
| Padrão | 5G NR 3GPP Release 17 **RedCap** (não é 5G full) |
| Chipset | Qualcomm Snapdragon X35 (SDX35) |
| Interface | USB 2.0 via M.2 Key-B |
| VID/PID | `0x1bc7` / `0x10a0` (QMI) |
| 5G throughput | DL 220 Mbps / UL 100 Mbps |
| LTE fallback | Cat 4 — DL 150 / UL 50 Mbps |

---

## Etapa 7 — Instalar pacotes do modem

```bash
opkg update

opkg install kmod-usb-net-qmi-wwan \
             kmod-usb-wdm \
             kmod-usb-serial-option \
             uqmi \
             picocom
```

Ative os drivers:

```bash
modprobe qmi_wwan
modprobe option
```

Verifique se o modem foi detectado:

```bash
lsusb | grep 1bc7
# Esperado: Bus 001 Device 002: ID 1bc7:10a0 Telit FN920C04

ls /dev/cdc-wdm*   # deve aparecer /dev/cdc-wdm0
ls /dev/ttyUSB*    # deve aparecer ttyUSB0, ttyUSB1, ttyUSB2
```

### Se o modem não aparecer ou `/dev/cdc-wdm0` não for criado

O kernel 6.6 do OpenWrt 24.10 pode não ter o PID do FN920C04. Injete manualmente:

```bash
echo "1bc7 10a0" > /sys/bus/usb/drivers/qmi_wwan/new_id
```

Para persistir após reboot, adicione ao `/etc/rc.local` (antes do `exit 0`):

```bash
cat >> /etc/rc.local << 'EOF'
sleep 5
modprobe qmi_wwan
echo "1bc7 10a0" > /sys/bus/usb/drivers/qmi_wwan/new_id 2>/dev/null
echo "1bc7 10a4" > /sys/bus/usb/drivers/qmi_wwan/new_id 2>/dev/null
EOF
```

---

## Etapa 8 — Configurar a conexão 5G

### 8.1 Verificar composição USB do modem

```bash
picocom -b 115200 /dev/ttyUSB1
```

Dentro do terminal serial:

```
AT#USBCFG?
```

Resposta esperada: `#USBCFG: 1` (QMI ativo). Se for diferente:

```
AT#USBCFG=1
```

Saia com `Ctrl+A` depois `Ctrl+X`.

### 8.2 Criar a interface de rede

```bash
uci set network.wan_5g=interface
uci set network.wan_5g.proto='qmi'
uci set network.wan_5g.device='/dev/cdc-wdm0'
uci set network.wan_5g.apn='sua.apn.aqui'   # veja tabela abaixo
uci set network.wan_5g.auth='none'
uci set network.wan_5g.pdptype='ipv4v6'
uci set network.wan_5g.defaultroute='1'
uci set network.wan_5g.peerdns='1'
uci commit network

# Adiciona ao firewall como WAN
uci add_list firewall.@zone[1].network='wan_5g'
uci commit firewall

# Sobe a interface
ifup wan_5g
/etc/init.d/firewall restart
```

### APNs — Brasil

| Operadora | APN |
|---|---|
| Claro | `claro.com.br` |
| TIM | `tim.br` |
| Vivo | `zap.vivo.com.br` |
| Oi | `oi.br` |

### 8.3 Verificar a conexão

```bash
# IP recebido pelo modem
ifstatus wan_5g | grep '"address"'

# Ping pela interface 5G
ping -I wwan0 -c 4 8.8.8.8

# Sinal e modo de rede (LTE / 5G NR)
uqmi -d /dev/cdc-wdm0 --get-serving-system
uqmi -d /dev/cdc-wdm0 --get-signal-info
```

---

## Problemas comuns

**Modem não aparece no `lsusb`**
```bash
dmesg | tail -30 | grep -iE "usb|1bc7"
# Verificar se o M.2 Key-B tem alimentação
```

**Interface sem IP — APN errada**
```bash
uqmi -d /dev/cdc-wdm0 --start-network --apn 'claro.com.br' --ip-family ipv4
uqmi -d /dev/cdc-wdm0 --get-data-status
```

**Modem demora para registrar**
Normal — aguarde 20–30 s após o boot:
```bash
watch -n 5 'uqmi -d /dev/cdc-wdm0 --get-serving-system'
```

**Fan não funciona após reboot**
```bash
/etc/init.d/fancontrol status   # verifica se o serviço está ativo
/etc/init.d/fancontrol start    # inicia manualmente se necessário
logread | grep fancontrol        # ver histórico
```

---

## Referência rápida

### Chave de boot SW1

| Posição | Quando usar |
|---|---|
| **NAND** | Boot normal (firmware em uso) |
| **eMMC** | Boot pelo eMMC (se instalado lá) |

### Comandos uqmi

```bash
uqmi -d /dev/cdc-wdm0 --get-serving-system   # operadora + modo (LTE/5G)
uqmi -d /dev/cdc-wdm0 --get-signal-info      # RSSI / RSRP / SNR
uqmi -d /dev/cdc-wdm0 --get-data-status      # conexão ativa?
uqmi -d /dev/cdc-wdm0 --get-imsi             # IMSI do SIM
uqmi -d /dev/cdc-wdm0 --get-iccid            # ICCID do SIM
```

### Temperatura e fan

```bash
# Temperatura atual
cat /sys/class/thermal/thermal_zone0/temp    # divide por 1000 = graus C

# Estado do fan (0=off 1=low 2=med 3=high)
cat /sys/class/thermal/cooling_device0/cur_state

# Status completo
/etc/init.d/fancontrol status
```

---

*OpenWrt 24.10 · BananaPi BPI-R3 Mini (MT7986A) · Telit FN920C04 (5G RedCap Release 17)*

**Referências:**
- [OpenWrt — BPI-R3 Mini](https://openwrt.org/toh/sinovoip/bananapi_bpi_r3_mini)
- [OpenWrt Forum — BPI-R3 Mini](https://forum.openwrt.org/t/bananapi-bpi-r3-mini-is-a-great-openwrt-device/208386)
- [Firmware selector — BPI-R3 Mini](https://firmware-selector.openwrt.org/?target=mediatek%2Ffilogic&id=bananapi_bpi-r3-mini)
- [Telit FN920C04 — página do produto](https://www.telit.com/devices/fn920c04/)
- [Patch kernel — qmi_wwan: Telit FN920C04](https://patches.linaro.org/project/linux-usb/patch/20240418111207.4138126-1-dnlplm@gmail.com/)
- [FW-WEB Wiki — BPI-R3 Mini](https://wiki.fw-web.de/doku.php?id=en:bpi-r3mini:start)
