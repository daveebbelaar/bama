import SwiftUI

/// The spacing scale. Every padding, spacing, and size sits on a 4 pt grid.
///   APP_GRID=1 __APP_NAME__     draw the grid, margins, and probes over the window
/// Snapshot mode also writes <page>-<mode>-layout.json, which tools/check-layout.swift checks.
enum Space {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let section: CGFloat = 32
    /// Window and page margins.
    static let margin: CGFloat = 20
}

extension View {
    /// Marks an area (a page, a card, a sheet). Probes inside it must sit on
    /// the 4 pt grid and at least `inset` from its edges.
    func gridArea(_ name: String, inset: CGFloat = Space.margin) -> some View {
        modifier(GridProbeModifier(kind: .area, name: name, area: name, edge: nil, inset: inset))
    }

    /// Marks a view inside `area`. Views with the same `edge` must share one
    /// leading edge. Pass `edge: nil` for views that sit side by side.
    func gridProbe(_ name: String, area: String, edge: String? = "lead") -> some View {
        modifier(GridProbeModifier(kind: .probe, name: name, area: area, edge: edge, inset: 0))
    }
}

/// Frames of every probe on screen, in window points with the origin at the top left.
@Observable
final class GridProbes {
    static let shared = GridProbes()
    static let enabled = ProcessInfo.processInfo.environment["APP_SNAPSHOT"] != nil
        || GridOverlay.enabled

    enum Kind: String, Codable { case area, probe }

    struct Probe: Codable {
        var kind: Kind
        var name: String
        var area: String
        var edge: String?
        var inset: Double
        var x: Double
        var y: Double
        var width: Double
        var height: Double
    }

    private(set) var probes: [String: Probe] = [:]
    /// Which view instance owns each key, so a view that leaves after its
    /// replacement arrived does not remove the replacement's frame.
    private var owners: [String: UUID] = [:]

    func update(_ probe: Probe, owner: UUID) {
        let key = "\(probe.kind.rawValue):\(probe.name)"
        probes[key] = probe
        owners[key] = owner
    }

    func remove(kind: Kind, name: String, owner: UUID) {
        let key = "\(kind.rawValue):\(name)"
        guard owners[key] == owner else { return }
        probes[key] = nil
        owners[key] = nil
    }

    /// Writes the probes next to a snapshot, for tools/check-layout.swift.
    func write(to path: String, window: CGSize) {
        struct File: Codable { var window: [String: Double]; var probes: [Probe] }
        let file = File(window: ["width": window.width, "height": window.height],
                        probes: probes.values.sorted { ($0.area, $0.y, $0.x) < ($1.area, $1.y, $1.x) })
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try? encoder.encode(file).write(to: URL(fileURLWithPath: path))
    }
}

private struct GridProbeModifier: ViewModifier {
    let kind: GridProbes.Kind
    let name: String
    let area: String
    let edge: String?
    let inset: CGFloat
    @State private var owner = UUID()

    func body(content: Content) -> some View {
        if GridProbes.enabled {
            content
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
                    GridProbes.shared.update(.init(kind: kind, name: name, area: area, edge: edge, inset: inset,
                                                   x: frame.minX, y: frame.minY,
                                                   width: frame.width, height: frame.height), owner: owner)
                }
                .onDisappear { GridProbes.shared.remove(kind: kind, name: name, owner: owner) }
        } else {
            content
        }
    }
}

/// Draws the 8 pt grid, each area's inset, and each probe over the window.
struct GridOverlay: View {
    static let enabled = ProcessInfo.processInfo.environment["APP_GRID"] == "1"

    var body: some View {
        let probes = Array(GridProbes.shared.probes.values)
        GeometryReader { proxy in
            let origin = proxy.frame(in: .global).origin
            Canvas { context, size in
                var grid = Path()
                for x in stride(from: 0, through: size.width, by: 8) {
                    grid.addRect(CGRect(x: x, y: 0, width: 0.5, height: size.height))
                }
                for y in stride(from: 0, through: size.height, by: 8) {
                    grid.addRect(CGRect(x: 0, y: y, width: size.width, height: 0.5))
                }
                context.fill(grid, with: .color(.cyan.opacity(0.12)))

                for probe in probes {
                    let rect = CGRect(x: probe.x - origin.x, y: probe.y - origin.y,
                                      width: probe.width, height: probe.height)
                    if probe.kind == .area {
                        context.stroke(Path(rect), with: .color(.blue.opacity(0.6)), lineWidth: 1)
                        let inner = rect.insetBy(dx: probe.inset, dy: probe.inset)
                        context.stroke(Path(inner), with: .color(.blue.opacity(0.35)),
                                       style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    } else {
                        context.stroke(Path(rect), with: .color(.pink.opacity(0.8)), lineWidth: 1)
                        context.draw(Text(probe.name).font(.system(size: 9, weight: .medium)).foregroundStyle(.pink),
                                     at: CGPoint(x: rect.minX + 2, y: rect.minY - 6), anchor: .leading)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}
