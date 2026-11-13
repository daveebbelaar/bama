// Watches for tooltip windows while a person hovers with the real pointer.
// Read-only: it never moves the pointer, posts events, or changes the front app.
// Usage: swift tools/tooltip-watch.swift [AppName] [seconds]
//        (defaults: __APP_NAME__, 60 s). Start it, then ask the user to hover each control
//        and keep the pointer still for 4 s.
// Each line shows a window of the app above the normal layer (tooltips are layer 103 on
// macOS 26; menus and popovers use other layers) and how long after the pointer stopped
// it appeared. No line while the pointer rests on a control means no tooltip showed.
import AppKit

let args = CommandLine.arguments
let name = args.count > 1 ? args[1] : "__APP_NAME__"
let seconds = args.count > 2 ? Double(args[2]) ?? 60 : 60

guard let app = NSWorkspace.shared.runningApplications.first(where: {
    $0.localizedName == name || $0.executableURL?.lastPathComponent == name
}) else {
    print("tooltip-watch: \(name) is not running")
    exit(1)
}
let pid = app.processIdentifier
print("tooltip-watch: watching \(name) (pid \(pid)) for \(Int(seconds)) s. Hover each control and keep still for 4 s.")

let start = Date()
var lastMouse = NSEvent.mouseLocation
var stoppedAt = Date()
var seen: [Int: Date] = [:]

func elapsed(_ date: Date) -> String { String(format: "%.1f s", Date().timeIntervalSince(date)) }

while Date().timeIntervalSince(start) < seconds {
    let mouse = NSEvent.mouseLocation
    if mouse != lastMouse { lastMouse = mouse; stoppedAt = Date() }

    let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
    var now: Set<Int> = []
    for window in info {
        guard (window[kCGWindowOwnerPID as String] as? Int32) == pid,
              let layer = window[kCGWindowLayer as String] as? Int, layer != 0,
              let number = window[kCGWindowNumber as String] as? Int else { continue }
        now.insert(number)
        if seen[number] == nil {
            seen[number] = Date()
            let bounds = window[kCGWindowBounds as String] as? [String: CGFloat] ?? [:]
            let size = "\(Int(bounds["Width"] ?? 0))x\(Int(bounds["Height"] ?? 0))"
            print("+ layer \(layer) window \(size) at pointer \(Int(mouse.x)),\(Int(mouse.y)), \(elapsed(stoppedAt)) after the pointer stopped")
        }
    }
    for (number, shown) in seen where !now.contains(number) {
        print("- window gone after \(elapsed(shown))")
        seen[number] = nil
    }
    Thread.sleep(forTimeInterval: 0.05)
}
print("tooltip-watch: done")
