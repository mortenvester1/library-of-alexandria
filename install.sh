#!/bin/bash
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

# Detect OS
if [[ "$(uname)" == "Darwin" ]]
then
  OS="MacOS"
elif grep -qi "fedora\|nobara" /etc/os-release 2>/dev/null
then
  OS="Fedora"
elif grep -qi "ubuntu\|debian" /etc/os-release 2>/dev/null
then
  OS="Ubuntu"
else
  error "install is only supported on macOS, Ubuntu, and Fedora/Nobara"
fi

# Set XDG_CONFIG_HOME if not already
XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-${HOME}/.config}

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
 	git clone https://github.com/mortenvester1/library-of-alexandria.git ${REPO_DEST}
fi

# Linux specific setup + install pkgs
if [[ "${OS}" == "Ubuntu" || "${OS}" == "Fedora" ]]
then
  LINUX_ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')

  if [[ "${OS}" == "Fedora" ]]
  then
    # Fedora / Nobara
    sudo dnf check-update || true
    bash ${REPO_DEST}/pkgs/dnf/repos.sh
    xargs sudo dnf -y install < ${REPO_DEST}/pkgs/dnf/pkgs.txt
    sudo dnf clean all
    sudo systemctl enable --now docker
    sudo usermod -aG docker "$(whoami)"

    wget -P /tmp https://github.com/derailed/k9s/releases/latest/download/k9s_linux_${LINUX_ARCH}.rpm
    sudo dnf install -y /tmp/k9s_linux_${LINUX_ARCH}.rpm
    rm /tmp/k9s_linux_${LINUX_ARCH}.rpm
  else
    # Ubuntu / Debian
    sudo add-apt-repository ppa:rmescandon/yq
    sudo apt update
    xargs sudo apt -y install < ${REPO_DEST}/pkgs/apt/pkgs.txt
    sudo apt clean

    wget -P /tmp https://github.com/derailed/k9s/releases/latest/download/k9s_linux_${LINUX_ARCH}.deb
    sudo apt install -y /tmp/k9s_linux_${LINUX_ARCH}.deb
    rm /tmp/k9s_linux_${LINUX_ARCH}.deb

    # install just
    JUST_VERSION=$(curl -s https://api.github.com/repos/casey/just/releases/latest | grep '"tag_name"' | sed 's/.*"\([^"]*\)".*/\1/')
    curl -fsSL "https://github.com/casey/just/releases/latest/download/just-${JUST_VERSION}-$(uname -m)-unknown-linux-musl.tar.gz" | tar -xz -C "${HOME}/.local/bin/" just

    # install ghostty
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/mkasberg/ghostty-ubuntu/HEAD/install.sh)"

    # install fzf
    FZF_VERSION=$(curl -s https://api.github.com/repos/junegunn/fzf/releases/latest | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')
    mkdir -p "${HOME}/.local/bin"
    curl -fsSL "https://github.com/junegunn/fzf/releases/latest/download/fzf-${FZF_VERSION}-linux_${LINUX_ARCH}.tar.gz" | tar -xz -C "${HOME}/.local/bin/"
  fi

  # set zsh as default shell
  chsh -s "$(which zsh)"

  # download asdf binary
  curl -L -o /tmp/asdf-linux.tar.gz https://github.com/asdf-vm/asdf/releases/download/v0.19.0/asdf-v0.19.0-linux-${LINUX_ARCH}.tar.gz
  sudo tar -xzf /tmp/asdf-linux.tar.gz -C /usr/local/bin/
  rm /tmp/asdf-linux.tar.gz

  # install starship
  curl -sS https://starship.rs/install.sh | sh -s -- --bin-dir "${HOME}/.local/bin" --yes

  # install uv
  curl -LsSf https://astral.sh/uv/install.sh | sh

  # install ollama
  # curl -fsSL https://ollama.com/install.sh | sh
fi

# install brew + install packages (macOS only)
if [[ "${OS}" == "MacOS" ]]
then
  if [[ -n $(command -v brew) ]]
  then
    info "homebrew is already installed. Will update"
    brew update
  else
    info "homebrew not installed. Will install"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi

  export PATH="/opt/homebrew/bin:$PATH"

  # Add homebrew zsh to allowed shells and set as default
  if [[ ! $(grep "$(brew --prefix)/bin/zsh" /etc/shells) ]]; then
    echo "$(brew --prefix)/bin/zsh" | sudo tee -a /etc/shells

    chsh -s "$(brew --prefix)/bin/zsh"
  fi

  # Install brew dependencies
  info "installing brew bundle. sudo access may be requested..."
  NONINTERACTIVE=1 brew bundle install --file "${REPO_DEST}/pkgs/homebrew/Brewfile"

  # local additions
  if [[ -s "${REPO_DEST}/pkgs/homebrew/Brewfile.local" ]]
  then
    info "installing local brew bundle. sudo access may be requested..."
    NONINTERACTIVE=1 brew bundle install --file "${REPO_DEST}/pkgs/homebrew/Brewfile.local"
  fi
fi

# setup dotfiles
info "installing dotfiles..."
stow --target ${HOME} --dir "${REPO_DEST}/dotfiles" -R --no-folding asdf git gnupg starship vim zsh k9s ghostty
if [[ "${OS}" == "MacOS" ]]
then
  stow --target ${HOME} --dir "${REPO_DEST}/dotfiles" -R --no-folding zed opencode claude
fi

# setup asdf - merge .tool-version files if local exist
zsh -c "source ${REPO_DEST}/dotfiles/zsh/.config/zsh/aliases.zsh && asdf-merge"

# add packages to be controlled by asdf
info "installing asdf dependencies..."
cat ${HOME}/.tool-versions | grep -v '^#' | xargs -L1 zsh -c 'bootstrap_asdf() { asdf plugin add "$1"; }; bootstrap_asdf "$@"' _
asdf install

info "installation complete. You should reload your shell with 'exec \$SHELL'"
