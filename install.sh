#!/bin/zsh

set -u

# string formatters
if [[ -t 1 ]]
then
  tty_escape() { printf "\033[%sm" "$1"; }
else
  tty_escape() { :; }
fi
tty_mkbold() { tty_escape "1;$1"; }
tty_underline="$(tty_escape "4;39")"
tty_blue="$(tty_mkbold 34)"
tty_red="$(tty_mkbold 31)"
tty_bold="$(tty_mkbold 39)"
tty_reset="$(tty_escape 0)"

shell_join() {
  local arg
  printf "%s" "$1"
  shift
  for arg in "$@"
  do
    printf " "
    printf "%s" "${arg// /\ }"
  done
}

info() {
  printf "${tty_blue}INFO${tty_reset}: %s\n" "$(shell_join "$@")" >&2
}

warn() {
  printf "${tty_red}WARNING${tty_reset}: %s\n" "$(shell_join "$@")" >&2
}

error() {
  printf "${tty_red}ERROR${tty_reset}: %s\n" "$(shell_join "$@")" >&2
  exit 1
}


usage() {
  cat <<EOS
library of alexandria installer
Usage: [SKIP_GIT=1] install.sh [options]
    -h, --help       Display this message.
    SKIP_GIT         Skip git operations. Use when script is run from local filesystem
EOS
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]
do
  case "$1" in
    -h | --help) usage ;;
    *)
      error "unrecognized option: '$1'"
      usage 1
      ;;
  esac
done

# First check OS.
OS="$(uname)"
if [[ "${OS}" != "Darwin" ]]
then
  error "install is only supported on macOS"
fi

REPO_DEST="${HOME}/git/library-of-alexandria"
if [[ -n "${SKIP_GIT-}" && -d ${REPO_DEST} ]]
then
  info "skipping git operations. Will install/upgrade based on state of local repo"
elif [[ -d "${REPO_DEST}" ]];
then
 	warn "'${REPO_DEST}' already exists. Will stash and pull main"
 	git -C ${REPO_DEST} stash push -m "library-of-alexandria-upgrade"
 	git -C ${REPO_DEST} checkout main
 	git -C ${REPO_DEST} pull
else
  info "'${REPO_DEST}' does not exist. Will clone repo"
 	mkdir -p "${HOME}/git"
 	git clone https://github.com/mortenvester1/library-of-alexandria.git $(dirname ${REPO_DEST})
fi

# install brew + install packages
if [[ -n $(command -v brew) ]]
then
  info "homebrew is already installed. Will update"
  brew update
else
  info "homebrew already not installed. Will install"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  export PATH="/opt/homebrew/bin:$PATH"
fi

# Install brew dependencies
export HOMEBREW_BUNDLE_FILE_GLOBAL=${HOMEBREW_BUNDLE_FILE_GLOBAL:-${XDG_CONFIG_HOME}/homebrew/Brewfile}
if [[ -s "${HOMEBREW_BUNDLE_FILE_GLOBAL}" ]]
then
  info "installing brew bundle from global. sudo access may be requested..."
  # installing from
  NONINTERACTIVE=1 brew bundle install --global
else
  info "installing brew bundle from repo as it has not been moved to XDG_CONFIG_HOME. sudo access may be requested..."
  NONINTERACTIVE=1 brew bundle install --file "${REPO_DEST}/dotfiles/homebrew/.config/homebrew/Brewfile"
fi

# local additions
if [[ -s "${HOMEBREW_BUNDLE_FILE_GLOBAL}.local" ]]
then
  info "installing local brew bundle. sudo access may be requested..."
  NONINTERACTIVE=1 brew bundle install --file "${HOMEBREW_BUNDLE_FILE_GLOBAL}.local"
fi

# # setup dotfiles
info "installing dotfiles..."
stow --target ${HOME} --dir "${REPO_DEST}/dotfiles" -R asdf git gnupg starship vim zed zsh sql-formatter k9s homebrew

# setup asdf - merge .tool-version files if local exist
zsh -c "source ${REPO_DEST}/dotfiles/zsh/.config/zsh/.zsh_aliases && asdf-merge"

# add packages to be controlled by asdf
info "installing asdf dependencies..."
cat ${HOME}/.tool-versions | grep -v '^#' | xargs -L1 zsh -c 'bootstrap_asdf() { asdf plugin add "$1"; }; bootstrap_asdf "$@"' _
asdf install

info "installation complete. You should reload your shell with 'exec \$SHELL'"
