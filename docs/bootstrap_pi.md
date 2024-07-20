# Bootstrap Pi

## Argon One V2 case fan

`curl https://download.argon40.com/argon1.sh | bash`

# Bootstrap Pi

This document lists out all applications and tools to install on a fresh Raspberry Pi machine. They are divided into three sections with the latter listing tools that are usually managed by asdf on a per project basis. Some tools may be installed manual or through apt for initial setup, only for asdf to take over management later.

1. Setup dotfiles by running [scripts/bootstrap_dotfiles.bash](../scripts/bootstrap_dotfiles.bash) from the root of the repo and supplying the argument `pi` (`scripts/bootstrap_dotfiles.bash pi`)
2. Install tools managed by apt or manually by running [scripts/bootstrap_pi.bash](../scripts/bootstrap_pi.bash) from the root of the repo
3. Setup up global tools with asdf [scripts/bootstrap_asdf.bash](../scripts/bootstrap_asdf.bash) from the root of the repo
4. Run [scripts/bootstrap_git.bash](../scripts/bootstrap_git.bash) to set global configuration options (email and signingkey) that should not be version controlled

## Managed manually

- argon one v2 fan control
- asdf
- starship
- trunk

## Managed with apt

- stow
- curl
- direnv
- fzf
- git
- gpg
- jq
- minidlna
- rename
- transmission-daemon
- vim
- yq
- zsh

## Managed with asdf

- just
- golang
- kubectl
- python
