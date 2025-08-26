{ lib, config, pkgs, ... }:

{
  programs.starship = {
    enable = true;
    settings = lib.importTOML ./resources/starship.toml;
  };
}
