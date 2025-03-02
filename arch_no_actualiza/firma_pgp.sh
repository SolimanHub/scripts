#!/usr/bin/bash

# Usar este script cuando arch no actualice bien
# EJEM
# :: El archivo /var/cache/pacman/pkg/scrcpy-1.24-1-x86_64.pkg.tar.zst está dañado (paquete no válido o dañado (firma PGP)).
# ¿Quiere eliminarlo? [S/n]

# 1- Vamos a descargar una copia nueva de la base de datos del paquete maestro que está en los servidores definidos en pacman.conf, pero forzando la descarga.
pacman -Syy

# 2- Ahora toca gestionar firmas y claves utilizando el comando pacman-key. Con la siguiente opción (--refresh-keys), lograremos actualizar los certificados:
pacman-key --refresh-keys

# 3- Verificaremos las claves maestras actualizadas en el paso anterior. Para esta gestión, emplearemos la opción --populate archlinux:

pacman-key --populate archlinux

# 4- Toca purgar un poco: borraremos los paquetes guardados y limpiaremos repositorios no utilizados, ejecutando nuevamente pacman con las opciones "-Scc"

pacman -Scc --noconfirm

# 5- Por último, forzaremos una actualización completa de la base de datos y actualizaremos todos los paquetes en nuestro sistema ArchLinux:

pacman -Syyu --noconfirm
