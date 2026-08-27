# FlexProbe —— 可快速移植的布局抓取工具

基于 FLEX++ 源码的轻量移植层：**在任何目标 IPA 里，三指双击唤出菜单，
一键导出当前全部窗口的视图树 / 控制器树 / 屏幕信息到 zip，通过系统分享面板
发到电脑 / WSL 离线分析。**

> 设计目标：让没有 Mac 的开发者，在任意 App 里用 30 秒抓到「布局类信息」，
> 交给 WSL / AI 分析，用于逆向、UI 还原、插件开发。

---

## 一、快速开始（30 秒抓一份快照）

1. 把 `FlexProbe` 模块并入目标 App（见下两节任一方式）
2. 手机上打开目标 App，**三指双击**屏幕 → 弹出菜单
3. 点「📸 导出布局快照(分享)」→ 系统分享面板 → 「存储到文件 / 微信 / AirDrop」发到电脑
4. 把 zip 放到 WSL，运行：

```bash
python3 tools/analyze_layout_zip.py flexprobe-snapshot.zip
python3 tools/analyze_layout_zip.py flexprobe-snapshot.zip --find Button   # 只看按钮
python3 tools/analyze_layout_zip.py flexprobe-snapshot.zip --top 30        # 类名 Top30
```

---

## 二、用法 A：作为独立 tweak（deb）注入目标 IPA

本仓库本身就是一个 Theos 工程（FLEX++）。默认**注入全部进程**（与原版一致）。

只想注入某个 App，指定它的 Bundle ID 打包：

```bash
# 在 GitHub Actions 手动触发，或在有 macOS SDK 的机器上：
make package FLEXPROBE_TARGET_BUNDLE=com.example.someapp FINALPACKAGE=1
```

产物：
- `packages/FLEX++_<version>.deb`（带 plist 过滤，只注入指定 App）
- `packages/FLEX++_<version>.dylib`（手工注入用）

安装 deb 后即可三指双击抓快照。

---

## 三、用法 B：并入其他 Theos 工程（源码级打包）

其他 IPA 的插件工程（比如 DYKiller 或自研 tweak），在 `Makefile` 里 include 一下即可：

```make
TWEAK_NAME = MyTweak
# ... 其它配置 ...

# 指向 FLEX fork 仓库在本机的路径
FLEXPROBE_DIR ?= $(THEOS_PROJECT_DIR)/../flex-
include $(FLEXPROBE_DIR)/flexprobe.mk

include $(THEOS_MAKE_PATH)/tweak.mk
```

`flexprobe.mk` 会自动：
- 把 FLEX++ 全部源码（`.m/.mm/.c`）+ capstone 反汇编 + `FlexProbe/*.m` 并入你的 target
- 追加 `-lz`、include 路径、capstone 宏
- 追加 `-fobjc-arc`（FLEX 要求 ARC）
- 追加 `-w` 静默编译（宿主如需保留警告可删掉 flexprobe.mk 最后一行）

> ⚠️ 符号冲突：FLEX 类名以 `FLEX`/`FP` 前缀、fishhook 用 `flex_` 前缀，一般与宿主无冲突。
> 若宿主自带 capstone / FLEX 全家桶，建议改为只并入 `FlexProbe/` 子目录。

---

## 四、手机上怎么操作

| 手势 | 行为 |
|---|---|
| **三指双击** | 弹出 FlexProbe 菜单 |
| 菜单·📸 导出布局快照 | 主线程采集 → 后台打包 zip → 弹分享面板 |
| 菜单·🎞 快速连拍 ×3 | 每 1.5s 采一份写 tmp（抓转场/动画中间态），连拍 3 份 |
| 菜单·🚀 打开 FLEX++ | 打开原版 FLEX++ 调试面板 |

FLEX++ 自带的三指长按打开 FLEX 面板与 FlexProbe 三指双击并存，互不冲突。

---

## 五、快照 zip 内容与格式约定

| 文件 | 内容 |
|---|---|
| `meta.txt` | 采集时间 / bundleID / App 版本 / iOS 版本 / 设备 / 屏幕尺寸与 scale / 安全区 / 方向 / 深浅色 |
| `layout-tree.txt` | 人读视图树：每行一个视图，缩进层级，含 frame / windowFrame / bounds / hidden / alpha / corner / bg 色 / 约束数 / 所属 VC |
| `vc-tree.txt` | 人读控制器树：child / presented / nav / tab 全展开 |
| `layout.json` | 机读同源数据，供脚本/AI 解析 |

`layout.json` 结构：

```json
{
  "meta":     { "capturedAt": "...", "bundleID": "...", "screenBounds": {"x":0,"y":0,"w":390,"h":844}, "...": "..." },
  "windows": [
    {
      "class": "UIWindow", "level": 0.0,
      "frame": {"x":0,"y":0,"w":390,"h":844}, "key": true,
      "rootViewController": "AWEShellViewController",
      "subviews": [
        {
          "class": "UIView", "ptr": "0x...",
          "frame": {...}, "windowFrame": {...}, "bounds": {...},
          "hidden": false, "alpha": 1.0, "opaque": true, "clips": false, "touch": true,
          "autoresizing": 18, "constraintsActive": 2, "constraintsTotal": 3,
          "cornerRadius": 12.0, "bg": "#111111FF", "vc": "AWEShellViewController",
          "subviews": [ "...递归..." ]
        }
      ]
    }
  ],
  "viewControllers": [ "...控制器树..." ]
}
```

字段说明：
- `frame` / `windowFrame`：前者是视图在父视图内的 frame，后者是换算到**窗口坐标**后的 frame
  （WSL 分析布局是否全屏 / 越界 / 是否被底栏压住，都用 `windowFrame`）
- `vc`：该视图响应链上最近的非 nil 控制器类名
- `constraintsActive / constraintsTotal`：自身上约束的激活数 / 总数（不含父链）
- 节点上限 30000、深度上限 64，超出截断并在 `layout-tree.txt` 末尾注明

---

## 六、目录结构

```text
flex-/  (本仓库,subezhj/flex- fork)
├── FLEX++.m/…  FLEX 原版源码(平铺根目录,不动)
├── FlexProbe/                  # ← 移植层
│   ├── FPEntry.m               #   入口:三指双击菜单 + 导出 + 分享 + 连拍
│   ├── FPLayoutSnapshot.h/.m   #   视图树/控制器树/屏幕信息采集
│   └── FPZipWriter.h/.m        #   最小 zip 写入(移植自 DYKiller DKZipWriter)
├── flexprobe.mk                # 宿主工程一行 include 集成
├── tools/
│   └── analyze_layout_zip.py   # WSL/PC 侧分析脚本
└── Makefile                    # 支持 FLEXPROBE_TARGET_BUNDLE 参数化注入目标
```

---

## 七、常见问题

**Q: 三指双击会不会跟系统手势冲突？**
A: 三指双击是系统「缩放(Zoom)」的手势，未开启辅助功能 Zoom 时无冲突。
若目标 App 自身有三指双击，可在 `FPEntry.m` 里把 `numberOfTapsRequired` 改为 3，或换成
`UIWindowDidBecomeKeyNotification` 之外的自定义入口（如摇一摇）。

**Q: 快照抓不全 / 超大视图树卡顿？**
A: 上限 30000 节点。正常 App 首页几百~几千节点，采集在主线程几十毫秒内完成。
采集只在触发时运行一次，平时零开销。

**Q: 关掉功能？**
A: 独立 deb 直接卸载；并入工程则删除 `include $(FLEXPROBE_DIR)/flexprobe.mk` 一行即可。

**Q: 需要 iOS 26 / 私有 API 吗？**
A: 不需要。纯 UIKit 公开 API，iOS 12+ 可用；FLEX++ 本体对低版本兼容。
