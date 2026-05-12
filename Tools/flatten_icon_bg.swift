#!/usr/bin/env swift
import Foundation
import AppKit
import CoreGraphics

// Flood-fills the outer background of the icon with a solid color while leaving
// the artwork untouched (notebook lines stay dark, shadows on white stay intact).

guard CommandLine.arguments.count >= 3 else {
    print("usage: flatten_icon_bg.swift <input.png> <output.png>")
    exit(1)
}
let inputPath = CommandLine.arguments[1]
let outputPath = CommandLine.arguments[2]

guard let provider = CGDataProvider(url: URL(fileURLWithPath: inputPath) as CFURL),
      let inputImage = CGImage(pngDataProviderSource: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
else { fatalError("Could not load \(inputPath)") }

let target: Int = 1024
let bytesPerRow = target * 4
guard let context = CGContext(
    data: nil,
    width: target,
    height: target,
    bitsPerComponent: 8,
    bytesPerRow: bytesPerRow,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { fatalError("Could not create context") }

context.interpolationQuality = .high
context.draw(inputImage, in: CGRect(x: 0, y: 0, width: target, height: target))

guard let data = context.data else { fatalError("No pixel data") }
let buffer = data.bindMemory(to: UInt8.self, capacity: target * target * 4)

// Background color (solid, slightly off-black).
let bgR: UInt8 = 0x16
let bgG: UInt8 = 0x16
let bgB: UInt8 = 0x18

// Pixels with brightness below this can be background candidates.
// Tuned so it covers the full original gradient (which peaks around ~75)
// but stays well below the white notebook/plates (~245+).
let bgThreshold: Int = 110

func brightness(at idx: Int) -> Int {
    let r = Int(buffer[idx])
    let g = Int(buffer[idx + 1])
    let b = Int(buffer[idx + 2])
    return (r + g + b) / 3
}

// BFS flood-fill from all four corners, walking only through dark pixels.
var visited = [Bool](repeating: false, count: target * target)
var stack: [(Int, Int)] = [
    (0, 0), (target - 1, 0), (0, target - 1), (target - 1, target - 1)
]

while let (x, y) = stack.popLast() {
    if x < 0 || x >= target || y < 0 || y >= target { continue }
    let cell = y * target + x
    if visited[cell] { continue }
    let pixelIdx = cell * 4
    if brightness(at: pixelIdx) >= bgThreshold { continue }
    visited[cell] = true
    stack.append((x + 1, y))
    stack.append((x - 1, y))
    stack.append((x, y + 1))
    stack.append((x, y - 1))
}

// Replace every background pixel with the solid color.
for i in 0..<(target * target) where visited[i] {
    let pixelIdx = i * 4
    buffer[pixelIdx] = bgR
    buffer[pixelIdx + 1] = bgG
    buffer[pixelIdx + 2] = bgB
    buffer[pixelIdx + 3] = 255
}

guard let outputImage = context.makeImage() else { fatalError("makeImage failed") }
let rep = NSBitmapImageRep(cgImage: outputImage)
guard let pngData = rep.representation(using: .png, properties: [:]) else { fatalError("PNG encode failed") }
try pngData.write(to: URL(fileURLWithPath: outputPath))
print("Wrote \(outputPath)")
