#!/bin/bash
if [[ -f install-vars ]]; then
  source install-vars
else
  echo "could not find file 'install-vars'.. exiting"
  exit 1
fi

sudo apt update
sudo apt upgrade -y
sudo apt install -y build-essential tk-dev libncurses5-dev libncursesw5-dev \
    libreadline6-dev libdb5.3-dev libgdbm-dev libsqlite3-dev libssl-dev \
    libbz2-dev libexpat1-dev liblzma-dev zlib1g-dev libffi-dev tar wget vim \
    python3 python3-pip

if [[ -z ${USERHOME} || -z ${GITHUB_PRIVATE} || -z ${GITHUB_KEY_NAME} || -z ${GITHUB_PUBLIC} || -z ${SSHCONFIG} || -z ${USERNAME} || -z ${GROUP} ]];
then
    echo "skipping ssh setup"
else
    echo "setup ssh"
    [ -d "${USERHOME}/.ssh" ] && rm -rf ${USERHOME}/.ssh
    mkdir ${USERHOME}/.ssh
    echo "${GITHUB_PRIVATE}" >> ${USERHOME}/.ssh/${GITHUB_KEY_NAME}
    echo "${GITHUB_PUBLIC}" >> ${USERHOME}/.ssh/${GITHUB_KEY_NAME}.pub
    echo "${SSHCONFIG}" >> ${USERHOME}/.ssh/config
    ssh-keyscan github.com >> ~/.ssh/known_hosts

    chown -R ${USERNAME}:${GROUP} ${USERHOME}/.ssh
    chmod 600 ${USERHOME}/.ssh/${GITHUB_KEY_NAME}
    eval "$(ssh-agent -s)"
    ssh-add ${USERHOME}/.ssh/${GITHUB_KEY_NAME}
fi

if [[ -z ${USERHOME} ]];
then
    echo "skipping git + dot setup"
else
    echo "installing git"
    sudo apt install -y git wget
    mkdir -p ${USERHOME}/git

    git clone https://github.com/mortenvester1/library-of-alexandria.git ${USERHOME}/git/library-of-alexandria
    cp ${USERHOME}/git/library-of-alexandria/dot/.[bvt]* .
fi

if [[ -z ${USERHOME} || -z ${GITCONFIG} ]];
then
    echo "skipping .gitconfig"
else
    echo "${GITCONFIG}" >> ${USERHOME}/.gitconfig
fi

if [[ -z ${USERHOME} ]];
then
    echo "skipping tmux setup"
else
    echo "setup tmux"
    sudo apt install -y tmux
    mkdir -p ${USERHOME}/.tmux/plugins
    git clone https://github.com/tmux-plugins/tmux-copycat ${USERHOME}/.tmux/plugins/tmux-copycat
    git clone https://github.com/tmux-plugins/tmux-resurrect ${USERHOME}/.tmux/plugins/tmux-resurrect
    git clone https://github.com/tmux-plugins/tmux-prefix-highlight.git ${USERHOME}/.tmux/plugins/tmux-prefix-highlight
    git clone https://github.com/tmux-plugins/tmux-cpu ${USERHOME}/.tmux/plugins/tmux-cpu
    tmux source-file ~/.tmux.conf
fi


if [[ -z ${FSTAB} ]];
then
    echo "skipping fstab setup"
else
    echo "update fstab"
    sudo apt install -y ntfs-3g
    sudo mkdir -p /mnt/ntfs
    sudo mkdir -p /mnt/storage
    sudo cat /etc/fstab >> fstab
    echo "${FSTAB}" >> fstab
    sudo cp fstab /etc/fstab
    rm fstab
fi

if [[ -z ${MEDIA_DEVICE} || -z ${MEDIA_MOUNT_PATH} || -z ${MEDIA_DIR} ]];
then
    echo "skipping minidlna setup"
else
    echo "installing minidlna"
    sudo apt install -y minidlna
    sudo service minidlna stop
    sudo usermod -aG pi minidlna
    sudo mount ${MEDIA_DEVICE} ${MEDIA_MOUNT_PATH}
    mkdir -p ${MEDIA_DIR}
    sudo sed -i 's~media_dir=/var/lib/minidlna~media_dir=V,'${MEDIA_DIR}'~' /etc/minidlna.conf
    sudo sed -i 's/#friendly_name=/friendly_name=pidlna/' /etc/minidlna.conf
    sudo sed -i 's/#inotify=yes/inotify=yes/' /etc/minidlna.conf

    sudo service minidlna restart
    sudo service minidlna force-reload
fi

if [[ -z ${INCOMPLETE_DIR} || -z ${DOWNLOAD_DIR} || -z ${RPC_PASSWORD} || -z ${USERNAME} || -z ${PEER_PORT} || -z ${GROUP} || -z ${USERHOME} ]];
then
    echo "skipping transmission setup"
else
    echo "installing transmission"
    sudo apt install -y transmission-daemon jq
    sudo systemctl stop transmission-daemon
    mkdir -p ${INCOMPLETE_DIR}
    mkdir -p ${DOWNLOAD_DIR}
    sudo jq --arg pwd ${RPC_PASSWORD} --arg user ${USERNAME} --arg incomplete_dir ${INCOMPLETE_DIR} --arg download_dir ${DOWNLOAD_DIR} --arg port ${PEER_PORT} '."rpc-password" = $pwd | ."rpc-whitelist" = "192.168.*.*" | ."rpc-username" = $user | ."incomplete-dir-enabled" = "true" | ."incomplete-dir" = $incomplete_dir | ."download-dir" = $download_dir | ."peer-port" = $port ' /etc/transmission-daemon/settings.json >> settings.json
    sudo chmod 644 settings.json
    sudo cp settings.json /etc/transmission-daemon/settings.json
    rm settings.json
    sudo sed -i 's/User=debian-transmission/User='${USERNAME}'/' /etc/init.d/transmission-daemon
    sudo sed -i 's/User=debian-transmission/User='${USERNAME}'/' /etc/systemd/system/multi-user.target.wants/transmission-daemon.service
    sudo sed -i 's/User=debian-transmission/User='${USERNAME}'/' /lib/systemd/system/transmission-daemon.service
    sudo systemctl daemon-reload

    sudo chown -R ${USERNAME}:${GROUP} /etc/transmission-daemon
    mkdir -p ${USERHOME}/.config/transmission-daemon/
    sudo ln -sf /etc/transmission-daemon/settings.json ${USERHOME}/.config/transmission-daemon/
    sudo chown -R ${USERNAME}:${GROUP} ${USERHOME}/.config/transmission-daemon/
    sudo systemctl start transmission-daemon
fi

if [[ -z ${PEER_PORT} ]];
then
    echo "skipping ufw setup"
else
    echo "install firewall"
    sudo apt install -y ufw
    sudo ufw allow ${PEER_PORT}
    sudo ufw allow OpenSSH
fi

if [[ -z ${USERNAME} ]];
then
    echo "skipping docker setup"
else
    echo "installing docker"
    sudo curl -sSL https://get.docker.com | sh
    sudo usermod -aG docker ${USERNAME}
    sudo apt install -y libffi-dev libssl-dev python3 python3-pip
    sudo pip3 install docker-compose
fi


echo "run 'sudo reboot' to reboot and mount drives"
echo "run 'sudo ufw enable' to enable firewall"
echo "run 'sudo service transmission-daemon start' to start transmission"
echo "run 'git remote set-url origin git@github.com:USERNAME/REPOSITORY.git' to make git use ssh for each repo"
