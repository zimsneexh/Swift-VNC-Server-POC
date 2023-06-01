import AppKit

extension NSImage {
    func pixelData() -> [Pixel] {
        guard let bmp = self.representations[0] as? NSBitmapImageRep else {
            return []
        }
        
        let data = bmp.bitmapData
        var pixels: [Pixel] = []
        
        for row in 0..<bmp.pixelsHigh {
            for col in 0..<bmp.pixelsWide {
                let pixelIndex = (bmp.bytesPerRow * row) + col * 4
                
                let r = data?[pixelIndex]
                let g = data?[pixelIndex + 1]
                let b = data?[pixelIndex + 2]
                let a = data?[pixelIndex + 3]
                
                pixels.append(Pixel(r: r ?? 0, g: g ?? 0, b: b ?? 0, a: a ?? 0, row: Int64(row) , col: Int64(col)))
            }
        }
        
        return pixels
    }
    
    
}

extension NSImage {
    
    func pngWrite(to url: URL, options: Data.WritingOptions = .atomic) -> Bool {
        do {
            let data = self.pngData
            try data?.write(to: url, options: options)
            return true
        } catch {
            return false
        }
    }

    var pngData: Data? {
        guard let tiffRepresentation = tiffRepresentation, let bitmapImage = NSBitmapImageRep(data: tiffRepresentation) else { return nil }
        return bitmapImage.representation(using: .png, properties: [:])
    }
}


struct Pixel {
    var r: UInt8
    var g: UInt8
    var b: UInt8
    var a: UInt8
    var row: Int64
    var col: Int64

    init(r: UInt8, g: UInt8, b: UInt8, a: UInt8, row: Int64, col: Int64) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
        self.row = row
        self.col = col
    }

    var color: NSColor {
        return NSColor(red: CGFloat(r) / 255.0, green: CGFloat(g) / 255.0, blue: CGFloat(b) / 255.0, alpha: CGFloat(a) / 255.0)
    }

    var description: String {
        return "RGBA(\(r), \(g), \(b), \(a))"
    }
}
