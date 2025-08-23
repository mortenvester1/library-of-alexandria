{ config, pkgs, ... }:

{
  # Import the base git module
  imports = [ ./common.nix ];

  # jetson-specific home settings
  home.username = "jetson";
  home.homeDirectory = "/home/jetson";

  # jetson-specific Git configuration
  programs.git = {
    userEmail = "mortenvester1@gmail.com";
  };

  programs.zsh.shellAliases = {
    "ls" = "ls --color -alh --group-directories-first";
  };
}
