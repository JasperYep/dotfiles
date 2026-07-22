# dotfiles

Arch Linux · Hyprland · Ghostty · Neovim

这个仓库恢复可公开、可移植的桌面与用户工作环境。`main`是唯一真源，GNU Stow负责把配置链接到`$HOME`。

## 前置条件

目标机器必须已经：

- 安装、完整更新并能够启动Arch Linux；
- 具有可用的网络、kernel、GPU和audio驱动；
- 创建普通用户并配置`sudo`；
- 能够访问Arch、AUR和GitHub。

系统更新和硬件适配必须在运行本仓库前完成。本仓库不会执行`pacman -Syu`，不会配置额外软件仓库，也不会修改分区、bootloader、kernel、initramfs、microcode或GPU驱动。

## 一键恢复

在基础Arch中执行：

```bash
sudo pacman -S --needed git base-devel && \
git clone https://github.com/JasperYep/dotfiles "$HOME/dotfiles" && \
"$HOME/dotfiles/bootstrap.sh"
```

AUR阶段会保留交互式PKGBUILD审核；“一键”表示只有一个入口，不表示跳过安全检查。

恢复完成后：

```bash
# 重新登录TTY1
start-hyprland

# 在图形会话内验证
~/dotfiles/verify.sh --session
```

目标机器特有的显示器、GPU环境变量和输入设备配置位于：

```text
~/.config/hypr/host.conf
```

初次恢复会从`host.example.conf`生成通用配置，以后不会覆盖。

## 主题

```bash
theme-switch light
theme-switch dark
theme-switch toggle
theme-switch status
```

主题切换只更新symlink并reload正在运行的应用，不会修改Git工作树。

## 验证

```bash
~/dotfiles/verify.sh --repo-only
~/dotfiles/verify.sh
~/dotfiles/verify.sh --session
```

详细边界见：

- [`docs/scope.md`](docs/scope.md)
- [`docs/private-restore.md`](docs/private-restore.md)
