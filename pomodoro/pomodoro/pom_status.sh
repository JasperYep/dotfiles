#!/bin/bash

STATUS_FILE="/tmp/pomodoro_status"
# 确保在启动脚本中设置了 PATH，以便能找到 xsetroot
XSETROOT_CMD=$(which xsetroot)

# 循环体：每秒更新一次 dwm 状态栏
while true; do
    
    # --- 1. 获取 Pomodoro 状态 ---
    if [ -f "$STATUS_FILE" ]; then
        # 如果 Pomodoro 正在运行，读取状态文件
        read PHASE_CHAR SECONDS < "$STATUS_FILE"
        
        MINUTES=$((SECONDS / 60))
        SECONDS_FMT=$(printf "%02d" $((SECONDS % 60)))

        # 根据阶段设置图标
        case "$PHASE_CHAR" in
            W) ICON="  " ;;      # 工作
            S) ICON="  " ;;      # 短休息
            L) ICON=" 󰽺 " ;;      # 长休息
            *) ICON="  " ;;
        esac
        
        # 格式化 Pomodoro 状态：[ICON] M:SS
        POMO_STATUS="$ICON $MINUTES:$SECONDS_FMT"
        
    else
        # Pomodoro 未运行，显示占位符或空
        POMO_STATUS=" ▶ " # 您也可以显示 "[P-OFF]"
    fi
    
    # --- 2. 获取其他系统状态 (例如时间和日期) ---
    # 您可以将任何其他您想要显示的信息添加到这里

	WEEK_NUM=$(date '+%V') # %V 是 ISO 8601 标准的周数
	if [ $((WEEK_NUM % 2)) -eq 1 ]; then
	    WEEK_TAG="I"
	else
	    WEEK_TAG="II"
	fi


    # --- 3. 组合并更新 dwm 状态栏 ---
    # 使用分隔符，例如 " | "
    FULL_STATUS="$POMO_STATUS | $(date '+%b.%d %l:%M %p')  $WEEK_TAG "
    
    # 调用 xsetroot 更新状态栏
    if [ -n "$XSETROOT_CMD" ]; then
        "$XSETROOT_CMD" -name "$FULL_STATUS"
    fi
    
    # 睡眠 1 秒，实现实时更新
    sleep 1
done
