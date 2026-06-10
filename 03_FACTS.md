# Project Facts

These are the confirmed facts about the codebase and behavior:

## 1. Project Architecture
- The application is a SwiftUI macOS app with an AppKit lifecycle managed by `AppDelegate`.
- Key files:
  - `App.swift`: Main development file containing UI and core window/hover logic.
  - `main.swift`: Outdated standalone file.
- State management uses `AppStore` (an `ObservableObject`), which saves workspaces and folders as JSON data inside `UserDefaults.standard` under the key `"FolderShelfWorkspaces"`.

## 2. Drag-to-Reorder Sidebar Folders (Bug 1)
- The folder reordering logic `reorderFolders(from:to:)` is already defined in `AppStore` at line 149 of `App.swift`:
  ```swift
  func reorderFolders(from source: IndexSet, to destination: Int) {
      guard let index = workspaces.firstIndex(where: { $0.id == selectedWorkspaceID }) else { return }
      workspaces[index].folders.move(fromOffsets: source, toOffset: destination)
      save()
  }
  ```
- In `SidebarView` (line 346 of `App.swift`), the sidebar renders folder items using a `List` structure:
  ```swift
  List {
      if let folders = store.selectedWorkspace?.folders, !folders.isEmpty {
          ForEach(folders) { folder in
              HStack { ... }
              .onTapGesture { store.selectedFolderID = folder.id }
          }
          .onMove(perform: store.reorderFolders)
      }
  }
  ```
- **Fact**: The `.onMove` modifier is applied to the `ForEach`, and the list style is set to `.listStyle(.sidebar)`. In SwiftUI, direct tap gestures (`.onTapGesture`) on list items sometimes interfere with drag gestures, or list item structures might prevent dragging unless an explicit edit mode or drag indicator is handled correctly.

## 3. Subfolder Generic Name Display (Bug 2)
- In `App.swift`'s `LocalFile` struct initialization (line 46):
  ```swift
  self.name = resources?.localizedName ?? url.lastPathComponent
  ```
- In `DetailView.refreshFiles()`, directories are read using `FileManager.default.contentsOfDirectory`:
  ```swift
  let urls = try fm.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .creationDateKey, .localizedTypeDescriptionKey], options: [.skipsHiddenFiles])
  ```
- **Fact**: `includingPropertiesForKeys` does **not** include `.localizedNameKey`. This could cause `resources?.localizedName` to return `nil`.
- **Fact**: In macOS file system URL structures, a directory URL sometimes has a trailing slash (e.g. `path/to/folder/`). If so, `url.lastPathComponent` might return an empty string or fall back to generic values.
- **Fact**: In `App.swift`'s `FileRowView` (line 852), name is rendered via `Text(file.name)`. In `main.swift` (which works), the name is rendered using `Text(url.lastPathComponent)`. Check why `file.name` evaluates to `"folder"` or `"文件夹"` for directories.
