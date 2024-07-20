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
    minidlna\
    rename\
    transmission-daemon\
    vim\
    yq\
    zsh

# pull repo
mkdir -p "${HOME}/git"
git clone git@github.com:mortenvester1/library-of-alexandria.git "${HOME}/git/library-of-alexandria"

# asdf install
git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.0

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
