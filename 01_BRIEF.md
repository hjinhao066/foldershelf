# Project Brief: FolderShelf Bugfixes

## Background
FolderShelf is a lightweight macOS utility that provides quick finder-like folder access. It triggers a slide-down window (using an `NSPanel` floating window) when the mouse hovers at the top-center edge of any screen, and hides it when the mouse leaves the window (unless pinned).

Currently, it has a few outstanding issues under active development.

## Target Goals & Success Criteria
There are two specific bugs to fix in this iteration:

### 1. Workspace Folders Drag-to-Reorder Bug
- **Issue**: Although the user can add multiple local directories to a workspace, they cannot drag and drop them to reorder their list positions in the left sidebar.
- **Success Criteria**: 
  - Users can click and drag folders in the left sidebar "挂载目录" list to reorder them.
  - The new order must be persistent (saved to `UserDefaults` automatically) and correctly restored upon app restart.
  - No graphical glitches during list item dragging.

### 2. Subfolder Display Name Bug
- **Issue**: If a mounted directory contains subfolders, the file browser (right detail list/grid view) displays their type description or name simply as "folder" or "文件夹" rather than their actual customized/localized folder name (e.g. displaying "Projects" instead of "folder").
- **Success Criteria**:
  - The right-side file list/grid must show the actual specific folder name (e.g., "Developer", "Downloads", "Documents") instead of a generic string like "folder" or "文件夹".
  - Double-clicking a subfolder should still open/navigate into it correctly.

## Constraints & Style
- Keep the current SwiftUI structure and custom styles intact (e.g., solid dark gray background `#292929` or `Color(red: 0.16, green: 0.16, blue: 0.16)`).
- Avoid third-party package dependencies; implement everything natively in Swift (SwiftUI / AppKit).
- Do not affect the top hover trigger and auto-hide logic in `AppDelegate`.
