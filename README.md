# 一加13 双击电源键打开手电筒

一个 Magisk/KernelSU 模块，锁屏状态下双击电源键即可开关手电筒。适配一加13（ColorOS / Android 16，骁龙平台）。

## 功能

- 锁屏状态下双击电源键，切换手电筒开/关
- 默认使用最大亮度
- 仅锁屏时生效，解锁后电源键行为完全交给系统，不与相机/闪光灯冲突
- 监听进程自愈 + 崩溃自动重启

## 原理

模块通过 `getevent` 监听电源键的按下事件，检测两次按下间隔是否小于设定值判定为双击；在锁屏状态下，向手电筒的 sysfs 节点写入亮度实现开关。

实测一加13 (PJZ110) 的手电筒节点为：

| 节点 | 作用 |
| --- | --- |
| `/sys/class/leds/led:switch_2/brightness` | 使能开关（1=开，0=关） |
| `/sys/class/leds/led:torch_1/brightness` | 亮度（0~500） |
| `/sys/class/leds/led:torch_2/brightness` | 亮度（0~500） |

## 安装

1. 下载 [Releases](releases) 中的 zip 包
2. 在 KernelSU / Magisk 管理器中「从本地安装」该 zip
3. 重启手机

## 配置

`power_torch.sh` 顶部的配置项：

| 配置 | 默认 | 说明 |
| --- | --- | --- |
| `DOUBLE_CLICK_DELAY` | 350 | 双击间隔（毫秒），两次按下小于此值判定为双击 |
| `TORCH_BRIGHTNESS` | 0 | 手电筒亮度（1~500）；0 表示最大亮度 |
| `COOLDOWN_TIME` | 500 | 触发后冷却（毫秒） |
| `LOCK_ONLY` | 1 | 1=仅锁屏生效；0=任何状态生效 |
| `LOG_FILE` | `$MODDIR/torch.log` | 运行日志路径，留空关闭日志 |

## 注意事项

- **请关闭 ColorOS 自带的「双击电源键」手势**（设置 → 侧键/双击电源键 → 设为无），否则锁屏双击会同时触发系统动作。
- 本模块仅在一加13 (PJZ110) 上验证；其他机型的手电筒节点可能不同，请自行确认。

## 构建

依赖 Python 3，运行：

```bash
python build_zip.py
```

产物输出到 `dist/` 目录。

## 协议

[MIT License](LICENSE)
