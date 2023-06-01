//
//  VNCStructs.swift
//  VNCTest
//
//  Created by zimsneexh on 31.05.23.
//

import Foundation

//
// The VNC ServerInit message
//
// MARK: Determine parameters at runtime
struct ServerInit {
    var framebuffer_width: UInt16 = 1920
    var framebuffer_height: UInt16 = 1080
    var pixel_format: PixelFormat = PixelFormat()
    var name_length: UInt32 = UInt32("Velocity".utf8.count)
    var name_string: [UInt8] = "Velocity".utf8.map { UInt8($0) }
    
    func pack() -> [UInt8] {
        var packed_data = [UInt8](repeating: 0, count: 32)
        
        let framebuffer_width = pack_uint16(toPack: self.framebuffer_width)
        let framebuffer_height = pack_uint16(toPack: self.framebuffer_height)
        
        packed_data[0] = framebuffer_width[0]
        packed_data[1] = framebuffer_width[1]
        
        packed_data[2] = framebuffer_height[0]
        packed_data[3] = framebuffer_height[1]
        
        // 16 UInt8's
        let pixel_format = self.pixel_format.pack()
        packed_data[4] = pixel_format[0]
        packed_data[5] = pixel_format[1]
        packed_data[6] = pixel_format[2]
        packed_data[7] = pixel_format[3]
        packed_data[8] = pixel_format[4]
        packed_data[9] = pixel_format[5]
        packed_data[10] = pixel_format[6]
        packed_data[11] = pixel_format[7]
        packed_data[12] = pixel_format[8]
        packed_data[13] = pixel_format[9]
        packed_data[14] = pixel_format[10]
        packed_data[15] = pixel_format[11]
        packed_data[16] = pixel_format[12]
        packed_data[17] = pixel_format[13]
        packed_data[18] = pixel_format[14]
        packed_data[19] = pixel_format[15]

        let name_length = pack_uint32(toPack: self.name_length)
        
        packed_data[20] = name_length[0]
        packed_data[21] = name_length[1]
        packed_data[22] = name_length[2]
        packed_data[23] = name_length[3]
        
        var i = 24
        for uint in self.name_string {
            packed_data[i] = uint
            i += 1
        }
        
        return packed_data
    }
}

//
// The VNC PixelFormat message
//
// MARK: Determine parameters at runtime
struct PixelFormat {
    var bits_per_pixel: UInt8 = 32 // <--- probably wrong??
    var depth: UInt8 = 24 // <--- especially these
    // macOS on M1 uses LE
    var big_endian_flag: UInt8 = 0
    var true_color_flag: UInt8 = 1
    var red_max: UInt16 = 255
    var green_max: UInt16 = 255
    var blue_max: UInt16 = 255
    var red_shift: UInt8 = 16
    var green_shift: UInt8 = 8
    var blue_shift: UInt8 = 0
    
    // Pack with 24 bits of padding
    func pack() -> [UInt8] {
        var packed_data = [UInt8](repeating: 0, count: 16)
                            
        // Bits Per Pixel
        packed_data[0] = self.bits_per_pixel
        
        // Depth
        packed_data[1] = self.depth
        
        // BigEndianFlag
        packed_data[2] = self.big_endian_flag
        
        // TrueColorFlag
        packed_data[3] = self.true_color_flag
        
        // Red, green, blue Max as UInt8
        let red_max = pack_uint16(toPack: self.red_max)
        let green_max = pack_uint16(toPack: self.green_max)
        let blue_max = pack_uint16(toPack: self.blue_max)
        
        // Red
        packed_data[4] = red_max[0]
        packed_data[5] = red_max[1]
        
        // Green
        packed_data[6] = green_max[0]
        packed_data[7] = green_max[1]

        // Blue
        packed_data[8] = blue_max[0]
        packed_data[9] = blue_max[1]
        
        // Red shift
        packed_data[10] = self.red_shift
        
        // Green shift
        packed_data[11] = self.green_shift
        
        // Blue shift
        packed_data[12] = self.blue_shift
        
        // Padding
        packed_data[13] = 0
        packed_data[14] = 0
        packed_data[15] = 0
        
        print("PixelFormat: \(packed_data)")
        return packed_data
    }
}

struct FramebufferUpdate {
    
    var message_type: UInt8 = 0
    var number_of_rects: UInt16 = 1 // <-- performance improvements?
    var rectangles: [Rectangle]
    
    func pack() -> [UInt8] {
        var packed_data = [UInt8](repeating: 0, count: 16)
        packed_data[0] = self.message_type
        packed_data[1] = 0
            
        let number_of_rectangles = pack_uint16(toPack: UInt16(self.rectangles.count))
        packed_data[2] = number_of_rectangles[0]
        packed_data[3] = number_of_rectangles[1]
        
        var i = 4
        for rectangle in rectangles {
            
            // Set X_POS for Rectangle (UInt16)
            let x_position = pack_uint16(toPack: rectangle.x_position)
            packed_data[i] = x_position[0]
            i += 1
            packed_data[i] = x_position[1]
            i += 1
            
            // Set Y_POS for Rectangle (UInt16)
            let y_position = pack_uint16(toPack: rectangle.y_position)
            packed_data[i] = y_position[0]
            i += 1
            packed_data[i] = y_position[1]
            i += 1
            
            // Width
            let width = pack_uint16(toPack: rectangle.width)
            packed_data[i] = width[0]
            i += 1
            packed_data[i] = width[1]
            i += 1
            
            // Height
            let height = pack_uint16(toPack: rectangle.height)
            packed_data[i] = height[0]
            i += 1
            packed_data[i] = height[1]
            i += 1
            
            // EncodingType
            let encoding_type = pack_int32(toPack: rectangle.encoding_type)
            packed_data[i] = encoding_type[0]
            i += 1
            packed_data[i] = encoding_type[1]
            i += 1
            packed_data[i] = encoding_type[2]
            i += 1
            packed_data[i] = encoding_type[3]
            i += 1
        }
        
        print("\(packed_data)")
        return packed_data
    }
    
}

struct Rectangle {
    var x_position: UInt16 = 0
    var y_position: UInt16 = 0
    var width: UInt16
    var height: UInt16
    var encoding_type: Int32 = 0 // <-- raw
}


// UInt32 -> [UInt8]
func pack_uint32(toPack: UInt32) -> [UInt8] {
    var packed_data = [UInt8](repeating: 0, count: 4)
    packed_data[0] = UInt8(truncatingIfNeeded: toPack >> 24)
    packed_data[1] = UInt8(truncatingIfNeeded: toPack >> 16)
    packed_data[2] = UInt8(truncatingIfNeeded: toPack >> 8)
    packed_data[3] = UInt8(truncatingIfNeeded: toPack)
    return packed_data
}

// UInt16 -> [UInt8]
func pack_uint16(toPack: UInt16) -> [UInt8] {
    var packed_data = [UInt8](repeating: 0, count: 2)
    packed_data[0] = UInt8(truncatingIfNeeded: toPack >> 8)
    packed_data[1] = UInt8(truncatingIfNeeded: toPack)
    return packed_data
}

func pack_int32(toPack: Int32) -> [UInt8] {
    var packed_data = [UInt8](repeating: 0, count: 4)
    packed_data[0] = UInt8(truncatingIfNeeded: toPack >> 24)
    packed_data[1] = UInt8(truncatingIfNeeded: toPack >> 16)
    packed_data[2] = UInt8(truncatingIfNeeded: toPack >> 8)
    packed_data[3] = UInt8(truncatingIfNeeded: toPack)
    return packed_data
}
