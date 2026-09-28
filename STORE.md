# KernelSU 官方商店：上线状态与更新流程

本文档记录本模块在 KernelSU 官方商店（`modules.kernelsu.org`）的上线状态和每次发版的更新步骤，供后续迭代及 agent 直接参照执行。

## 现状（2026-09-10 首次上线）

| 项目 | 值 |
| --- | --- |
| 模块 id | `coloros_double_power_torch` |
| 商店页面 | https://modules.kernelsu.org/module/coloros_double_power_torch/ |
| 商店数据 JSON | https://modules.kernelsu.org/module/coloros_double_power_torch.json |
| 官方仓库 | https://github.com/KernelSU-Modules-Repo/coloros_double_power_torch（默认分支 `main`，本账号持有 admin 权限） |
| 官方仓库内容 | `module.json`、`README.md` |
| 已上线版本 | `v2.2`（versionCode 24），release tag `24-v2.2` |

- 源码仓库（本仓库，`Sev73n/OnePlus13_doubletap_flash`）与官方仓库相互独立：日常开发只在本仓库进行，官方仓库仅用于商店展示与分发，两仓库通过 `module.json` 的 `sourceUrl` 字段关联，源码仓库不转移。
- 商店收录由官方机器人完成：官方仓库**新建 Release** 后，`KernelSU-Bot` 约 30 秒内自动触发该模块的增量构建（[modules 仓库 workflow_dispatch](https://github.com/KernelSU-Modules-Repo/modules/actions/workflows/build.yml)），几分钟内商店生效。

## 一、更新流程（每次发版照此执行）

前置条件：`gh` CLI 已登录且对本仓库、官方仓库都有写权限（账号 Sev73n）。

### 1. 本仓库：改代码并发布

1. 修改代码；**同步更新 `module.prop` 的 `version` 和 `versionCode`，版本码必须严格递增**（如 22 → 23）。
2. 本地构建模块包：

   ```bash
   python build_zip.py
   # 产物：dist/coloros_double_power_torch_v<版本名>.zip
   ```

3. 提交改动并打 tag 推送，本仓库的 Release 由 CI（`.github/workflows/release.yml`）自动创建：

   ```bash
   git add -A && git commit -m "feat: v2.1"
   git tag v2.1
   git push origin master --tags
   ```

### 2. 官方商店仓库：新建 Release

在官方仓库新建 Release，**tag 必须用 `[versionCode]-[versionName]` 格式**（版本码-版本名，中间是连字符），并上传 zip 资产：

```bash
# 示例：versionCode=23, version=v2.1
gh release create 23-v2.1 "dist/coloros_double_power_torch_v2.1.zip" \
  -R KernelSU-Modules-Repo/coloros_double_power_torch \
  --title "v2.1" \
  --notes "更新内容：
- 修复 xxx
- 新增 xxx"
```

要点（官方规则）：

- 版本号与版本码由机器人从 **zip 内 `module.prop`** 解析；`versionCode` 必须大于上一个 release。
- 必须**新建 Release** 才能触发机器人更新；只修改已有 Release 的 zip 资产、不新建 release，机器人感知不到，不会更新。
- 勾选 pre-release 的按 Beta 处理，默认不展示；只有**默认分支（main）**会被处理。
- Release 标题填版本名，正文填更新日志。

### 3. 同步 README / module.json（内容有改动时才需要）

官方仓库的 `README.md`（商店详情页展示）和 `module.json`（summary 等元信息）改动后，需要同步到官方仓库。注意：**实测单纯 push 文件不会触发增量重建**（增量构建由 KernelSU-Bot 在新建 Release 时调度），改动会在每日定时全量构建（`cron: 0 0 * * *`，即北京时间约 08:00）时生效；想让改动立即上线，就随下一次发版的新 Release 一起带出（新建 Release 会重新抓取该模块的 README / module.json）。

同步命令（先取当前文件 sha 再 PUT）：

```bash
# README 同步示例
gh api --method PUT repos/KernelSU-Modules-Repo/coloros_double_power_torch/contents/README.md \
  -f message="docs: sync README" \
  -f content="$(base64 -w0 README.md)" \
  -f sha="$(gh api repos/KernelSU-Modules-Repo/coloros_double_power_torch/contents/README.md --jq .sha)" \
  -f branch=main

# module.json 同步示例（把上面对应的 README.md 换成 module.json 即可）
```

> 注意：文件含中文/特殊字符时，`base64` 必须加 `-w0` 去掉换行；提交前确认本地文件是 LF 换行（本仓库 `.gitattributes` 已强制）。

### 4. 验证

```bash
# 官方仓库 Release 是否就位
gh api repos/KernelSU-Modules-Repo/coloros_double_power_torch/releases --jq '.[0] | {tag_name, name, prerelease}'

# 商店数据是否更新（机器人触发构建约 30 秒后，页面生效约几分钟）
curl -sL https://modules.kernelsu.org/module/coloros_double_power_torch.json | python -m json.tool
# 关注字段：latestRelease、releases[0].versionCode / tagName / isPrerelease

# 商店构建是否成功
gh run list -R KernelSU-Modules-Repo/modules --limit 5
```

若 JSON 里版本没更新，等 2~5 分钟重试；构建日志中出现 `Found module coloros_double_power_torch` / `Updated release ...@<tag>` 即表示收录成功。

## 二、首次提交记录（2026-09-09 已完成，仅留档）

1. 在 https://github.com/KernelSU-Modules-Repo/submission/issues/new 发 issue：
   - 标题（必须）：`[submission] coloros_double_power_torch`
   - 正文：`module_id: coloros_double_power_torch` + `source: https://github.com/Sev73n/OnePlus13_doubletap_flash`
2. 机器人审批通过后自动创建 `KernelSU-Modules-Repo/coloros_double_power_torch` 仓库并授予 admin 权限（issue #70，2026-09-09 关闭）。
3. 首次上线（2026-09-10）：向官方仓库提交 `module.json` + `README.md`，创建 release `22-v2.0`（v2.0 / versionCode 22），商店构建成功并已上线。

## 三、常见问题

- **发布新版本后商店没更新**：确认 tag 格式为 `版本码-版本名`、zip 内 `module.prop` 的 `versionCode` 递增、Release 是新建（而非编辑已有 release）。
- **zip 构建产物名不对**：构建脚本按 `module.prop` 的 `id` 与 `version` 生成 `dist/<id>_<version>.zip`。
- **需要测试版展示**：官方仓库 Release 勾选 pre-release，商店按 Beta 处理、默认不展示。
