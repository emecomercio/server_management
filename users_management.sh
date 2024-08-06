#!/bin/bash

# Comprobación de permisos de superusuario
if [ "$EUID" -ne 0 ]; then
  echo "Este script debe ejecutarse con permisos de superusuario (root)."
  exit 1
fi
# Funciones para verificar existencias
group_exists() {
    local group_name="$1"
    getent group "$group_name" > /dev/null 2>&1
}
user_exists() {
    local username="$1"
    id "$username" > /dev/null 2>&1
}
# Funciones comunes
continue_msg() {
    echo -e "\n--------------------------------"
    read -p "Presione Enter para continuar..."
}
request_username() {
    echo "Ingrese el nombre del usuario:"
    read username

}
request_group() {
    echo "Ingrese el nombre del grupo:"
    read group_name

}
update_password() {
    local username="$1"

    while true; do
        echo "Ingrese la contraseña del usuario (mínimo 8 caracteres):"
        read -s password
        echo "Confirme la contraseña del usuario:"
        read -s password_confirm

        if [ "$password" != "$password_confirm" ]; then
            echo "Las contraseñas no coinciden. Inténtelo de nuevo."
        elif [ ${#password} -lt 8 ]; then
            echo "La contraseña debe tener al menos 8 caracteres. Inténtelo de nuevo."
        else
            break
        fi
    done

    echo -e "$password\n$password" | passwd $username
}
# Gestión de logs
save_log() {
    touch /var/log/users_created.log
    touch /var/log/users_modified.log
    touch /var/log/users_deleted.log
    local username="$1"
    local action="$2"
    local info="$3"
    local DATE=`date +%F`
    local TIME`date +%T`
    local log_file
    local log_entry
    if [ "$action" == "created" ]; then
        log_file=/var/log/users_created.log
        log_entry="Usuario $username creado el $DATE a las $TIME"
    elif [ "$action" == "modified" ]; then
        log_file=/var/log/users_modified.log
        log_entry="Usuario $username modificado ($info) el $DATE a las $TIME"
    elif [ "$action" == "deleted" ]; then
        log_file=/var/log/users_deleted.log
        log_entry="Usuario $username eliminado el $DATE a las $TIME"
    fi
    echo $log_entry >> $log_file
}
read_log() {
    local log_file="$1"
    if [ ! -f "$log_file" ]; then
        echo "El archivo de log '$log_file' no existe."
        return
    elif [ ! -s "$log_file" ]; then
        echo "El archivo de log '$log_file' está vacío."
        return
    fi
    echo "Contenido del archivo de log '$log_file':"
    echo "-------------------------------------------------------"
    cat "$log_file"
}
list_last_20_boots(){
    echo "Listando los últimos 20 arranques del sistema:"
    journalctl --list-boots | tail -n 20
}
list_last_15_ssh_boots() {
    echo "Listando los últimos 15 arranques SSH del sistema:"
    echo "Resultados con sshd.service:"
    echo "----------------------------"
    journalctl -u sshd.service | grep -i 'starting OpenSSH' | tail -n 15
    echo "Resultados con ssh.service:"
    echo "----------------------------"
    journalctl -u ssh.service | grep -i 'starting OpenSSH' | tail -n 15
}
list_last_logins() {
    echo "Listando los últimos inicios de sesión:"
    lastlog
}
last_login_by_username(){
    request_username
    if ! user_exists "$username"; then
        echo "El usuario '$username' no existe."
        return
    fi
    lastlog -u "$username"
}
list_failed_ssh_boots() {
    echo "Listando los arranques fallidos de SSH:"
    if [ ! -f "/var/log/auth.log" ]; then
        echo "El archivo de log '/var/log/auth.log' no existe."
        return
    elif [ ! -s "/var/log/auth.log" ]; then
        echo "El archivo de log '/var/log/auth.log' está vacío."
        return
    fi
    grep -i 'failed' /var/log/auth.log
}
list_failed_boots() {
    echo "Listando los últimos 25 arranques fallidos del sistema:"
    echo "------------------------------Failed------------------------------"
    journalctl | grep --color=always -i 'failed' | tail -n 25
    echo "------------------------------Failure------------------------------"
    journalctl | grep --color=always -i 'failure' | tail -n 25
    echo "------------------------------Error------------------------------"
    journalctl | grep --color=always -i 'error' | tail -n 25
    echo "------------------------------Denied------------------------------"
    journalctl | grep --color=always -i 'denied' | tail -n 25
    echo "------------------------------Refused------------------------------"
    journalctl | grep --color=always -i 'refused' | tail -n 25
    echo "------------------------------Disconnected------------------------------"
    journalctl | grep --color=always -i 'disconnected' | tail -n 25
    echo "------------------------------Unreachable------------------------------"
    journalctl | grep --color=always -i 'unreachable' | tail -n 25
    echo "------------------------------Timeout------------------------------"
    journalctl | grep --color=always -i 'timeout' | tail -n 25
}
# Funciones de menu Grupo
create_group() {
    request_group
    if group_exists "$group_name"; then
        echo "El grupo '$group_name' ya existe."
    else
        groupadd $group_name
        echo "Grupo $group_name creado."
    fi
}
delete_group() {
    request_group
    if ! group_exists "$group_name"; then
        echo "El grupo '$group_name' no existe."
        return
    fi

    groupdel "$group_name"
    if [ $? -eq 0 ]; then
        echo "Grupo $group_name eliminado exitosamente."
    else
        echo "Error al eliminar el grupo $group_name."
        return
    fi
}
list_group() {
    request_group
    if group_exists "$group_name"; then
        echo "Listado de los usuarios del grupo '$group_name'"
        echo -e "Nota: los usuarios listados son aquellos cuyo grupo es uno de sus grupos secundarios.\n"
        echo -n "$group_name: "
        members=$(getent group "$group_name" | cut -d: -f4)     
        if [ -z "$members" ]; then
            echo "-"
        else
            echo "$members"
        fi
    else
        echo "El grupo '$group_name' no existe."
    fi
}
list_groups() {
    echo "Listado de grupos y sus usuarios:"
    echo -e "Nota: los usuarios listados son aquellos cuyo grupo es uno de sus grupos secundarios.\n"

    groups=$(cut -d: -f1 /etc/group | sort)
    for group in $groups; do
        echo -n "$group: "
        members=$(getent group "$group" | cut -d: -f4)     
        if [ -z "$members" ]; then
            echo "-"
        else
            echo "$members"
        fi
    done
}
# Funciones de menu Usuario
create_user() {
    default_group="users"

    request_username
    if user_exists "$username"; then
        echo "El usuario '$username' ya existe."
        return
    fi

    echo "Nota: deje en blanco si desea agregar al grupo por defecto '$default_group')"
    request_group
    if [ -z "$group_name" ]; then
        group_name=$default_group
    elif ! group_exists "$group_name"; then
        echo "El grupo '$group_name' no existe. Se asignará al grupo por defecto '$default_group'."
        group_name=$default_group
    fi

    useradd -m -g $group_name -s /bin/bash $username 
    update_password $username
    save_log $username "created"
    echo "Usuario $username creado y asignado $group_name como su grupo primario."
}
delete_user() {
    request_username
    if ! user_exists "$username"; then
        echo "El usuario '$username' no existe."
        return 
    fi

    userdel -r "$username"
    if [ $? -eq 0 ]; then
        save_log $username "deleted"
        echo "Usuario $username eliminado exitosamente."
    else
        echo "Error al eliminar el usuario $username."
        return 
    fi
}
list_user() {
    request_username
    if user_exists "$username"; then
        echo "Listado de los grupos de $username"
        echo "Nota: el primero grupo es su grupo primario"
        groups "$username"
    else
        echo "El usuario '$username' no existe."
    fi
}
list_users() {
    echo "Listado de usuarios y todos sus grupos:"
    echo "Nota: el primero grupo es su grupo primario"

    users=$(cut -d: -f1 /etc/passwd | sort)
    for user in $users; do
        groups "$user"
    done
}
modify_username() {
    echo "Ingrese el nombre actual del usuario:"
    read old_username
    if ! user_exists "$old_username"; then
        echo "El usuario '$old_username' no existe."
        return
    fi

    echo "Ingrese el nuevo nombre del usuario:"
    read new_username
    if user_exists "$new_username"; then
        echo "El nuevo nombre de usuario '$new_username' ya existe."
        return
    fi

    usermod -l "$new_username" "$old_username"
    save_log $new_username "modified" "nombre de usuario"
    echo "Nombre de usuario cambiado de $old_username a $new_username."
}
modify_primary_usergroup() {
    request_username
    if ! user_exists "$username"; then
        echo "El usuario '$username' no existe."
        return
    fi

    echo "Ingrese el nuevo grupo primario del usuario:"
    read new_group
    if ! group_exists "$new_group"; then
        echo "El grupo '$new_group' no existe."
        return
    fi

    usermod -g "$new_group" "$username"
    save_log $username "modified" "grupo primario"
    echo "El grupo primario del usuario $username ha sido cambiado a $new_group."
}
delete_secondary_usergroups() {
    request_username
    if ! user_exists "$username"; then
        echo "El usuario '$username' no existe."
        return
    fi

    echo "Ingrese los nombres de los grupos secundarios uno por uno. Presione Enter sin escribir nada para finalizar."

    secondary_groups=""
    while true; do
        read -p "Grupo secundario: " group
        if [ -z "$group" ]; then
            break
        fi
        
        if group_exists "$group"; then
            gpasswd -d "$username" "$group"
            if [ -z "$secondary_groups" ]; then
                secondary_groups=$group
            else      
                secondary_groups="$secondary_groups,$group"
            fi
        else
            echo "El grupo '$group' no existe."
        fi
    done

    if [ -z "$secondary_groups" ]; then
        echo "No se han ingresado grupos secundarios."
    else
        echo "Usuario $username eliminado de los grupos: $secondary_groups."
    fi
}
asign_secondary_usergroups() {
    request_username
    if ! user_exists "$username"; then
        echo "El usuario '$username' no existe."
        return
    fi

    echo "Ingrese los nombres de los grupos secundarios uno por uno. Presione Enter sin escribir nada para finalizar."

    secondary_groups=""
    while true; do
        read -p "Grupo secundario: " group
        if [ -z "$group" ]; then
            break
        fi

        if group_exists "$group"; then
            if [ -z "$secondary_groups" ]; then
                secondary_groups=$group
            else
                secondary_groups="$secondary_groups,$group"
            fi
        else
            echo "El grupo '$group' no existe."
        fi
    done

    if [ -z "$secondary_groups" ]; then
        echo "No se han ingresado grupos secundarios."
    else
        usermod -aG $secondary_groups $username
        save_log $username "modified" "grupos secundarios"
        echo "Usuario $username añadido a los grupos: $secondary_groups."
    fi
}
# Funciones de menu SSH
check_ssh() {
    systemctl is-active sshd > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "El servicio SSH está activo."
    else
        echo "El servicio SSH no está activo."
    fi
}
enable_ssh() {
    systemctl enable sshd
    echo "El servicio SSH ha sido habilitado para el arranque."
}
disable_ssh() {
    systemctl disable sshd
    echo "El servicio SSH ha sido deshabilitado para el arranque."
}
start_ssh() {
    systemctl start sshd
    echo "El servicio SSH ha sido iniciado."
}
stop_ssh() {
    systemctl stop sshd
    echo "El servicio SSH ha sido detenido."
}

menu() {
    while true; do
        clear

        echo "Seleccione una opción:"
        echo "1. Gestión de grupos"
        echo "2. Gestión usuarios"
        echo "3. Gestión SSH"
        echo "4. Gestión de logs"
        echo "5. Salir"

        read -p "Opción: " option
        case $option in
            1)
                while true; do
                    clear

                    echo "Seleccione una opción:"
                    echo "a. Crear grupo"
                    echo "b. Eliminar grupo"
                    echo "c. Listar grupo"
                    echo "d. Listar todos los grupos"
                    echo "e. Volver al menú principal"

                    read -p "Opción: " group_option
                    case $group_option in
                        a)
                            clear 
                            create_group ;;
                        b) 
                            clear
                            delete_group ;;
                        c) 
                            clear
                            list_group ;;
                        d) 
                            clear
                            list_groups ;;
                        e) break ;;
                        *) echo "Opción inválida. Inténtelo de nuevo." ;;
                    esac
                    continue_msg
                done
                ;;
            2)
                while true; do
                    clear

                    echo "Seleccione una opción:"
                    echo "a. Crear usuario"
                    echo "b. Eliminar usuario"
                    echo "c. Listar usuario (y sus grupos)"
                    echo "d. Listar todos los usuarios"
                    echo "e. Modificar nombre de usuario"
                    echo "f. Modificar grupo primario"
                    echo "g. Eliminar grupos secundarios"
                    echo "h. Asignar grupos secundarios"
                    echo "i. Volver al menú principal"

                    read -p "Opción: " user_option
                    case $user_option in
                        a) 
                            clear
                            create_user ;;
                        b) 
                            clear
                            delete_user ;;
                        c) 
                            clear
                            list_user ;;
                        d) 
                            clear
                            list_users ;;
                        e) 
                            clear
                            modify_username ;;
                        f) 
                            clear
                            modify_primary_usergroup ;;
                        g) 
                            clear
                            delete_secondary_usergroups ;;
                        h) 
                            clear
                            asign_secondary_usergroups ;;
                        i) break ;;
                        *) echo "Opción inválida. Inténtelo de nuevo." ;;
                    esac
                    continue_msg
                done
                ;;
            3)
                while true; do
                    clear

                    echo "Seleccione una opción:"
                    echo "a. Verificar estado del servicio SSH"
                    echo "b. Habilitar servicio SSH para el arranque"
                    echo "c. Deshabilitar servicio SSH para el arranque"
                    echo "d. Iniciar servicio SSH"
                    echo "e. Detener servicio SSH"
                    echo "f. Volver al menú principal"
                    
                    read -p "Opción: " ssh_option
                    case $ssh_option in
                        a) 
                            clear
                            check_ssh ;;
                        b) 
                            clear
                            enable_ssh ;;
                        c) 
                            clear
                            disable_ssh ;;
                        d) 
                            clear
                            start_ssh ;;
                        e) 
                            clear
                            stop_ssh ;;
                        f) break ;;
                        *) echo "Opción inválida. Inténtelo de nuevo." ;;
                    esac
                    continue_msg
                done
                ;;
            4)
                while true; do
                    clear

                    echo "Seleccione una opción:"
                    echo "a. Listar los últimos 20 arranques del sistema"
                    echo "b. Listar los últimos 15 arranques SSH"
                    echo "c. Listar los últimos inicios de sesión"
                    echo "d. Mostrar el último ingreso de un usuario específico"
                    echo "e. Listar los arranques fallidos de SSH"
                    echo "f. Listar los últimos arranques fallidos del sistema"
                    echo "g. Volver al menú principal"
                    
                    read -p "Opción: " log_option
                    case $log_option in
                        a) 
                            clear
                            list_last_20_boots ;;
                        b) 
                            clear
                            list_last_15_ssh_boots ;;
                        c) 
                            clear
                            list_last_logins ;;
                        d) 
                            clear
                            last_login_by_username ;;
                        e) 
                            clear
                            list_failed_ssh_boots ;;
                        f) 
                            clear
                            list_failed_boots ;;
                        g) break ;;
                        *) echo "Opción inválida. Inténtelo de nuevo." ;;
                    esac
                    continue_msg
                done
                ;;
            5)
                clear
                echo "Saliendo del programa..."
                sleep 3
                clear
                exit 0
                ;;
            *) echo "Opción inválida. Inténtelo de nuevo." ;;
        esac
        continue_msg
    done
}
menu