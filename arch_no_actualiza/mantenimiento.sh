#!/usr/bin/bash

# Configurar colores
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
NC='\033[0m'

# Script de mantenimiento para Arch Linux y derivadas
# Combina corrección de paquetes, actualización completa y limpieza del sistema

# Función para limpiar si se interrumpe el script
cleanup() {
    echo -e "${RED}\n[!] Interrupción capturada. Limpiando...${NC}"
    exit 1
}
trap cleanup SIGINT SIGTERM

# 1. Forzar actualización de la base de datos de paquetes
echo -e "${YELLOW}\n[1/10] Actualizando base de datos de paquetes...${NC}"
sudo pacman -Syy

# 2. Actualizar claves GPG
echo -e "${YELLOW}\n[2/10] Actualizando claves GPG...${NC}"
sudo pacman-key --refresh-keys

# 3. Poblar claves de Arch Linux
echo -e "${YELLOW}\n[3/10] Restableciendo claves principales...${NC}"
sudo pacman-key --populate archlinux

# 4. Limpieza completa de caché de paquetes
echo -e "${YELLOW}\n[4/10] Limpiando caché de paquetes...${NC}"
sudo pacman -Scc --noconfirm

# 5. Obtimizando mirrorlist
echo -e "${YELLOW}\n[5/10] Obtimizando mirrorlist...${NC}"
sudo reflector --latest 10 --sort rate --protocol https --save /etc/pacman.d/mirrorlist

# 6. Eliminando datos de sync
echo -e "${YELLOW}\n[6/10] Eliminando datos de sync...${NC}"
sudo rm -rf /var/lib/pacman/sync

# 7. Actualización completa del sistema
echo -e "${YELLOW}\n[7/10] Actualizando sistema...${NC}"
sudo pacman -Syyu --noconfirm

# 8. Eliminar paquetes huerfanos
echo -e "${YELLOW}\n[8/10] Buscando paquetes huerfanos...${NC}"
huerfanos=$(pacman -Qtdq)
if [ -n "$huerfanos" ]; then
    echo "Eliminando huerfanos:"
    echo "$huerfanos"
    sudo pacman -Rns --noconfirm $huerfanos
else
    echo "No se encontraron paquetes huerfanos"
fi

# 9. Limpieza avanzada de caché (conserva últimas 2 versiones)
echo -e "${YELLOW}\n[9/10] Limpieza avanzada de caché...${NC}"
if command -v paccache &>/dev/null; then
    sudo paccache -rk2       # Mantiene 2 versiones anteriores
    sudo paccache -ruk0      # Elimina versiones no instaladas
else
    echo -e "${YELLOW}\nInstalando pacman-contrib para limpieza avanzada...${NC}"
    sudo pacman -S --noconfirm pacman-contrib
    sudo paccache -rk2
    sudo paccache -ruk0
fi

# 10. Limpieza de archivos temporales
echo -e "${YELLOW}\n[10/10] Limpiando archivos temporales...${NC}"
sudo systemd-tmpfiles --clean
sudo rm -rf /var/tmp/* /tmp/* 2>/dev/null

echo -e "${GREEN}\n[✓] Mantenimiento completado exitosamente!${NC}"
