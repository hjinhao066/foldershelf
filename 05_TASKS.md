# Project Tasks

Here are the specific tasks that need to be accomplished by the assigned Agent:

## Task 1: Fix Sidebar Folder Drag-to-Reorder
- **Goal**: Make folders in the left sidebar draggable to reorder.
- **Investigation Points**:
  1. Inspect why `.onMove(perform: store.reorderFolders)` in `SidebarView` (applied to `ForEach` inside `List`) does not trigger drag handles or respond to dragging.
  2. Check if the `.onTapGesture` on the list row content intercepts drag gestures.
  3. Ensure that if you change how selection or tap is handled, clicking a folder still selects it correctly.
  4. Verify that reordering works on both macOS standard mode and fullscreen modes.
- **Verification**: Run the app, add 3-4 folders, drag to reorder them, exit the app, reopen, and check if the order is persisted correctly.

## Task 2: Fix Detail View Subfolder Display Name
- **Goal**: Ensure directories/subfolders in the right-side detail list/grid display their actual last path component name (e.g. "Developer") instead of the generic string "folder" or "文件夹".
- **Investigation Points**:
  1. Inspect `LocalFile`'s `init(url:)` constructor. Check the values returned by `resources?.localizedName` and `url.lastPathComponent` for directory URLs.
  2. Verify if the trailing slash in `URL` impacts `url.lastPathComponent`. (If necessary, use `url.deletingLastPathComponent().lastPathComponent` or strip trailing slashes).
  3. Check if requesting `[.localizedNameKey]` in `FileManager.default.contentsOfDirectory` resolves the issue.
- **Verification**: Mounted folder should contain subfolders. Open it in FolderShelf and verify the folders are displayed with their actual names (e.g., if there's a folder called `Projects`, it shouldn't show up as `folder`).

## Task 3: Deliver Solution & Sandbox Output
- **Goal**: Write your modified code to the sandboxed path.
- **Path**: `working/<agent_name>/App.swift`
- **Rule**: Do NOT write directly to the root `App.swift`.
