{ lib, pkgs, hostname, username, singBoxSubscribe, ... }:

let
  subscriptionEnvFile = "/etc/sing-box/subscription.env";
  singBoxSyncRunner = pkgs.writeShellApplication {
    name = "sing-box-sync-runner";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.sing-box
    ];
    text = ''
      set -euo pipefail

      : ''${SUBSCRIPTION_URL:?SUBSCRIPTION_URL is not set}

      workdir=/var/lib/sing-box
      tmp="$(mktemp "$workdir/config.json.XXXXXX")"
      trap 'rm -f "$tmp"' EXIT

      ${pkgs.python3}/bin/python ${../../scripts/singbox-sync/sync_subscription.py} \
        --subscription-url "$SUBSCRIPTION_URL" \
        --user-agent "''${SUBSCRIPTION_UA:-clashmeta}" \
        --base-config ${../../scripts/singbox-sync/base.json} \
        --converter-bin ${lib.getExe singBoxSubscribe} \
        --output "$tmp"

      ${lib.getExe pkgs.sing-box} check -c "$tmp"
      install -o sing-box -g sing-box -m 0640 "$tmp" "$workdir/config.json"
    '';
  };
in

{
  imports = lib.optionals (builtins.pathExists ./hardware-configuration.nix) [
    ./hardware-configuration.nix
  ];

  system.stateVersion = "25.11";

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
    trusted-users = [ "root" "@wheel" ];
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = hostname;
  networking.networkmanager.enable = true;
  systemd.services.NetworkManager-wait-online.enable = true;

  time.timeZone = "Asia/Shanghai";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocales = [ "zh_CN.UTF-8/UTF-8" ];

  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;
  services.gnome = {
    core-apps.enable = false;
    core-developer-tools.enable = false;
    games.enable = false;
    gnome-keyring.enable = true;
  };
  environment.gnome.excludePackages = with pkgs; [
    gnome-tour
    gnome-user-docs
  ];

  programs.dconf.enable = true;
  programs.nix-ld.enable = true;
  programs.zsh.enable = true;

  security.polkit.enable = true;
  security.rtkit.enable = true;

  services.libinput.enable = true;
  services.udisks2.enable = true;

  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5 = {
      addons = with pkgs; [
        fcitx5-chinese-addons
        fcitx5-gtk
        kdePackages.fcitx5-configtool
      ];
      waylandFrontend = true;
    };
  };

  environment.shells = with pkgs; [ zsh ];
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    noto-fonts
    noto-fonts-cjk-sans
  ];
  hardware.graphics.enable = true;

  users.users.${username} = {
    isNormalUser = true;
    description = "Jasper";
    extraGroups = [ "wheel" "networkmanager" ];
    shell = pkgs.zsh;
  };

  users.users.sing-box = {
    isSystemUser = true;
    group = "sing-box";
    home = "/var/lib/sing-box";
  };
  users.groups.sing-box = { };

  environment.systemPackages = with pkgs; [
    gnome-tweaks
    seahorse
  ];

  systemd.tmpfiles.rules = [
    "d /etc/sing-box 0750 root root -"
  ];

  systemd.services.sing-box-sync = {
    description = "Generate sing-box config from subscription";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    before = [ "sing-box.service" ];
    unitConfig.ConditionPathExists = subscriptionEnvFile;
    serviceConfig = {
      Type = "oneshot";
      UMask = "0077";
      EnvironmentFile = subscriptionEnvFile;
      ExecStartPre = "${pkgs.coreutils}/bin/install -d -o sing-box -g sing-box -m 0700 /var/lib/sing-box";
      ExecStart = lib.getExe singBoxSyncRunner;
      ExecStartPost = "${pkgs.systemd}/bin/systemctl try-restart sing-box.service";
    };
  };

  systemd.timers.sing-box-sync = {
    description = "Periodic sing-box subscription refresh";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2m";
      OnUnitActiveSec = "6h";
      Persistent = true;
      Unit = "sing-box-sync.service";
    };
  };

  systemd.services.sing-box = {
    description = "sing-box universal proxy";
    wantedBy = [ "multi-user.target" ];
    requires = [ "sing-box-sync.service" ];
    wants = [
      "network-online.target"
    ];
    after = [
      "network-online.target"
      "sing-box-sync.service"
    ];
    serviceConfig = {
      User = "sing-box";
      Group = "sing-box";
      StateDirectory = "sing-box";
      StateDirectoryMode = "0700";
      WorkingDirectory = "/var/lib/sing-box";
      ExecStart = "${lib.getExe pkgs.sing-box} run -c /var/lib/sing-box/config.json";
      Restart = "on-failure";
      RestartSec = "5s";
      AmbientCapabilities = [
        "CAP_NET_ADMIN"
        "CAP_NET_BIND_SERVICE"
        "CAP_NET_RAW"
      ];
      CapabilityBoundingSet = [
        "CAP_NET_ADMIN"
        "CAP_NET_BIND_SERVICE"
        "CAP_NET_RAW"
      ];
    };
  };
}
