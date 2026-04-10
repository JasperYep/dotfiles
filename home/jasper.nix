{ pkgs, username, singBoxSubscribe, ... }:

{
  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;
  dconf.enable = true;

  home.sessionVariables = {
    EDITOR = "nvim";
    TERMINAL = "kitty";
    VISUAL = "nvim";
  };

  home.packages = with pkgs; [
    alacritty
    bat
    clang-tools
    curl
    fd
    file
    fzf
    gcc
    git
    gnumake
    kitty
    libnotify
    lua-language-server
    mpv
    nautilus
    neovim
    python3
    python3Packages.black
    python3Packages.isort
    ripgrep
    sing-box
    singBoxSubscribe
    stylua
    tmux
    udisks
    unzip
    util-linux
    uv
    vim
    wget
    wl-clipboard
    xdg-utils
    yazi
    zip
    zoxide
    zimfw
    nodePackages.pyright
  ];

  xdg.enable = true;

  xdg.configFile."alacritty" = {
    source = ../alacritty/.config/alacritty;
    recursive = true;
  };

  xdg.configFile."kitty" = {
    source = ../kitty/.config/kitty;
    recursive = true;
  };

  xdg.configFile."nvim" = {
    source = ../nvim/.config/nvim;
    recursive = true;
  };

  xdg.configFile."tmux" = {
    source = ../tmux/.config/tmux;
    recursive = true;
  };

  xdg.configFile."yazi" = {
    source = ../yazi/.config/yazi;
    recursive = true;
  };

  xdg.configFile."fd/ignore".text = "";
  xdg.configFile."ripgrep/config".text = "";

  dconf.settings = {
    "org/gnome/desktop/input-sources" = {
      xkb-options = [ "ctrl:nocaps" ];
    };
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-light";
    };
  };

  home.file.".Xresources".source = ../X/.Xresources;
  home.file.".vimrc".source = ../nvim/.vimrc;
  home.file.".clang-format".source = ../nvim/.clang-format;
  home.file.".zshrc".source = ../zsh/.zshrc;
  home.file.".zimrc".source = ../zsh/.zimrc;
  home.file.".local/share/pomodoro" = {
    source = ../pomodoro/pomodoro;
    recursive = true;
  };
  home.file.".local/bin/pomodoro" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      exec "$HOME/.local/share/pomodoro/pom_ctrl.sh" "$@"
    '';
  };
}
