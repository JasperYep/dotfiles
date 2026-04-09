{ lib, pkgs, ... }:

{
  imports = lib.optionals (builtins.pathExists ./hardware-configuration.nix) [
    ./hardware-configuration.nix
  ];

  system.stateVersion = "25.11";

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.auto-optimise-store = true;

  networking.hostName = "jasper";
  networking.networkmanager.enable = true;

  time.timeZone = "Asia/Shanghai";

  users.users.jasper = {
    isNormalUser = true;
    description = "Jasper";
    extraGroups = [ "wheel" "networkmanager" ];
    shell = pkgs.zsh;
  };

  programs.zsh.enable = true;

  environment.systemPackages = with pkgs; [
    alacritty
    bat
    curl
    fd
    fzf
    git
    kitty
    neovim
    ripgrep
    tmux
    unzip
    uv
    vim
    wget
    yazi
    zip
  ];
}
