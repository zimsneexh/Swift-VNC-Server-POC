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



