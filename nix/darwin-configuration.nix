{ config, pkgs, ... }:

{
  # Import nix-darwin modules
  imports = [
    <home-manager/nix-darwin>  # Import Home Manager module
  ];

  # Set primary user
  system.primaryUser = "mortenvester1";

  # User configuration
  users.users.mortenvester1 = {
    name = "mortenvester1";
    home = "/Users/mortenvester1";
    shell = pkgs.zsh;
  };

  # Enable services;
  services.openssh.enable = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Enable experimental features
  nix.extraOptions = ''
    experimental-features = nix-command flakes
  '';

  # Configure Home Manager
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.mortenvester1 = import ./home/macos.nix;

  # Locale
  time.timeZone = "America/New_York";

  # Packages
  environment.systemPackages = with pkgs; [
    coreutils
    curl
    git
    vim
    wget
    zsh
  ];

  environment.pathsToLink = [ "/share/zsh" ];

  # System version
  system.stateVersion = 5;
}
