{ config, pkgs, ... }:

{
  # Import the base git module
  imports = [ ./common.nix ];
  home.stateVersion = "25.05";

  # macOS-specific home settings
  home.username = "mortenvester1";
  home.homeDirectory = "/Users/mortenvester1";

  # macOS-specific Git configuration
  programs.git = {
    userEmail = "mortenvester1@gmail.com";

    extraConfig = {
      user.signingKey = "0FECDDE7D4D64E37";  # Your macOS GPG key ID
      commit.gpgsign = true;             # Enable signing
    };
  };

  programs.zsh = {
    shellAliases = {
      "ls" = "gls --color -alh --group-directories-first";
    };

    envExtra = ''
      # add homebrew to path
      export PATH="/opt/homebrew/bin:$PATH"

      # java home
      export JAVA_HOME="/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home/"
      export PATH="/opt/homebrew/opt/openjdk@17/bin:$PATH"
    '';
  };

  # macOS-specific packages
  home.packages = with pkgs; [
    pinentry_mac  # For GPG passphrase entry on macOS
  ];
}
