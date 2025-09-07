#!/bin/bash

set -u

# First check OS.
OS="$(uname)"
if [[ "${OS}" != "Darwin" ]]
then
  printf "ERROR: Install is only supported on macOS\n"
  exit 1
fi

# Pull repo
REPO_DEST="${HOME}/git/library-of-alexandria"
if [[ -d "${REPO_DEST}" ]];
then
	printf "WARNING: ${REPO_DEST} already exists. Will stash and pull main\n"
	git -C ${REPO_DEST} stash push -m "library-of-alexandria-upgrade"
	git -C ${REPO_DEST} checkout main
	git -C ${REPO_DEST} pull
else
	mkdir -p "${HOME}/git"
	git clone https://github.com/mortenvester1/library-of-alexandria.git $(dirname ${REPO_DEST})
fi

# install brew + install packages
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
export PATH="/opt/homebrew/bin:$PATH"

printf "INFO: install brew bundle. sudo access may be requested\n"
NONINTERACTIVE=1 brew bundle install --file Brewfile

# setup dotfiles
stow -t ${HOME} -R asdf git gnupg starship vim zed zsh

# setup asdf
bootstrap_asdf() {
  asdf plugin add "$1"
  asdf install "$@"
};
export -f bootstrap_asdf

# add packages to be controlled by asdf
cat ${HOME}/.tool-versions | xargs -L1 bash -c 'bootstrap_asdf "$@"' _

printf "INFO: installation complete. You should reload your shell\n"
