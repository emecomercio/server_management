alias chrome='nohup google-chrome & disown && exit'
alias addalias='gedit ~/.bash_aliases && source ~/.bashrc'
alias chatgpt='nohup google-chrome https://chat.openai.com/ & disown && exit'
alias restapache='sudo systemctl restart apache2'
alias crea2='nohup google-chrome https://ceibal.schoology.com/home & disown && exit'
alias proyectoeme='nohup google-chrome http://proyectoeme.test & disown && exit'
alias mysqlworkbench='nohup mysql-workbench & disown && exit'

codext() {
    if [ "$1" = "proyectoeme" ]; then
        code /var/www/proyectoeme
    else
        code "$1"
    fi
    exit
}

clipboard() {
    "$@" | xclip -selection clipboard
}

phpserve() {
    if [ "$1" = "proyectoeme" ]; then
        dir="/var/www/proyectoeme/public"
    else
        dir="${1:-.}"
    fi
    echo "Serving from directory: $(realpath "$dir")"
    php -S localhost:8000 -t "$dir"
}

rootsql() {
    if [ -z "$1" ]; then
        mysql -u root -p
    else
        mysql -u root -p < "$1"
    fi
}