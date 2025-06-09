#!/bin/bash

# pull repo
if [[ ! -d "${HOME}/git/library-of-alexandria" ]]; then
	mkdir -p "${HOME}/git"
	git clone https://github.com/mortenvester1/library-of-alexandria.git "${HOME}/git/library-of-alexandria"
fi

cd dotfiles
if [[ "${1}" = pi ]]
then
  stow -t ${HOME} zshpi
else
  stow -t ${HOME} zsh gnupg zed
fi

# shared packages
stow -t ${HOME} asdf git starship vim
