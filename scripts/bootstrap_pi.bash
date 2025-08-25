#!/bin/bash

# prereqs
# forward ssh agent for github access

# upgrade
sudo apt-get update && sudo apt -y upgrade

# install packages from apt
sudo apt install -y curl\
    direnv\
    fzf\
    git\
    gpg\
    jq\
    rename\
    transmission-daemon\
    unrar\
    vim\
    stow\
    zsh
    # yq
    # minidlna

# asdf
git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.0

# jellyfin
curl https://repo.jellyfin.org/install-debuntu.sh | sudo bash

# starship
curl -sS https://starship.rs/install.sh | sh

# trunk-io
curl https://get.trunk.io -fsSL | bash -s -- -y

# Argon One V2 fan control
curl https://download.argon40.com/argon1.sh | bash

# set zsh as default
chsh -s /bin/zsh

# remove unused stuff
sudo apt -y autoremove
