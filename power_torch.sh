#!/system/bin/sh
# 双击电源键开关手电筒（仅锁屏时生效）
# 适配机型：一加13 (PJZ110) / OPPO 骁龙 ColorOS 15+，KernelSU / Magisk
# 实测节点：使能开关 = led:switch_2，亮度 = led:torch_1 + led:torch_2（双 LED）

MODDIR=${0%/*}

# ========== 配置项 ==========
DOUBLE_CLICK_DELAY=350   # 双击间隔（毫秒），两次按下小于此值判定为双击
TORCH_BRIGHTNESS=0       # 手电筒亮度(1~500)；0=自动使用最大亮度
COOLDOWN_TIME=500        # 触发后冷却（毫秒）
LOCK_ONLY=1              # 1=仅锁屏生效；0=任何状态都生效
LOG_FILE="$MODDIR/torch.log"   # 运行日志，留空则关闭
# ============================

# 手电筒使能开关节点（实测 led:switch_2；不要用 switch_0）
SWITCH_NODE=""
for f in /sys/class/leds/led:switch_2/brightness /sys/class/leds/*switch*/brightness; do
    [ -w "$f" ] 2>/dev/null && { SWITCH_NODE="$f"; break; }
done
[ -z "$SWITCH_NODE" ] && SWITCH_NODE="/sys/class/leds/led:switch_2/brightness"

# 手电筒亮度节点（实测 led:torch_1 + led:torch_2，双 LED）
TORCH_NODES=""
for f in /sys/class/leds/led:torch_1/brightness /sys/class/leds/led:torch_2/brightness; do
    [ -w "$f" ] 2>/dev/null && TORCH_NODES="$TORCH_NODES $f"
done
# 兜底：探测任意 torch 节点
[ -z "$TORCH_NODES" ] && for f in /sys/class/leds/*torch*/brightness; do
    [ -w "$f" ] 2>/dev/null && TORCH_NODES="$TORCH_NODES $f"
done
[ -z "$TORCH_NODES" ] && TORCH_NODES="/sys/class/leds/led:torch_1/brightness"

# 亮度上限：取第一个 torch 节点的 max_brightness
set -- $TORCH_NODES
MAX_BRIGHT=$(cat "${1%/*}/max_brightness" 2>/dev/null)
[ -z "$MAX_BRIGHT" ] && MAX_BRIGHT=500

# 亮度为 0 或超上限时，使用最大亮度
if [ -z "$TORCH_BRIGHTNESS" ] || [ "$TORCH_BRIGHTNESS" -le 0 ] 2>/dev/null || [ "$TORCH_BRIGHTNESS" -gt "$MAX_BRIGHT" ] 2>/dev/null; then
    TORCH_BRIGHTNESS=$MAX_BRIGHT
fi

log() { [ -n "$LOG_FILE" ] && echo "$(date '+%m-%d %H:%M:%S') $*" >> "$LOG_FILE"; }

# 判断是否处于锁屏（ColorOS 用 KeyguardStateMonitor.mIsShowing）
is_locked() {
    [ "$LOCK_ONLY" = "0" ] && return 0
    dumpsys window policy 2>/dev/null | grep -q "mIsShowing=true"
}

# 手电筒切换：以 switch_2 为开关状态，亮度写入 torch_1/torch_2
torch_toggle() {
    CUR=$(cat "$SWITCH_NODE" 2>/dev/null)
    if [ "$CUR" = "1" ]; then
        echo 0 > "$SWITCH_NODE" 2>/dev/null
        log "toggle OFF"
    else
        for n in $TORCH_NODES; do
            echo "$TORCH_BRIGHTNESS" > "$n" 2>/dev/null
        done
        echo 1 > "$SWITCH_NODE" 2>/dev/null
        log "toggle ON ($TORCH_BRIGHTNESS)"
    fi
}

# 等待系统就绪
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 2
done
sleep 5

# 主循环：每轮重新探测电源键设备 + 限时监听（输入设备可能重枚举，旧 fd 失效需自愈）
while true; do
    POWER_DEV=""
    for dev in /dev/input/event*; do
        getevent -lp "$dev" 2>/dev/null | grep -q "KEY_POWER" && { POWER_DEV="$dev"; break; }
    done
    [ -z "$POWER_DEV" ] && POWER_DEV="/dev/input/event1"

    log "listen $POWER_DEV"

    last_click_time=0
    last_trigger_time=0

    timeout 60 getevent -lt "$POWER_DEV" 2>/dev/null | grep --line-buffered "KEY_POWER.*DOWN" | while read -r line; do
        # 解析 "[ 12345.678900]" 前缀为微秒数（秒+6位微秒拼接）
        current=$(echo "$line" | sed 's/^\[[[:space:]]*\([0-9]*\)\.\([0-9]*\)\].*/\1\2/')
        [ -z "$current" ] && continue

        # 冷却期内忽略
        if [ "$last_trigger_time" -gt 0 ]; then
            cd=$((current - last_trigger_time))
            [ "$cd" -lt "$((COOLDOWN_TIME * 1000))" ] && continue
        fi

        if [ "$last_click_time" -eq 0 ]; then
            last_click_time=$current
        else
            diff=$((current - last_click_time))
            if [ "$diff" -le "$((DOUBLE_CLICK_DELAY * 1000))" ]; then
                if is_locked; then
                    log "dblclick -> toggle"
                    torch_toggle
                else
                    log "dblclick but unlocked, ignore"
                fi
                last_trigger_time=$current
                last_click_time=0
            else
                last_click_time=$current
            fi
        fi
    done
    sleep 1
done
