# Library of Alexandria

This repo is my personal library of everything.

## Repo structure

Below is a list of the most important files and directories in the repo.

```text
library-of-alexandria/
├── apps/              # Contains various apps
│   └── entrance/      # A application gateway for accessing self-hosted services
├── cron/              # Contains various cronjobs
├── dotfiles/          # Configuration files of software
│   ├── apt/           # List of packages to install with apt-get
│   ├── asdf/          # default tools managed with asdf
│   ├── git/           # git configuration
│   ├── gnupg/         # gnupg configuration
│   ├── homebrew/      # Brewfile with tools managed by Homebrew
│   ├── k9s/           # k9s configuration
│   ├── opencode/      # opencode configuration
│   ├── sql-formatter/ # sql-formatter configuration
│   ├── starship/      # starship / shell prompt configuration
│   ├── vim/           # vim configuration
│   ├── zed/           # zed configuration
│   └── zsh/           # zsh startup files
├── install.sh         # script to install / upgrade the repo contents on machine
```

## Install

The install requires bash, curl, git, sudo to be installed on your system. Run the [install.sh](./install.sh) script using curl

```sh
/bin/zsh -c "$(curl -fsSL https://raw.githubusercontent.com/mortenvester1/library-of-alexandria/refs/heads/main/install.sh)"
```

After initial install, overrides and additional tool installations can be configurd in the following files. Simply rerun the install script for the overrides to take effect.

```sh
${XDG_CONFIG_HOME}/asdf/.tool-versions.local
${XDG_CONFIG_HOME}/git/.gitlocal
${XDG_CONFIG_HOME}/homebrew/Brewfile.local
${XDG_CONFIG_HOME}/zsh/.zshrc.local
```

## Development

You can run the

```sh
/bin/zsh -c "$(curl -fsSL file:///$(pwd)/install.sh)"
```

or

```sh
just upgrade
```

## References

- [XDG Base Directories](https://specifications.freedesktop.org/basedir-spec/latest/)

## Guides

- [Generate SSH keys](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent)
- [Generate GPG Keys](https://docs.github.com/en/authentication/managing-commit-signature-verification/generating-a-new-gpg-key)
- [Gnu Stow](https://tamerlan.dev/how-i-manage-my-dotfiles-using-gnu-stow/)

### Raspberry pi

- [Pi NAS](https://www.raspberrypi.com/tutorials/nas-box-raspberry-pi-tutorial/)
- [Pi Hole](https://www.raspberrypi.com/tutorials/running-pi-hole-on-a-raspberry-pi/)
- [transmission](https://pimylifeup.com/raspberry-pi-transmission/)

### Media Server

- [Minidlna](https://bbrks.me/rpi-minidlna-media-server/)
- [Tdarr](https://docs.tdarr.io/docs/welcome/what)
- [Jellyfin](https://itsfoss.com/jellyfin-raspberry-pi/)

## zsh

- [zsh startup files](https://zsh.sourceforge.io/Doc/Release/Files.html)
- [zsh completion guide](https://thevaluable.dev/zsh-completion-guide-examples/)
- [zinit gallery](https://zdharma-continuum.github.io/zinit/wiki/GALLERY/#plugins)

## Jetson

- [Jetson Lab](https://www.jetson-ai-lab.com/)

## Todo

- [x] Create bootstrap scripts for Raspberry OS
- [x] Adopt `stow` for managing dotfiles
- [x] Create dotfiles for Raspberry OS
- [x] Look into nixos
- [x] remove nix
- [x] migrate bootstrap pi to install
- [x] update docs
- [ ] add cronjobs
