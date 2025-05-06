#!/usr/bin/bash

# Script de mantenimiento para Arch Linux y derivadas
# Combina corrección de paquetes, actualización completa y limpieza del sistema

# Función para limpiar si se interrumpe el script
cleanup() {
    echo -e "\n[!] Interrupción capturada. Limpiando..."
    exit 1
}
trap cleanup SIGINT SIGTERM

# 1. Forzar actualización de la base de datos de paquetes
echo -e "\n[1/8] Actualizando base de datos de paquetes..."
sudo pacman -Syy

# 2. Actualizar claves GPG
echo -e "\n[2/8] Actualizando claves GPG..."
sudo pacman-key --refresh-keys

# 3. Poblar claves de Arch Linux
echo -e "\n[3/8] Restableciendo claves principales..."
sudo pacman-key --populate archlinux

# 4. Limpieza completa de caché de paquetes
echo -e "\n[4/8] Limpiando caché de paquetes..."
sudo pacman -Scc --noconfirm

# 5. Actualización completa del sistema
echo -e "\n[5/8] Actualizando sistema..."
sudo pacman -Syyu --noconfirm

# 6. Eliminar paquetes huerfanos
echo -e "\n[6/8] Buscando paquetes huerfanos..."
huerfanos=$(pacman -Qtdq)
if [ -n "$huerfanos" ]; then
    echo "Eliminando huerfanos:"
    echo "$huerfanos"
    sudo pacman -Rns --noconfirm $huerfanos
else
    echo "No se encontraron paquetes huerfanos"
fi

# 7. Limpieza avanzada de caché (conserva últimas 2 versiones)
echo -e "\n[7/8] Limpieza avanzada de caché..."
if command -v paccache &>/dev/null; then
    sudo paccache -rk2       # Mantiene 2 versiones anteriores
    sudo paccache -ruk0      # Elimina versiones no instaladas
else
    echo "Instalando pacman-contrib para limpieza avanzada..."
    sudo pacman -S --noconfirm pacman-contrib
    sudo paccache -rk2
    sudo paccache -ruk0
fi

# 8. Limpieza de archivos temporales
echo -e "\n[8/8] Limpiando archivos temporales..."
sudo systemd-tmpfiles --clean
sudo rm -rf /var/tmp/* /tmp/* 2>/dev/null

echo -e "\n[✓] Mantenimiento completado exitosamente!"
