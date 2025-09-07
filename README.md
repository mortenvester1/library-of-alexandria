# Library of Alexandria

This repo is my personal library of everything.

## Install

Run the [install.sh](./install.sh script) using curl

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/mortenvester1/library-of-alexandria/refs/heads/main/install.sh)"
```

## Development

You can run the

```sh
/bin/bash -c "$(curl -fsSL file:///$(pwd)/install.sh)"
```

## References

- [XDG Base Directories](https://specifications.freedesktop.org/basedir-spec/latest/)
- [zsh](https://zsh.sourceforge.io/Doc/Release/Files.html)

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

## Todo

- [x] Create bootstrap scripts for Raspberry OS
- [x] Adopt `stow` for managing dotfiles
- [x] Create dotfiles for Raspberry OS
- [x] Look into nixos
- [x] remove nix
- [ ] migrate bootstrap pi to install
- [x] update docs
- [ ] add cronjobs
