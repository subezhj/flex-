#!/usr/bin/env python3
"""FlexProbe 布局快照分析工具（在 WSL / PC 上运行，纯标准库）。

用法:
    python3 analyze_layout_zip.py <snapshot.zip>                 # 概要
    python3 analyze_layout_zip.py <snapshot.zip> --find 关键词    # 过滤含类名关键词的视图
    python3 analyze_layout_zip.py <snapshot.zip> --top 30         # 类名 TopN(默认 20)
    python3 analyze_layout_zip.py <snapshot.zip> --json           # 额外打印完整 JSON 摘要

输出:
    meta 摘要 / 窗口与视图统计 / 类名 TopN / 全屏视图 / 越界视图 / VC 树摘录
"""

import argparse
import json
import sys
import zipfile


def load(zip_path):
    zf = zipfile.ZipFile(zip_path)
    names = set(zf.namelist())
    data = {}
    if "meta.txt" in names:
        data["meta_txt"] = zf.read("meta.txt").decode("utf-8", "replace")
    if "vc-tree.txt" in names:
        data["vc_tree"] = zf.read("vc-tree.txt").decode("utf-8", "replace")
    if "layout.json" in names:
        data["json"] = json.loads(zf.read("layout.json").decode("utf-8", "replace"))
    return data, names


def walk_views(node, out):
    out.append(node)
    for sub in node.get("subviews", []):
        walk_views(sub, out)


def rnd(v, nd=1):
    try:
        return round(float(v), nd)
    except (TypeError, ValueError):
        return v


def frame_str(f):
    if not isinstance(f, dict):
        return "?"
    return (f"x={rnd(f.get('x'))} y={rnd(f.get('y'))} "
            f"w={rnd(f.get('w'))} h={rnd(f.get('h'))}")


def near_screen(scr, f, tol=1.0):
    if not isinstance(f, dict):
        return False
    return (abs(float(f.get("w", 0)) - float(scr["w"])) <= tol and
            abs(float(f.get("h", 0)) - float(scr["h"])) <= tol)


def out_of_bounds(scr, f, tol=0.5):
    if not isinstance(f, dict):
        return False
    x, y = float(f.get("x", 0)), float(f.get("y", 0))
    w, h = float(f.get("w", 0)), float(f.get("h", 0))
    return x < -tol or y < -tol or x + w > float(scr["w"]) + tol or y + h > float(scr["h"]) + tol


def main():
    ap = argparse.ArgumentParser(description="FlexProbe 快照分析")
    ap.add_argument("zip")
    ap.add_argument("--find", default=None, help="只显示类名含该关键词的视图")
    ap.add_argument("--top", type=int, default=20)
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()

    try:
        data, names = load(args.zip)
    except Exception as e:  # noqa: BLE001
        print(f"[FlexProbe] 无法读取 {args.zip}: {e}")
        sys.exit(1)

    print("═" * 60)
    print(f"档案: {args.zip}")
    print(f"内含文件: {', '.join(sorted(names))}")

    if data.get("meta_txt"):
        print("\n── meta ──")
        print(data["meta_txt"].strip())

    j = data.get("json")
    if not j:
        print("\n(无 layout.json，仅列出文件清单)")
        return

    meta = j.get("meta", {})
    if not data.get("meta_txt") and meta:
        print("\n── meta ──")
        for k, v in meta.items():
            print(f"  {k}: {v}")

    windows = j.get("windows", [])
    views = []
    for w in windows:
        walk_views(w, views)

    print(f"\n── 统计 ──")
    print(f"  窗口数: {len(windows)}")
    print(f"  视图节点总数: {len(views)}")

    screen = meta.get("screenBounds", {})
    if screen:
        scr_w, scr_h = float(screen["w"]), float(screen["h"])
        full = [v for v in views if near_screen(screen, v.get("windowFrame"))
                and v.get("class") not in ("UIWindow", "UITransitionView", "UILayoutContainerView")]
        oob = [v for v in views if out_of_bounds(screen, v.get("windowFrame"))]
        hidden = [v for v in views if v.get("hidden")]
        print(f"  全屏视图(非容器类): {len(full)}")
        print(f"  越出屏幕边界的视图: {len(oob)}")
        print(f"  hidden 视图: {len(hidden)}")
        print(f"\n  全屏视图样例(前 10):")
        for v in full[:10]:
            print(f"    {v.get('class')} {frame_str(v.get('windowFrame'))} vc={v.get('vc') or '-'}")

    print(f"\n── 类名 Top{args.top} ──")
    from collections import Counter
    cnt = Counter(v.get("class", "?") for v in views)
    for cls, n in cnt.most_common(args.top):
        print(f"  {n:5d}  {cls}")

    if args.find:
        print(f"\n── 匹配 \"{args.find}\"(共 {sum(1 for v in views if args.find in v.get('class',''))} 个) ──")
        for v in views:
            if args.find not in v.get("class", ""):
                continue
            print(f"  {v.get('class')} [{v.get('ptr')}] frame={frame_str(v.get('frame'))} "
                  f"window={frame_str(v.get('windowFrame'))} hidden={v.get('hidden')} "
                  f"alpha={v.get('alpha')} bg={v.get('bg') or '-'} vc={v.get('vc') or '-'}")
            subs = v.get("subviews")
            if subs:
                for s in subs[:6]:
                    print(f"      └ {s.get('class')} {frame_str(s.get('frame'))}")

    vc = data.get("vc_tree")
    if vc:
        print(f"\n── VC 树摘录(前 40 行) ──")
        for line in vc.strip().splitlines()[:40]:
            print(line)

    if args.json:
        print(f"\n── 完整 JSON(截断 200 行) ──")
        for line in json.dumps(j, ensure_ascii=False, indent=2).splitlines()[:200]:
            print(line)


if __name__ == "__main__":
    main()
