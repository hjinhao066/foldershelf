# Project Status

Last Updated: 2026-06-24

## Current State

- 2026-06-24 (r8)：**默认排序改修改日期 + 多选**。① 新装/下载首启的默认排序由「创建日期」改为**「修改日期、最新在上」**，且**「文件夹始终置顶」默认关**（不再按种类把文件夹顶到最前），即纯按修改时间排序；用户仍可右键表头自由改（设置照常持久化）。注意：本机 UserDefaults 早已是 dateModified/降序/foldersOnTop=0，所以本机看不到变化，只有全新安装才生效。② **文件多选 + 多文件拖拽**：单击选一个、**⌘+单击**切换勾选、**Shift+单击**从锚点选连续一段（列表与网格都支持）；选中多个后**整组一起拖出**到访达/其它 App。右键多选项时「在访达中显示／拷贝／移到废纸篓」对整组生效。关键实现：SwiftUI 的 `.onDrag` 一次只能给一个 item，多文件拖拽拖不动——故把行/卡片的全部鼠标交互（点选/双击/悬停/右键菜单/拖拽）下沉到一个透明的 AppKit 覆盖层 `RowInteractionView`(`NSViewRepresentable`)+`RowInteractionNSView`，`mouseDragged` 里用 `beginDraggingSession` 给每个选中 URL 建一个 `NSDraggingItem`，实现真正的多项拖拽；`acceptsFirstMouse=true` 适配 nonactivating 面板。数据层：`selectedFileID:URL?`→`selectedFileIDs:Set<URL>`+`selectionAnchorID`；右键菜单改为数据驱动 `[RowMenuItem]` 由 AppKit 渲染 NSMenu。已编译通过、替换 bundle、重启验证无崩溃。
- 2026-06-14 (r7)：**排序 + 列可定制（Finder 化）**。① 排序设置（字段/升降序）现持久化，默认按**创建日期**；新增**「文件夹始终置顶」**开关（右键表头菜单），关掉即可让所有文件按单一键纯排序（如严格按创建时间），不再被强制把文件夹顶到最前。② 右键表头新增「排序方式」子菜单，可直接选 名称/种类/修改日期/创建日期/大小（即使该列未显示也能选）。③ **列可拖动调换顺序**（名称列固定第一，其余 种类/修改/创建/大小 可拖拽重排，顺序持久化）；创建日期列默认改为显示。代码：新增 `FileColumn` 枚举 + `ColumnDropDelegate`，表头与行均按 `visibleColumns` 顺序渲染。已 typecheck 通过、重建替换 bundle、重启验证运行。
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
| 2026-06-14 | Claude Code (r7) | 排序持久化+默认创建日期+「文件夹始终置顶」开关+排序方式菜单；列可拖动重排（FileColumn/ColumnDropDelegate）|
| 2026-06-24 | Claude Code (r8) | 默认排序改修改日期（文件夹置顶默认关）+ 文件多选（⌘点选/Shift连选，批量在访达显示/拷贝/废纸篓）|

## Active Workstreams

- 无（v0.2.0 已收工）。后续候选：Quick Look 空格预览、键盘方向键导航、新建文件夹按钮、前进/后退历史。
