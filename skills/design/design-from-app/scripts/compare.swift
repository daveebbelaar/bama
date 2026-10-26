#!/usr/bin/env swift
// Compares a rebuild with its reference screenshot.
//   swift compare.swift reference.png build.png out-folder [x y w h]
// Writes side-by-side.png, diff.png (red where pixels differ), and overlay.png
// (the build at 50% over the reference), and prints how many pixels differ.
// An optional x y w h (points; both images are 2x captures) compares one region,
// so you can fix one component at a time. Both images must have the same scale.

import AppKit
import CoreGraphics
import Foundation

let args = Array(CommandLine.arguments.dropFirst())
guard args.count >= 3 else { print("usage: swift compare.swift reference.png build.png out-folder [x y w h]"); exit(1) }

func load(_ path: String) -> CGImage {
    guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { print("cannot read \(path)"); exit(1) }
    return image
}

func pixels(_ image: CGImage, width: Int, height: Int) -> [UInt8] {
    var data = [UInt8](repeating: 0, count: width * height * 4)
    let ctx = CGContext(data: &data, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height).offsetBy(dx: 0, dy: CGFloat(height - image.height)))
    return data
}

func write(_ data: [UInt8], width: Int, height: Int, to path: String) {
    var copy = data
    let ctx = CGContext(data: &copy, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

var reference = load(args[0])
var build = load(args[1])
let out = args[2]
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)

if args.count >= 7, let x = Double(args[3]), let y = Double(args[4]), let w = Double(args[5]), let h = Double(args[6]) {
    let rect = CGRect(x: x * 2, y: y * 2, width: w * 2, height: h * 2)
    reference = reference.cropping(to: rect)!
    build = build.cropping(to: rect)!
}

let width = max(reference.width, build.width), height = max(reference.height, build.height)
let a = pixels(reference, width: width, height: height)
let b = pixels(build, width: width, height: height)

var diff = [UInt8](repeating: 255, count: width * height * 4)
var overlay = [UInt8](repeating: 255, count: width * height * 4)
var different = 0
for i in stride(from: 0, to: a.count, by: 4) {
    let delta = max(abs(Int(a[i]) - Int(b[i])), abs(Int(a[i + 1]) - Int(b[i + 1])), abs(Int(a[i + 2]) - Int(b[i + 2])))
    let gray = UInt8((Int(a[i]) + Int(a[i + 1]) + Int(a[i + 2])) / 3)
    if delta > 24 {
        different += 1
        diff[i] = 230; diff[i + 1] = 40; diff[i + 2] = 40
    } else {
        diff[i] = 255 - (255 - gray) / 4; diff[i + 1] = diff[i]; diff[i + 2] = diff[i]
    }
    for c in 0..<3 { overlay[i + c] = UInt8((Int(a[i + c]) + Int(b[i + c])) / 2) }
}

var side = [UInt8](repeating: 255, count: width * 2 * height * 4)
for y in 0..<height {
    for x in 0..<width {
        let src = (y * width + x) * 4
        let left = (y * width * 2 + x) * 4, right = (y * width * 2 + width + x) * 4
        for c in 0..<4 { side[left + c] = a[src + c]; side[right + c] = b[src + c] }
    }
}

write(side, width: width * 2, height: height, to: "\(out)/side-by-side.png")
write(diff, width: width, height: height, to: "\(out)/diff.png")
write(overlay, width: width, height: height, to: "\(out)/overlay.png")
let percent = Double(different) / Double(width * height) * 100
print(String(format: "%.2f%% of pixels differ (%d of %d)", percent, different, width * height))
print("wrote \(out)/side-by-side.png, diff.png, overlay.png")
