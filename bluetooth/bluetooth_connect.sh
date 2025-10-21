#!/bin/bash

bluetoothctl power on
bluetoothctl agent on
bluetoothctl default-agent

echo "Escaneando dispositivos Bluetooth por 10 segundos..."
bluetoothctl scan on &
sleep 10
bluetoothctl scan off

echo "Dispositivos encontrados:"
# Mostrar dispositivos disponibles
bluetoothctl devices

read -p "Ingrese la dirección MAC del dispositivo para conectar: " mac

echo "Conectando al dispositivo $mac..."
bluetoothctl connect $mac
