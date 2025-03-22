#!/bin/bash

# Install home brew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install stow
/opt/homebrew/bin/brew install stow
alias stow=/opt/homebrew/bin/stow

cd dotfiles
if [[ "${1}" = pi ]]
then
  sudo apt install -y stow
  stow -t ${HOME} zshpi
else
  brew install stow
  stow -t ${HOME} zsh gnupg zed
fi

# shared packages
stow -t ${HOME} asdf git starship vim
