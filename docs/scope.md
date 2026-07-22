# Public restore scope

## 自动恢复

- Arch官方仓、AUR和Flatpak中的用户体验软件
- npm全局工具、uv tools和VS Code extensions
- Hyprland、Waybar、Rofi、Ghostty、Mako和Hyprpaper
- Zsh、Starship、tmux、Yazi、Ripgrep和Neovim
- Fcitx5公开配置与Rime输入法入口
- GTK主题、MIME defaults和可公开的VS Code settings
- `daily-wallpaper.timer`
- `tt`程序和systemd unit；只有私人日程存在时才启用

## 由基础Arch负责

- partition、filesystem、mount和bootloader
- kernel、initramfs、firmware、microcode和GPU driver
- 已完成的系统更新、可用的package database、network、audio与sudo

## 不自动启用

下列软件或服务即使由用户另行安装，也不由公共bootstrap配置或启用：

- Docker、libvirt、CUPS、SSH server
- Tailscale、sing-box、Sunshine和其他网络服务
- Snapper、Btrfs/GRUB集成
- 任何依赖目标机器硬件或私人credential的system service
- system upgrade、额外Pacman repository和hardware-specific package管理

## 恢复契约

- `main`是唯一公开真源。
- bootstrap遇到manifest错误、Stow冲突或验证失败时立即停止。
- runtime-writable目录必须是真实目录，不能被Stow折叠为仓库symlink。
- 重复执行bootstrap不能产生新的Git变化或重复配置。
