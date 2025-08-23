{ config, pkgs, lib, ... }:

{
  # Common home manager configuration for all hosts
  # Let Home Manager manage itself
  programs.home-manager.enable = true;

  imports = [
    ./modules/git.nix
    #./modules/zsh.nix
  ];

  # Common locale settings
  home.language = {
    base = "en_US.UTF-8";
    address = "en_US.UTF-8";
    monetary = "en_US.UTF-8";
    paper = "en_US.UTF-8";
    time = "en_GB.UTF-8"; # Monday is start of week
  };

  # Common packages used on all hosts
  home.packages = with pkgs; [
    coreutils
    fzf
    jq
    rename
    yq
  ];

  # Cross-platform XDG directories configuration
  xdg = {
    enable = true;
    configHome = "${config.home.homeDirectory}/.config";
    dataHome = "${config.home.homeDirectory}/.local/share";
    cacheHome = "${config.home.homeDirectory}/.cache";
  };

  # # Ensure consistent file permissions across platforms
  # home.file = {
  #   ".config".recursive = true;
  #   ".local/share".recursive = true;
  #   ".cache".recursive = true;
  # };
}
