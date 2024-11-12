#!/bin/bash

#
continue_msg() {
    echo -e "\n--------------------------------"
    read -p "Presione Enter para continuar..."
}
# Funciones
update_system() {
    echo "Actualizando todo (puede tardar bastante)..."
    sleep 3
    dnf update -y
}

install_utilities() {
    echo "Instalando utilidades..."
    sleep 3
    dnf install -y curl wget tree
    dnf install -y gedit
    dnf install -y gnome-tweaks
}

install_git() {
    echo "Instalando Git..."
    sleep 3
    dnf install -y git
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

install_php() {
   echo "Instalando PHP y librerias necesarias"
   sleep 4
   dnf install -y https://rpms.remirepo.net/fedora/remi-release-$(rpm -E %fedora).rpm
   dnf makecache
   dnf module reset php
   dnf module enable php:remi-8.3
   dnf install -y php php-cli php-common php-curl php-mysqlnd php-xml php-mbstring php-zip -y
}

install_chrome() {
    echo "Instalando Google Chrome..."
    sleep 3
    chrome_url="https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm"
    chrome_rpm="/tmp/google-chrome-stable.rpm"
    wget -q -O "$chrome_rpm" "$chrome_url"
    dnf install -y "$chrome_rpm"
}

install_vscode() {
    echo "Instalando VSCode..."
    sleep 3
    rpm --import https://packages.microsoft.com/keys/microsoft.asc
    echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" | tee /etc/yum.repos.d/vscode.repo > /dev/null
    dnf check-update
    dnf install -y code
}
create_ssh_key() {
    ssh-keygen -t rsa -b 4096 -C "$gitemail"
    eval "$(ssh-agent -s)"
    ssh-add ~/.ssh/id_rsa
    cat ~/.ssh/id_rsa.pub
}
config_git() {
    echo "Configurando Git..."
    sleep 1
    echo "Ingresa tu nombre de usuario"
    read -r gitname;
    echo "Ingresa tu email de usuario"
    read -r gitemail;
    sudo -u $SUDO_USER git config --global user.name "$gitname"
    sudo -u $SUDO_USER git config --global user.email "$gitemail"

    echo "¿Deseas crear una clave SSH? (s/n)"
    read -r create_ssh;
    if [ "$create_ssh" == "s" ]; then
        create_ssh_key
    elif [ "$create_ssh" == "n" ]; then
        return
    else
        echo "Opción inválida"
    fi
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

make_apache_url() {
    if ! groups $USER | grep -q apache; then
        echo "Debes estar en el grupo apache para ejecutar esta funcion (ejecuta 'Configurar apache')"
        return
    fi

    echo "Creando archivo de configuracion de apache..."

    sleep 1

    read -p "Ingresa el nombre del proyecto: " project_name
    read -p "Ingresa el correo de administrador: " admin_email

    if [ -z "$project_name" ] || [ -z "$admin_email" ]; then
        echo "El nombre del proyecto y el correo de administrador son requeridos."
        return
    fi

    if [[ ! "$project_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo "El nombre del proyecto solo debe contener caracteres alfanuméricos, guiones y guiones bajos."
        return
    fi

    if [[ ! "$admin_email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        echo "El correo electrónico ingresado no es válido."
        return
    fi

    project_dir="/var/www/$project_name"
    if [ ! -d "$project_dir" ]; then
        echo "Creando el directorio $project_dir..."
        mkdir "$project_dir"
        chown -R $SUDO_USER:apache "$project_dir"
    fi

    if [ ! -d "$project_dir/public" ]; then
        echo "Creando el directorio publico $project_dir/public..."
        mkdir "$project_dir/public"
        chown -R $SUDO_USER:apache "$project_dir/public"
    fi

    echo "<VirtualHost *:80>
    ServerAdmin $admin_email
    DocumentRoot /var/www/$project_name/public

     <Directory /var/www/$project_name/public>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog /var/log/httpd/$project_name-error.log
    CustomLog /var/log/httpd/$project_name-access.log combined
    </VirtualHost>" | tee /etc/httpd/conf.d/$project_name.conf > /dev/null

    echo "127.0.0.1 $project_name.test" | tee -a /etc/hosts > /dev/null

    systemctl restart httpd
    echo "Apache configurado"
    sleep 1
    echo "Puede acceder a $project_name.test en su navegador"
}

config_mysql_secure() {
    echo "Configurando MySQL Server (ejecutando secure installation)..."
    sleep 1
    mysql_secure_installation
}

enable_window_options() {
    echo "Activando opciones de ventana..."
    echo "Dale en 'continuar' al cartel y cierra la ventana"
    sudo -u $SUDO_USER gnome-tweaks
    sudo -u $SUDO_USER gsettings set org.gnome.desktop.wm.preferences button-layout ':minimize,maximize,close'
}
# Menu
while true; do
    clear

    echo "Menú Principal"
    echo "1) Actualizar sistema (recomendado) COMPOSER"
    echo "2) Instalaciones"
    echo "3) Configuraciones"
    echo "4) Salir"

    read -p "Elija una opción [1-4]: " opcion_principal
    case $opcion_principal in
        1)
            install_composer
            ;;
        2)
            while true; do
                clear

                echo "Menú Instalaciones"
                echo "1) Instalar Apache"
                echo "2) Instalar MySQL Server"
                echo "3) Instalar PHP"
                echo "4) Instalar Composer"
                echo "5) Instalar Redis"
                echo "6) Volver al menú principal"

                read -p "Elija una opción [1-8]: " opcion_instalaciones
                case $opcion_instalaciones in
                    1)
                        install_apache
                        ;;
                    2)
                        install_mysql
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
                echo "1) Configurar git"
                echo "2) Configurar apache (general)"
                echo "3) Configurar Apache para un nuevo proyecto"
                echo "4) Configurar MySQL Server (secure installation)"
                echo "5) Activar opciones de ventana"
                echo "6) Volver al menú principal"

                read -p "Elija una opción [1-6]: " opcion_configuraciones
                case $opcion_configuraciones in
                    1)
                        config_git
                        ;;
                    2)
                        config_apache
                        ;;
                    3)
                        make_apache_url
                        ;;
                    4)
                        config_mysql_secure
                        ;;
                    5)
                        enable_window_options
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