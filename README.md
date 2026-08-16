# 💎 flex++ (FLEX++)

> **iOS 26+ 液态玻璃 (Liquid Glass) 极效 iOS 运行时调试与探索工具箱**

本项目基于开源 FLEX 框架深度重构与拓展，专为 iOS 逆向、Plugin / Tweak 调试与自动化测试打造。

* **项目常用名**：`flex++` (FLEX++)
* **GitHub 官方仓库**：[https://github.com/subezhj/flex-](https://github.com/subezhj/flex-)
* **编译产物**：`FLEX++.dylib` / `com.pxx917144686.flex.deb`

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
