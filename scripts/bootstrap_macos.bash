#!/bin/bash

# Install applications/tools managed by homebrew
brew install -q asdf\
    bitwarden\
    coreutils\
    direnv\
    docker\
    docker-compose\
    fzf\
    git-lfs\
    gpg2\
    iterm2\
    jq\
    obsidian\
    openjdk\
    k9s\
    pinentry-mac\
    starship\
    stow\
    trunk-io\
    yq\
    zed

# casks
brew install --cask drawio\
    lunar

# fonts
brew install font-caskaydia-cove-nerd-font
