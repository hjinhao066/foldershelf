// Unit tests for the pure logic in App.swift. Run: Tests/run_tests.sh
import AppKit
import Foundation

var failures = 0
func check(_ cond: Bool, _ msg: String) {
    if cond { print("PASS \(msg)") } else { print("FAIL \(msg)"); failures += 1 }
}

// App.swift's @main entry is renamed at build time (see run_tests.sh); this is the process entry.
@_cdecl("main")
func testMain(_ argc: Int32, _ argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> Int32 {
    // StorageInfo
    let gb: Int64 = 1_000_000_000
    let s = StorageInfo(name: "Macintosh HD", available: 182 * gb, total: 1000 * gb)
    check(s.summary == "Macintosh HD 剩 182 GB / 共 1 TB", "summary text: \(s.summary)")
    check(abs(s.usedFraction - 0.818) < 1e-9, "usedFraction 0.818")
    check(StorageInfo(name: "x", available: 0, total: 0).usedFraction == 0, "zero total -> 0")
    check(StorageInfo(name: "x", available: 5, total: 4).usedFraction == 0, "available>total clamps to 0")
    check(StorageInfo(name: "x", available: -5, total: 4).usedFraction == 1, "negative available clamps to 1")
    if let live = StorageInfo.load() {
        check(live.total > 0 && live.available >= 0 && live.available <= live.total, "live startup disk: \(live.summary)")
    } else {
        check(false, "StorageInfo.load() returned nil for /")
    }
    check(StorageInfo.load(at: URL(fileURLWithPath: "/definitely/not/here")) == nil, "missing path -> nil")

    // PreviewNav
    check(PreviewNav.step(from: 2, count: 5, forward: true) == 3, "step forward")
    check(PreviewNav.step(from: 2, count: 5, forward: false) == 1, "step back")
    check(PreviewNav.step(from: 4, count: 5, forward: true) == 4, "clamp at end")
    check(PreviewNav.step(from: 0, count: 5, forward: false) == 0, "clamp at start")
    check(PreviewNav.step(from: nil, count: 5, forward: true) == 0, "nil forward -> first")
    check(PreviewNav.step(from: nil, count: 5, forward: false) == 4, "nil back -> last")
    check(PreviewNav.step(from: nil, count: 0, forward: true) == 0, "empty list")
    check(PreviewNav.move(from: 5, count: 20, delta: 4) == 9, "grid down by 4 columns")
    check(PreviewNav.move(from: 2, count: 20, delta: -4) == 0, "grid up clamps at first")
    check(PreviewNav.move(from: 18, count: 20, delta: 4) == 19, "grid down clamps at last")
    check(PreviewNav.move(from: nil, count: 20, delta: 4) == 0, "no selection, down -> first")
    check(PreviewNav.move(from: nil, count: 20, delta: -1) == 19, "no selection, up -> last")
    check(PreviewNav.gridColumns(width: 480) == 5, "gridColumns 480pt -> 5")
    check(PreviewNav.gridColumns(width: 10) == 1, "gridColumns narrow -> 1")
    check(!PreviewNav.arrowsMoveFiles(previewVisible: false, focusInSidebarList: true), "sidebar focus, no preview -> arrows left to sidebar")
    check(PreviewNav.arrowsMoveFiles(previewVisible: false, focusInSidebarList: false), "file area focus -> arrows move files")
    check(PreviewNav.arrowsMoveFiles(previewVisible: true, focusInSidebarList: true), "preview open -> arrows step files")
    let table = NSTableView(), inner = NSView()
    table.addSubview(inner)
    check(PreviewNav.isInsideTable(inner), "view inside NSTableView detected")
    check(!PreviewNav.isInsideTable(NSView()), "plain view is not a table")
    check(!PreviewNav.isInsideTable(nil), "nil responder is not a table")

    // AppStore selection memory (isolated defaults suite, never the real app's prefs)
    let suite = "foldertop.tests.\(UUID().uuidString)"
    let d = UserDefaults(suiteName: suite)!
    let dl = FolderItem(path: "/tmp/dl", displayName: "Downloads")
    let cv = FolderItem(path: "/tmp/cv", displayName: "简历通稿")
    let study = Workspace(name: "学习 (Study)", folders: [dl, cv])
    let work = Workspace(name: "工作 (Work)", folders: [FolderItem(path: "/tmp/w", displayName: "w")])
    d.set(try! JSONEncoder().encode([work, study]), forKey: "FolderShelfWorkspaces")
    var st = AppStore(defaults: d)
    check(st.selectedWorkspaceID == study.id, "nothing remembered -> opens 学习 even if not first")
    check(st.selectedFolderID == dl.id, "nothing remembered -> first folder (Downloads)")
    st.selectedFolderID = cv.id
    st.selectWorkspace(work.id)
    check(st.selectedFolderID == work.folders[0].id, "switching workspace opens its first folder")
    st.selectWorkspace(study.id)
    check(st.selectedFolderID == cv.id, "switching back reopens last folder in that workspace")
    st.selectWorkspace(work.id)
    st = AppStore(defaults: d)
    check(st.selectedWorkspaceID == work.id, "relaunch reopens last workspace (tab click alone persisted)")
    st.selectWorkspace(study.id)
    st = AppStore(defaults: d)
    check(st.selectedFolderID == cv.id, "relaunch reopens last folder")
    d.set(UUID().uuidString, forKey: AppStore.selectedWorkspaceKey)
    st = AppStore(defaults: d)
    check(st.selectedWorkspaceID == study.id, "stale workspace id -> falls back to 学习")
    // PanelSize
    check(PanelSize.load(d) == PanelSize.defaultSize, "no saved size -> default \(PanelSize.defaultSize)")
    PanelSize.save(NSSize(width: 1200.4, height: 610.6), d)
    check(PanelSize.load(d) == NSSize(width: 1200, height: 611), "saved size round-trips (rounded)")
    PanelSize.save(NSSize(width: 100, height: 100), d)
    check(PanelSize.load(d) == PanelSize.defaultSize, "too-small saved size ignored")
    let laptop = NSRect(x: 0, y: 0, width: 1000, height: 500)
    check(PanelSize.fit(NSSize(width: 1200, height: 611), in: laptop) == NSSize(width: 1000, height: 500), "fit shrinks to small screen")
    check(PanelSize.fit(NSSize(width: 800, height: 400), in: laptop) == NSSize(width: 800, height: 400), "fit never grows")
    d.removePersistentDomain(forName: suite)

    print(failures == 0 ? "ALL PASSED" : "\(failures) FAILED")
    return failures == 0 ? 0 : 1

}
