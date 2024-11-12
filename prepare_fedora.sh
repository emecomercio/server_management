#!/bin/bash
if [[ $EUID -ne 0 ]]; then
   echo "Este script debe ejecutarse como administrador" >&2
   exit 1
fi
continue_msg() {
    echo -e "\n--------------------------------"
    read -p "Presione Enter para continuar..."
}

update_system() {
    echo "Actualizando todo (puede tardar bastante)..."
    sleep 3
    dnf update -y
}

install_apache() {
    echo "Instalando Apache..."
    sleep 3
    dnf install -y httpd
    systemctl start httpd
    systemctl enable httpd
}

install_mysql() {
    echo "Instalando MySQL Server..."
    sleep 3
    dnf install -y mysql-server
    echo "Puede tardar un poco"
    systemctl start mysqld
    systemctl enable mysqld
}

install_composer() {
    echo "Instalando Composer..."
    sleep 3
    php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
    php -r "if (hash_file('sha384', 'composer-setup.php') === 'dac665fdc30fdd8ec78b38b9800061b4150413ff2e3b6f88543c636f7cd84f6db9189d43a81e5503cda447da73c7e5b6') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
    php composer-setup.php
    php -r "unlink('composer-setup.php');"
    mv composer.phar /usr/local/bin/composer
}

install_redis() {
    echo "Instalando Redis (Valkey)..."
    dnf install valkey-compat-redis -y

    systemctl start valkey
    systemctl enable valkey
    echo "Verificando el estado de Redis..."
    systemctl status valkey
    echo "Redis instalado con éxito. Versión de Redis:"
    redis-server --version
    echo "Configuración de Redis: para permitir persistencia, edita el archivo de configuración en /etc/redis.conf"
    echo "Instalación completada. Redis está en ejecución."
}

install_php() {
   echo "Instalando PHP y librerias necesarias"
   sleep 4
   dnf install -y https://rpms.remirepo.net/fedora/remi-release-$(rpm -E %fedora).rpm
   dnf makecache
   dnf module reset php
   dnf module enable php:remi-8.3
   dnf install -y php php-cli php-common php-curl php-mysqlnd php-xml php-mbstring php-zip -y
}

config_apache() {
    echo "Configurando Apache..."
    sleep 1
    firewall-cmd --permanent --add-service=http
    firewall-cmd --permanent --add-service=https
    firewall-cmd --reload
    usermod -aG apache $USER
    echo "$SUDO_USER agregado a grupo apache"
    sleep 1
    chown -R $SUDO_USER:apache /var/www
    echo "Permisos para $SUDO_USER:apache ajustados en /var/www"
    sleep 1
}

config_mysql_secure() {
    echo "Configurando MySQL Server (ejecutando secure installation)..."
    sleep 1
    mysql_secure_installation
}

while true; do
    clear

    echo "Menú Principal"
    echo "1) Actualizar sistema (recomendado si no lo has hecho)"
    echo "2) Instalaciones"
    echo "3) Configuraciones"
    echo "4) Salir"

    read -p "Elija una opción [1-4]: " opcion_principal
    case $opcion_principal in
        1)
            update_system
            ;;
        2)
            while true; do
                clear

                echo "Menú Instalaciones"
                echo "1) Instalar Apache"
                echo "2) Instalar MySQL Server"
                echo "3) Instalar PHP"
                echo "4) Instalar Composer"
                echo "5) Instalar Redis (Valkey)"
                echo "6) Volver al menú principal"

                read -p "Elija una opción [1-6]: " opcion_instalaciones
                case $opcion_instalaciones in
                    1)
                        install_apache
                        ;;
                    2)
                        install_mysql
                        ;;
                    3)
                        install_php
                        ;;
                    4)
                        install_composer
                        ;;
                    5) 
                        install_redis
                        ;;
                    6)
                        break
                        ;;
                    *)
                        echo "Opción no válida"
                        ;;
                esac
                continue_msg
            done
            ;;
        3)
            while true; do
                clear

                echo "Menú Configuraciones"
                echo "1) Configurar Apache"
                echo "2) Configurar MySQL Server (mysql_secure_installation)"
                echo "3) Volver al menú principal"

                read -p "Elija una opción [1-3]: " opcion_configuraciones
                case $opcion_configuraciones in
                    1)
                        config_apache
                        ;;
                    2)
                        config_mysql_secure
                        ;;
                    3)
                        break
                        ;;
                    *)
                        echo "Opción no válida"
                        ;;
                esac
                continue_msg
            done
            ;;
        4)
            echo "Saliendo..."
            exit 0
            ;;
        *)
            echo "Opción no válida"
            ;;
    esac
    continue_msg
done
