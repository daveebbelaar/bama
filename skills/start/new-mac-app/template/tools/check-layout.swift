#!/usr/bin/env swift
// Checks the layout files that snapshot mode writes next to each PNG.
// Usage: swift tools/check-layout.swift [--unit 4] /tmp/__APP_NAME__-shots/*-layout.json
// --unit sets the grid step for rules 2 and 5. A design kit measured from
// another app keeps that app's numbers: pass its step, or 0.5 to check only
// edges, insets, and overlaps.
//
// Rules, for views marked with .gridArea and .gridProbe (UI/Grid.swift):
//   1. Every view starts on a whole or half point across, so edges stay sharp.
//      (Heights of text have fractions, so y is checked through the gaps in rule 5.)
//   2. A probe starts a multiple of the unit (4 pt) from its area's leading edge.
//   3. A probe stays at least the area's inset from both sides.
//   4. Probes with the same area and edge share one leading edge.
//   5. Stacked probes on one edge are a multiple of the unit apart. Text heights
//      have fractions and SwiftUI rounds positions, so gaps get 0.5 pt of room.
//   6. Probes in one area never overlap.
// Prints PASS or FAIL per file and exits with 1 on any failure.

import Foundation

struct Probe: Decodable {
    var kind: String
    var name: String
    var area: String
    var edge: String?
    var inset: Double
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    var maxX: Double { x + width }
    var maxY: Double { y + height }
}

struct LayoutFile: Decodable {
    var probes: [Probe]
}

let tolerance = 0.26
let gapTolerance = 0.51
let pixelTolerance = 0.05

func onGrid(_ value: Double, step: Double, within: Double = tolerance) -> Bool {
    let rest = value.truncatingRemainder(dividingBy: step)
    return abs(rest) < within || abs(abs(rest) - step) < within
}

func fmt(_ value: Double) -> String { String(format: "%g", value) }

var paths = Array(CommandLine.arguments.dropFirst())
var unit = 4.0
if let index = paths.firstIndex(of: "--unit"), index + 1 < paths.count, let value = Double(paths[index + 1]) {
    unit = value
    paths.removeSubrange(index...(index + 1))
}

var failedFiles = 0
for path in paths {
    guard let data = FileManager.default.contents(atPath: path),
          let file = try? JSONDecoder().decode(LayoutFile.self, from: data) else {
        print("FAIL \(path): cannot read")
        failedFiles += 1
        continue
    }
    var problems: [String] = []
    let areas = Dictionary(file.probes.filter { $0.kind == "area" }.map { ($0.area, $0) },
                           uniquingKeysWith: { first, _ in first })
    let probes = file.probes.filter { $0.kind == "probe" }

    for probe in file.probes where probe.width > 0 {
        if !onGrid(probe.x, step: 0.5, within: pixelTolerance) {
            problems.append("\(probe.name): x \(fmt(probe.x)) is between pixels")
        }
    }

    for probe in probes {
        guard let area = areas[probe.area] else {
            problems.append("\(probe.name): area \"\(probe.area)\" has no .gridArea")
            continue
        }
        let lead = probe.x - area.x
        if !onGrid(lead, step: unit) {
            problems.append("\(probe.name): starts \(fmt(lead)) pt into \(area.name), not a multiple of \(fmt(unit))")
        }
        if lead < area.inset - tolerance {
            problems.append("\(probe.name): starts \(fmt(lead)) pt into \(area.name), inside its \(fmt(area.inset)) pt inset")
        }
        let trail = area.maxX - probe.maxX
        if trail < area.inset - tolerance {
            problems.append("\(probe.name): ends \(fmt(trail)) pt from the right of \(area.name), inside its \(fmt(area.inset)) pt inset")
        }
    }

    let edges = Dictionary(grouping: probes.filter { $0.edge != nil }) { "\($0.area)/\($0.edge!)" }
    for (key, group) in edges.sorted(by: { $0.key < $1.key }) {
        let xs = Set(group.map { ($0.x * 2).rounded() / 2 })
        if xs.count > 1 {
            let list = group.map { "\($0.name) \(fmt($0.x))" }.joined(separator: ", ")
            problems.append("edge \(key) has \(xs.count) leading edges: \(list)")
        }
        let stacked = group.sorted { $0.y < $1.y }
        for (above, below) in zip(stacked, stacked.dropFirst()) where below.y >= above.maxY - tolerance {
            let gap = below.y - above.maxY
            if !onGrid(gap, step: unit, within: min(gapTolerance, unit / 2 - 0.01)) {
                problems.append("\(above.name) to \(below.name): gap \(fmt(gap)) pt, not a multiple of \(fmt(unit))")
            }
        }
    }

    for (area, group) in Dictionary(grouping: probes, by: \.area) {
        for (index, first) in group.enumerated() {
            for second in group.dropFirst(index + 1) {
                let overlapX = min(first.maxX, second.maxX) - max(first.x, second.x)
                let overlapY = min(first.maxY, second.maxY) - max(first.y, second.y)
                if overlapX > tolerance && overlapY > tolerance {
                    problems.append("\(first.name) and \(second.name) overlap in \(area)")
                }
            }
        }
    }

    let name = (path as NSString).lastPathComponent
    if problems.isEmpty {
        print("PASS \(name): \(probes.count) probes in \(areas.count) areas")
    } else {
        failedFiles += 1
        print("FAIL \(name)")
        for problem in problems { print("  - \(problem)") }
    }
}

exit(failedFiles == 0 ? 0 : 1)
