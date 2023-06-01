//
//  VNCEncode.swift
//  VNCTest
//
//  Created by zimsneexh on 01.06.23.
//

import AppKit
import CoreGraphics

func nsImageToRawEncoding(image: NSImage, rawEncoding: UInt8) -> Data? {
    guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        return nil
    }

    let width = cgImage.width
    let height = cgImage.height
    let bytesPerPixel = 4
    let dataSize = width * height * bytesPerPixel

    guard let cfData = cgImage.dataProvider?.data else {
        return nil
    }

    let imagePixelData = CFDataGetBytePtr(cfData)!
    var rawData = Data(count: dataSize)

    for index in 0 ..< dataSize {
        rawData[index] = imagePixelData[index]
    }

    return rawData
}

func U8_RGBA_to_2bit_color(r: UInt8, g: UInt8, b: UInt8, a: UInt8) -> UInt8 {
    let red = (r & 0xFF) << 6
    let green = ((g & 0xFF) << 2) | ((r & 0xF0) >> 4)
    let blue = ((b & 0xFF) << 2) | ((g & 0xF0) >> 4)
    let alpha = a & 0xFF

    return (red | green | blue | alpha)
}


