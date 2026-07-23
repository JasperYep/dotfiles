# dotfiles

从已安装、更新并适配好硬件的基础 Arch，一键恢复我的 Hyprland 工作环境。

## 换新电脑

以普通用户执行：

```bash
sudo pacman -S --needed git base-devel && \
git clone https://github.com/JasperYep/dotfiles ~/dotfiles && \
~/dotfiles/bootstrap.sh
```

完成后重新登录 TTY1：

```bash
start-hyprland
~/dotfiles/verify.sh --session
```

本仓库只恢复软件、dotfiles 和用户服务，不更新系统，也不修改 kernel、驱动或 bootloader。机器专属配置写入 `~/.config/hypr/host.conf`；私密数据需自行恢复。

详细边界：[scope](docs/scope.md) · [private restore](docs/private-restore.md)
