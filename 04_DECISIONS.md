# Project Decisions

These are the design decisions agreed upon by the coordinator (Boss) and the team:

## Architecture & Code Changes
1. **Source File Lock**: The primary code file `/Users/jinhao/FolderShelf/App.swift` is locked. External agents must write their modified version to their own sandbox folder: `working/<agent>/App.swift`.
2. **Framework Alignment**: No external dependencies or UI packages. All changes must use native SwiftUI (macOS 12/13+) and AppKit APIs.
3. **No Functional Regression**: The mouse hover-to-trigger detection in `AppDelegate` and window hiding logic in `MainView` must not be altered, modified, or broken in the process.

## Final Review
- The human coordinator will compare different agent submissions and manually merge them into `final/App.swift`, which will then be deployed back to the root directory `/Users/jinhao/FolderShelf/App.swift`.
