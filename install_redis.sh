#!/bin/bash

# Actualizar los repositorios y el sistema
echo "Actualizando el sistema..."
sudo dnf update -y

# Instalar Redis
echo "Instalando Redis..."
sudo dnf install redis -y

# Iniciar el servicio de Redis
echo "Iniciando Redis..."
sudo systemctl start redis

# Habilitar Redis para que se inicie al arrancar el sistema
echo "Habilitando Redis al inicio..."
sudo systemctl enable redis

# Verificar que Redis está corriendo
echo "Verificando el estado de Redis..."
sudo systemctl status redis | grep "Active"

# Mostrar la versión de Redis instalada
echo "Redis instalado con éxito. Versión de Redis:"
redis-server --version

# Configuración opcional: habilitar la persistencia de datos (modificar en /etc/redis.conf)
echo "Configuración de Redis: para permitir persistencia, edita el archivo de configuración en /etc/redis.conf"

echo "Instalación completada. Redis está en ejecución."

