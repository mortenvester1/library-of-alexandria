#!/bin/bash
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
