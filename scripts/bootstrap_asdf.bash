#!/bin/bash

bootstrap_asdf() {
  asdf plugin add "$@"
  asdf install "$@"
  # asdf global "$@"
};
export -f bootstrap_asdf

# add pacakges to be controlled by asdf
cat dotfiles/.tool-versions | xargs -L1 bash -c 'bootstrap_asdf "$@"' _
