#!/system/bin/sh
MODDIR=${0%/*}

# 等待系统启动完成
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 3
done

chmod 755 "$MODDIR/power_torch.sh"

# 防止重复启动：pidfile 存在 /data 重启后仍保留，但 PID 会重置，
# 所以除了 kill -0 探活，还要校验 /proc/PID/cmdline 确实是本脚本，避免 PID 复用误判。
PIDFILE="$MODDIR/.power_torch.pid"
if [ -f "$PIDFILE" ]; then
    OLD_PID=$(cat "$PIDFILE" 2>/dev/null)
    if [ -n "$OLD_PID" ] && [ -d "/proc/$OLD_PID" ]; then
        if grep -q "power_torch.sh" "/proc/$OLD_PID/cmdline" 2>/dev/null; then
            exit 0
        fi
    fi
fi

# 后台启动，异常退出后自动重启
(
    while true; do
        "$MODDIR/power_torch.sh" >/dev/null 2>&1
        sleep 5
    done
) &
echo $! > "$PIDFILE"
