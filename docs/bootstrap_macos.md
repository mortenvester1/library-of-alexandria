# Bootstrap MacOS

This document lists out all applications and tools to install on a fresh MacOS machine. They are divided into three sections with the latter listing tools that are usually managed by asdf on a per project basis. Some tools may be installed manual or through brew for initial setup, only for asdf to take over management later.

1. Install homebrew `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`
2. Setup dotfiles by running [scripts/bootstrap_dotfiles.bash](../scripts/bootstrap_dotfiles.bash) from the root of the repo
3. Install tools managed by Homebrew by running [scripts/bootstrap_brew.bash](../scripts/bootstrap_brew.bash) from the root of the repo
4. Setup up global tools with asdf [scripts/bootstrap_asdf.bash](../scripts/bootstrap_asdf.bash) from the root of the repo

## Managed Manually

- [ ] Chrome
- [ ] Diivy
- [ ] Docker Desktop
- [ ] Dropbox
- [ ] Firefox
- [ ] Google Drive
- [ ] Ollama
- [ ] Xcode
- [ ] Homebrew

## Managed with Homebrew

- [ ] asdf
- [ ] Bitwarden
- [ ] coreutils
- [ ] direnv
- [ ] Docker
- [ ] Docker Compose
- [ ] Drawio
- [ ] Fzf
- [ ] Git-lfs
- [ ] Gpg
- [ ] Iterm2
- [ ] Java
- [ ] jq
- [ ] k9s
- [ ] Lunar
- [ ] Pinetry
- [ ] starship
- [ ] Trunk
- [ ] yq
- [ ] Zed

## Managed with asdf

- [ ] just
- [ ] golang
- [ ] kubectl
- [ ] poetry
- [ ] python
- [ ] Terraform
