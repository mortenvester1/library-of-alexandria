#!/bin/bash

bootstrap_asdf() {
  asdf plugin add "$1"
  asdf install "$@"
};
export -f bootstrap_asdf

# add pacakges to be controlled by asdf
cat dotfiles/asdf/.tool-versions | xargs -L1 bash -c 'bootstrap_asdf "$@"' _
