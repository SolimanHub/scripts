#!/bin/bash
set -e

# Definimos colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # Sin color

if [ "$(id -u)" -eq 0 ]; then
    echo -e "${RED}¡No ejecutes el script como root! Usa 'sudo' para ejecutarlo.${NC}"
    exit 1
fi

echo -e "${GREEN}Actualizando la base de datos de paquetes y actualizando paquetes instalados...${NC}"
sudo pacman -Syyu --noconfirm

echo -e "${YELLOW}Eliminando paquetes huérfanos (dependencias no necesarias)...${NC}"
sudo pacman -Rns $(pacman -Qdtq) --noconfirm 2>/dev/null || echo -e "${YELLOW}No hay paquetes huérfanos para eliminar${NC}"

echo -e "${YELLOW}Limpiando caché de paquetes...${NC}"
sudo pacman -Sc --noconfirm

echo -e "${CYAN}Ejecutando fstrim...${NC}"
sudo fstrim -av

# Opcional: Limpiar cache de AUR (si usas yay)
if command -v yay &> /dev/null; then
    echo -e "${YELLOW}Limpiando caché de AUR (yay)...${NC}"
    yay -Sc --noconfirm
fi

echo -e "${GREEN}Proceso de actualización completado.${NC}"
