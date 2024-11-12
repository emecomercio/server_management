echo "Instalando Redis (Valkey)..."
dnf install valkey-compat-redis -y

# Iniciar el servicio de Redis
echo "Iniciando Redis..."
systemctl start valkey

# Habilitar Redis para que se inicie al arrancar el sistema
echo "Habilitando Redis al inicio..."
systemctl enable valkey

# Verificar que Redis está corriendo
echo "Verificando el estado de Redis..."
systemctl status valkey

# Mostrar la versión de Redis instalada
echo "Redis instalado con éxito. Versión de Redis:"
redis-server --version

# Configuración opcional: habilitar la persistencia de datos (modificar en /etc/redis.conf)
echo "Configuración de Redis: para permitir persistencia, edita el archivo de configuración en /etc/redis.conf"

echo "Instalación completada. Redis está en ejecución."

