# Bootstrap MacOS

This document lists out all applications and tools to install on a fresh MacOS machine. They are divided into three sections with the latter listing tools that are usually managed by asdf on a per project basis. Some tools may be installed manual or through brew for initial setup, only for asdf to take over management later.

1. Install developer tools `xcode-select --install`
1. clone repo
1. Generate a new ssh key for [github](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent)
1. Install tools managed by Homebrew by running [scripts/bootstrap_macos.bash](../scripts/bootstrap_macos.bash) from the root of the repo
1. Setup dotfiles by running [scripts/bootstrap_dotfiles.bash](../scripts/bootstrap_dotfiles.bash) from the root of the repo
1. Setup up global tools with asdf [scripts/bootstrap_asdf.bash](../scripts/bootstrap_asdf.bash) from the root of the repo
1. Run [scripts/bootstrap_git.bash](../scripts/bootstrap_git.bash) to set global configuration options (email and signingkey) that should not be version controlled

## Managed Manually

- Chrome
- Diivy
- Firefox
- Google Drive
- Ollama
- Xcode
- Homebrew

## Managed with Homebrew

- asdf
- Bitwarden
- coreutils
- direnv
- Docker
- Drawio
- Fzf
- Git-lfs
- Gpg
- Iterm2
- Java
- jq
- k9s
- Lunar
- Pinetry
- starship
- stow
- Trunk
- yq
- Zed

## Managed with asdf

- just
- golang
- kubectl
- uv
- python
- Terraform
