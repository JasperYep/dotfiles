#!/bin/bash
# 检查 Zim 是否已存在
if [ ! -d "${ZDOTDIR:-$HOME}/.zim" ]; then
echo "Installing Zim framework..."
curl -fsSL https://raw.githubusercontent.com/zimfw/install/master/install.zsh | zsh
else
echo "Zim is already installed."
fi

