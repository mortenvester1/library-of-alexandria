{ config, pkgs, ... }:

{
  imports =
    [
      ./hardware-configuration.nix # host specific, auto generated
      ./home/jetson.nix # from hosts dir
    ];

  # Use the systemd-boot EFI boot loader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Enable SSH server (if needed)
  # services.openssh.enable = true;

  # Set default shell for users
  users.defaultUserShell = pkgs.zsh;

  # Set your time zone
  time.timeZone = "America/New_York";

  # Enable networking
  networking.networkmanager.enable = true;

  # Basic system locale, refined by homemanager
  location.enable = true;
  i18n.defaultLocale = "en_US.UTF-8";

  # System-wide packages
  environment.systemPackages = with pkgs; [
    coreutils
    curl
    git
    vim
    wget
    zsh
  ];

  # Enabled geoclue for automatic timezone setting
  services.geoclue2 = {
    enable = true;
    enableDemoAgent = true;
  };

  # Enable automatic timezone detection
  services.automatic-timezoned = {
    enable = true;
  };

  # Enable Home Manager for your user
  home-manager.users.jetson = import ./home/jetson.nix;
}
