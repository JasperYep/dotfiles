#!/bin/bash
set -euo pipefail

echo "🚀 Starting deployment script..."

# ------------------- 配置 -------------------
DOTFILES_REPO="https://github.com/JasperYep/dotfiles.git"
BARE_REPO="$HOME/.cfg"
BACKUP_DIR="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"

# ------------------- 基础函数 -------------------
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
require_cmd git
require_cmd curl
require_cmd sudo
require_cmd pacman

echo "✅ basic commands found"

# ------------------- 安装基础工具 -------------------
echo "Installing base packages..."
# 只安装需要的，不做全局升级
sudo pacman -Sy --needed --noconfirm \
    git yazi zsh vim neovim kitty i3 fzf fd ripgrep rofi \
    adobe-source-han-sans-cn-fonts adobe-source-han-serif-cn-fonts ttf-jetbrains-mono-nerd \
    firefox lightdm picom feh \
    fcitx5-im fcitx5-rime rime-double-pinyin

# git clone https://github.com/LazyVim/starter ~/.config/nvim
# rm -rf ~/.config/nvim/.git
# ------------------- 克隆裸仓库 -------------------
if [ -e "$BARE_REPO" ]; then
    echo "⚠️  Existing repo detected: $BARE_REPO"
    echo "    Backing it up to ${BARE_REPO}.bak-$(date +%s)"
    mv "$BARE_REPO" "${BARE_REPO}.bak-$(date +%s)"
fi

echo "Cloning bare repository..."
git clone --bare "$DOTFILES_REPO" "$BARE_REPO"

# ------------------- 定义 git wrapper -------------------
dog() {
    /usr/bin/git --git-dir="$BARE_REPO" --work-tree="$HOME" "$@"
}
export -f dog

dog config --local status.showUntrackedFiles no
echo "Bare repository configured."

# ------------------- 备份冲突文件 -------------------
dog checkout -f
echo "Dotfiles checked out successfully."

# ------------------- 设置 exclude -------------------
echo ".zim/modules/" >>"$BARE_REPO/info/exclude"
echo ".cache/" >>"$BARE_REPO/info/exclude"
echo "Git exclude setup done."

# ------------------- 安装 Neovim (LazyVim) 插件 -------------------

# if command -v nvim &>/dev/null && [ -d "$HOME/.config/nvim" ]; then
#     echo "Detected Neovim config. Assuming LazyVim setup."
#     echo "Triggering Lazy.nvim sync..."
#     nvim --headless "+Lazy! sync" +qa || true
# else
#     echo "⚠️  Neovim not installed or config not found at ~/.config/nvim"
# fi

# ------------------- 安装 Zim Framework -------------------
if [ ! -d "$HOME/.zim" ]; then
    echo "Installing Zim framework..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/zimfw/install/master/install.zsh)" "" --skip-yes
fi

chsh -s /usr/bin/zsh
exec zsh

zimfw install

# ------------------- 提示 -------------------

echo "Bootstrap complete!"
echo "- Conflicting files backed up in $BACKUP_DIR"
echo "- Dotfiles restored in $HOME"
echo "- Use 'dog status', 'dog add', 'dog commit', 'dog push' to manage dotfiles"
echo "- Zsh/Zim and Vim plugins installed"
echo "🎉 Deployment complete!"
