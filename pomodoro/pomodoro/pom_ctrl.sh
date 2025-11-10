#!/bin/bash
# 文件名: pomodoro_ctl.sh - 控制 Python 后端进程

# --- 配置 ---
# 替换为您的实际路径
POMO_BACKEND_SCRIPT="/home/jasper/pomodoro/pom_backend.py" 
STATUS_FILE="/tmp/pomodoro_status"
PID_FILE="/tmp/pomodoro_pid"

# --- 函数定义 ---

# 检查 PID 文件中的进程是否仍在运行
is_running() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        # 检查进程是否存在
        if ps -p "$PID" > /dev/null 2>&1; then
            return 0 # 进程正在运行
        else
            return 1 # 进程不存在
        fi
    fi
    return 1 # PID 文件不存在
}

# 启动计时器
start() {
    if is_running; then
        echo "Pomodoro 计时器已在运行 (PID: $(cat $PID_FILE))"
        return
    fi

    # 如果 PID 文件存在但进程已死，则清理残留文件
    if [ -f "$PID_FILE" ]; then
        echo "检测到旧的 PID 文件，但进程已退出。正在清理..."
        rm -f "$PID_FILE" "$STATUS_FILE"
    fi
    
    echo "启动 Pomodoro 计时器..."
    
    # 使用 nohup 在后台运行，并将 stdout/stderr 重定向到 /dev/null
    nohup python3 "$POMO_BACKEND_SCRIPT" >/dev/null 2>&1 &
    
    # 记录后台进程的 PID
    echo $! > "$PID_FILE"
    echo "启动成功，PID: $(cat $PID_FILE)"
}

# 停止计时器并清理文件
stop() {
    if is_running; then
        PID=$(cat "$PID_FILE")
        echo "停止 Pomodoro 计时器 (PID: $PID)..."
        
        # 尝试发送 SIGTERM 信号
        kill "$PID"
        
        # 即使 kill 失败 (例如进程刚刚自杀)，也要清理文件
        # 这样做可以确保下一次 start 不会误判
        rm -f "$PID_FILE" "$STATUS_FILE"
        echo "停止命令已发送，并清理了状态文件。"
    else
        # 进程未运行，但可能有残留文件，清理
        if [ -f "$PID_FILE" ] || [ -f "$STATUS_FILE" ]; then
            echo "Pomodoro 计时器未在运行，但正在清理残留文件。"
            rm -f "$PID_FILE" "$STATUS_FILE"
        else
            echo "Pomodoro 计时器未在运行。"
        fi
    fi
}

# --- 主逻辑 ---
case "$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    *)
        echo "用法: $0 {start|stop}"
        exit 1
        ;;
esac
