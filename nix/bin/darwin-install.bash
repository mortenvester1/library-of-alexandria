#!/bin/bash
VERSION="25.05"

# Install Nix and restart shell
sh <(curl -L https://nixos.org/nix/install) --daemon
exec $SHELL

# Add base nix-darwin config
# REVIEW: is this needed?
sudo mkdir /etc/nix-darwin
sudo tee /etc/nix-darwin/configuration.nix << 'EOF'
{ config, pkgs, ... }:

{
  # List packages installed in system profile. To search by name, run:
  # $ nix-env -qaP | grep wget
  environment.systemPackages =
    [
      pkgs.vim
    ];

  # Enable alternative shell support in nix-darwin.
  # programs.fish.enable = true;

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 6;
}
EOF

# Add the nixpkgs, nix-darwin, home-manager channels. First two must match in version
sudo nix-channel --add https://nixos.org/channels/nixpkgs-${VERSION}-darwin nixpkgs
sudo nix-channel --add https://github.com/nix-darwin/nix-darwin/archive/nix-darwin-${VERSION}.tar.gz darwin
sudo nix-channel --add https://github.com/nix-community/home-manager/archive/release-${VERSION}.tar.gz home-manager
sudo nix-channel --update

# Install nix-darwin and add to path (somehow?)
nix-env -iA darwin.darwin-rebuild
exec $SHELL

# Link darwin config to default location
mkdir -p ${HOME}/.nixpkgs
sudo ln -sf $(pwd)/nix/darwin-configuration.nix ${HOME}/.nixpkgs/darwin-configuration.nix

# Apply the configuration in nix/darwin-configuration.nix
sudo darwin-rebuild switch
