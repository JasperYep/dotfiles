#!/bin/bash
# 获取鼠标当前选中的文字
WORD=$(xclip -out -selection primary)

if [ -n "$WORD" ]; then
    # 查询单词，过滤掉冗余行，只取前 15 行以保持弹窗简洁
    DEFINITION=$(sdcv -n "$WORD" | sed '1,3d' | head -n 15)
    
    # 使用 Zenity 弹出浮窗
    zenity --info --title="Dictionary: $WORD" --text="$DEFINITION" --width=1000
fi
