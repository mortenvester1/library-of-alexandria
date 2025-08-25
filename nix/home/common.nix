{ config, pkgs, lib, ... }:

{
  # Common home manager configuration for all hosts
  # Let Home Manager manage itself
  programs.home-manager.enable = true;

  imports = [
    ./modules/git.nix
    ./modules/zsh.nix
  ];

  # Common locale settings
  home.language = {
    base = "en_US.UTF-8";
    address = "en_US.UTF-8";
    monetary = "en_US.UTF-8";
    paper = "en_US.UTF-8";
    time = "en_GB.UTF-8"; # Monday is start of week
  };

  # Common packages used on all hosts. Installed to user profile
  home.packages = with pkgs; [
    fzf
    jq
    rename
    yq
    asdf-vm
  ];

  # Cross-platform XDG directories configuration
  xdg = {
    enable = true;
    configHome = "${config.home.homeDirectory}/.config";
    dataHome = "${config.home.homeDirectory}/.local/share";
    cacheHome = "${config.home.homeDirectory}/.cache";
  };

  # Common PATH setup for all platforms
  home.sessionVariables = {
    PATH = "$HOME/.local/state/nix/profiles/home-manager/home-path/bin:$HOME/.nix-profile/bin:/nix/var/nix/profiles/default/bin:$PATH";
  };

  # services.gpg-agent = {
  #   enable = true;
  #   defaultCacheTtl = 1800;
  #   enableSshSupport = true;
  # };

}
