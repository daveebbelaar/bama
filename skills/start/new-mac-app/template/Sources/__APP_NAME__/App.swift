import AppKit
import SwiftData
import SwiftUI

// __APP_NAME__
//   __APP_NAME__                      the app
//   APP_STORE=<file> __APP_NAME__     use another database (tests, experiments)
//   APP_SNAPSHOT=<dir> __APP_NAME__   save a PNG of every sidebar page and Settings tab in light and dark mode, then quit
//   APP_SEED=1 __APP_NAME__           fill an empty /tmp store with sample items (tools/snap.sh)
//   __APP_NAME__ --selftest           run the self-test on a /tmp store and quit with 0 or 1 (tools/selftest.sh)
//   APP_ACCENT=<id> __APP_NAME__      run with another accent from Theme.all (UI/Theme.swift)
//   APP_GRID=1 __APP_NAME__           draw the 8 pt grid and the layout probes over the window

@main
struct __APP_NAME__App: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model = AppModel(container: Store.makeContainer())

    var body: some Scene {
        Window("__APP_NAME__", id: "main") {
            ContentView()
                .environment(model)
                .themed()
                .overlay { if GridOverlay.enabled { GridOverlay() } }
                .frame(minWidth: 760, minHeight: 480)
        }
        .modelContainer(model.container)
        .defaultSize(width: 1100, height: 720)
        .windowToolbarStyle(.unified)
        .commands {
            SidebarCommands()
            ToolbarCommands()
            CommandGroup(replacing: .newItem) {
                Button("New Item") { model.addItem() }
                    .keyboardShortcut("n")
            }
        }

        Settings {
            SettingsView()
                .environment(model)
                .themed()
        }
        .windowResizability(.contentSize)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Started from a terminal, the process is not a foreground app yet.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    /// The self-test's result becomes the exit code, after a normal quit.
    func applicationWillTerminate(_ notification: Notification) {
        if SelfTest.requested { exit(SelfTest.exitCode) }
    }
}

/// Where the data lives: ~/Library/Application Support/__APP_NAME__/__APP_NAME__.store
enum Store {
    /// True when APP_STORE points somewhere else (tests, snapshots, seed data).
    static var isOverridden: Bool {
        !(ProcessInfo.processInfo.environment["APP_STORE"] ?? "").isEmpty
    }

    static var url: URL {
        if let path = ProcessInfo.processInfo.environment["APP_STORE"], !path.isEmpty {
            return URL(fileURLWithPath: path)
        }
        let dir = URL.applicationSupportDirectory.appending(path: "__APP_NAME__", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appending(path: "__APP_NAME__.store")
    }

    static func makeContainer() -> ModelContainer {
        do {
            return try ModelContainer(for: Item.self, configurations: ModelConfiguration(url: url))
        } catch {
            fatalError("Could not open the database at \(url.path): \(error)")
        }
    }
}
