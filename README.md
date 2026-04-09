# dotfiles

这个分支是 `nixos`。

目标很明确：
- 保留 `main` 分支继续服务 Arch
- 在这个分支上先把通用配置迁到 `flake + NixOS + Home Manager`
- 暂时不处理 Hyprland、Waybar、Niri、i3、DWM 这类桌面专用配置

目前已经接入 Nix 的部分：
- `nvim`
- `kitty`
- `alacritty`
- `tmux`
- `yazi`
- `zsh`
- `.vimrc`
- `.clang-format`
- `.Xresources`

目前还没有接入 Nix 的部分：
- `hyprland/`
- `waybar/`
- `niri/`
- `i3/`
- `i3status/`
- `dwm/`
- `mako/`
- `wofi/`
- `fuzzel/`
- `sing-box` 服务本体

`scripts/singbox-sync/` 仍然保留在仓库里，但目前只是普通脚本，没有并入 NixOS service。

## 目录说明

- `flake.nix`：Nix 入口
- `hosts/jasper/default.nix`：当前这套 NixOS 主机配置
- `home/jasper.nix`：Home Manager 用户配置

## 第一次迁移到 NixOS

1. 安装一台最小 NixOS。
2. clone 仓库：

```bash
git clone git@github.com:JasperYep/dotfiles.git ~/dotfiles
cd ~/dotfiles
git switch nixos
```

3. 把目标机器自己的硬件配置复制进来：

```bash
cp /etc/nixos/hardware-configuration.nix ~/dotfiles/hosts/jasper/
```

4. 如果你的用户名或主机名不是 `jasper`，改这两个文件：
- `hosts/jasper/default.nix`
- `home/jasper.nix`

5. 第一次应用：

```bash
sudo nixos-rebuild switch --flake ~/dotfiles#jasper
```

## GNOME

这个分支现在没有启用任何桌面环境。

如果你之后决定用 GNOME，再在 `hosts/jasper/default.nix` 里加：

```nix
services.xserver.enable = true;
services.xserver.displayManager.gdm.enable = true;
services.xserver.desktopManager.gnome.enable = true;
```

## 注意事项

- `flake` 只会稳定看到已经加入 git 的文件。新建文件后记得 `git add`。
- 不要把任何 secret 直接写进 `flake.nix` 或其他 Nix 文件。Flake 内容会进 Nix store。
- `scripts/singbox-sync/subscription.env` 继续只保留本地，不入库。
- 第一次在 NixOS 上跑完后，建议把 `flake.lock` 和 `hosts/jasper/hardware-configuration.nix` 一并提交。
