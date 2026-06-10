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

// MARK: - Data Store

class AppStore: ObservableObject {
    @Published var workspaces: [Workspace] = []
    @Published var selectedWorkspaceID: UUID?
    @Published var selectedFolderID: UUID?
    
    init() {
        load()
        if workspaces.isEmpty {
            // Create default workspaces
            let defaultWS = Workspace(name: "课程学习 (Study)", folders: [])
            let downloadsWS = Workspace(name: "下载中转 (Downloads)", folders: [
                FolderItem(path: FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?.path ?? "", displayName: "Downloads")
            ])
            workspaces = [defaultWS, downloadsWS]
            selectedWorkspaceID = defaultWS.id
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
        // Prevent duplicate folders in the same workspace
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

// MARK: - Visual Effect Background

struct VisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        view.material = .hudWindow
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

// MARK: - Main View

struct MainView: View {
    @StateObject var store = AppStore()
    @State private var showAddWorkspaceSheet = false
    @State private var newWorkspaceName = ""
    @State private var isPinned = true
    
    var body: some View {
        HStack(spacing: 0) {
            // Left Sidebar
            SidebarView(store: store, showAddWorkspaceSheet: $showAddWorkspaceSheet)
                .frame(width: 200)
            
            Divider()
            
            // Right Detail (File Browser)
            DetailView(store: store, isPinned: $isPinned)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(VisualEffectView().ignoresSafeArea())
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
                    .buttonStyle(.borderedProminent)
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
    @Binding var showAddWorkspaceSheet: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            // Workspace Selection Header
            HStack {
                Menu {
                    ForEach(store.workspaces) { ws in
                        Button(ws.name) {
                            store.selectedWorkspaceID = ws.id
                            store.selectedFolderID = ws.folders.first?.id
                        }
                    }
                    Divider()
                    Button("添加新工作区...") {
                        showAddWorkspaceSheet = true
                    }
                    if let selected = store.selectedWorkspace, store.workspaces.count > 1 {
                        Button("删除当前工作区", role: .destructive) {
                            store.removeWorkspace(selected)
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "briefcase")
                        Text(store.selectedWorkspace?.name ?? "选择工作区")
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.06))
                    .cornerRadius(6)
                }
                .menuStyle(.pullDown)
                .frame(maxWidth: .infinity)
            }
            .padding(.top, 36) // Window control buffer
            .padding(.horizontal, 10)
            
            // Folder List
            VStack(alignment: .leading, spacing: 4) {
                Text("挂载目录")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
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
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(store.selectedFolderID == folder.id ? Color.primary.opacity(0.1) : Color.clear)
                                .cornerRadius(6)
                                .onTapGesture {
                                    store.selectedFolderID = folder.id
                                }
                            }
                        } else {
                            Text("暂无挂载文件夹")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                        }
                    }
                    .padding(.horizontal, 6)
                }
            }
            
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

// MARK: - Detail View (Files list)

struct DetailView: View {
    @ObservedObject var store: AppStore
    @Binding var isPinned: Bool
    
    @State private var files: [URL] = []
    @State private var searchText = ""
    
    let timer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()
    
    var filteredFiles: [URL] {
        let sorted = files
        if searchText.isEmpty {
            return sorted
        } else {
            return sorted.filter { $0.lastPathComponent.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                if let folder = store.selectedFolder {
                    Text(folder.displayName)
                        .font(.system(size: 15, weight: .bold))
                    
                    Button(action: {
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: folder.path)
                    }) {
                        Image(systemName: "arrow.right.macwindow")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    .help("在访达中打开")
                } else {
                    Text("文件浏览器")
                        .font(.system(size: 15, weight: .bold))
                }
                
                Spacer()
                
                // Search Bar
                if store.selectedFolder != nil {
                    TextField("搜索当前目录...", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 150)
                        .font(.system(size: 11))
                }
                
                // Pin toggle button
                Button(action: {
                    isPinned.toggle()
                    if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "FolderShelfWindow" }) {
                        window.level = isPinned ? .floating : .normal
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
            .padding(.top, 36) // Window control buffer
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            
            Divider()
            
            // Content
            if let folder = store.selectedFolder {
                if filteredFiles.isEmpty {
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
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(filteredFiles, id: \.self) { fileURL in
                                FileRowView(url: fileURL)
                            }
                        }
                        .padding(8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onDrop(of: [UTType.fileURL.identifier], isTargeted: nil) { providers in
                        handleDrop(providers: providers, destFolder: folder)
                    }
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
            refreshFiles()
        }
        .onAppear {
            refreshFiles()
        }
        .onReceive(timer) { _ in
            refreshFiles()
        }
    }
    
    func refreshFiles() {
        guard let folder = store.selectedFolder else {
            files = []
            return
        }
        
        let fm = FileManager.default
        do {
            let urls = try fm.contentsOfDirectory(at: folder.url, includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey, .fileSizeKey, .contentModificationDateKey], options: [.skipsHiddenFiles])
            
            // Sort by modification date (Newest first)
            files = urls.sorted { (url1, url2) -> Bool in
                let date1 = (try? url1.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
                let date2 = (try? url2.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
                return date1 > date2
            }
        } catch {
            print("Failed to read directory \(folder.path): \(error)")
            files = []
        }
    }
    
    func handleDrop(providers: [NSItemProvider], destFolder: FolderItem) -> Bool {
        for provider in providers {
            provider.loadObject(ofClass: URL.self) { url, error in
                if let sourceURL = url {
                    let dest = destFolder.url.appendingPathComponent(sourceURL.lastPathComponent)
                    DispatchQueue.main.async {
                        do {
                            // Ensure directory exists
                            try FileManager.default.createDirectory(at: destFolder.url, withIntermediateDirectories: true)
                            
                            // Check if file already exists
                            if FileManager.default.fileExists(atPath: dest.path) {
                                let ext = sourceURL.pathExtension
                                let base = sourceURL.deletingPathExtension().lastPathComponent
                                let newName = "\(base)_副本.\(ext)"
                                let newDest = destFolder.url.appendingPathComponent(newName)
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

// MARK: - File Row View

struct FileRowView: View {
    let url: URL
    @State private var isHovering = false
    
    var body: some View {
        HStack {
            FileIconView(url: url)
            Text(url.lastPathComponent)
                .lineLimit(1)
                .font(.system(size: 13))
                .foregroundColor(.primary)
            Spacer()
            
            Text(fileSizeString(url: url))
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isHovering ? Color.primary.opacity(0.08) : Color.clear)
        .cornerRadius(4)
        .onHover { hovering in
            isHovering = hovering
        }
        .onTapGesture(count: 2) {
            NSWorkspace.shared.open(url)
        }
        .onDrag {
            // Drag out of app to Finder/Other Apps
            return NSItemProvider(object: url as NSURL)
        }
    }
    
    func fileSizeString(url: URL) -> String {
        guard let resources = try? url.resourceValues(forKeys: [.fileSizeKey]),
              let size = resources.fileSize else {
            return ""
        }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
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

// MARK: - App Delegate & Launcher

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var window: NSWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create Status Item (Menu Bar Icon)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "folder.fill.badge.gearshape", accessibilityDescription: "FolderShelf")
            button.action = #selector(toggleWindow)
            button.target = self
        }
        
        // Build Window
        createWindow()
        
        // Hide dock icon since it runs primarily as an agent app
        NSApp.setActivationPolicy(.accessory)
    }
    
    func createWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 660, height: 440),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        window.identifier = NSUserInterfaceItemIdentifier("FolderShelfWindow")
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true // Drag by background
        window.isReleasedWhenClosed = false
        window.level = .floating // Default floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.backgroundColor = .clear
        window.hasShadow = true
        
        let hostingView = NSHostingView(rootView: MainView())
        window.contentView = hostingView
        
        // Center top of the primary screen on initial launch
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let x = screenRect.origin.x + (screenRect.width - 660) / 2
            let y = screenRect.origin.y + screenRect.height - 440 - 15
            window.setFrame(NSRect(x: x, y: y, width: 660, height: 440), display: true)
        }
        
        self.window = window
        window.makeKeyAndOrderFront(nil)
    }
    
    @objc func toggleWindow() {
        guard let window = window else { return }
        if window.isVisible {
            window.orderOut(nil)
        } else {
            // Align window to top-center of the screen where cursor is currently located
            if let screen = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }) ?? NSScreen.main {
                let screenRect = screen.visibleFrame
                let x = screenRect.origin.x + (screenRect.width - 660) / 2
                let y = screenRect.origin.y + screenRect.height - 440 - 15
                window.setFrame(NSRect(x: x, y: y, width: 660, height: 440), display: false)
            }
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
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
