#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""打包 Magisk/KernelSU 模块为 zip，保留 Unix 可执行权限位。

用法：python build_zip.py
产物：dist/<id>_<version>.zip（id/version 读取自 module.prop）
"""
import os
import re
import zipfile

ROOT = os.path.dirname(os.path.abspath(__file__))

# 需打包进模块的文件（zip 内为相对路径，根目录即 module.prop）
FILES = [
    "module.prop",
    "power_torch.sh",
    "service.sh",
    "META-INF/com/google/android/update-binary",
    "META-INF/com/google/android/updater-script",
]

# 需要可执行权限的文件
EXEC = {"power_torch.sh", "service.sh", "META-INF/com/google/android/update-binary"}

# 需要显式写入的目录条目
DIRS = [
    "META-INF/",
    "META-INF/com/",
    "META-INF/com/google/",
    "META-INF/com/google/android/",
]

S_IFREG = 0o100000
S_IFDIR = 0o040000


def read_prop(key):
    with open(os.path.join(ROOT, "module.prop"), encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line.startswith(key + "="):
                return line.split("=", 1)[1]
    return ""


def add_file(z, rel):
    full = os.path.join(ROOT, rel)
    zi = zipfile.ZipInfo.from_file(full, rel)
    mode = 0o755 if rel in EXEC else 0o644
    zi.external_attr = (S_IFREG | mode) << 16
    with open(full, "rb") as f:
        z.writestr(zi, f.read())
    print(f"  + {rel} ({mode:o})")


def main():
    mid = read_prop("id").strip()
    ver = read_prop("version").strip()
    mid = re.sub(r"[^A-Za-z0-9_.-]", "_", mid) or "module"
    ver = re.sub(r"[^A-Za-z0-9_.-]", "_", ver) or "v1.0"

    dist = os.path.join(ROOT, "dist")
    os.makedirs(dist, exist_ok=True)
    out = os.path.join(dist, f"{mid}_{ver}.zip")

    if os.path.exists(out):
        os.remove(out)

    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for d in DIRS:
            zi = zipfile.ZipInfo(d)
            zi.external_attr = (S_IFDIR | 0o755) << 16
            z.writestr(zi, b"")
            print(f"  d {d}")
        for rel in FILES:
            add_file(z, rel)

    print(f"\n打包完成: {out}")
    print(f"大小: {os.path.getsize(out)} 字节")


if __name__ == "__main__":
    main()
