#!/usr/bin/env swift
import Foundation
import AppKit
import CoreGraphics

// LiftLog icon — matches the reference: dark background, white barbell
// passing behind a spiral-bound log with one orange accent line.

let size: CGFloat = 1024
let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.png"

guard let context = CGContext(
    data: nil,
    width: Int(size),
    height: Int(size),
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { fatalError("Could not create context") }

context.translateBy(x: 0, y: size)
context.scaleBy(x: 1, y: -1)

// MARK: - Palette
let white  = CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1)
let black  = CGColor(red: 0.10, green: 0.10, blue: 0.11, alpha: 1)
let accent = CGColor(red: 0.96, green: 0.45, blue: 0.20, alpha: 1)

// MARK: - Background (flat dark with subtle gradient like the reference)
context.saveGState()
let bgGradient = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: [
        CGColor(red: 0.16, green: 0.16, blue: 0.17, alpha: 1),
        CGColor(red: 0.07, green: 0.07, blue: 0.08, alpha: 1)
    ] as CFArray,
    locations: [0, 1]
)!
context.addRect(CGRect(x: 0, y: 0, width: size, height: size))
context.clip()
context.drawLinearGradient(
    bgGradient,
    start: CGPoint(x: 0, y: 0),
    end: CGPoint(x: size, y: size),
    options: []
)
context.restoreGState()

// MARK: - Helpers
func fillRoundedRect(_ rect: CGRect, radius: CGFloat, color: CGColor) {
    context.setFillColor(color)
    context.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
    context.fillPath()
}

let cx = size / 2
let cy = size / 2

// MARK: - Barbell (drawn first so the notebook overlays it)
let barLength: CGFloat = size * 0.92
let barHeight: CGFloat = size * 0.045
let barRect = CGRect(
    x: cx - barLength/2,
    y: cy - barHeight/2,
    width: barLength,
    height: barHeight
)
fillRoundedRect(barRect, radius: barHeight/2, color: white)

// Plates: inner (big) and outer (small) on each side.
let bigPlateWidth: CGFloat  = size * 0.075
let bigPlateHeight: CGFloat = size * 0.32
let bigPlateRadius: CGFloat = bigPlateWidth * 0.35

let smallPlateWidth: CGFloat  = size * 0.045
let smallPlateHeight: CGFloat = size * 0.18
let smallPlateRadius: CGFloat = smallPlateWidth * 0.40

let plateGap: CGFloat = size * 0.018

func drawPlates(side: CGFloat) {
    // side = -1 for left, +1 for right.
    let outerEdge = cx + side * (barLength/2)

    // Small (outer) plate sits at the very end of the bar.
    let smallCenterX = outerEdge - side * (smallPlateWidth/2 + size * 0.005)
    let smallRect = CGRect(
        x: smallCenterX - smallPlateWidth/2,
        y: cy - smallPlateHeight/2,
        width: smallPlateWidth,
        height: smallPlateHeight
    )
    fillRoundedRect(smallRect, radius: smallPlateRadius, color: white)

    // Big (inner) plate to the inside.
    let bigCenterX = smallCenterX - side * (smallPlateWidth/2 + plateGap + bigPlateWidth/2)
    let bigRect = CGRect(
        x: bigCenterX - bigPlateWidth/2,
        y: cy - bigPlateHeight/2,
        width: bigPlateWidth,
        height: bigPlateHeight
    )
    fillRoundedRect(bigRect, radius: bigPlateRadius, color: white)
}

drawPlates(side: -1)
drawPlates(side: +1)

// MARK: - Notebook (dominant centerpiece, overlays the bar)
let notebookWidth: CGFloat  = size * 0.46
let notebookHeight: CGFloat = size * 0.62
let notebookX = cx - notebookWidth/2
let notebookY = cy - notebookHeight/2
let notebookRect = CGRect(x: notebookX, y: notebookY, width: notebookWidth, height: notebookHeight)
let notebookCorner: CGFloat = size * 0.055

// Drop shadow
context.saveGState()
context.setShadow(
    offset: CGSize(width: 0, height: 18),
    blur: 40,
    color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.55)
)
fillRoundedRect(notebookRect, radius: notebookCorner, color: white)
context.restoreGState()

// MARK: - Spiral binding rings on the left edge of the notebook
let ringCount = 5
let ringWidth: CGFloat  = size * 0.062
let ringHeight: CGFloat = size * 0.026
let ringRadius: CGFloat = ringHeight / 2
let ringEdgeX = notebookX - ringWidth * 0.45

let firstRingY = notebookY + notebookHeight * 0.13
let lastRingY  = notebookY + notebookHeight * 0.87
let ringStep   = (lastRingY - firstRingY) / CGFloat(ringCount - 1)

for i in 0..<ringCount {
    let y = firstRingY + CGFloat(i) * ringStep - ringHeight/2
    let rect = CGRect(x: ringEdgeX, y: y, width: ringWidth, height: ringHeight)
    fillRoundedRect(rect, radius: ringRadius, color: white)
}

// MARK: - Lines on the page
let lineHeight: CGFloat = size * 0.035
let lineCorner = lineHeight / 2
let lineLeft  = notebookX + size * 0.065
let lineRight = notebookX + notebookWidth - size * 0.04
let lineSpan  = lineRight - lineLeft

func line(yFraction: CGFloat, widthFraction: CGFloat, color: CGColor) {
    let y = notebookY + notebookHeight * yFraction - lineHeight/2
    let w = lineSpan * widthFraction
    let rect = CGRect(x: lineLeft, y: y, width: w, height: lineHeight)
    fillRoundedRect(rect, radius: lineCorner, color: color)
}

line(yFraction: 0.33, widthFraction: 1.00, color: black)
line(yFraction: 0.52, widthFraction: 0.84, color: black)
line(yFraction: 0.71, widthFraction: 0.55, color: accent)

// MARK: - Save
guard let cgImage = context.makeImage() else { fatalError("Could not produce image") }
let rep = NSBitmapImageRep(cgImage: cgImage)
guard let pngData = rep.representation(using: .png, properties: [:]) else { fatalError("PNG encode failed") }
try pngData.write(to: URL(fileURLWithPath: outputPath))
print("Wrote icon to \(outputPath)")
