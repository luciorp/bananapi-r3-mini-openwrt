# BananaPi BPI-R3 Mini — OpenWrt + Telit FN920C04 5G RedCap via M.2 (QMI)

## Índice

1. [Hardware](#1-hardware)
2. [Montagem do Modem M.2](#2-montagem-do-modem-m2)
3. [Instalar OpenWrt no BPI-R3 Mini](#3-instalar-openwrt-no-bpi-r3-mini) — via pendrive USB
   - [⚠️ IMPORTANTE — Instalar fan control logo após o boot](#️-importante--instale-o-controle-de-fan-antes-de-qualquer-outra-coisa)
   - [3.6 Acesso via Wi-Fi](#36-acesso-via-wi-fi)
4. [Suporte do kernel ao FN920C04](#4-suporte-do-kernel-ao-fn920c04)
5. [Instalar Pacotes e Dependências](#5-instalar-pacotes-e-dependências)
6. [Verificar o Modem](#6-verificar-o-modem)
7. [Configurar Composição USB QMI (AT commands)](#7-configurar-composição-usb-qmi-at-commands)
8. [Configurar Interface de Rede (UCI)](#8-configurar-interface-de-rede-uci)
9. [Testar a Conexão 5G](#9-testar-a-conexão-5g)
10. [Troubleshooting](#10-troubleshooting)
11. [Referência Rápida](#11-referência-rápida)

---

## 1. Hardware

### BananaPi BPI-R3 Mini

| Componente | Especificação |
|---|---|
| SoC | MediaTek MT7986A (Filogic 830) — 4x ARM Cortex-A53 @ 2 GHz |
| RAM | 2 GB DDR4 |
| Flash | 8 GB eMMC + 128 MB SPI-NAND |
| Wi-Fi | Wi-Fi 6 dual-band (2.4 / 5 GHz) — MT7976C |
| Ethernet | 2x 2.5 GbE SFP |
| **M.2 Key-M** | PCIe 2.0 x2 — NVMe SSD 2280 |
| **M.2 Key-B** | USB 2.0/3.0 + SIM — **slot do modem celular** |
| SIM | Slot nano-SIM no board, conectado ao M.2 Key-B |
| OpenWrt | Suportado desde 23.05 — alvo `mediatek/filogic` |

### Telit FN920C04 — 5G RedCap

| Campo | Detalhe |
|---|---|
| Padrão | **5G NR 3GPP Release 17 RedCap** (Reduced Capability) |
| Chipset | Qualcomm Snapdragon X35 (SDX35) |
| Form factor | M.2 Key-B — 30 × 42 × 2,3 mm |
| Interface host | **USB 2.0** (480 Mbps) + PCIe Gen 2.0 |
| VID USB | `0x1bc7` (Telit/Cinterion) |
| 5G throughput | DL 220 Mbps / UL 100 Mbps (Sub-6 GHz SA/NSA) |
| LTE fallback | Cat 4 — DL 150 Mbps / UL 50 Mbps |
| Temperatura | −40 °C a +85 °C (industrial) |
| SIM | Dual UICC (1,8 V / 3 V) |
| GNSS integrado | L1 + L5 |

> **RedCap ≠ Full 5G.** O FN920C04 implementa 5G RedCap (Release 17), otimizado para IoT industrial, wearables e terminais fixos. Velocidade menor que FN980/FN990, porém menor custo e consumo.

### Bandas suportadas (FN920C04-WW)

**5G NR:** n1 n2 n3 n5 n7 n8 n12 n13 n14 n18 n20 n25 n26 n28 n30 n38 n40 n41 n48 n53 n66 n70 n71 n77 n78 n79

**LTE:** B1 B2 B3 B4 B5 B7 B8 B12 B13 B14 B17 B18 B19 B20 B25 B26 B28 B30 B34 B38 B39 B40 B41 B42 B43 B48 B66 B71

---

## 2. Montagem do Modem M.2

1. Com o board **desligado e sem alimentação**
2. Encaixe o FN920C04 no slot **M.2 Key-B** (conector de 75 pinos, lado com os pinos maiores)
3. Fixe com o parafuso M2 × 3 mm
4. Insira o **nano-SIM** no slot da placa (não no modem) — chip para baixo
5. Conecte as antenas 5G nos conectores U.FL do modem (mínimo 2 × antena principal + 1 × diversidade)

> O FN920C04 tem antenas separadas para GNSS — se quiser usar o GNSS, conecte também a antena GNSS no conector correspondente.

---

## 3. Instalar OpenWrt no BPI-R3 Mini

### 3.1 Chave de boot (SW1) — única chave

O BPI-R3 Mini tem **uma única chave** (não 4 como no BPI-R3 full) que seleciona entre os dois storages internos. Não há slot SD.

| Posição | Boot de |
|---|---|
| **NAND** | SPI-NAND — **posição para instalar** |
| **eMMC** | eMMC — posição de uso permanente |

> A chave fica na borda da placa. A placa sai de fábrica com OpenWrt do fabricante gravado no NAND. Use essa instalação de fábrica para gravar o OpenWrt no eMMC.

### 3.2 Imagens necessárias

Baixe do [firmware selector](https://firmware-selector.openwrt.org/?target=mediatek%2Ffilogic&id=bananapi_bpi-r3-mini) ou diretamente:

```
https://downloads.openwrt.org/releases/24.10.0/targets/mediatek/filogic/
```

Baixe os 5 arquivos abaixo (substitua `24.10.0` pela versão atual):

| Arquivo | Gravado em |
|---|---|
| `openwrt-24.10.0-...-bananapi_bpi-r3-mini-emmc-gpt.bin` | `/dev/mmcblk0` (tabela de partições) |
| `openwrt-24.10.0-...-bananapi_bpi-r3-mini-emmc-preloader.bin` | `/dev/mmcblk0boot0` (bootrom) |
| `openwrt-24.10.0-...-bananapi_bpi-r3-mini-emmc-bl31-uboot.fip` | `/dev/mmcblk0p3` (U-Boot + ATF) |
| `openwrt-24.10.0-...-bananapi_bpi-r3-mini-initramfs-recovery.itb` | `/dev/mmcblk0p4` (recovery) |
| `openwrt-24.10.0-...-bananapi_bpi-r3-mini-squashfs-sysupgrade.itb` | `/dev/mmcblk0p5` (rootfs) |

### 3.3 Preparar o pendrive USB

Formate um pendrive como **FAT32** e copie os 5 arquivos acima para a raiz.

> O BPI-R3 Mini tem uma porta USB Type-A. É a mesma porta usada para o pendrive de instalação.

### 3.4 Gravar OpenWrt no eMMC via USB (procedimento completo)

#### Passo 1 — Chave na posição NAND, ligar a placa

1. Coloque a chave SW1 na posição **NAND**
2. Insira o pendrive USB com os arquivos de instalação
3. Ligue a placa

O OpenWrt de fábrica do NAND sobe automaticamente. O IP padrão é `192.168.1.1`.

#### Passo 2 — Acessar via SSH

```bash
ssh root@192.168.1.1
# senha: admin (ou vazia, depende da versão de fábrica)
```

Se não funcionar via Ethernet, conecte um adaptador USB-serial (3,3 V) ao conector UART da borda da placa (**GND, RX, TX** — lembre de cruzar RX/TX) a **115200 bps 8N1**.

#### Passo 3 — Montar o pendrive

```bash
# Identificar o device do pendrive
ls /dev/sd*         # deve aparecer /dev/sda ou /dev/sda1

mkdir -p /mnt/usb
mount /dev/sda1 /mnt/usb
ls /mnt/usb         # confirme que os arquivos estão lá
```

#### Passo 4 — Gravar no eMMC

Execute os comandos abaixo **na ordem exata**. Defina a variável com o prefixo dos arquivos para simplificar:

```bash
# Ajuste o prefixo conforme a versão baixada
IMG="/mnt/usb/openwrt-24.10.0-mediatek-filogic-bananapi_bpi-r3-mini"

# 1. Tabela de partições GPT
dd if="${IMG}-emmc-gpt.bin" of=/dev/mmcblk0 bs=512 conv=fsync
sync

# 2. Preloader (bootrom) — requer desabilitar proteção de escrita antes
echo 0 > /sys/block/mmcblk0boot0/force_ro
dd if="${IMG}-emmc-preloader.bin" of=/dev/mmcblk0boot0 bs=512 conv=fsync
sync

# 3. Recarregar tabela de partições (necessário após gravar a GPT)
mdev -s 2>/dev/null || true
sleep 2

# 4. U-Boot + ARM Trusted Firmware
dd if="${IMG}-emmc-bl31-uboot.fip" of=/dev/mmcblk0p3 bs=512 conv=fsync

# 5. Recovery kernel
dd if="${IMG}-initramfs-recovery.itb" of=/dev/mmcblk0p4 bs=512 conv=fsync

# 6. Sistema de arquivos (rootfs)
dd if="${IMG}-squashfs-sysupgrade.itb" of=/dev/mmcblk0p5 bs=512 conv=fsync
sync

# 7. Habilitar boot pelo eMMC
mmc bootpart enable 1 1 /dev/mmcblk0
```

#### Passo 5 — Trocar a chave e reiniciar

```bash
# Desmontar o pendrive
umount /mnt/usb
```

1. Desligue a placa (sem o `reboot`, para poder mexer na chave com segurança)
2. Coloque a chave SW1 na posição **eMMC**
3. Retire o pendrive (opcional, mas recomendado)
4. Ligue — o OpenWrt 24.10 sobe do eMMC

### 3.5 Primeiro acesso via Ethernet

Conecte um cabo Ethernet entre o seu computador e **qualquer uma das portas 2.5 GbE** do BPI-R3 Mini (a porta LAN padrão é a mais próxima do conector USB-C de alimentação).

```bash
ssh root@192.168.1.1   # sem senha no primeiro boot
```

```bash
# Defina senha imediatamente
passwd

# Defina timezone (exemplo: Brasil)
uci set system.@system[0].timezone='BRT3'
uci set system.@system[0].zonename='America/Sao_Paulo'
uci commit system
```

Acesso web (LuCI): `http://192.168.1.1`

---

> ## ⚠️ IMPORTANTE — Instale o controle de fan antes de qualquer outra coisa
>
> O BPI-R3 Mini tem um **bug conhecido no OpenWrt**: o fan para de funcionar logo após o boot completar. Dentro do case oficial a placa pode atingir **73 °C ou mais em idle** sem o fan ligado, o que pode danificar o hardware ao longo do tempo.
>
> **Instale o controle de fan imediatamente após o primeiro boot**, antes de configurar qualquer outra coisa.
>
> ```bash
> # No seu computador (onde clonou este repositório):
> scp scripts/fancontrol.sh   root@192.168.1.1:/usr/bin/fancontrol
> scp scripts/fancontrol-init root@192.168.1.1:/etc/init.d/fancontrol
>
> ssh root@192.168.1.1 "chmod +x /usr/bin/fancontrol /etc/init.d/fancontrol && \
>     /etc/init.d/fancontrol enable && \
>     /etc/init.d/fancontrol start"
> ```
>
> Confirme que está funcionando:
>
> ```bash
> ssh root@192.168.1.1 "/etc/init.d/fancontrol status"
> # Deve mostrar: Temperatura : XX°C  |  Fan estado : LOW/MED/HIGH
> ```
>
> O script corrige o bug do boot automaticamente toda vez que a placa iniciar, e controla a velocidade do fan por temperatura com histerese. Veja a seção [Scripts de controle do fan](#fan-control) para detalhes.

---

## 3.6 Acesso via Wi-Fi

O OpenWrt 24.10 no BPI-R3 Mini **não cria rede Wi-Fi por padrão** — as interfaces wireless precisam ser configuradas manualmente no primeiro uso.

### Configurar Wi-Fi pelo terminal (SSH/UART)

```bash
# Listar rádios disponíveis
uci show wireless

# Configurar rádio 5 GHz (radio0 = MT7976C 5G)
uci set wireless.radio0.disabled='0'
uci set wireless.radio0.channel='auto'
uci set wireless.radio0.country='BR'

# Criar rede Wi-Fi 5 GHz
uci set wireless.default_radio0.ssid='BPI-R3-Mini'
uci set wireless.default_radio0.encryption='psk2'
uci set wireless.default_radio0.key='suasenha123'

# Configurar rádio 2.4 GHz (radio1)
uci set wireless.radio1.disabled='0'
uci set wireless.radio1.channel='auto'
uci set wireless.radio1.country='BR'

uci set wireless.default_radio1.ssid='BPI-R3-Mini'
uci set wireless.default_radio1.encryption='psk2'
uci set wireless.default_radio1.key='suasenha123'

uci commit wireless
wifi up
```

Após `wifi up`, as redes aparecem em 10–15 segundos.

### Conectar via Wi-Fi e SSH

1. No seu celular ou computador, conecte à rede `BPI-R3-Mini`
2. O roteador distribui DHCP — você receberá um IP no range `192.168.1.x`
3. Acesse via SSH:

```bash
ssh root@192.168.1.1
```

4. Acesso web: abra `http://192.168.1.1` no navegador

### Configurar Wi-Fi pelo LuCI (interface web)

Se já estiver acessando via Ethernet ou SSH, o LuCI é mais simples:

1. Abra `http://192.168.1.1` no navegador
2. Vá em **Network → Wireless**
3. Clique em **Edit** no rádio desejado (5 GHz ou 2.4 GHz)
4. Configure **SSID**, **Encryption** (`WPA2-PSK`) e **Key**
5. Clique em **Save & Apply**

### Notas sobre Wi-Fi no BPI-R3 Mini

| Rádio | Frequência | Chip | Padrão |
|---|---|---|---|
| `radio0` | 5 GHz | MT7976C | Wi-Fi 6 (802.11ax) — 3×3 |
| `radio1` | 2.4 GHz | MT7976C | Wi-Fi 6 (802.11ax) — 2×2 |

> O driver `mt76` para o MT7976C está incluído no OpenWrt 24.10. Não é necessário instalar pacotes adicionais para Wi-Fi básico.

---

## 4. Suporte do kernel ao FN920C04

### Situação nos kernels

O suporte ao FN920C04 no driver `qmi_wwan` foi adicionado em **abril de 2024** (patch de Daniele Palmas, mergeado no kernel 6.9).

| Kernel | Status FN920C04 |
|---|---|
| ≥ 6.9 (mainline) | Suporte nativo — PIDs já no `qmi_wwan.c` |
| 6.6.x (OpenWrt 24.10) | **Pode não ter** — depende de backport |
| < 6.6 | Sem suporte — necessário adicionar manualmente |

### Verificar se o OpenWrt 24.10 já inclui o patch

```bash
grep -r "10a0\|10a4\|10a9" /lib/modules/$(uname -r)/kernel/drivers/net/usb/ 2>/dev/null
# ou via modinfo
modinfo qmi_wwan | grep alias | grep 1bc7
```

### Se o PID não estiver no driver — adicionar manualmente

Após carregar o módulo, injete o ID via sysfs:

```bash
# Carrega o módulo (se não estiver carregado)
modprobe qmi_wwan

# Adiciona o FN920C04 PID 0x10a0 ao qmi_wwan em tempo real
echo "1bc7 10a0" > /sys/bus/usb-serial/drivers/qmi_wwan/new_id 2>/dev/null || \
echo "1bc7 10a0" > /sys/bus/usb/drivers/qmi_wwan/new_id

# Repita para o PID ativo no seu modem (10a0, 10a4 ou 10a9)
```

Para persistir entre reboots, adicione no `/etc/rc.local` antes do `exit 0`:

```bash
cat >> /etc/rc.local << 'EOF'
sleep 5
modprobe qmi_wwan
echo "1bc7 10a0" > /sys/bus/usb/drivers/qmi_wwan/new_id 2>/dev/null
echo "1bc7 10a4" > /sys/bus/usb/drivers/qmi_wwan/new_id 2>/dev/null
EOF
```

Também adicione o PID ao `option` (serial AT):

```bash
modprobe option
echo "1bc7 10a0" > /sys/bus/usb-serial/drivers/option1/new_id 2>/dev/null
```

---

## 5. Instalar Pacotes e Dependências

```bash
opkg update

# Driver de rede QMI (cria /dev/cdc-wdm* e wwan0)
opkg install kmod-usb-net-qmi-wwan

# Gerenciamento do dispositivo USB CDC WDM
opkg install kmod-usb-wdm

# Portas seriais AT (/dev/ttyUSBx) — driver option
opkg install kmod-usb-serial-option

# uqmi — protocolo QMI para netifd + utilitário CLI
opkg install uqmi

# Terminal serial para enviar AT commands
opkg install picocom

# (opcional) Interface web para configurar o modem
opkg install luci-proto-qmi
```

Ative os módulos:

```bash
modprobe qmi_wwan
modprobe option
```

Verifique se os módulos carregaram:

```bash
lsmod | grep -E "qmi|option"
```

---

## 6. Verificar o Modem

### 6.1 Verificar presença USB

```bash
lsusb
```

Saída esperada (FN920C04 em composição QMI):
```
Bus 001 Device 002: ID 1bc7:10a0 Telit Wireless Solutions FN920C04
```

PIDs possíveis dependendo da composição ativa:

| PID | Interfaces (ordem) |
|---|---|
| `0x10a0` | rmnet (QMI) + ttyUSB AT/NMEA + ttyUSB AT + ttyUSB diag |
| `0x10a4` | rmnet (QMI) + ttyUSB AT + ttyUSB AT + ttyUSB diag |
| `0x10a9` | rmnet (QMI) + ttyUSB AT + ttyUSB diag + log + ADB |

Se o PID for outro (ex: 0x10a2, 0x10a7 = MBIM), veja seção 7.

### 6.2 Verificar nós de dispositivo

```bash
ls /dev/cdc-wdm*    # interface QMI → /dev/cdc-wdm0
ls /dev/ttyUSB*     # portas AT   → ttyUSB0, ttyUSB1, ttyUSB2
ip link | grep wwan # interface de rede → wwan0
```

### 6.3 Verificar status do modem via uqmi

```bash
# Estado de registro na rede
uqmi -d /dev/cdc-wdm0 --get-serving-system

# Informações de sinal
uqmi -d /dev/cdc-wdm0 --get-signal-info

# IMSI do SIM
uqmi -d /dev/cdc-wdm0 --get-imsi

# ICCID do SIM
uqmi -d /dev/cdc-wdm0 --get-iccid
```

---

## 7. Configurar Composição USB QMI (AT commands)

### 7.1 Acessar a porta AT

```bash
# A porta AT do FN920C04 é geralmente ttyUSB1 na composição 0x10a0
picocom -b 115200 /dev/ttyUSB1

# Teste básico
AT
OK
```

Se não responder, tente `ttyUSB0` ou `ttyUSB2`.

### 7.2 Verificar composição atual

```
AT#USBCFG?
#USBCFG: 1

OK
```

### 7.3 Composições do FN920C04

| `AT#USBCFG` | PID USB | Protocolo de dados |
|---|---|---|
| `1` | `0x10a0` | **QMI (rmnet)** ← recomendado para OpenWrt |
| `3` | `0x10a4` | QMI (rmnet) — sem NMEA |
| `5` | `0x10a9` | QMI + ADB |
| `2` | `0x10a2` | MBIM |
| `6` | `0x10a7` | MBIM alternativo |

> Consulte o AT Command Reference Guide do FN920 para a lista completa. Os valores acima são os documentados nos patches do kernel Linux.

Para forçar composição QMI (se necessário):

```
AT#USBCFG=1
OK
```

O modem reinicia a enumeração USB automaticamente. Confirme com `lsusb` — deve aparecer PID `0x10a0`.

### 7.4 Verificar modo de rede (5G RedCap / LTE)

```
AT+COPS?
+COPS: 0,0,"TIM",13
```

Modo de acesso (`13` = 5G NR NSA, `11` = LTE, `0` = GSM).

Para forçar seleção automática de rede:
```
AT+COPS=0
OK
```

Verificar tipo de serviço RedCap registrado:
```
AT+CEREG?
+CEREG: 0,1,"XXXX","XXXXXXXX",13
```

---

## 8. Configurar Interface de Rede (UCI)

### 8.1 Criar interface WAN QMI

```bash
uci set network.wan_5g=interface
uci set network.wan_5g.proto='qmi'
uci set network.wan_5g.device='/dev/cdc-wdm0'
uci set network.wan_5g.apn='sua.apn.aqui'
uci set network.wan_5g.auth='none'
uci set network.wan_5g.pdptype='ipv4v6'
uci set network.wan_5g.defaultroute='1'
uci set network.wan_5g.peerdns='1'
uci set network.wan_5g.metric='10'
uci commit network
```

Bloco UCI em `/etc/config/network`:

```
config interface 'wan_5g'
    option proto        'qmi'
    option device       '/dev/cdc-wdm0'
    option apn          'sua.apn.aqui'
    option auth         'none'
    option pdptype      'ipv4v6'
    option defaultroute '1'
    option peerdns      '1'
    option metric       '10'
```

### 8.2 Adicionar ao firewall (zona WAN)

```bash
uci add_list firewall.@zone[1].network='wan_5g'
uci commit firewall
/etc/init.d/firewall restart
```

### 8.3 Ativar a interface

```bash
ifup wan_5g

# Acompanhe o processo
logread -f | grep -E "netifd|qmi|wan_5g"
```

---

## 9. Testar a Conexão 5G

```bash
# Verificar IP recebido
ifstatus wan_5g | grep -E '"address"|"gateway"'

# Ping pela interface 5G
ping -I wwan0 -c 4 8.8.8.8

# Rota padrão
ip route show default

# DNS
nslookup google.com

# Sinal detalhado
uqmi -d /dev/cdc-wdm0 --get-signal-info
# Saída inclui: rssi, rsrq, rsrp, snr

# Confirmar registro
uqmi -d /dev/cdc-wdm0 --get-serving-system
# "selected-network": deve mostrar "lte" (4G) ou nr (5G NR/RedCap)
```

---

## 10. Troubleshooting

### `lsusb` não mostra o FN920C04

```bash
# Checar se USB está ativo
lsusb -t

# Mensagens do kernel
dmesg | tail -50 | grep -iE "usb|1bc7|fn920"

# Verificar se o M.2 Key-B tem alimentação (alguns boards precisam de jumper)
```

### `/dev/cdc-wdm0` não criado — PID não reconhecido pelo qmi_wwan

```bash
# Ver PID atual do modem
lsusb | grep 1bc7
# Ex: ID 1bc7:10a2 → composição MBIM → mudar para QMI via AT

# Se PID for 10a0 mas wdm não aparece → adicionar ID manualmente
echo "1bc7 10a0" > /sys/bus/usb/drivers/qmi_wwan/new_id
```

### Interface `wwan0` aparece mas sem IP

```bash
# APN errada é a causa mais comum
# Teste manual sem netifd
uqmi -d /dev/cdc-wdm0 --start-network \
     --apn 'sua.apn.aqui' \
     --auth-type none \
     --ip-family ipv4

# Verificar estado de dados
uqmi -d /dev/cdc-wdm0 --get-data-status
```

### Modem demora para registrar

O FN920C04 pode levar 15–30 s após o boot para se registrar na rede. Aguarde antes de testar:

```bash
# Loop de status enquanto aguarda registro
watch -n 5 'uqmi -d /dev/cdc-wdm0 --get-serving-system 2>&1'
```

### OpenWrt não tem o PID no kernel após reboot

Adicione ao `/etc/rc.local` conforme descrito na seção 4. Alternativamente, compile o OpenWrt com o patch incluso ou use uma imagem snapshot (mais recente).

### Verificar log do netifd

```bash
logread | grep -E "netifd|qmi|wan_5g"
```

---

## 11. Referência Rápida

### Chave de boot BPI-R3 Mini (única chave SW1)

| Situação | Posição SW1 |
|---|---|
| Instalar (gravar eMMC via USB) | **NAND** |
| Uso permanente após instalação | **eMMC** |

### PIDs USB — FN920C04 (VID `0x1bc7`)

| PID | Composição | Driver de rede |
|---|---|---|
| `0x10a0` | QMI + AT/NMEA + AT + diag | `qmi_wwan` — **use este** |
| `0x10a4` | QMI + AT + AT + diag | `qmi_wwan` |
| `0x10a9` | QMI + AT + diag + log + ADB | `qmi_wwan` |
| `0x10a2` | MBIM + AT + AT + diag | `cdc_mbim` |
| `0x10a7` | MBIM alternativo | `cdc_mbim` |

### Comandos uqmi úteis

```bash
uqmi -d /dev/cdc-wdm0 --get-serving-system     # operadora + modo de acesso
uqmi -d /dev/cdc-wdm0 --get-signal-info        # RSSI / RSRP / RSRQ / SNR
uqmi -d /dev/cdc-wdm0 --get-data-status        # conexão de dados ativa?
uqmi -d /dev/cdc-wdm0 --get-imsi               # IMSI do SIM
uqmi -d /dev/cdc-wdm0 --get-iccid             # ICCID do SIM
uqmi -d /dev/cdc-wdm0 --get-pin-status         # PIN necessário?
uqmi -d /dev/cdc-wdm0 --verify-pin1 <PIN>      # desbloquear PIN
```

### APNs comuns — Brasil

| Operadora | APN | Auth |
|---|---|---|
| Claro | `claro.com.br` | none |
| TIM | `tim.br` | none |
| Vivo | `zap.vivo.com.br` | none |
| Oi | `oi.br` | none |

---

*Documentação para: OpenWrt 24.10.x · BananaPi BPI-R3 Mini (MT7986A) · Telit FN920C04 (5G RedCap 3GPP Rel-17)*

**Referências:**
- [Telit FN920C04 — página do produto](https://www.telit.com/devices/fn920c04/)
- [FN920C04-WW Datasheet — Techship](https://techship.com/downloads/telit-cinterion-fn920c04-ww-datasheet/)
- [Patch Linux kernel — qmi_wwan: add Telit FN920C04 compositions](https://patches.linaro.org/project/linux-usb/patch/20240418111207.4138126-1-dnlplm@gmail.com/)
- [Patch Linux kernel — option: add Telit FN920C04 MBIM compositions](https://www.spinics.net/lists/stable/msg776239.html)
- [BPI-R3 Forum — Flash NOR/NAND/eMMC from SD](https://forum.banana-pi.org/t/banana-pi-r3-how-to-flash-nor-nand-or-emmc-from-the-sd-cards-bootmenu/19719)
- [OpenWrt Forum — BPI-R3 Mini](https://forum.openwrt.org/t/bananapi-bpi-r3-mini-is-a-great-openwrt-device/208386)
- [OpenWrt — QMI/LTE setup](https://openwrt.org/docs/guide-user/network/wan/wwan/ltedongle)
- [Telit Linux USB Drivers User Guide r20](https://www.telit.com/wp-content/uploads/2025/10/TC_Telit_Modules_Linux_USB_Drivers_User_Guide_r20.pdf)
