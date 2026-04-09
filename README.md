# dotfiles

这份仓库当前以 Arch Linux 为主。

原则很简单：
- `main` 分支继续维护现在这套 Arch 上已经在用的配置
- NixOS 相关内容单独放到新的分支里演进，不污染当前主线

## 目录约定

- `X/`：X11 相关配置
- `alacritty/`、`kitty/`、`tmux/`、`zsh/`、`yazi/`：终端和命令行工具配置
- `nvim/`：Neovim 配置
- `i3/`、`i3status/`、`hyprland/`、`niri/`、`waybar/`、`mako/`、`wofi/`、`fuzzel/`：窗口管理器和桌面组件配置
- `dwm/`：DWM 相关内容
- `dict/`：词典数据
- `scripts/`：自用脚本和工具
- `scripts/singbox-sync/`：sing-box 订阅同步工具，单独有自己的 README

## 当前策略

这个仓库现在不追求“完全声明式”或“Nix 优先”。

当前目标只有两个：
- 保持 Arch 这套配置继续可用
- 给后续 NixOS 迁移预留分支和整理空间

所以这里保留现有目录形态，不做大规模搬迁或重写。

## 使用说明

这不是一套已经完全自动化的 stow/chezmoi 仓库，而是按配置主题归档的 dotfiles 集合。

迁移或恢复时，按需把对应目录里的文件链接或复制到目标位置。例如：
- `nvim/.config/nvim` -> `~/.config/nvim`
- `kitty/.config/kitty` -> `~/.config/kitty`
- `zsh/.zshrc` -> `~/.zshrc`
- `X/.xinitrc` -> `~/.xinitrc`

## 分支约定

- `main`：Arch 主线，保持当前机器可用
- `nixos`：后续 NixOS / Home Manager / flake 迁移分支

如果以后开始做 NixOS：
- 尽量新增，不直接破坏 `main` 上这套 Arch 目录
- Nix 入口文件如 `flake.nix`、`hosts/`、`home/` 放到 `nixos` 分支维护
