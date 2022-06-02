#!/bin/bash

bootstrap_dotfiles() {
  DEST=$(echo ${1} | cut -d\/ -f2-)

  mkdir -p $(dirname ${HOME}/${DEST})
  cp ${1} ${HOME}/${DEST}
};
export -f bootstrap_dotfiles

# add pacakges to be controlled by asdf
find dotfiles -type f | xargs -L1 bash -c 'bootstrap_dotfiles "$@"' _
