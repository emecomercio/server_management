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
    dnf install -y curl wget grep tree
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
    # Configurar firewall para permitir trafico http y https
    echo "Configurando firewall para Apache..."
    firewall-cmd --permanent --add-service=http
    firewall-cmd --permanent --add-service=https
    firewall-cmd --reload
}

install_mysql() {
    echo "Instalando MySQL Server..."
    sleep 3
    dnf install -y mysql-server
    echo "Puede tardar un poco"
    systemctl start mysqld
    systemctl enable mysqld
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
config_git() {
    echo "Configurando Git..."
    sleep 1
    echo "Ingresa tu nombre de usuario"
    read -r gitname;
    echo "Ingresa tu email de usuario"
    read -r gitemail;
    sudo -u $SUDO_USER git config --global user.name "$gitname"
    sudo -u $SUDO_USER git config --global user.email "$gitemail"
}

config_apache() {
    echo "Configurando Apache..."
    sleep 1
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
    echo "1) Actualizar sistema (recomendado)"
    echo "2) Instalar y configurar todo (no recomendado)"
    echo "3) Instalaciones"
    echo "4) Configuraciones"
    echo "5) Salir"

    read -p "Elija una opción [1-4]: " opcion_principal
    case $opcion_principal in
        1)
            update_system
            ;;
        2)
            update_system
            install_utilities
            install_git
            install_apache
            install_php
            install_mysql
            install_chrome
            install_vscode
            config_git
            config_apache
            config_mysql_secure
            enable_window_options
            ;;
        3)
            while true; do
                clear

                echo "Menú Instalaciones"
                echo "1) Instalar utilidades (recomendado)"
                echo "2) Instalar git"
                echo "3) Instalar apache"
                echo "4) Instalar MySQL Server"
                echo "5) Instalar PHP"
                echo "6) Instalar Google Chrome"
                echo "7) Instalar VsCode"
                echo "8) Volver al menú principal"

                read -p "Elija una opción [1-8]: " opcion_instalaciones
                case $opcion_instalaciones in
                    1)
                        install_utilities
                        ;;
                    2)
                        install_git
                        ;;
                    3)
                        install_apache
                        ;;
                    4)
                        install_mysql
                        ;;
                    5)
                        install_php
                        ;;
                    6)
                        install_chrome
                        ;;
                    7)
                        install_vscode
                        ;;
                    8)
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
        5)
            echo "Saliendo..."
            exit 0
            ;;
        *)
            echo "Opción no válida"
            ;;
    esac
    continue_msg
done