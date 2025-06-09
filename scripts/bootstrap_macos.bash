#!/bin/bash

/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install applications/tools managed by homebrew
/opt/homebrew/bin/brew install -q asdf\
    coreutils\
    direnv\
    fzf\
    git-lfs\
    gpg2\
    jq\
    k9s\
    openjdk\
    pinentry-mac\
    starship\
    stow\
    trunk-io\
    yq

# casks
/opt/homebrew/bin/brew install --cask bitwarden\
    chrome\
    divvy\
    docker\
    drawio\
    dropbox\
    firefox\
    google-drive\
    iterm2\
    lunar\
    mpv\
    mullvadvpn\
    obsidian\
    ollama\
    signal\
    whatsapp\
    zed

# fonts
/opt/homebrew/bin/brew install font-caskaydia-cove-nerd-font
