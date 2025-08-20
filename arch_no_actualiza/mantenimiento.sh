#!/usr/bin/bash

# Configurar colores
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
NC='\033[0m'

# Script de mantenimiento para Arch Linux y derivadas

cleanup() {
    echo -e "${RED}\n[!] Interrupción capturada. Limpiando...${NC}"
    exit 1
}
trap cleanup SIGINT SIGTERM

# 1. Limpiar database local de paquetes (sync)
echo -e "${YELLOW}\n[1/13] Eliminando base local de paquetes (sync)...${NC}"
sudo rm -rf /var/lib/pacman/sync

# 2. Borrar cache de paquetes descargados (prevención corrupción)
echo -e "${YELLOW}\n[2/13] Limpiando cache de paquetes para evitar corrupción...${NC}"
sudo rm -rf /var/cache/pacman/pkg/*

# 3. Optimizar mirrorlist
echo -e "${YELLOW}\n[3/13] Optimizando mirrorlist...${NC}"
if command -v reflector &>/dev/null; then
    sudo reflector --latest 10 --sort rate --protocol https --save /etc/pacman.d/mirrorlist
else
    echo -e "${YELLOW}Instalando reflector...${NC}"
    sudo pacman -Sy --noconfirm reflector
    sudo reflector --latest 10 --sort rate --protocol https --save /etc/pacman.d/mirrorlist
fi

# 4. Forzar actualización de la base de datos de paquetes (doble Syy)
echo -e "${YELLOW}\n[4/13] Sincronizando repositorios...${NC}"
sudo pacman -Syy

# 5. Reparar/reinstalar keyring y pacman si detecta corrupción o error de lectura
echo -e "${YELLOW}\n[5/13] Reparando keyring y núcleo de pacman...${NC}"
sudo pacman -Syyu --needed archlinux-keyring pacman

# 6. Re-inicializar claves GnuPG y repoblar claves de Arch
echo -e "${YELLOW}\n[6/13] Reinicializando claves gnupg y repoblando claves Arch...${NC}"
sudo rm -rf /etc/pacman.d/gnupg
sudo pacman-key --init
sudo pacman-key --populate archlinux

# 7. Refrescar todas las claves GPG
echo -e "${YELLOW}\n[7/13] Refrescando todas las claves GPG (opcional)...${NC}"
sudo pacman-key --refresh-keys

# 8. Limpieza completa de caché de paquetes (Scc)
echo -e "${YELLOW}\n[8/13] Eliminando caché de paquetes (Scc)...${NC}"
sudo pacman -Scc --noconfirm

# 9. Actualización completa del sistema
echo -e "${YELLOW}\n[9/13] Actualizando sistema...${NC}"
sudo pacman -Syyu

# 10. Eliminar paquetes huérfanos
echo -e "${YELLOW}\n[10/13] Buscando y eliminando paquetes huérfanos...${NC}"
huerfanos=$(pacman -Qtdq)
if [ -n "$huerfanos" ]; then
    echo "Eliminando huérfanos:"
    echo "$huerfanos"
    sudo pacman -Rns $huerfanos
else
    echo "No se encontraron paquetes huérfanos"
fi

# 11. Limpieza avanzada de caché (paccache)
echo -e "${YELLOW}\n[11/13] Limpieza avanzada de caché...${NC}"
if command -v paccache &>/dev/null; then
    sudo paccache -rk2
    sudo paccache -ruk0
else
    echo -e "${YELLOW}Instalando pacman-contrib para limpieza avanzada...${NC}"
    sudo pacman -S --noconfirm pacman-contrib
    sudo paccache -rk2
    sudo paccache -ruk0
fi

# 12. Limpieza de archivos temporales
echo -e "${YELLOW}\n[12/13] Limpiando archivos temporales...${NC}"
sudo systemd-tmpfiles --clean
sudo rm -rf /var/tmp/* /tmp/* 2>/dev/null

# 13. Sugerencia final: revisar estado de servicios y archivos de registro
echo -e "${YELLOW}\n[13/13] Comprobando errores de sistema y servicios...${NC}"
systemctl --failed || true
echo "Para revisar los registros: journalctl -p err -b"

echo -e "${GREEN}\n[✓] Mantenimiento completado exitosamente!${NC}"

