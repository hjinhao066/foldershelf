# Project Status

Last Updated: 2026-06-12

## Current State

- 2026-06-12 (r6)：应用改名 FolderShelf → **FolderTop**（现为 `/Applications/FolderTop.app`，CFBundleName/CFBundleExecutable 已改；CFBundleIdentifier 保持 `com.jinhao.FolderShelf` 不变，保住 UserDefaults 里的工作区数据）。修复浅色模式 bug：3 处写死的深灰背景 `Color(red: 0.16, ...)` 改为 `NSColor.windowBackgroundColor`，配色随系统明暗模式自适应。旧 `/Applications/FolderShelf.app` 已删除。
- 两个历史 bug（侧栏拖拽排序、子文件夹显示名）已修复并 live（2026-06-07 rounds 1-4）。
- 2026-06-09 v0.2.0：又修 4 个 bug（删工作区后选中悬空、启动不选目录右侧空白、弹出重置面板尺寸、无扩展名副本命名带尾点），并完成 7 项 UI 精修（胶囊工作区标签、统一图标按钮 hover、侧栏删除钮 hover 浮现、添加按钮强调态、行/卡片缓动动画+选中描边、弹窗跟随系统强调色、视图模式持久化）。
- 已纳入 git 版本控制并发布 GitHub：https://github.com/hjinhao066/foldershelf （public，main 分支，Release v0.2.0）。
- `/Applications/FolderShelf.app` 已替换为 v0.2.0 构建并重启验证运行正常。
- root `App.swift` = `final/App.swift` = `working/claude_code/App.swift`（三份同步）。
- 构建方式：`swiftc -parse-as-library -O App.swift -o <bin>` → 替换 bundle 内 `Contents/MacOS/FolderTop` → `codesign --force --sign -` → `open /Applications/FolderTop.app`。

## History

| Date | Agent | Work |
|------|-------|------|
| 2026-06-07 | Antigravity | 搭建 cowork workspace，准备 briefs |
| 2026-06-07 | Claude Code (r1) | 修侧栏拖拽排序（List selection 替代 onTapGesture）|
| 2026-06-07 | Claude Code (r2) | 合并上线；修返回钮越过挂载根；Finder 化（文件夹置顶/选中/右键菜单）|
| 2026-06-07 | Claude Code (r3) | 找到子文件夹名真因（列宽挤压非数据问题）并修复 |
| 2026-06-07 | Claude Code (r4) | 列表横向滚动 + 名称列可拖拽调宽 |
| 2026-06-09 | Claude Code (r5) | v0.2.0：4 bug 修复 + 7 项 UI 精修 + git/GitHub 版本控制 + Release |
| 2026-06-12 | Claude Code (r6) | 改名 FolderTop + 修浅色模式配色（背景改 windowBackgroundColor 自适应）|

## Active Workstreams

- 无（v0.2.0 已收工）。后续候选：Quick Look 空格预览、键盘方向键导航、新建文件夹按钮、前进/后退历史。
