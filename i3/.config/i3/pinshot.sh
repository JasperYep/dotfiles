#!/bin/bash
# 生成唯一文件名
FILE="/tmp/pinshot_$(date +%s%N).png"

# 截图、存盘、复制到剪贴板
maim -s | tee "$FILE" | xclip -selection clipboard -t image/png

# 以后台模式启动 feh，确保不阻塞后续操作
feh --title "pinshot" --class "pinshot" --borderless "$FILE" &
