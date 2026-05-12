#!/usr/bin/env swift
import Foundation
import AppKit
import CoreGraphics

// LiftLog app icon generator.
// Draws a barbell + spiral-bound log to a 1024×1024 PNG.

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

// Flip so (0,0) is top-left.
context.translateBy(x: 0, y: size)
context.scaleBy(x: 1, y: -1)

// MARK: - Background (rounded dark gradient)
let bgRect = CGRect(x: 0, y: 0, width: size, height: size)
context.saveGState()
let bgGradient = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: [
        CGColor(red: 0.16, green: 0.16, blue: 0.17, alpha: 1.0),
        CGColor(red: 0.05, green: 0.05, blue: 0.06, alpha: 1.0)
    ] as CFArray,
    locations: [0, 1]
)!
context.addRect(bgRect)
context.clip()
context.drawLinearGradient(
    bgGradient,
    start: CGPoint(x: 0, y: 0),
    end: CGPoint(x: size, y: size),
    options: []
)
context.restoreGState()

// MARK: - Colors
let white = CGColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1)
let darkText = CGColor(red: 0.10, green: 0.10, blue: 0.11, alpha: 1)
let accent = CGColor(red: 0.95, green: 0.45, blue: 0.20, alpha: 1)

// MARK: - Barbell
let cx = size / 2
let cy = size / 2

let barLength: CGFloat = size * 0.78
let barHeight: CGFloat = size * 0.055
let barRect = CGRect(
    x: cx - barLength/2,
    y: cy - barHeight/2,
    width: barLength,
    height: barHeight
)
context.setFillColor(white)
context.addPath(CGPath(roundedRect: barRect, cornerWidth: barHeight/2, cornerHeight: barHeight/2, transform: nil))
context.fillPath()

func plate(centerX: CGFloat, width: CGFloat, height: CGFloat) {
    let rect = CGRect(x: centerX - width/2, y: cy - height/2, width: width, height: height)
    let radius = width * 0.35
    context.setFillColor(white)
    context.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
    context.fillPath()
}

let innerPlateWidth: CGFloat = size * 0.075
let innerPlateHeight: CGFloat = size * 0.36
let outerPlateWidth: CGFloat = size * 0.045
let outerPlateHeight: CGFloat = size * 0.22

let leftInnerX = cx - barLength/2 + innerPlateWidth*0.7
let rightInnerX = cx + barLength/2 - innerPlateWidth*0.7
let leftOuterX = cx - barLength/2 + outerPlateWidth*0.2
let rightOuterX = cx + barLength/2 - outerPlateWidth*0.2

plate(centerX: leftInnerX, width: innerPlateWidth, height: innerPlateHeight)
plate(centerX: rightInnerX, width: innerPlateWidth, height: innerPlateHeight)
plate(centerX: leftOuterX, width: outerPlateWidth, height: outerPlateHeight)
plate(centerX: rightOuterX, width: outerPlateWidth, height: outerPlateHeight)

// MARK: - Notebook in the center
let notebookWidth: CGFloat = size * 0.44
let notebookHeight: CGFloat = size * 0.56
let notebookX = cx - notebookWidth/2
let notebookY = cy - notebookHeight/2
let notebookRect = CGRect(x: notebookX, y: notebookY, width: notebookWidth, height: notebookHeight)
let notebookCorner: CGFloat = size * 0.05

// Shadow behind the notebook
context.saveGState()
context.setShadow(
    offset: CGSize(width: 0, height: 14),
    blur: 40,
    color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.45)
)
context.setFillColor(white)
context.addPath(CGPath(roundedRect: notebookRect, cornerWidth: notebookCorner, cornerHeight: notebookCorner, transform: nil))
context.fillPath()
context.restoreGState()

// MARK: - Spiral binding rings on the left edge
let ringCount = 5
let ringWidth: CGFloat = size * 0.07
let ringHeight: CGFloat = size * 0.028
let ringRadius: CGFloat = ringHeight / 2
let firstRingY = notebookY + notebookHeight * 0.10
let lastRingY = notebookY + notebookHeight * 0.90
let ringStep = (lastRingY - firstRingY) / CGFloat(ringCount - 1)
let ringX = notebookX - ringWidth * 0.35

for i in 0..<ringCount {
    let y = firstRingY + CGFloat(i) * ringStep - ringHeight/2
    let rect = CGRect(x: ringX, y: y, width: ringWidth, height: ringHeight)
    context.setFillColor(white)
    context.addPath(CGPath(roundedRect: rect, cornerWidth: ringRadius, cornerHeight: ringRadius, transform: nil))
    context.fillPath()
}

// MARK: - Lines on the notebook page
let lineHeight: CGFloat = size * 0.038
let lineCorner = lineHeight / 2
let lineLeft = notebookX + size * 0.075
let lineRight = notebookX + notebookWidth - size * 0.04
let lineFullWidth = lineRight - lineLeft

func line(yFraction: CGFloat, widthFraction: CGFloat, color: CGColor) {
    let y = notebookY + notebookHeight * yFraction - lineHeight/2
    let w = lineFullWidth * widthFraction
    let rect = CGRect(x: lineLeft, y: y, width: w, height: lineHeight)
    context.setFillColor(color)
    context.addPath(CGPath(roundedRect: rect, cornerWidth: lineCorner, cornerHeight: lineCorner, transform: nil))
    context.fillPath()
}

line(yFraction: 0.32, widthFraction: 1.00, color: darkText)
line(yFraction: 0.50, widthFraction: 0.92, color: darkText)
line(yFraction: 0.68, widthFraction: 0.62, color: accent)

// MARK: - Save
guard let cgImage = context.makeImage() else { fatalError("Could not produce image") }
let rep = NSBitmapImageRep(cgImage: cgImage)
guard let pngData = rep.representation(using: .png, properties: [:]) else { fatalError("PNG encode failed") }
try pngData.write(to: URL(fileURLWithPath: outputPath))
print("Wrote icon to \(outputPath)")
