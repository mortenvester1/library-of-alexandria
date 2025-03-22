#!/bin/bash

cd dotfiles
if [[ "${1}" = pi ]]
then
  stow -t ${HOME} zshpi
else
  stow -t ${HOME} zsh gnupg zed
fi

# shared packages
stow -t ${HOME} asdf git starship vim
