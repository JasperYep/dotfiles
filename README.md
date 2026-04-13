# dotfiles

Arch Linux · Hyprland · Neovim

## 装机

```bash
bash <(curl -sL https://raw.githubusercontent.com/JasperYep/dotfiles/main/bootstrap.sh)
```

## 更新包列表

```bash
pacman -Qqen > pkgs/pacman.txt
pacman -Qqem > pkgs/aur.txt
```

## 分支

- `main` — Arch
- `nixos` — NixOS 实验
