# Public restore scope

## 自动恢复（默认 Core）

- 核心 Arch 官方仓用户体验包（Hyprland、Waybar、Rofi、Ghostty、Neovim、Firefox、Zathura 等）
- Pi 官方 user-local 安装、Maple Mono NF CN 字体与系统 Adwaita 光标主题
- Lua 格式的 Hyprland 主配置，以及 Waybar、Rofi、Ghostty、Mako 和 Hyprpaper 配置；Hyprlock 与 Hyprpaper 按上游要求继续使用各自的 `.conf` 格式
- Zsh、Starship、tmux、Yazi、Ripgrep 和 Neovim 配置
- Fcitx5 公开配置与 Rime 输入法入口
- GTK 主题、核心 MIME defaults（Markdown 默认使用 Neovim）
- `daily-wallpaper.timer`
- `tt` 程序和 systemd unit；只有私人日程存在时才启用

## 可选恢复 Profiles

大型工作设施已重构为独立 Profile，按需安装：

- `academic`：TeX Live 全套（约 3.0 GiB）、Zotero、Pandoc
- `documents`：LibreOffice、OnlyOffice、Calibre、Anki、MarkText、Obsidian
- `dev`：VS Code 应用本体、Android Studio、Clang、Go、Ruby、Docker、pnpm、bun
- `ai`：Codex CLI、Gemini CLI、Clawhub、Ollama
- `media`：GIMP、Kdenlive、HandBrake、OBS Studio、Draw.io
- `communication`：微信、QQ、腾讯会议、Telegram、QQ 音乐、百度网盘、LocalSend
- `infra`：QEMU Desktop、libvirt、virt-manager
- `remote`：RustDesk (Flatpak)、Remmina、Clash Verge

使用方法：

```bash
./bootstrap.sh --with academic,dev
./bootstrap.sh --full
```

## 由基础 Arch 负责

- partition、filesystem、mount 和 bootloader
- kernel、initramfs、firmware、microcode 和 GPU driver
- 已完成的系统更新、可用的 package database、network、audio 与 sudo

## 不自动启用

下列软件或服务即使由用户另行安装，也不由公共 bootstrap 配置或启用：

- Docker、libvirt、CUPS、SSH server
- Tailscale、sing-box、Sunshine 和其他网络服务
- Snapper、Btrfs/GRUB 集成
- 任何依赖目标机器硬件或私人 credential 的 system service
- system upgrade、额外 Pacman repository 和 hardware-specific package 管理

## 恢复契约

- `main` 是唯一公开真源。
- bootstrap 遇到 manifest 错误、Stow 冲突或验证失败时立即停止。
- runtime-writable 目录必须是真实目录，不能被 Stow 折叠为仓库 symlink。
- 重复执行 bootstrap 不能产生新的 Git 变化或重复配置。
