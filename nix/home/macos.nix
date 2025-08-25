{ config, pkgs, ... }:

{
  # Import the base module shared across targets
  imports = [ ./common.nix ];
  home.stateVersion = "25.05";

  # macOS-specific home settings
  home.username = "mortenvester1";
  home.homeDirectory = "/Users/mortenvester1";

  # macOS-specific Git configuration
  programs.git = {
    userEmail = "mortenvester1@gmail.com";

    extraConfig = {
      user.signingKey = "0FECDDE7D4D64E37";
      commit.gpgsign = true;
    };
  };

  programs.zsh = {
    shellAliases = {
      "ls" = "gls --color -alh --group-directories-first";
    };

    envExtra = ''
      # Add brew to path
      export PATH="$PATH:/opt/homebrew/bin"
    '';
  };

  # macOS-specific packages
  home.packages = with pkgs; [
    pinentry_mac  # For GPG passphrase entry on macOS
  ];
}
