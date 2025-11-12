#!/usr/bin/env python3

import time
import subprocess
import os
import sys

import signal # Added for SIGTERM handling
STATUS_FILE = "/tmp/pomodoro_status"

# --- Pomodoro 配置 ---
# (配置保持不变...)
WORK_TIME = 25 * 60
SHORT_BREAK = 5 * 60
LONG_BREAK = 15 * 60
CYCLES = 4
# # DEBUG
# WORK_TIME = 5 
# SHORT_BREAK = 5 
# LONG_BREAK = 6 
# CYCLES = 4
# --- 状态写入函数 ---
def write_status_file(phase, remaining_seconds):
    """将当前阶段和剩余秒数写入临时文件"""
    # 格式: PHASE_CHAR REMAINING_SECONDS
    # 例如: W 1500 (工作, 剩余 1500 秒)
    phase_char = phase[0].upper() # W, S (Short), L (Long)
    with open(STATUS_FILE, 'w') as f:
        f.write(f"{phase_char} {remaining_seconds}")

# --- 通知函数 (保持不变) ---
def send_notification(title, message, icon="dialog-information"):
    try:
        subprocess.run(
            ['notify-send', '-i', icon, title, message],
            check=False # 即使失败也不中断
        )
    except FileNotFoundError:
        pass # 忽略找不到 notify-send 的错误

# --- SIGTERM Handler for graceful shutdown ---
def signal_handler(signum, frame):
    """Handles SIGTERM (from 'kill' command) for graceful shutdown."""
    print("\n[INFO] SIGTERM received. Shutting down gracefully...")
    
    # 1. Send final notification (distinct from controller script's notification)
    send_notification("Pomodoro Stopped", "Session ended by Controller. Have a nice day!", "dialog-ok")
    
    # 2. Clean up status file
    if os.path.exists(STATUS_FILE):
         os.remove(STATUS_FILE)
         
    # 3. Exit process
    sys.exit(0)

# --- 核心计时逻辑 ---
def run_timer(duration, phase_name, icon):
    remaining_seconds = duration
    
    print(f"\n--- Starting {phase_name} ({duration // 60} minutes) ---")

    while remaining_seconds >= 0:
        # 实时写入状态文件
        write_status_file(phase_name, remaining_seconds)
        
        # 检查是否有控制命令 (例如: 检查一个 /tmp/pomodoro_stop 文件)
        # 此处简化，依赖外部控制脚本的 SIGTERM (kill)

        time.sleep(1)
        remaining_seconds -= 1

    # 阶段结束通知
    # send_notification(
    #     f"Pomodoro: {phase_name} Concluded",
    #     f"Time's up! Moving to the next phase after {phase_name}.",
    #     icon
    # )

def pomodoro_cycle():
    # ... (与之前代码相同，调用 run_timer) ...
    pomo_count = 0
    # 启动时写入状态
    write_status_file("START", 0) 
    
    while True:
        # 1. 工作阶段
        send_notification("Deep Focus 🌿", f"Pomodoro {pomo_count + 1} begins. Center your mind.", "dialog-ok")
        run_timer(WORK_TIME, "W", "appointment-new")
        pomo_count += 1
        # 2. 休息阶段
        if pomo_count % CYCLES == 0:
            send_notification("Long Break! 🎉", f"Cycle completed ({pomo_count} sessions). Take a proper pause.", "dialog-ok")
            run_timer(LONG_BREAK, "L", "preferences-system")
        else:
            send_notification("Quick Rest ☕", f"Session {pomo_count} complete. Enjoy your moment.", "coffee")
            run_timer(SHORT_BREAK, "S", "coffee")
            
        print(f"\nTotal Pomodoros Completed: {pomo_count}")

if __name__ == "__main__":
    signal.signal(signal.SIGTERM, signal_handler)
    try:
        pomodoro_cycle()
    except KeyboardInterrupt:
        # Graceful cleanup on Ctrl+C (SIGINT)
        if os.path.exists(STATUS_FILE):
             os.remove(STATUS_FILE)
        print("\nPomodoro timer stopped by user.")
        send_notification("User Stop.", "Bye-Bye~. Have a nice day!","dialog-ok")
    except Exception as e:
        # Ensure cleanup on unexpected errors
        print(f"\n[ERROR] Pomodoro encountered a fatal exception: {e}", file=sys.stderr)
        send_notification("ERROR", "Oops, something's wrong...","coffee")
        if os.path.exists(STATUS_FILE):
             os.remove(STATUS_FILE)
        sys.exit(1)
    # 退出时，由控制脚本负责清理
