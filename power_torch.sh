#!/system/bin/sh
# 双击电源键开关手电筒（仅锁屏时生效）
# 适配机型：一加13 (PJZ110) / OPPO 骁龙 ColorOS 15+，KernelSU / Magisk
#
# 控制方式：
# 1. SystemUI 广播负责通知栏/快捷开关状态
#    开灯: am broadcast ... --ez intent_extra_flashlight false
#    关灯: am broadcast ... --ez intent_extra_flashlight true
# 2. 锁屏时相机手电筒驱动会 CAM_START_DEV 后因 Invalid Opcode 264 立刻 STOP，
#    灯电流保持 0，所以状态为开但灯不亮。这时再按系统 2 档的电流写灯节点。
# 3. 通知栏关灯只改 flashlight_enabled，不会清掉这些节点。后台跟随该状态，
#    变为关时把本模块点亮的灯关掉。

MODDIR=${0%/*}

# ========== 配置项 ==========
DOUBLE_CLICK_DELAY=350   # 双击间隔（毫秒），两次按下小于此值判定为双击
TORCH_BRIGHTNESS=32      # 补光电流，与系统手电筒 2 档写进 torch 节点的值一致
COOLDOWN_TIME=500        # 触发后冷却（毫秒）
LOCK_ONLY=1              # 1=仅锁屏生效；0=任何状态都生效
LOG_FILE="$MODDIR/torch.log"   # 运行日志，留空则关闭
# ============================

BCAST_ACTION="com.android.systemui.ACTION_SWITCH_FLASHLIGHT"
BCAST_EXTRA="intent_extra_flashlight"

log() { [ -n "$LOG_FILE" ] && echo "$(date '+%m-%d %H:%M:%S') $*" >> "$LOG_FILE"; }

# 以系统状态为准。锁屏时 led:switch_2 不会跟着广播变化，用它判断开关会误判。
flashlight_enabled() {
    settings get secure flashlight_enabled 2>/dev/null | tr -d '[:space:]'
}

SWITCH_NODE=/sys/class/leds/led:switch_2/brightness
TORCH_NODE_1=/sys/class/leds/led:torch_1/brightness
TORCH_NODE_2=/sys/class/leds/led:torch_2/brightness

led_is_on() { [ "$(cat "$SWITCH_NODE" 2>/dev/null)" = "1" ]; }

led_on() {
    echo "$TORCH_BRIGHTNESS" > "$TORCH_NODE_1" 2>/dev/null
    echo "$TORCH_BRIGHTNESS" > "$TORCH_NODE_2" 2>/dev/null
    echo 1 > "$SWITCH_NODE" 2>/dev/null
}

led_off() {
    echo 0 > "$SWITCH_NODE" 2>/dev/null
    echo 0 > "$TORCH_NODE_1" 2>/dev/null
    echo 0 > "$TORCH_NODE_2" 2>/dev/null
}

# 只收回本模块点亮的灯。相机自己占用闪光灯时 owned=0，不会去关。
follow_torch_state() {
    owned=0
    if [ "$(flashlight_enabled)" != "1" ] && led_is_on; then
        led_off
    fi
    while true; do
        if [ "$(flashlight_enabled)" = "1" ]; then
            if ! led_is_on; then
                led_on
                owned=1
                log "LED on (follow) brightness=$TORCH_BRIGHTNESS"
            fi
        elif [ "$owned" = "1" ]; then
            led_off
            owned=0
            log "LED off (follow)"
        fi
        sleep 0.25
    done
}

# 启动时清空旧日志，避免长期运行无限增长（仅当开启日志时）
[ -n "$LOG_FILE" ] && : > "$LOG_FILE"

# 判断是否处于锁屏（ColorOS 用 KeyguardStateMonitor.mIsShowing）
is_locked() {
    [ "$LOCK_ONLY" = "0" ] && return 0
    dumpsys window policy 2>/dev/null | grep -q "mIsShowing=true"
}

torch_on() {
    am broadcast -a "$BCAST_ACTION" --ez "$BCAST_EXTRA" false --user 0 >/dev/null 2>&1
    log "ON (broadcast) enabled=$(flashlight_enabled)"
}

torch_off() {
    am broadcast -a "$BCAST_ACTION" --ez "$BCAST_EXTRA" true --user 0 >/dev/null 2>&1
    log "OFF (broadcast) enabled=$(flashlight_enabled)"
}

torch_toggle() {
    if [ "$(flashlight_enabled)" = "1" ]; then
        torch_off
    else
        torch_on
    fi
}

# 跟随系统手电筒状态，补上驱动没点亮的灯，并在通知栏关闭时灭灯
if [ -f "$MODDIR/.torch_follow.pid" ]; then
    kill "$(cat "$MODDIR/.torch_follow.pid" 2>/dev/null)" 2>/dev/null
fi
follow_torch_state &
echo $! > "$MODDIR/.torch_follow.pid"

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
