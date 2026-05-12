#!/usr/bin/env swift
import Foundation
import AppKit
import CoreGraphics

// LiftLog app icon. 1024×1024.
// Barbell hero with stacked Olympic-style plates and a compact log overlay.

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

// Top-left origin.
context.translateBy(x: 0, y: size)
context.scaleBy(x: 1, y: -1)

// MARK: - Palette
let accent      = CGColor(red: 0.96, green: 0.45, blue: 0.20, alpha: 1)
let accentDim   = CGColor(red: 0.58, green: 0.20, blue: 0.06, alpha: 1)
let plateTop    = CGColor(red: 0.99, green: 0.99, blue: 1.00, alpha: 1)
let plateBot    = CGColor(red: 0.82, green: 0.83, blue: 0.85, alpha: 1)
let darkText    = CGColor(red: 0.13, green: 0.13, blue: 0.15, alpha: 1)

// MARK: - Background: radial dark gradient with a warm tint baked in
context.saveGState()
let bgSpace = CGColorSpaceCreateDeviceRGB()
let bgGradient = CGGradient(
    colorsSpace: bgSpace,
    colors: [
        CGColor(red: 0.18, green: 0.17, blue: 0.18, alpha: 1),
        CGColor(red: 0.08, green: 0.07, blue: 0.08, alpha: 1),
        CGColor(red: 0.03, green: 0.03, blue: 0.04, alpha: 1)
    ] as CFArray,
    locations: [0, 0.55, 1]
)!
context.drawRadialGradient(
    bgGradient,
    startCenter: CGPoint(x: size * 0.5, y: size * 0.35),
    startRadius: 0,
    endCenter: CGPoint(x: size * 0.5, y: size * 0.5),
    endRadius: size * 0.75,
    options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
)

// Soft warm halo behind the barbell to add life
let halo = CGGradient(
    colorsSpace: bgSpace,
    colors: [
        CGColor(red: 0.96, green: 0.45, blue: 0.20, alpha: 0.15),
        CGColor(red: 0.96, green: 0.45, blue: 0.20, alpha: 0.0)
    ] as CFArray,
    locations: [0, 1]
)!
context.drawRadialGradient(
    halo,
    startCenter: CGPoint(x: size * 0.5, y: size * 0.5),
    startRadius: 0,
    endCenter: CGPoint(x: size * 0.5, y: size * 0.5),
    endRadius: size * 0.45,
    options: []
)
context.restoreGState()

// MARK: - Helpers
func fillRoundedRect(_ rect: CGRect, radius: CGFloat, color: CGColor) {
    context.setFillColor(color)
    context.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
    context.fillPath()
}

func fillRoundedRectGradient(_ rect: CGRect, radius: CGFloat, top: CGColor, bottom: CGColor) {
    context.saveGState()
    context.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
    context.clip()
    let grad = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [top, bottom] as CFArray,
        locations: [0, 1]
    )!
    context.drawLinearGradient(
        grad,
        start: CGPoint(x: rect.minX, y: rect.minY),
        end: CGPoint(x: rect.minX, y: rect.maxY),
        options: []
    )
    context.restoreGState()
}

// MARK: - Barbell geometry
let cx = size / 2
let cy = size / 2

// Bar
let barLength: CGFloat = size * 0.86
let barHeight: CGFloat = size * 0.038
let barRect = CGRect(
    x: cx - barLength/2,
    y: cy - barHeight/2,
    width: barLength,
    height: barHeight
)
fillRoundedRectGradient(barRect, radius: barHeight/2, top: plateTop, bottom: plateBot)

// Plate stack on each side: collar (near bar) → big plate → small outer plate.
let collarWidth: CGFloat = size * 0.022
let collarHeight: CGFloat = size * 0.10
let collarRadius: CGFloat = collarWidth * 0.35

let bigPlateWidth: CGFloat = size * 0.075
let bigPlateHeight: CGFloat = size * 0.38
let bigPlateRadius: CGFloat = bigPlateWidth * 0.32

let smallPlateWidth: CGFloat = size * 0.042
let smallPlateHeight: CGFloat = size * 0.22
let smallPlateRadius: CGFloat = smallPlateWidth * 0.35

let plateGap: CGFloat = size * 0.012

func drawPlateStack(side: CGFloat) {
    // side: -1 for left, +1 for right.
    let barEnd = cx + side * (barLength/2)

    // Collar sits just inside the bar end.
    let collarCenterX = barEnd - side * (collarWidth/2 + size * 0.005)
    let collarRect = CGRect(
        x: collarCenterX - collarWidth/2,
        y: cy - collarHeight/2,
        width: collarWidth,
        height: collarHeight
    )
    fillRoundedRectGradient(collarRect, radius: collarRadius, top: plateTop, bottom: plateBot)

    // Big plate just beyond collar.
    let bigCenterX = collarCenterX - side * (collarWidth/2 + plateGap + bigPlateWidth/2)
    let bigRect = CGRect(
        x: bigCenterX - bigPlateWidth/2,
        y: cy - bigPlateHeight/2,
        width: bigPlateWidth,
        height: bigPlateHeight
    )
    fillRoundedRectGradient(bigRect, radius: bigPlateRadius, top: plateTop, bottom: plateBot)

    // Small outer plate beyond big plate.
    let smallCenterX = bigCenterX - side * (bigPlateWidth/2 + plateGap + smallPlateWidth/2)
    let smallRect = CGRect(
        x: smallCenterX - smallPlateWidth/2,
        y: cy - smallPlateHeight/2,
        width: smallPlateWidth,
        height: smallPlateHeight
    )
    fillRoundedRectGradient(smallRect, radius: smallPlateRadius, top: plateTop, bottom: plateBot)
}

drawPlateStack(side: -1)
drawPlateStack(side: +1)

// MARK: - Compact notebook in the center
let notebookWidth: CGFloat = size * 0.36
let notebookHeight: CGFloat = size * 0.48
let notebookX = cx - notebookWidth/2
let notebookY = cy - notebookHeight/2
let notebookRect = CGRect(x: notebookX, y: notebookY, width: notebookWidth, height: notebookHeight)
let notebookCorner: CGFloat = size * 0.05

// Drop shadow
context.saveGState()
context.setShadow(
    offset: CGSize(width: 0, height: 18),
    blur: 36,
    color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.55)
)
context.setFillColor(plateTop)
context.addPath(CGPath(roundedRect: notebookRect, cornerWidth: notebookCorner, cornerHeight: notebookCorner, transform: nil))
context.fillPath()
context.restoreGState()

// Subtle paper gradient
fillRoundedRectGradient(
    notebookRect,
    radius: notebookCorner,
    top: CGColor(red: 1, green: 1, blue: 1, alpha: 1),
    bottom: CGColor(red: 0.92, green: 0.92, blue: 0.94, alpha: 1)
)

// Spiral rings on left edge
let ringCount = 5
let ringWidth: CGFloat = size * 0.052
let ringHeight: CGFloat = size * 0.02
let ringRadius: CGFloat = ringHeight / 2
let ringEdgeX = notebookX - ringWidth * 0.32

let firstRingY = notebookY + notebookHeight * 0.13
let lastRingY = notebookY + notebookHeight * 0.87
let ringStep = (lastRingY - firstRingY) / CGFloat(ringCount - 1)

for i in 0..<ringCount {
    let y = firstRingY + CGFloat(i) * ringStep - ringHeight/2
    let rect = CGRect(x: ringEdgeX, y: y, width: ringWidth, height: ringHeight)
    fillRoundedRectGradient(rect, radius: ringRadius, top: plateTop, bottom: plateBot)
}

// MARK: - Lines on the page
let lineHeight: CGFloat = size * 0.034
let lineCorner = lineHeight / 2
let lineLeft = notebookX + size * 0.055
let lineRight = notebookX + notebookWidth - size * 0.03
let lineSpan = lineRight - lineLeft

func line(yFraction: CGFloat, widthFraction: CGFloat, color: CGColor) {
    let y = notebookY + notebookHeight * yFraction - lineHeight/2
    let w = lineSpan * widthFraction
    let rect = CGRect(x: lineLeft, y: y, width: w, height: lineHeight)
    fillRoundedRect(rect, radius: lineCorner, color: color)
}

line(yFraction: 0.30, widthFraction: 0.95, color: darkText)
line(yFraction: 0.50, widthFraction: 0.78, color: darkText)
line(yFraction: 0.70, widthFraction: 0.58, color: accent)

// Subtle inner glow line under the orange to add depth
context.saveGState()
context.setShadow(offset: .zero, blur: 14, color: accentDim)
let glowY = notebookY + notebookHeight * 0.70 - lineHeight/2
let glowRect = CGRect(x: lineLeft, y: glowY, width: lineSpan * 0.58, height: lineHeight)
fillRoundedRect(glowRect, radius: lineCorner, color: accent)
context.restoreGState()

// MARK: - Save
guard let cgImage = context.makeImage() else { fatalError("Could not produce image") }
let rep = NSBitmapImageRep(cgImage: cgImage)
guard let pngData = rep.representation(using: .png, properties: [:]) else { fatalError("PNG encode failed") }
try pngData.write(to: URL(fileURLWithPath: outputPath))
print("Wrote icon to \(outputPath)")
