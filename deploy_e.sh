#!/bin/bash
set -euo pipefail

echo "🚀 Starting deployment script..."

# ------------------- 配置 -------------------
DOTFILES_REPO="https://github.com/JasperYep/dotfiles.git"
BARE_REPO="$HOME/.cfg"
# BACKUP_DIR="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"

# ------------------- 基础函数 -------------------
log() {
    echo "[$(date +%H:%M:%S)] $*"
}
log_error() {
    echo "❌ $*" >&2
}
require_cmd() {
    if ! command -v "$1" &>/dev/null; then
        log_error "Required command '$1' not found. Please install it first."
        exit 1
    fi
}

# ------------------- 检查命令 -------------------
for cmd in git curl sudo pacman; do
    require_cmd "$cmd"
done
log "✅ basic commands found"

# ------------------- 安装基础工具 -------------------
log "Installing base packages..."
sudo pacman -Sy --needed --noconfirm \
    git yazi zsh neovim kitty i3 fzf fd ripgrep rofi \
    adobe-source-han-sans-cn-fonts adobe-source-han-serif-cn-fonts ttf-jetbrains-mono-nerd \
    firefox lightdm lightdm-gtk-greeter picom feh \
    fcitx5-im fcitx5-rime rime-double-pinyin

# ------------------- 克隆裸仓库 -------------------
if [ -d "$BARE_REPO" ]; then
    log "⚠️  Existing repo detected: $BARE_REPO"
    mv "$BARE_REPO" "${BARE_REPO}.bak-$(date +%s)"
fi

log "Cloning bare repository..."
git clone --bare "$DOTFILES_REPO" "$BARE_REPO"

dog() {
    /usr/bin/git --git-dir="$BARE_REPO" --work-tree="$HOME" "$@"
}
export -f dog

dog config --local status.showUntrackedFiles no
log "Bare repository configured."

# ------------------- 备份冲突文件并 checkout -------------------
log "Checking out dotfiles (force write)..."
dog checkout -f
log "Dotfiles checked out successfully."

# ------------------- 设置 exclude -------------------
cat >>"$BARE_REPO/info/exclude" <<EOF
.zim/modules/
.cache/
EOF
log "Git exclude setup done."

# ------------------- 安装 Zim Framework -------------------
if [ ! -d "$HOME/.zim" ]; then
    log "Installing Zim framework..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/zimfw/install/master/install.zsh)" "" --skip-yes
fi

# 改 shell
if [ "$SHELL" != "/usr/bin/zsh" ]; then
    chsh -s /usr/bin/zsh
fi

# 安装 zim 插件
zsh -i -c "zimfw install"

# ------------------- Pacman 包恢复 -------------------
if [ -f "$HOME/pkglist.txt" ]; then
    echo ""
    read -rp "📦 Detected pkglist.txt. Restore packages with pacman now? [y/N] " ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
        log "Restoring packages from pkglist.txt ..."
        sudo pacman -S --needed - <"$HOME/pkglist.txt"
    else
        log "Skipped package restore."
    fi
else
    log "No pkglist.txt found. You can export one on old system with:"
    echo "    pacman -Qeq > ~/pkglist.txt"
fi

# ------------------- 键盘 & LightDM 配置 -------------------

sudo mkdir -p /etc/X11/xorg.conf.d
sudo cp -f "$HOME/.config/scripts/00-keyboard.conf" /etc/X11/xorg.conf.d/
# 设置 greeter
# sudo sh -c 'echo "[Seat:*]" > /etc/lightdm/lightdm.conf'
sudo sh -c 'echo "greeter-session=lightdm-gtk-greeter" >> /etc/lightdm/lightdm.conf'

# 开机自启
sudo systemctl enable lightdm.service

# ------------------- 提示 -------------------
log "Bootstrap complete!"
# echo "- Conflicting files backed up in $BACKUP_DIR"
echo "- Dotfiles restored in $HOME"
echo "- Use 'dog status', 'dog add', 'dog commit', 'dog push' to manage dotfiles"
echo "🎉 Deployment complete! Please reboot the system."
