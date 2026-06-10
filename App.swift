import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Models

struct FolderItem: Identifiable, Codable, Hashable {
    var id = UUID()
    var path: String
    var displayName: String
    
    var url: URL {
        URL(fileURLWithPath: path)
    }
}

struct Workspace: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var folders: [FolderItem]
}

enum ViewMode: String, Codable {
    case list
    case grid
}

enum SortField: String, Codable {
    case name
    case dateModified
    case dateCreated
    case size
    case type
}

struct LocalFile: Identifiable, Hashable {
    var id: URL { url }
    let url: URL
    let name: String
    let dateModified: Date
    let dateCreated: Date
    let size: Int64
    let typeDescription: String
    let ext: String
    let isDirectory: Bool

    init(url: URL) {
        self.url = url
        self.ext = url.pathExtension

        let resources = try? url.resourceValues(forKeys: [.contentModificationDateKey, .creationDateKey, .fileSizeKey, .localizedTypeDescriptionKey, .localizedNameKey, .isDirectoryKey])
        // Use the Finder display name (handles localized / custom folder names);
        // fall back to the raw path component if unavailable.
        self.name = resources?.localizedName ?? url.lastPathComponent
        self.dateModified = resources?.contentModificationDate ?? Date.distantPast
        self.dateCreated = resources?.creationDate ?? Date.distantPast
        self.size = Int64(resources?.fileSize ?? 0)
        self.typeDescription = resources?.localizedTypeDescription ?? "文件"
        self.isDirectory = resources?.isDirectory ?? false
    }
}

// MARK: - Window Drag Handler (AppKit helper to enable custom drag area)

struct WindowDragHandler: NSViewRepresentable {
    class DragView: NSView {
        override func mouseDown(with event: NSEvent) {
            // Initiate standard macOS window dragging
            self.window?.performDrag(with: event)
        }
    }
    
    func makeNSView(context: Context) -> DragView {
        let view = DragView()
        return view
    }
    
    func updateNSView(_ nsView: DragView, context: Context) {}
}

// MARK: - Helpers

func isMouseInsideWindow() -> Bool {
    guard let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "FolderShelfWindow" }),
          window.isVisible else { return false }
    return NSMouseInRect(NSEvent.mouseLocation, window.frame, false)
}

// MARK: - Data Store

class AppStore: ObservableObject {
    @Published var workspaces: [Workspace] = []
    @Published var selectedWorkspaceID: UUID?
    @Published var selectedFolderID: UUID?
    
    init() {
        load()
        if workspaces.isEmpty {
            // Default workspaces: 学习, 工作, 生活
            let studyWS = Workspace(name: "学习", folders: [])
            let workWS = Workspace(name: "工作", folders: [])
            let lifeWS = Workspace(name: "生活", folders: [])
            workspaces = [studyWS, workWS, lifeWS]
            selectedWorkspaceID = studyWS.id
        }
    }
    
    var selectedWorkspace: Workspace? {
        workspaces.first(where: { $0.id == selectedWorkspaceID })
    }
    
    var selectedFolder: FolderItem? {
        selectedWorkspace?.folders.first(where: { $0.id == selectedFolderID })
    }
    
    func addWorkspace(name: String) {
        let ws = Workspace(name: name, folders: [])
        workspaces.append(ws)
        selectedWorkspaceID = ws.id
        save()
    }
    
    func removeWorkspace(_ ws: Workspace) {
        workspaces.removeAll(where: { $0.id == ws.id })
        if selectedWorkspaceID == ws.id {
            selectedWorkspaceID = workspaces.first?.id
        }
        save()
    }
    
    func addFolder(path: String, displayName: String) {
        guard let index = workspaces.firstIndex(where: { $0.id == selectedWorkspaceID }) else { return }
        if workspaces[index].folders.contains(where: { $0.path == path }) {
            return
        }
        let item = FolderItem(path: path, displayName: displayName)
        workspaces[index].folders.append(item)
        selectedFolderID = item.id
        save()
    }
    
    func removeFolder(_ folder: FolderItem) {
        guard let index = workspaces.firstIndex(where: { $0.id == selectedWorkspaceID }) else { return }
        workspaces[index].folders.removeAll(where: { $0.id == folder.id })
        if selectedFolderID == folder.id {
            selectedFolderID = workspaces[index].folders.first?.id
        }
        save()
    }
    
    func reorderFolders(from source: IndexSet, to destination: Int) {
        guard let index = workspaces.firstIndex(where: { $0.id == selectedWorkspaceID }) else { return }
        workspaces[index].folders.move(fromOffsets: source, toOffset: destination)
        save()
    }
    
    func save() {
        if let data = try? JSONEncoder().encode(workspaces) {
            UserDefaults.standard.set(data, forKey: "FolderShelfWorkspaces")
        }
        if let selectedWSID = selectedWorkspaceID {
            UserDefaults.standard.set(selectedWSID.uuidString, forKey: "FolderShelfSelectedWorkspaceID")
        }
    }
    
    func load() {
        if let data = UserDefaults.standard.data(forKey: "FolderShelfWorkspaces"),
           let decoded = try? JSONDecoder().decode([Workspace].self, from: data) {
            workspaces = decoded
        }
        if let wsIDString = UserDefaults.standard.string(forKey: "FolderShelfSelectedWorkspaceID"),
           let wsID = UUID(uuidString: wsIDString) {
            selectedWorkspaceID = wsID
        } else {
            selectedWorkspaceID = workspaces.first?.id
        }
    }
}

// MARK: - Main View

struct MainView: View {
    @StateObject var store = AppStore()
    @State private var showAddWorkspaceSheet = false
    @State private var newWorkspaceName = ""
    @State private var isPinned = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Workspace Menu Bar (Horizontal,一字排开, 贴紧顶端)
            HStack(spacing: 12) {
                // Workspace Label
                HStack(spacing: 6) {
                    Image(systemName: "briefcase.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 13))
                    Text("工作区:")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary)
                }
                
                // Horizontal Workspace tabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(store.workspaces) { ws in
                            Text(ws.name)
                                .font(.system(size: 12, weight: store.selectedWorkspaceID == ws.id ? .semibold : .regular))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(store.selectedWorkspaceID == ws.id ? Color.primary.opacity(0.12) : Color.primary.opacity(0.04))
                                .cornerRadius(6)
                                .onTapGesture {
                                    store.selectedWorkspaceID = ws.id
                                    store.selectedFolderID = ws.folders.first?.id
                                }
                                .contextMenu {
                                    if store.workspaces.count > 1 {
                                        Button("删除工作区", role: .destructive) {
                                            store.removeWorkspace(ws)
                                        }
                                    }
                                }
                        }
                    }
                }
                
                // Add Workspace Button
                Button(action: { showAddWorkspaceSheet = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                        .padding(5)
                        .background(Color.primary.opacity(0.06))
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                // Pin toggle button
                Button(action: {
                    isPinned.toggle()
                    // Pin only governs auto-hide (see .onHover below); the panel always
                    // floats so it never slips behind the active app when unpinned.
                    if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "FolderShelfWindow" }) {
                        window.level = .floating
                    }
                }) {
                    Image(systemName: isPinned ? "pin.fill" : "pin")
                        .foregroundColor(isPinned ? .orange : .secondary)
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .help(isPinned ? "窗口置顶已开启" : "开启窗口置顶")
                
                // Close button
                Button(action: {
                    if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "FolderShelfWindow" }) {
                        window.orderOut(nil)
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .padding(.leading, 4)
            }
            .padding(.top, 4) // Snug against absolute top of the screen
            .padding(.horizontal, 14)
            .padding(.bottom, 8)
            .background(WindowDragHandler())
            
            Divider()
            
            // Bottom Content
            HStack(spacing: 0) {
                // Left Sidebar (Folders list)
                SidebarView(store: store)
                    .frame(width: 180)
                
                Divider()
                
                // Right Detail (File Browser)
                DetailView(store: store)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        // Solid dark gray background
        .background(Color(red: 0.16, green: 0.16, blue: 0.16))
        .onHover { isHovering in
            // Hide automatically when the mouse exits the window, unless pinned
            if !isHovering && !isPinned {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    if !isMouseInsideWindow() {
                        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "FolderShelfWindow" }) {
                            window.orderOut(nil)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showAddWorkspaceSheet) {
            VStack(spacing: 16) {
                Text("新建工作区 (Workspace)")
                    .font(.headline)
                TextField("工作区名称", text: $newWorkspaceName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
                HStack {
                    Button("取消") {
                        showAddWorkspaceSheet = false
                    }
                    Button("创建") {
                        if !newWorkspaceName.isEmpty {
                            store.addWorkspace(name: newWorkspaceName)
                            newWorkspaceName = ""
                        }
                        showAddWorkspaceSheet = false
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(6)
                }
            }
            .padding()
            .frame(width: 260, height: 140)
        }
    }
}

// MARK: - Sidebar View

struct SidebarView: View {
    @ObservedObject var store: AppStore
    
    var body: some View {
        VStack(spacing: 8) {
            Text("挂载目录")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.top, 10)
            
            // Bind selection to the store so a single click selects a folder.
            // The List's own selection handling does NOT swallow the row-reorder
            // drag the way a manual .onTapGesture on the row content did, which is
            // what previously blocked .onMove from ever starting a drag.
            List(selection: $store.selectedFolderID) {
                if let folders = store.selectedWorkspace?.folders, !folders.isEmpty {
                    ForEach(folders) { folder in
                        HStack {
                            Image(systemName: "folder.fill")
                                .foregroundColor(.blue)
                                .font(.system(size: 13))
                            Text(folder.displayName)
                                .lineLimit(1)
                                .font(.system(size: 13))
                            Spacer()
                            
                            Button(action: { store.removeFolder(folder) }) {
                                Image(systemName: "minus.circle")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 11))
                            }
                            .buttonStyle(.plain)
                        }
                        .listRowInsets(EdgeInsets(top: 4, leading: 6, bottom: 4, trailing: 6))
                        // Native sidebar selection now draws the highlight; keep the
                        // row background clear so we don't double-paint the selection.
                        .listRowBackground(Color.clear)
                        .tag(folder.id)
                    }
                    .onMove(perform: store.reorderFolders)
                } else {
                    Text("暂无挂载文件夹")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .listRowBackground(Color.clear)
                }
            }
            .listStyle(.sidebar)
            .background(Color.clear)
            
            Spacer()
            
            // Add Folder Button
            Button(action: addFolderDialog) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("添加本地文件夹")
                }
                .font(.system(size: 12, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .background(Color.primary.opacity(0.06))
            .cornerRadius(6)
            .padding(.horizontal, 10)
            .padding(.bottom, 12)
        }
    }
    
    func addFolderDialog() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "选择要挂载到该工作区的本地文件夹"
        if panel.runModal() == .OK {
            if let url = panel.url {
                let displayName = url.lastPathComponent
                store.addFolder(path: url.path, displayName: displayName)
            }
        }
    }
}

// MARK: - Detail View (Files list/grid)

struct DetailView: View {
    @ObservedObject var store: AppStore
    
    @State private var files: [LocalFile] = []
    @State private var currentURL: URL? = nil
    @State private var searchText = ""
    @State private var selectedFileID: URL? = nil
    @State private var nameWidth: CGFloat = 200   // resizable; auto-expands to fill when the window is wide
    @State private var viewMode: ViewMode = .list
    @State private var sortField: SortField = .dateModified
    @State private var sortAscending = false
    
    // Customizable Columns
    @State private var showType = true
    @State private var showDateModified = true
    @State private var showDateCreated = false   // Finder's default list view hides "Created"; re-enable via the column menu
    @State private var showSize = true
    
    // Resizable Columns Widths
    @State private var typeWidth: CGFloat = 100
    @State private var modifiedWidth: CGFloat = 120
    @State private var createdWidth: CGFloat = 120
    @State private var sizeWidth: CGFloat = 70
    
    let timer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()
    
    var sortedFiles: [LocalFile] {
        files.sorted { (f1, f2) -> Bool in
            // Keep folders above files, like Finder's default sort.
            if f1.isDirectory != f2.isDirectory {
                return f1.isDirectory
            }
            switch sortField {
            case .name:
                return sortAscending ? f1.name.localizedStandardCompare(f2.name) == .orderedAscending : f1.name.localizedStandardCompare(f2.name) == .orderedDescending
            case .dateModified:
                return sortAscending ? f1.dateModified < f2.dateModified : f1.dateModified > f2.dateModified
            case .dateCreated:
                return sortAscending ? f1.dateCreated < f2.dateCreated : f1.dateCreated > f2.dateCreated
            case .size:
                return sortAscending ? f1.size < f2.size : f1.size > f2.size
            case .type:
                return sortAscending ? f1.typeDescription.localizedCompare(f2.typeDescription) == .orderedAscending : f1.typeDescription.localizedCompare(f2.typeDescription) == .orderedDescending
            }
        }
    }
    
    var filteredFiles: [LocalFile] {
        let sorted = sortedFiles
        if searchText.isEmpty {
            return sorted
        } else {
            return sorted.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header control bar
            HStack(spacing: 8) {
                // Navigation / Breadcrumbs
                if let folder = store.selectedFolder, let current = currentURL {
                    // Compare standardized paths so a trailing slash can't fool us into
                    // thinking we're below root and let the user navigate ABOVE the mount.
                    let atRoot = current.standardizedFileURL.path == folder.url.standardizedFileURL.path
                    HStack(spacing: 6) {
                        Button(action: {
                            if !atRoot {
                                currentURL = current.deletingLastPathComponent()
                                refreshFiles()
                            }
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 11, weight: .bold))
                               .foregroundColor(!atRoot ? .primary : .secondary)
                                .padding(5)
                                .background(Color.primary.opacity(0.04))
                                .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                        .disabled(atRoot)
                        
                        Text(current.lastPathComponent)
                            .font(.system(size: 14, weight: .bold))
                        
                        Button(action: {
                            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: current.path)
                        }) {
                            Image(systemName: "arrow.right.macwindow")
                                .foregroundColor(.secondary)
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.plain)
                        .help("在访达中打开当前目录")
                    }
                } else {
                    Text("文件浏览器")
                        .font(.system(size: 13, weight: .bold))
                }
                
                Spacer()
                
                // View Mode Toggle
                if store.selectedFolder != nil {
                    Picker("", selection: $viewMode) {
                        Image(systemName: "list.bullet").tag(ViewMode.list)
                        Image(systemName: "square.grid.2x2").tag(ViewMode.grid)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 65)
                    .font(.system(size: 11))
                    .padding(.trailing, 4)
                }
                
                // Search Bar
                if store.selectedFolder != nil {
                    TextField("搜索当前目录...", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 140)
                        .font(.system(size: 11))
                }
            }
            .padding(.top, 10)
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
            
            Divider()
            
            // Files browser area
            if let folder = store.selectedFolder {
                if viewMode == .list {
                    listTableView(folder: folder)
                } else if filteredFiles.isEmpty {
                    emptyFilesView(folder: folder)
                } else {
                    gridFilesView(folder: folder)
                }
            } else {
                VStack {
                    Spacer()
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                        .padding(.bottom, 8)
                    Text("请在左侧选择或添加一个“挂载目录”")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onChange(of: store.selectedFolderID) { _ in
            currentURL = store.selectedFolder?.url
            refreshFiles()
        }
        .onAppear {
            if currentURL == nil {
                currentURL = store.selectedFolder?.url
            }
            refreshFiles()
        }
        .onReceive(timer) { _ in
            refreshFiles()
        }
    }
    
    // Total width of every column to the right of the name column, including the
    // 15pt gap/divider that follows each one (and the gap after the name column).
    private var otherColumnsWidth: CGFloat {
        var w: CGFloat = 15
        if showType { w += typeWidth + 15 }
        if showDateModified { w += modifiedWidth + 15 }
        if showDateCreated { w += createdWidth + 15 }
        if showSize { w += sizeWidth + 15 }
        return w
    }

    @ViewBuilder
    private func headerLabel(_ title: String, _ field: SortField) -> some View {
        HStack(spacing: 2) {
            Text(title)
            if sortField == field {
                Image(systemName: sortAscending ? "chevron.up" : "chevron.down").font(.system(size: 9))
            }
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundColor(.secondary)
    }

    @ViewBuilder
    private func listHeader(nameW: CGFloat) -> some View {
        HStack(spacing: 0) {
            Button(action: { toggleSort(.name) }) { headerLabel("名称", .name) }
                .buttonStyle(.plain)
                .frame(width: nameW, alignment: .leading)
            // Dragging this resizes the name column (and triggers horizontal scroll for long names).
            ResizableHeaderDivider(width: Binding(get: { nameW }, set: { nameWidth = $0 }), minWidth: 120)

            if showType {
                Button(action: { toggleSort(.type) }) { headerLabel("种类", .type) }
                    .buttonStyle(.plain)
                    .frame(width: typeWidth, alignment: .leading)
                ResizableHeaderDivider(width: $typeWidth, minWidth: 50)
            }
            if showDateModified {
                Button(action: { toggleSort(.dateModified) }) { headerLabel("修改日期", .dateModified) }
                    .buttonStyle(.plain)
                    .frame(width: modifiedWidth, alignment: .leading)
                ResizableHeaderDivider(width: $modifiedWidth, minWidth: 60)
            }
            if showDateCreated {
                Button(action: { toggleSort(.dateCreated) }) { headerLabel("创建日期", .dateCreated) }
                    .buttonStyle(.plain)
                    .frame(width: createdWidth, alignment: .leading)
                ResizableHeaderDivider(width: $createdWidth, minWidth: 60)
            }
            if showSize {
                Button(action: { toggleSort(.size) }) { headerLabel("大小", .size) }
                    .buttonStyle(.plain)
                    .frame(width: sizeWidth, alignment: .leading)
                ResizableHeaderDivider(width: $sizeWidth, minWidth: 40)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 6)
        .frame(width: 48 + nameW + otherColumnsWidth, alignment: .leading)
        // Opaque base so the pinned header never shows the rows scrolling underneath it.
        .background(Color.primary.opacity(0.03))
        .background(Color(red: 0.16, green: 0.16, blue: 0.16))
        .overlay(Divider(), alignment: .bottom)
        .contextMenu {
            Toggle("种类", isOn: $showType)
            Toggle("修改日期", isOn: $showDateModified)
            Toggle("创建日期", isOn: $showDateCreated)
            Toggle("大小", isOn: $showSize)
        }
    }

    @ViewBuilder
    func listTableView(folder: FolderItem) -> some View {
        GeometryReader { geo in
            let basePad: CGFloat = 48
            // Name column fills the viewport when there's room; grows past it (→ horizontal
            // scroll) when the user widens it or the window is too narrow for all columns.
            let nameW = max(nameWidth, geo.size.width - basePad - otherColumnsWidth)
            let totalW = basePad + nameW + otherColumnsWidth
            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                LazyVStack(spacing: 2, pinnedViews: [.sectionHeaders]) {
                    Section {
                        if filteredFiles.isEmpty {
                            Text(searchText.isEmpty ? "当前文件夹为空，或无法访问" : "没有找到匹配的文件")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                        } else {
                            ForEach(filteredFiles) { file in
                                FileRowView(
                                    file: file,
                                    isSelected: selectedFileID == file.id,
                                    showType: showType,
                                    showDateModified: showDateModified,
                                    showDateCreated: showDateCreated,
                                    showSize: showSize,
                                    nameWidth: nameW,
                                    typeWidth: typeWidth,
                                    modifiedWidth: modifiedWidth,
                                    createdWidth: createdWidth,
                                    sizeWidth: sizeWidth,
                                    onSingleTap: { selectedFileID = file.id },
                                    onDoubleTap: { handleFileDoubleTap(file: file) }
                                )
                                .contextMenu { fileContextMenu(file) }
                            }
                        }
                    } header: {
                        listHeader(nameW: nameW)
                    }
                }
                .frame(width: totalW, alignment: .leading)
                .padding(.vertical, 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onDrop(of: [UTType.fileURL.identifier], isTargeted: nil) { providers in
                handleDrop(providers: providers, destFolder: folder)
            }
        }
    }

    @ViewBuilder
    func emptyFilesView(folder: FolderItem) -> some View {
        VStack {
            Spacer()
            Image(systemName: "folder.badge.minus")
                .font(.system(size: 36))
                .foregroundColor(.secondary)
                .padding(.bottom, 8)
            Text(searchText.isEmpty ? "当前文件夹为空，或无法访问" : "没有找到匹配的文件")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: nil) { providers in
            handleDrop(providers: providers, destFolder: folder)
        }
    }

    @ViewBuilder
    func gridFilesView(folder: FolderItem) -> some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 75), spacing: 12)], spacing: 16) {
                ForEach(filteredFiles) { file in
                    FileCardView(
                        file: file,
                        isSelected: selectedFileID == file.id,
                        onSingleTap: { selectedFileID = file.id },
                        onDoubleTap: { handleFileDoubleTap(file: file) }
                    )
                    .contextMenu { fileContextMenu(file) }
                }
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: nil) { providers in
            handleDrop(providers: providers, destFolder: folder)
        }
    }

    func toggleSort(_ field: SortField) {
        if sortField == field {
            sortAscending.toggle()
        } else {
            sortField = field
            sortAscending = true
        }
    }
    
    func refreshFiles() {
        guard let folderURL = currentURL ?? store.selectedFolder?.url else {
            files = []
            return
        }
        
        let fm = FileManager.default
        do {
            let urls = try fm.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .creationDateKey, .localizedTypeDescriptionKey, .localizedNameKey], options: [.skipsHiddenFiles])
            files = urls.map { LocalFile(url: $0) }
        } catch {
            print("Failed to read directory \(folderURL.path): \(error)")
            files = []
        }
    }
    
    func handleFileDoubleTap(file: LocalFile) {
        if file.isDirectory {
            currentURL = file.url
            searchText = ""          // start fresh in the new folder, like Finder
            selectedFileID = nil
            refreshFiles()
        } else {
            NSWorkspace.shared.open(file.url)
        }
    }

    // MARK: Finder-style right-click actions

    @ViewBuilder
    func fileContextMenu(_ file: LocalFile) -> some View {
        Button("打开") { handleFileDoubleTap(file: file) }
        Button("在访达中显示") { NSWorkspace.shared.activateFileViewerSelecting([file.url]) }
        Divider()
        Button("重命名…") { renameFile(file) }
        Button("拷贝") { copyToPasteboard(file) }
        Divider()
        Button("移到废纸篓", role: .destructive) { trashFile(file) }
    }

    func renameFile(_ file: LocalFile) {
        let alert = NSAlert()
        alert.messageText = "重命名"
        alert.informativeText = "为“\(file.name)”输入新名称："
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        field.stringValue = file.url.lastPathComponent
        alert.accessoryView = field
        alert.addButton(withTitle: "重命名")
        alert.addButton(withTitle: "取消")
        if alert.runModal() == .alertFirstButtonReturn {
            let newName = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !newName.isEmpty, newName != file.url.lastPathComponent else { return }
            let dest = file.url.deletingLastPathComponent().appendingPathComponent(newName)
            do {
                try FileManager.default.moveItem(at: file.url, to: dest)
                refreshFiles()
            } catch {
                NSSound.beep()
                print("Rename failed: \(error)")
            }
        }
    }

    func copyToPasteboard(_ file: LocalFile) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects([file.url as NSURL])
    }

    func trashFile(_ file: LocalFile) {
        do {
            try FileManager.default.trashItem(at: file.url, resultingItemURL: nil)
            if selectedFileID == file.id { selectedFileID = nil }
            refreshFiles()
        } catch {
            NSSound.beep()
            print("Trash failed: \(error)")
        }
    }
    
    func handleDrop(providers: [NSItemProvider], destFolder: FolderItem) -> Bool {
        let destURL = currentURL ?? destFolder.url
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, error in
                if let sourceURL = url {
                    let dest = destURL.appendingPathComponent(sourceURL.lastPathComponent)
                    DispatchQueue.main.async {
                        do {
                            try FileManager.default.createDirectory(at: destURL, withIntermediateDirectories: true)
                            
                            if FileManager.default.fileExists(atPath: dest.path) {
                                let ext = sourceURL.pathExtension
                                let base = sourceURL.deletingPathExtension().lastPathComponent
                                let newName = "\(base)_副本.\(ext)"
                                let newDest = destURL.appendingPathComponent(newName)
                                try FileManager.default.copyItem(at: sourceURL, to: newDest)
                            } else {
                                try FileManager.default.copyItem(at: sourceURL, to: dest)
                            }
                            refreshFiles()
                        } catch {
                            print("File drop copy error: \(error)")
                        }
                    }
                }
            }
        }
        return true
    }
}

// MARK: - Resizable Header Divider

struct ResizableHeaderDivider: View {
    @Binding var width: CGFloat
    let minWidth: CGFloat
    // nil = not currently dragging. Captured once at drag start so the column
    // tracks from its real starting width rather than a fragile 0 sentinel.
    @State private var startWidth: CGFloat? = nil

    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.12))
            .frame(width: 1, height: 14)
            // Generous transparent grab zone so the 1pt line is easy to catch.
            .padding(.horizontal, 7)
            .contentShape(Rectangle())
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { value in
                        let base = startWidth ?? width
                        if startWidth == nil { startWidth = base }
                        // Drag right widens the column, drag left narrows it.
                        width = max(minWidth, base + value.translation.width)
                    }
                    .onEnded { _ in
                        startWidth = nil
                    }
            )
    }
}

// MARK: - File Row View (List mode)

struct FileRowView: View {
    let file: LocalFile
    let isSelected: Bool
    let showType: Bool
    let showDateModified: Bool
    let showDateCreated: Bool
    let showSize: Bool

    let nameWidth: CGFloat
    let typeWidth: CGFloat
    let modifiedWidth: CGFloat
    let createdWidth: CGFloat
    let sizeWidth: CGFloat

    let onSingleTap: () -> Void
    let onDoubleTap: () -> Void

    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 0) {
            // Name Column (fixed width; widen it via the header divider and scroll
            // horizontally to reach the rest — full name shows on hover via .help).
            HStack(spacing: 8) {
                FileIconView(url: file.url)
                Text(file.name)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                    .help(file.name)
                Spacer(minLength: 0)
            }
            .frame(width: nameWidth, alignment: .leading)
            Spacer().frame(width: 15)

            // Type Column
            if showType {
                Text(file.typeDescription)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .frame(width: typeWidth, alignment: .leading)
                Spacer().frame(width: 15)
            }

            // Date Modified Column
            if showDateModified {
                Text(fileDateString(file.dateModified))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .frame(width: modifiedWidth, alignment: .leading)
                Spacer().frame(width: 15)
            }

            // Date Created Column
            if showDateCreated {
                Text(fileDateString(file.dateCreated))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .frame(width: createdWidth, alignment: .leading)
                Spacer().frame(width: 15)
            }

            // Size Column
            if showSize {
                Text(fileSizeString(file.size))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .frame(width: sizeWidth, alignment: .leading)
                Spacer().frame(width: 15)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor.opacity(0.25)
                              : (isHovering ? Color.primary.opacity(0.08) : Color.clear))
        .cornerRadius(4)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
        .onTapGesture(count: 2) {
            onDoubleTap()
        }
        .onTapGesture(count: 1) {
            onSingleTap()
        }
        .onDrag {
            onSingleTap()
            return NSItemProvider(object: file.url as NSURL)
        }
    }

    func fileSizeString(_ size: Int64) -> String {
        if size == 0 { return "--" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    func fileDateString(_ date: Date) -> String {
        if date == Date.distantPast { return "--" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - File Card View (Grid mode)

struct FileCardView: View {
    let file: LocalFile
    let isSelected: Bool
    let onSingleTap: () -> Void
    let onDoubleTap: () -> Void
    @State private var isHovering = false
    
    var body: some View {
        VStack(spacing: 6) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: file.url.path))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 40, height: 40)
            
            Text(file.name)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .font(.system(size: 11))
                .foregroundColor(.primary)
                .frame(height: 32, alignment: .top)
        }
        .frame(width: 75, height: 90)
        .padding(6)
        .background(isSelected ? Color.accentColor.opacity(0.25)
                              : (isHovering ? Color.primary.opacity(0.08) : Color.clear))
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
        .onTapGesture(count: 2) {
            onDoubleTap()
        }
        .onTapGesture(count: 1) {
            onSingleTap()
        }
        .onDrag {
            onSingleTap()
            return NSItemProvider(object: file.url as NSURL)
        }
    }
}

struct FileIconView: View {
    let url: URL
    var body: some View {
        Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 18, height: 18)
    }
}

// MARK: - App Window Delegate

class WindowDelegate: NSObject, NSWindowDelegate {
    var onFocusLost: (() -> Void)?
    
    func windowDidResignKey(_ notification: Notification) {
        onFocusLost?()
    }
}

// MARK: - App Delegate & Launcher

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var window: NSWindow?
    let windowDelegate = WindowDelegate()
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var edgeTriggered = false
    private var dwellTimer: Timer?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create Status Item (Menu Bar Icon)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "folder.fill.badge.gearshape", accessibilityDescription: "FolderShelf")
            button.action = #selector(toggleWindow)
            button.target = self
        }
        
        // Build Main Window
        createWindow()
        
        // Detect the mouse reaching the top-center edge of ANY screen via a global
        // event monitor (the same approach menu-bar tools like Ice use). This fires
        // regardless of which app is focused or whether it is fullscreen. A tracking
        // -area window cannot: a focused/fullscreen app (Chrome, Ghostty) starves the
        // background trigger window of mouseEntered events. Reading NSScreen live on
        // each move also makes multi-monitor and display changes self-correcting.
        startEdgeMonitor()

        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)
    }
    
    func createWindow() {
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 660, height: 440),
            styleMask: [.borderless, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        // Behave as a floating utility panel that never steals focus from the
        // foreground app or the menu bar. This is what lets menu-bar managers
        // like Ice keep revealing their hidden items while this panel is open:
        // hovering the menu bar no longer activates FolderShelf and interrupts Ice.
        window.isFloatingPanel = true
        window.becomesKeyOnlyIfNeeded = true // only grabs key focus for the search field
        window.hidesOnDeactivate = false

        window.identifier = NSUserInterfaceItemIdentifier("FolderShelfWindow")
        // CRITICAL BUG FIX: Disable isMovableByWindowBackground so column dragging doesn't move the window!
        window.isMovableByWindowBackground = false
        window.isReleasedWhenClosed = false
        window.level = .floating // Float above the active app; shown without activation
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // Solid dark gray background
        window.backgroundColor = NSColor(red: 0.16, green: 0.16, blue: 0.16, alpha: 1.0)
        window.isOpaque = true
        window.hasShadow = true
        
        // Hook focus lost callback to auto-hide
        windowDelegate.onFocusLost = { [weak self] in
            guard let self = self else { return }
            if self.window?.level != .floating {
                self.window?.orderOut(nil)
            }
        }
        window.delegate = windowDelegate
        
        let hostingView = NSHostingView(rootView: MainView())
        window.contentView = hostingView
        
        // Align with the visible area of the primary screen (snugly under the status bar / menu bar)
        if let screen = NSScreen.main {
            let visibleRect = screen.visibleFrame
            let x = visibleRect.origin.x + (visibleRect.width - 660) / 2
            let y = visibleRect.origin.y + visibleRect.height - 440
            window.setFrame(NSRect(x: x, y: y, width: 660, height: 440), display: true)
        }
        
        self.window = window
    }
    
    func startEdgeMonitor() {
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            self?.checkTopEdge()
        }
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.checkTopEdge()
            return event
        }
    }

    /// Returns the screen whose top-center hot zone currently contains `loc`, else nil.
    private func screenForTopCenter(at loc: NSPoint) -> NSScreen? {
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(loc, $0.frame, false) }) else { return nil }
        let frame = screen.frame
        let topY = frame.origin.y + frame.height
        let centerX = frame.origin.x + frame.width / 2
        let atTop = loc.y >= topY - 4                 // within 4pt of the very top edge
        let inCenter = abs(loc.x - centerX) <= 130    // 260pt-wide hot zone at top center
        return (atTop && inCenter) ? screen : nil
    }

    private func checkTopEdge() {
        let loc = NSEvent.mouseLocation
        if screenForTopCenter(at: loc) != nil {
            // In the hot zone. Require a brief dwell so merely passing across the top
            // (e.g. on the way to the menu bar / Ice icons) does not pop the panel and
            // steal focus. Only fire if the cursor is STILL in the zone after the dwell.
            if !edgeTriggered && dwellTimer == nil {
                dwellTimer = Timer.scheduledTimer(withTimeInterval: 0.22, repeats: false) { [weak self] _ in
                    guard let self = self else { return }
                    self.dwellTimer = nil
                    if !self.edgeTriggered, let s = self.screenForTopCenter(at: NSEvent.mouseLocation) {
                        self.edgeTriggered = true
                        self.showWindowOnScreen(s)
                    }
                }
            }
        } else {
            // Left the hot zone: cancel a pending dwell, and re-arm once the cursor has
            // clearly dropped away from the top so the next dwell can trigger again.
            dwellTimer?.invalidate()
            dwellTimer = nil
            if let scr = NSScreen.screens.first(where: { NSMouseInRect(loc, $0.frame, false) }) {
                let topY = scr.frame.origin.y + scr.frame.height
                if loc.y < topY - 60 { edgeTriggered = false }
            }
        }
    }

    func showWindowOnScreen(_ screen: NSScreen) {
        guard let window = window else { return }
        
        // Align with the visible area of the target screen (snugly under the status bar / menu bar)
        let visibleRect = screen.visibleFrame
        let x = visibleRect.origin.x + (visibleRect.width - 660) / 2
        let y = visibleRect.origin.y + visibleRect.height - 440
        
        window.setFrame(NSRect(x: x, y: y, width: 660, height: 440), display: false)
        window.level = .floating
        // Show the panel above the active app WITHOUT activating FolderShelf, so
        // the menu bar / Ice stay interactive and a fullscreen app is not kicked out.
        window.orderFrontRegardless()
    }
    
    @objc func toggleWindow() {
        guard let window = window else { return }
        if window.isVisible {
            window.orderOut(nil)
        } else {
            if let screen = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }) ?? NSScreen.main {
                showWindowOnScreen(screen)
            }
        }
    }
}

@main
struct FolderShelfApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
