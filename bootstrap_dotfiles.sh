#!/usr/bin/env bash
set -euo pipefail

# ------------------- 配置 -------------------
DOTFILES_REPO="https://github.com/username/dotfiles.git"
BARE_REPO="$HOME/.cfg"
BACKUP_DIR="$HOME/.config-backup"

# ------------------- 安装基础工具 -------------------
echo "Installing base packages..."
# Arch Linux 示例，如果是其他系统需要改包管理器
sudo pacman -Syu --needed git yazi zsh vim neovim kitty i3 i3status fzf fd ripgrep --noconfirm

# ------------------- 克隆裸仓库 -------------------
echo "Cloning bare repository..."
git clone --bare "$DOTFILES_REPO" "$BARE_REPO"

# ------------------- 创建 dog alias -------------------
echo "Creating 'dog' alias..."
if ! grep -q "alias dog=" "$HOME/.zshrc"; then
    echo "alias dog='/usr/bin/git --git-dir=$BARE_REPO/ --work-tree=$HOME'" >>"$HOME/.zshrc"
fi
alias dog="/usr/bin/git --git-dir=$BARE_REPO/ --work-tree=$HOME"

dog config --local status.showUntrackedFiles no

# ------------------- 备份冲突文件 -------------------
mkdir -p "$BACKUP_DIR"
echo "Backing up conflicting files..."
CONFLICT_FILES=$(dog checkout 2>&1 | egrep "\s+\." | awk '{print $1}' || true)
if [ -n "$CONFLICT_FILES" ]; then
    for f in $CONFLICT_FILES; do
        echo "Backing up $f -> $BACKUP_DIR/"
        mkdir -p "$(dirname "$BACKUP_DIR/$f")"
        mv "$HOME/$f" "$BACKUP_DIR/$f"
    done
fi

# ------------------- 检出 dotfiles -------------------
dog checkout || true
echo "Dotfiles checked out successfully."

# ------------------- 设置 .gitignore -------------------
IGNORE_FILE="$HOME/.gitignore"
for path in ".zim/modules/" ".cache/"; do
    if ! grep -qx "$path" "$IGNORE_FILE" 2>/dev/null; then
        echo "$path" >>"$IGNORE_FILE"
    fi
done
echo ".gitignore setup done."

# ------------------- 安装 Zim Framework -------------------
if [ ! -d "$HOME/.zim" ]; then
    echo "Installing Zim framework..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/zimfw/install/master/install.zsh)" "" --skip-yes
fi

# ------------------- 安装 Vim/Neovim 插件 -------------------
if [ -f "$HOME/.vimrc" ] || [ -f "$HOME/.config/nvim/init.vim" ]; then
    echo "Installing Vim/Neovim plugins..."
    # vim-plug 示例
    curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
    nvim +PlugInstall +qall || vim +PlugInstall +qall
fi

# ------------------- 提示 -------------------
echo "Bootstrap complete!"
echo "- Conflicting files backed up in $BACKUP_DIR"
echo "- Dotfiles restored in $HOME"
echo "- Use 'dog status', 'dog add', 'dog commit', 'dog push' to manage dotfiles"
echo "- Zsh/Zim and Vim plugins installed"
