# 提交到 KernelSU 官方模块商店

本文档记录把本模块提交到 KernelSU 官方商店（`modules.kernelsu.org`）的步骤，供迭代同步时查阅。

## 背景说明

- 源码仓库（本仓库）：`Sev73n/OnePlus13_doubletap_flash`，持续在此迭代开发。
- 官方商店仓库：`KernelSU-Modules-Repo/coloros_double_power_torch`，由机器人创建，仅用于商店展示与分发。
- 两仓库独立，通过 `module.json` 的 `sourceUrl` 字段关联，源码仓库不 transfer。

## 一、首次提交（发 issue）

打开以下地址新建 issue：

> https://github.com/KernelSU-Modules-Repo/submission/issues/new

**标题**（必须严格此格式）：

```
[submission] coloros_double_power_torch
```

**正文**（可选，建议填）：

```
module_id: coloros_double_power_torch
source: https://github.com/Sev73n/OnePlus13_doubletap_flash
```

机器人会自动创建 `KernelSU-Modules-Repo/coloros_double_power_torch` 仓库，并把你设为 admin。

## 二、机器人建仓后，在新仓库补充文件

| 文件 | 说明 |
| --- | --- |
| `module.json` | 直接复制本仓库根目录的 `module.json`（含 `metamodule`、`summary`、`sourceUrl`） |
| `README.md` | 复制本仓库的 `README.md`（模块完整说明） |

## 三、发布 Release

官方商店仓库的 Release tag 格式与源码仓库不同，必须使用：

```
[versionCode]-[versionName]
```

例如：`22-v2.0`。

要点：

1. 必须**新建 Release** 并上传 zip 资产，机器人才能抓到更新；只改资产、不新建 release 是无效的。
2. 版本号（`version`）和版本码（`versionCode`）从 zip 内的 `module.prop` 解析；版本码必须严格递增。
3. 默认只展示稳定版（Release）；勾选 pre-release 的算 Beta，不默认展示。
4. 只有默认分支会被处理。

## 四、迭代同步流程

1. 在源码仓库改代码、提交，本地构建 `python build_zip.py` 得到 `dist/coloros_double_power_torch_*.zip`。
2. 在源码仓库打 tag（如 `v2.1`），源码仓库自己的 release 自动更新。
3. 需要同步到官方商店时，在 `KernelSU-Modules-Repo/coloros_double_power_torch` 新建 Release，tag 用 `版本码-版本名`（版本码递增），上传新版 zip。
