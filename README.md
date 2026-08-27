# 💎 flex++ (FLEX++)

> **iOS 26+ 液态玻璃 (Liquid Glass) 极效 iOS 运行时调试与探索工具箱**

本项目基于开源 FLEX 框架深度重构与拓展，专为 iOS 逆向、Plugin / Tweak 调试与自动化测试打造。

* **项目常用名**：`flex++` (FLEX++)
* **GitHub 官方仓库**：[https://github.com/subezhj/flex-](https://github.com/subezhj/flex-)
* **编译产物**：`FLEX++.dylib` / `com.pxx917144686.flex.deb`

---

> 🎯 **仓库还内置 [FlexProbe —— 可快速移植的布局抓取工具](#-flexprobe--可快速移植的布局抓取工具)**：
> 三指双击一键导出任意 IPA 全部窗口视图树/控制器树/屏幕信息为 zip，通过分享面板发到电脑/WSL 离线分析。
> 支持作为独立 deb 注入指定 App，或 `include flexprobe.mk` 一行并入其他 Theos 工程。

---

## 🔥 核心特色功能

### 1. 🎨 iOS 16+/26+ 液态玻璃 (Liquid Glass) 视觉重构
- **悬浮液态玻璃胶囊工具条 (`FLEXExplorerToolbar`)**：
  - 采用 iOS 系统级 `UIVisualEffectView`（超薄透光毛玻璃 `UIBlurEffectStyleSystemThinMaterial`）。
  - 16.0pt 平滑高阶圆角、0.5pt 光感微亮半透明边框与 12.0pt 弥散阴影。
  - 按压弹性缩放 Feedback 触控动画（Spring Transform）。
- **动态深浅模式自适应 (`FLEXColor`)**：
  - 支持 `glassBackgroundColor` / `glassBorderColor` / `glassCardBackgroundColor`，完美兼容 Dark / Light Theme。

### 2. 🖐️ 三指轻敲手势拦截与冲突管理 (`FLEXManager+ThreeFingerTap`)
- **三指手势拦截与冲突检测**：
  - 自动捕获 3 指触控手势，判断当前窗口是否存在其他插件的三指手势识别器。
- **三指轻敲唤醒弹窗选择器**：
  - 触发时自动展示液态玻璃选择弹窗：
    - `[ 开启 FLEX++ 调试面板 ]`
    - `[ 打开 其他调试工具 / 传递手势 ]`（冲突时显示）
    - `[ 关闭三指唤醒功能 ]`
    - `[ 取消 ]`
- **菜单快捷开关**：
  - 在 FLEX++ 菜单中增加 **“三指轻敲唤醒 FLEX: 已开启/已关闭”** 开关，支持 `NSUserDefaults` 持久化保存。

### 3. 🛠️ 强悍的调试与抓包功能集
- **网络 API 拦截与抓包 (Network Observer)**：实时捕获 HTTP/HTTPS 请求，查看 Header/Body/JSON 响应。
- **System & DoKit 日志**：控制台 Console / os_log / NSLog 抓取，支持一键导出为 `.txt` 文件。
- **沙盒文件与 SQLite 数据库查看器**：直接浏览 Documents/Library 沙盒，在线预览与编辑 Plist / SQLite 数据。
- **Runtime 运行时与 UI 树探索**：点选 UI 控件，动态遍历 Class / Ivar / Property，在线调用 ObjC 方法。

### 4. ⚙️ GitHub Actions (CI/CD) 自动编译发布
- 配置 `.github/workflows/build.yml` 与 `publish-release.yml`；
- 每次 `git push main` 自动在 macOS Runner 上使用 Theos 编译，发布 `.dylib` 与 `.deb` 产物至 Releases 页面。

---

## 🛠️ 构建与编译说明

### 本地编译 (Theos)
在 macOS / iOS 终端环境下：
```bash
make package FINALPACKAGE=1
```

### 云端自动编译 (GitHub Actions)
只需提交代码并推送到主分支：
```bash
git add .
git commit -m "feat: update flex++"
git push origin main
```
GitHub Actions 会自动触发构建并生成最新的 Release 产物。

---

## 🎯 FlexProbe —— 可快速移植的布局抓取工具

> 基于 FLEX++ 源码的轻量移植层：**在任何目标 IPA 里，三指双击唤出菜单，一键导出当前全部窗口的视图树 / 控制器树 / 屏幕信息到 zip，通过系统分享面板发到电脑 / WSL 离线分析。**
>
> 设计目标：让没有 Mac 的开发者，在任意 App 里用 30 秒抓到「布局类信息」，交给 WSL / AI 分析，用于逆向、UI 还原、插件开发。

### 1️⃣ 移植层 `FlexProbe/`

> 纯 UIKit 公开 API，无 Logos 依赖，iOS 12+。

| 文件 | 职责 |
|---|---|
| `FlexProbe/FPEntry.m` | 三指双击唤起菜单；📸 导出快照 / 🎞 连拍×3 / 🚀 打开 FLEX |
| `FlexProbe/FPLayoutSnapshot.h/.m` | 采集全部窗口视图树/控制器树/屏幕信息 → `meta.txt` + `layout-tree.txt` + `vc-tree.txt` + `layout.json` |
| `FlexProbe/FPZipWriter.h/.m` | 最小 zip 写入（移植自 DYKiller 的 DKZipWriter，无第三方依赖） |
| `flexprobe.mk` | 宿主工程一行 include 集成文件 |
| `tools/analyze_layout_zip.py` | WSL / PC 侧离线分析脚本（纯标准库） |
| `README-FLEXPROBE.md` | 移植与使用完整文档 |

### 2️⃣ 两种移植方式

#### 方式 A：独立 deb 注入目标 IPA

默认注入全部进程（与原版 FLEX++ 一致）；只想注入某个 App，指定 Bundle ID 打包：

```bash
# 在 GitHub Actions 手动触发，或本地 macOS 环境：
make package FLEXPROBE_TARGET_BUNDLE=com.example.someapp FINALPACKAGE=1
```

产物：
- `packages/FLEX++_<version>.deb`（带 plist 过滤，只注入指定 App）
- `packages/FLEX++_<version>.dylib`（手工注入用）

#### 方式 B：并入其他 Theos 工程（源码级打包）

其他 IPA 的插件工程，在 `Makefile` 里 include 一下即可：

```make
TWEAK_NAME = MyTweak
# ... 其它配置 ...

FLEXPROBE_DIR ?= $(THEOS_PROJECT_DIR)/../flex-
include $(FLEXPROBE_DIR)/flexprobe.mk

include $(THEOS_MAKE_PATH)/tweak.mk
```

`flexprobe.mk` 自动完成：
- 把 FLEX++ 全部源码（`.m/.mm/.c`）+ capstone 反汇编 + `FlexProbe/*.m` 并入宿主 target
- 追加 `-lz`、include 路径、capstone 宏
- 追加 `-fobjc-arc`（FLEX 要求 ARC）
- 追加 `-w` 静默编译（宿主如需保留警告可删掉 flexprobe.mk 最后一行）

### 3️⃣ 无 Mac 工作流（核心诉求）

```text
手机：三指双击 → 导出快照 → 分享面板（存文件/微信/AirDrop）→ 发到电脑
WSL：python3 tools/analyze_layout_zip.py snapshot.zip [--find 类名] [--top 30]
```

手机上操作：

| 手势 / 菜单 | 行为 |
|---|---|
| **三指双击** | 弹出 FlexProbe 菜单 |
| 📸 导出布局快照 | 主线程采集 → 后台打包 zip → 弹分享面板 |
| 🎞 快速连拍 ×3 | 每 1.5s 采一份写 tmp（抓转场/动画中间态），连拍 3 份 |
| 🚀 打开 FLEX++ | 打开原版 FLEX++ 调试面板 |

### 4️⃣ 快照内容与格式约定

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
          "frame": {"..."}, "windowFrame": {"..."}, "bounds": {"..."},
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
- `frame` / `windowFrame`：前者是视图在父视图内的 frame，后者是换算到**窗口坐标**后的 frame（WSL 分析布局是否全屏 / 越界 / 是否被底栏压住，都用 `windowFrame`）
- `vc`：该视图响应链上最近的非 nil 控制器类名
- `constraintsActive / constraintsTotal`：自身上约束的激活数 / 总数（不含父链）
- 节点上限 30000、深度上限 64，超出截断并在 `layout-tree.txt` 末尾注明

### 5️⃣ WSL / PC 侧分析

```bash
python3 tools/analyze_layout_zip.py flexprobe-snapshot.zip             # 概要
python3 tools/analyze_layout_zip.py flexprobe-snapshot.zip --find Button # 只看按钮
python3 tools/analyze_layout_zip.py flexprobe-snapshot.zip --top 30      # 类名 Top30
python3 tools/analyze_layout_zip.py flexprobe-snapshot.zip --json        # 完整 JSON 摘要
```

输出：meta 摘要 / 窗口与视图统计 / 类名 TopN / 全屏视图 / 越界视图 / VC 树摘录 / 按类名过滤。

### 6️⃣ 常见问题

- **三指双击跟系统手势冲突？** 三指双击是系统「缩放 (Zoom)」的手势，未开启辅助功能 Zoom 时无冲突；目标 App 自身有三指手势时可在 `FPEntry.m` 改 `numberOfTapsRequired` 或换自定义入口。
- **快照抓不全 / 卡顿？** 上限 30000 节点；正常 App 首页几百~几千节点，主线程采集几十毫秒完成，且只在触发时运行一次，平时零开销。
- **关掉功能？** 独立 deb 直接卸载；并入工程则删除一行 `include` 即可。
- **需要 iOS 26 / 私有 API？** 不需要。纯 UIKit 公开 API，iOS 12+ 可用。

详细文档见 [README-FLEXPROBE.md](README-FLEXPROBE.md)。
