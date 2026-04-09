{ ... }:

{
  home.username = "jasper";
  home.homeDirectory = "/home/jasper";
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };

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

  home.file.".Xresources".source = ../X/.Xresources;
  home.file.".vimrc".source = ../nvim/.vimrc;
  home.file.".clang-format".source = ../nvim/.clang-format;
  home.file.".zshrc".source = ../zsh/.zshrc;
  home.file.".zimrc".source = ../zsh/.zimrc;
}
