#!/usr/bin/env swift
//
// Renders a full-bleed square source image into the standard macOS app-icon
// grid: the artwork is clipped to a rounded square (the "squircle" body) and
// centered on a transparent canvas with padding around it.
//
// Defaults follow Apple's Big Sur+ proportions on a 1024px canvas: an 824px
// body (≈100px padding per side) with a 185px corner radius.
//
// Usage:
//   swift make-rounded-icon.swift <input.png> <output.png> [canvas] [inset] [radius]

import AppKit
import Foundation

let args = CommandLine.arguments
guard args.count >= 3 else {
    FileHandle.standardError.write(Data("usage: make-rounded-icon.swift <input> <output> [canvas] [inset] [radius]\n".utf8))
    exit(1)
}

let inputPath = args[1]
let outputPath = args[2]
let canvas = args.count > 3 ? Double(args[3]) ?? 1024 : 1024
let inset = args.count > 4 ? Double(args[4]) ?? 100 : 100
let radius = args.count > 5 ? Double(args[5]) ?? 185 : 185

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("error: \(message)\n".utf8))
    exit(1)
}

guard let source = NSImage(contentsOfFile: inputPath),
      let sourceCG = source.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    fail("couldn't load image at \(inputPath)")
}

let pixels = Int(canvas)
guard let context = CGContext(
    data: nil,
    width: pixels,
    height: pixels,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fail("couldn't create graphics context")
}

context.clear(CGRect(x: 0, y: 0, width: canvas, height: canvas))
context.interpolationQuality = .high

let body = CGRect(x: inset, y: inset, width: canvas - inset * 2, height: canvas - inset * 2)
let rounded = CGPath(roundedRect: body, cornerWidth: radius, cornerHeight: radius, transform: nil)
context.addPath(rounded)
context.clip()

// Aspect-fill the source into the body so it covers the rounded square.
let sourceAspect = Double(sourceCG.width) / Double(sourceCG.height)
var drawRect = body
if sourceAspect > 1 {
    drawRect.size.width = body.height * sourceAspect
    drawRect.origin.x = body.midX - drawRect.width / 2
} else if sourceAspect < 1 {
    drawRect.size.height = body.width / sourceAspect
    drawRect.origin.y = body.midY - drawRect.height / 2
}
context.draw(sourceCG, in: drawRect)

guard let output = context.makeImage() else { fail("couldn't render image") }
let rep = NSBitmapImageRep(cgImage: output)
guard let data = rep.representation(using: .png, properties: [:]) else { fail("couldn't encode PNG") }

do {
    try data.write(to: URL(fileURLWithPath: outputPath))
    print("Wrote \(outputPath) (\(pixels)×\(pixels), body \(Int(body.width))px, radius \(Int(radius))px)")
} catch {
    fail("couldn't write \(outputPath): \(error.localizedDescription)")
}
