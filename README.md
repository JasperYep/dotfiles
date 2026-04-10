# dotfiles

这个分支的目标已经固定：

- `flake + NixOS + Home Manager`
- `GNOME + GDM`
- `sing-box` 走声明式 systemd 链路
- 不混用 Hyprland / Niri / i3 这类桌面

这是给一台现代 UEFI NixOS 工作站准备的主路径，不做桌面兼容分支。

## 现在这套配置会直接接管什么

- `GNOME`
- `GDM`
- `NetworkManager`
- `PipeWire`
- `fcitx5`
- `zsh`
- `nvim`
- `kitty`
- `alacritty`
- `tmux`
- `yazi`
- `pomodoro`
- `sing-box` 主服务
- `sing-box` 订阅同步与定时刷新

仓库里仍然保留 `hyprland/`、`waybar/`、`niri/`、`i3/`、`dwm/` 等目录，但它们现在只是旧工作流存档，不参与这条 NixOS 主路径。

## 目录说明

- `flake.nix`：入口，主机名和用户名也在这里收口
- `hosts/jasper/default.nix`：系统层
- `home/jasper.nix`：用户层
- `pkgs/sing-box-subscribe.nix`：订阅转换器的 Nix 包装
- `scripts/singbox-sync/`：`sing-box` 生成逻辑与基础模板

## 全新机迁移

这套流程假设你已经用 NixOS 安装器把系统装到磁盘上，并且机器是 UEFI 启动。

1. clone 仓库：

```bash
git clone git@github.com:JasperYep/dotfiles.git ~/dotfiles
cd ~/dotfiles
git switch nixos
```

2. 把目标机器的硬件配置复制进来：

```bash
cp /etc/nixos/hardware-configuration.nix ~/dotfiles/hosts/jasper/
```

3. 如果你的用户名或主机名不是 `jasper`，只改 `flake.nix` 里的这两个变量：

```nix
username = "jasper";
hostname = "jasper";
```

4. 在目标机器上准备 `sing-box` 的本地 secret 文件：

```bash
sudo install -d -m 0750 /etc/sing-box
sudo install -m 0640 ~/dotfiles/scripts/singbox-sync/subscription.env.example /etc/sing-box/subscription.env
sudoedit /etc/sing-box/subscription.env
```

5. 第一次应用整机配置：

```bash
sudo nixos-rebuild switch --flake ~/dotfiles#jasper
```

如果你改了 `hostname`，这里的 `#jasper` 也一起改成新的主机名。

6. 重启后从 GDM 登录 `GNOME`。

## sing-box 运行方式

`sing-box` 不再走手动覆盖 `/etc/sing-box/config.json` 的命令式流程。

现在的链路是：

1. `systemd` 读取 `/etc/sing-box/subscription.env`
2. 用仓库内的基础模板加订阅生成运行配置
3. 先执行 `sing-box check`
4. 校验通过后替换 `/var/lib/sing-box/config.json`
5. 自动重启 `sing-box`
6. 每 6 小时定时刷新一次

如果你只想手动预览生成结果，也可以在用户会话里运行：

```bash
cd ~/dotfiles/scripts/singbox-sync
./update-subscription.sh
```

它只会写 `generated/config.json`，不会改线上服务。

## 注意事项

- `flake` 只能稳定看到已经加入 git 的文件，新文件记得 `git add`
- 不要把任何 secret 写进 Nix 文件，Nix store 不是 secret 存储
- `/etc/sing-box/subscription.env` 是本机私密文件，不入库
- 第一次切到新机器后，建议把 `hosts/jasper/hardware-configuration.nix` 一并提交
