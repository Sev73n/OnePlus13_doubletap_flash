# 一加13 双击电源键打开手电筒

一个 Magisk/KernelSU 模块，锁屏状态下双击电源键即可开关手电筒。适配一加13（ColorOS / Android 16，骁龙平台）。

## 功能

- 锁屏状态下双击电源键，切换手电筒开/关
- 亮度默认与系统手电筒 2 档相同
- **通知栏手电筒开关状态自动同步**
- 仅锁屏时生效，解锁后电源键行为完全交给系统
- 监听进程自愈 + 崩溃自动重启

## 原理

模块通过 `getevent` 监听电源键的按下事件，检测两次按下间隔是否小于设定值判定为双击；在锁屏状态下，通过 SystemUI 广播走系统相机框架控制手电筒：

```
开灯: am broadcast -a com.android.systemui.ACTION_SWITCH_FLASHLIGHT --ez intent_extra_flashlight false
关灯: am broadcast -a com.android.systemui.ACTION_SWITCH_FLASHLIGHT --ez intent_extra_flashlight true
```

该广播由 `com.oplus.systemui.notification.flashlight.FlashlightNotification` 接收，最终调用 `FlashlightController.setFlashlightFromUser()`，因此**通知栏图标会自动同步**，也不会与相机使用闪光灯时互抢状态。

开关状态看 `settings secure flashlight_enabled`。一加 13 锁屏时，广播会把通知栏打成开，但相机闪光灯驱动在 `CAM_START_DEV` 之后会因 `Invalid Opcode: 264` 退出，灯电流仍是 0。模块发现系统状态已开、灯却没亮时，按 2 档电流写 `led:torch_1`、`led:torch_2` 和 `led:switch_2`。通知栏关掉时只改系统状态，模块再把这几个节点清掉。

## 安装

1. 下载 [Releases](https://github.com/KernelSU-Modules-Repo/coloros_double_power_torch/releases) 中的 zip 包
2. 在 KernelSU / Magisk 管理器中「从本地安装」该 zip
3. 重启手机

## 配置

`power_torch.sh` 顶部的配置项：

| 配置 | 默认 | 说明 |
| --- | --- | --- |
| `DOUBLE_CLICK_DELAY` | 350 | 双击间隔（毫秒），两次按下小于此值判定为双击 |
| `TORCH_BRIGHTNESS` | 32 | 驱动没点亮时补写的电流，对应系统 2 档 |
| `COOLDOWN_TIME` | 500 | 触发后冷却（毫秒） |
| `LOCK_ONLY` | 1 | 1=仅锁屏生效；0=任何状态生效 |
| `LOG_FILE` | `$MODDIR/torch.log` | 运行日志路径，留空关闭日志 |

## 注意事项

- **请关闭 ColorOS 自带的「双击电源键」手势**（设置 → 侧键/双击电源键 → 设为无），否则锁屏双击会同时触发系统动作。
- 本模块仅在一加13 (PJZ110) 上验证。

## 构建

依赖 Python 3，运行：

```bash
python build_zip.py
```

产物输出到 `dist/` 目录。

## 协议

[MIT License](https://github.com/Sev73n/OnePlus13_doubletap_flash/blob/master/LICENSE)
