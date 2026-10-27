# Project Status

Last Updated: 2026-10-25

## Current State

- 2026-10-27 (r9 收尾)：**空格预览关闭提速 + 方向键导航**。实测（诊断日志）第二下空格→预览隐藏仅约 2ms；根因是共享 QLPreviewPanel 在应用非激活时会无视 close()/orderOut()，原先要等面板收起才消失；现 close() 先 alpha=0+点击穿透（无动画、不闪）再 orderOut，show() 还原。方向键现在平时也可移动选中（列表上下、网格四向，按整行跳），并自动滚动到选中项。诊断日志已删。待用户实机再试一次确认。
- 2026-10-25 (r9)：**空格预览 + 底部存储条 + 配色重设计**。① 选中文件后按**空格**用 Quick Look（QLPreviewPanel）预览，再按空格或 Esc 关闭；预览打开时 ↑↓←→ 切换选中项、预览跟着换；面板收起/失焦时预览一起关。预览窗口层级比面板高一级（盖在上面）；`PreviewController`(数据源/代理) + `PreviewKeyCatcher`(本地按键监听) + `FolderPanel`(NSPanel 子类，`canBecomeKey=true`，orderOut 时关预览)；`RowInteractionNSView.needsPanelToBecomeKey=true` 让点行时面板成 key 而不激活应用；预览窗口自己有焦点时按键走 `previewPanel(_:handle:)`。② 面板最底部**启动盘剩余空间条**：「Macintosh HD 剩 X / 共 Y」+ 细进度条（已用比例，≥90% 变橙），用 `volumeAvailableCapacityForImportantUsage`，只在面板弹出（`folderTopPanelDidShow` 通知）时刷新，不轮询。③ **配色重设计**：新增 `Theme`（顶栏/侧栏/内容三层底色、高对比文字三级、细分隔线，深浅色自适应）；工作区选中标签与侧栏选中行改为强调色实心+白字（原生侧栏选中在非 key 面板里是灰的，改为自绘并隐藏列表自带底）。单测：`Tests/run_tests.sh`（StorageInfo/PreviewNav）。回滚：旧版 app 备份在 ~/reports/foldertop-20261025/backup/FolderTop.app。
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
| 2026-10-25 | Claude Code (r9) | 空格 Quick Look 预览（方向键切换）+ 底部启动盘存储条 + Theme 配色重设计 |

## Active Workstreams

- 无（v0.2.0 已收工）。后续候选：通用键盘方向键导航（目前仅预览打开时生效）、新建文件夹按钮、前进/后退历史。
