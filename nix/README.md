# nix

## Getting started

### MacOS

Run `bin/darwin-install.bash` to install nix, nix-pkgs, nix-darwin, home-manager. Then installs the configuration defined `darwin-configuration.nix`

To install configuration changes

```sh
sudo darwin-rebuild switch
```

To update nix channels

```sh
sudo nix-channel --update
```

See [nixos/packages](https://search.nixos.org/packages) for a list of available packages or use

```sh
nix search nixpkgs ${pkgname}
```

This will download the database locally the first time and after updates.

## Uninstall

Uninstall nix-darwin

```sh
sudo darwin-uninstaller
```

### Linux

Coming soon ...
