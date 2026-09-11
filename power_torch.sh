#!/system/bin/sh
# 双击电源键开关手电筒（仅锁屏时生效）
# 适配机型：一加13 (PJZ110) / OPPO 骁龙 ColorOS 15+，KernelSU / Magisk
#
# 控制方式：通过 SystemUI 广播走相机框架（通知栏开关可同步、不与相机 HAL 冲突）
#   开灯: am broadcast -a com.android.systemui.ACTION_SWITCH_FLASHLIGHT --ez intent_extra_flashlight false
#   关灯: am broadcast -a com.android.systemui.ACTION_SWITCH_FLASHLIGHT --ez intent_extra_flashlight true
# 若广播失败（SystemUI 未就绪）则回退直接写 LED 节点。

MODDIR=${0%/*}

# ========== 配置项 ==========
DOUBLE_CLICK_DELAY=350   # 双击间隔（毫秒），两次按下小于此值判定为双击
TORCH_BRIGHTNESS=500     # 开灯后亮度(1~500)；0=不覆盖，用系统记忆档位
COOLDOWN_TIME=500        # 触发后冷却（毫秒）
LOCK_ONLY=1              # 1=仅锁屏生效；0=任何状态都生效
LOG_FILE="$MODDIR/torch.log"   # 运行日志，留空则关闭
# ============================

BCAST_ACTION="com.android.systemui.ACTION_SWITCH_FLASHLIGHT"
BCAST_EXTRA="intent_extra_flashlight"

# 手电筒使能开关节点（实测 led:switch_2）
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
[ -z "$TORCH_NODES" ] && for f in /sys/class/leds/*torch*/brightness; do
    [ -w "$f" ] 2>/dev/null && TORCH_NODES="$TORCH_NODES $f"
done
[ -z "$TORCH_NODES" ] && TORCH_NODES="/sys/class/leds/led:torch_1/brightness"

set -- $TORCH_NODES
MAX_BRIGHT=$(cat "${1%/*}/max_brightness" 2>/dev/null)
[ -z "$MAX_BRIGHT" ] && MAX_BRIGHT=500

log() { [ -n "$LOG_FILE" ] && echo "$(date '+%m-%d %H:%M:%S') $*" >> "$LOG_FILE"; }

# 启动时清空旧日志，避免长期运行无限增长（仅当开启日志时）
[ -n "$LOG_FILE" ] && : > "$LOG_FILE"

# 判断是否处于锁屏（ColorOS 用 KeyguardStateMonitor.mIsShowing）
is_locked() {
    [ "$LOCK_ONLY" = "0" ] && return 0
    dumpsys window policy 2>/dev/null | grep -q "mIsShowing=true"
}

switch_state() { cat "$SWITCH_NODE" 2>/dev/null; }

# 等待开关节点到达期望状态，最多 ~2 秒
wait_state() {
    i=0
    while [ $i -lt 20 ]; do
        [ "$(switch_state)" = "$1" ] && return 0
        sleep 0.1
        i=$((i + 1))
    done
    return 1
}

# 开灯后按配置覆盖亮度（仅当 TORCH_BRIGHTNESS>0）
apply_brightness() {
    [ "$TORCH_BRIGHTNESS" -gt 0 ] 2>/dev/null || return 0
    for n in $TORCH_NODES; do echo "$TORCH_BRIGHTNESS" > "$n" 2>/dev/null; done
}

# 回退：直接写 LED 节点（广播不可用时）
sysfs_on() {
    B=$TORCH_BRIGHTNESS; [ "$B" -gt 0 ] 2>/dev/null || B=$MAX_BRIGHT
    for n in $TORCH_NODES; do echo "$B" > "$n" 2>/dev/null; done
    echo 1 > "$SWITCH_NODE" 2>/dev/null
}
sysfs_off() { echo 0 > "$SWITCH_NODE" 2>/dev/null; }

torch_on() {
    am broadcast -a "$BCAST_ACTION" --ez "$BCAST_EXTRA" false --user 0 >/dev/null 2>&1
    if wait_state 1; then
        apply_brightness
        log "ON (broadcast)"
    else
        sysfs_on
        log "ON (sysfs fallback)"
    fi
    return 0
}

torch_off() {
    am broadcast -a "$BCAST_ACTION" --ez "$BCAST_EXTRA" true --user 0 >/dev/null 2>&1
    if wait_state 0; then
        log "OFF (broadcast)"
    else
        sysfs_off
        log "OFF (sysfs fallback)"
    fi
    return 0
}

torch_toggle() {
    if [ "$(switch_state)" = "1" ]; then
        torch_off
    else
        torch_on
    fi
}

# 等待系统就绪
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 2
done
sleep 5

# 主循环：每轮重新探测电源键设备 + 限时监听（输入设备可能重枚举，旧 fd 失效需自愈）
LAST_DEV=""
while true; do
    POWER_DEV=""
    for dev in /dev/input/event*; do
        getevent -lp "$dev" 2>/dev/null | grep -q "KEY_POWER" && { POWER_DEV="$dev"; break; }
    done
    [ -z "$POWER_DEV" ] && POWER_DEV="/dev/input/event1"

    [ "$POWER_DEV" != "$LAST_DEV" ] && { log "listening on $POWER_DEV"; LAST_DEV="$POWER_DEV"; }

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
