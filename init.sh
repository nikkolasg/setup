#!/usr/bin/bash
# ./init_laptop.sh <user> <operation>
# User is the name of the user we want to do operations for
# operation can be one of the following:
# * user:
#   + create new user (given on cmd line)
#   + install sudo & set user as sudoers
# * pacman:
#   + configure pacman & update repo
#   + install predefined packages for laptop mode. 
# * system:
#   + install some common configuration files
# * backup:
#   + rsync data from backup server: 
#     - BACKUP_SERVER ip address
#     - BACKUP_USER name to connect with ssh
#     - BACKUP_PATH path to sync with data folders in home
#       It will sync all packages in download.rsync
#     - It first asks the users these informations
#   + install a cron job to periodically backup the folders in upload.rsync.
#     The difference is to avoid downloading big files for a new setup.
MODE="laptop"
if [[ $EUID -ne 0 ]]; then
    echo "[-] This script is not made to be ran as normal user"
    exit 1
fi

if [[ -z $1 ]]; then
    echo "[-] Must give an user to command line"
    exit 1
fi
USER=$1

runAsUser() {
    sudo -u $USER -H sh -c "$@"
}

user() {
    read -p "[*] Enter name of the user to create: " USER
    useradd -m -G wheel -s /bin/bash $USER
    passwd $USER

    echo "[+] Let's make you a sudoer."
    pacman -S --noconfirm sudo > /dev/null
    echo -e "# wheel group #\n%wheel ALL=(ALL) ALL" >> /etc/sudoers
}


pacman() {

    echo "[+] Configuring pacman & updating."
    cp pacman.conf /etc/pacman.conf
    chown root /etc/pacman.conf
    pacman -Syyu --noconfirm > /dev/null
    pacman -S --noconfirm yaourt > /dev/null

    echo "[+] Setting up blackarch repos"
    # https://blackarch.org/downloads.html#install-repo
    curl -O https://blackarch.org/strap.sh > /dev/null
    echo "34b1a3698a4c971807fb1fe41463b9d25e1a4a09" "strap.sh" > sum.txt
    sha1sum -c sum.txt > /dev/null
    if [[ $? -ne 0 ]]; then
        echo "[-] Blackarch sums don't match"
        echo "[-] $sum vs $sumCreated"
        exit 1
    fi
    rm sum.txt

    chmod +x strap.sh
    ./strap.sh > /dev/null
    rm strap.sh

    echo "[+] installing pre-defined packages ($MODE)."
    runAsUser "yaourt -S --needed --noconfirm - < packages.txt"
    runAsUser "yaourt -S --needed --noconfirm - < packages_$MODE.txt"
    zsh=$(chsh -l | grep zsh)
    echo "[+] Setting zsh as main shell"
    runAsUser "chsh -s $zsh"
}

system() {
    echo "[+] setup system files."
    # conf files for whole system
    chown -R root "root_$MODE"
    rsync -avzr --links "root_$MODE/" /
}

backup() {
    # rsync data folders
    read -p "[*] Enter username for the backup server: " BACKUP_USER
    read -p "[*] Enter the backup server address: " BACKUP_SERVER
    read -p "[*] Enter the backup path to merge with the current home: " BACKUP_PATH
    read -p "[*] Enter the rsync include files for backup (default include.rsync): " BACKUP_INCLUDE
    folder=$(pwd)
    if [[ -z $BACKUP_INCLUDE ]]; then
        BACKUP_INCLUDE=$folder/"include.rsync"
    fi

    echo "[+] Sync with the backup server to your home..."
    sleep 0.8
    runAsUser "rsync -ravz --links --files-from $BACKUP_INCLUDE $BACKUP_USER@$BACKUP_SERVER:$BACKUP_PATH /home/$USER/"

    echo "[+] Setting up cronjob for rsync"
    command="rsync -ravz --links --files-from $BACKUP_INCLUDE /home/$USER/ $BACKUP_USER@$BACKUP_SERVER:$BACKUP_PATH > /dev/null 2>&1"
    ## every hour
    job="0 * * * * $command"
    # from https://stackoverflow.com/questions/878600/how-to-create-cronjob-using-bash
    cat <(fgrep -i -v "$command" <(crontab -l)) <(echo "$job") | crontab -
}

$1
