#!/bin/bash

# Comprobación de permisos de superusuario
if [ "$EUID" -ne 0 ]; then
  echo "Este script debe ejecutarse con permisos de superusuario (root)."
  exit 1
fi

default_group="users" # Util mas abajo

#### Funciones para verificar existencias ####
group_exists() {
    local group_name="$1"
    getent group "$group_name" > /dev/null 2>&1
}
user_exists() {
    local username="$1"
    id "$username" > /dev/null 2>&1
}
#### Funciones comunes ####
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
#### Funciones de menu Grupo####
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
#### Funciones de menu Usuario####
create_user() {
    request_username
    echo "Nota: deje en blanco si desea agregar al grupo por defecto '$default_group')"
    request_group
    if user_exists "$username"; then
        echo "El usuario '$username' ya existe."
        return
    fi

    if [ -z "$group_name" ]; then
        group_name=$default_group
    elif ! group_exists "$group_name"; then
        echo "El grupo '$group_name' no existe. Se asignará al grupo por defecto '$default_group'."
        group_name=$default_group
    fi
    useradd -m -g $group_name $username
    update_password $username
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
    echo "El grupo primario del usuario $username ha sido cambiado a $new_group."
}
delete_secondary_usergroups() {
    request_username
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
        echo "Usuario $username añadido a los grupos: $secondary_groups."
    fi
}
#### Funciones de menu SSH####
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