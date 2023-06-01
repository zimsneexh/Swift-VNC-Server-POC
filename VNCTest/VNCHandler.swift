//
//  VNCHandler.swift
//  VNCTest
//
//  Created by zimsneexh on 31.05.23.
//

import Foundation
import AppKit
import Socket

enum CommandTypes {
    case SetPixelFormat
    case SetEncodings
    case FramebufferUpdateRequest
    case KeyEvent
    case PointerEvent
    case ClientCutText
}

var commands: [UInt8: CommandTypes] = [
    0: CommandTypes.SetPixelFormat,
    2: CommandTypes.SetEncodings,
    3: CommandTypes.FramebufferUpdateRequest,
    4: CommandTypes.KeyEvent,
    5: CommandTypes.PointerEvent,
    6: CommandTypes.ClientCutText,
]

func handle_event(pixelformat: inout PixelFormat, socket: Socket, buffer: inout Data) {
    let command = Array.init(buffer)
    
    if let message_type = commands[command[0]] {
        
        switch(message_type) {
        case CommandTypes.SetPixelFormat:
            let pixel_format_raw = Array(command[4..<20])
            pixelformat.bits_per_pixel = pixel_format_raw[0]
            pixelformat.depth = pixel_format_raw[1]
            pixelformat.big_endian_flag = pixel_format_raw[2]
            pixelformat.true_color_flag = pixel_format_raw[3]
            pixelformat.red_max = UInt16((pixel_format_raw[4] << 8) + pixel_format_raw[5])
            pixelformat.green_max = UInt16((pixel_format_raw[6] << 8) + pixel_format_raw[7])
            pixelformat.blue_max = UInt16((pixel_format_raw[8] << 8) + pixel_format_raw[9])
            pixelformat.red_shift = pixel_format_raw[10]
            pixelformat.green_shift = pixel_format_raw[11]
            pixelformat.blue_shift = pixel_format_raw[12]

            NSLog("Client updated PixelFormat: \(pixelformat)")
            break
            
        case CommandTypes.SetEncodings:
            let number_of_encodings = UInt16(UInt16(command[2] << 8) + UInt16(command[3]))
            NSLog("Number of encodings: \(number_of_encodings)")
            
            for i in stride(from: 0, to: Int(number_of_encodings * 4), by: 4) {
                let e1 = UInt16((UInt16(command[4+i]) << 8) + UInt16(command[4+i+1]))
                let e2 = UInt16((UInt16(command[4+i+2]) << 8) + UInt16(command[4+i+3]))
                let encoding_id = UInt32(e1 << 16 + e2)
                //print("EID=\(encoding_id)")
            }
            
            
            
            break
            
        case CommandTypes.FramebufferUpdateRequest:
            NSLog("Received FramebufferUpdateRequest")
            let incremental = command[1] != 0
            let x_position = UInt16(UInt16(command[2]) << 8 + UInt16(command[3]))
            let y_position = UInt16(UInt16(command[4]) << 8 + UInt16(command[5]))
            let req_width = UInt16(UInt16(command[6]) << 8 + UInt16(command[7]))
            let req_height = UInt16(UInt16(command[8]) << 8 + UInt16(command[9]))
            
            NSLog("incremental=\(incremental) x_position=\(x_position) y_position=\(y_position) width=\(req_width) height=\(req_height)")

            // The Framebuffer
            var fb: [UInt8]? = nil
            
            // 24bit FullColor mode with AlphaChannel
            if pixelformat.depth == 24 && pixelformat.bits_per_pixel == 32 {
                NSLog("Using 24bit FullColor mode with AlphaChannel.")
                
                // 32 bit -> Pixel
                let frame_buffer_size: UInt64 = UInt64(req_width) * UInt64(req_height) * 4
                                
                // Fake FB with ((U8) R/ (U8) G/ (U8) B) / (U8) A
                fb = Array(repeating: 0xFF, count: Int(frame_buffer_size))
                
                
            // 6bit Colors with 2bit AlphaChannel
            } else if pixelformat.depth == 6 && pixelformat.bits_per_pixel == 8 {
                NSLog("Using 6bit Colors with 2bit AlphaChannel.")
                
                // 8 bit -> Pixel
                let frame_buffer_size: UInt64 = UInt64(req_width) * UInt64(req_height)
                let color = U8_RGBA_to_2bit_color(r: UInt8(0xFF), g: UInt8(0xFF), b: UInt8(0xFF), a: UInt8(0xFF))
                
                NSLog("Color is \(color)")
                
                // Fake FB with U8(2bit A, 2bit R, 2bit G, 2bit B)
                fb = Array(repeating: color, count: Int(frame_buffer_size))
            }
            
            // Check for framebuffer
            guard let fb = fb else {
                NSLog("Could not allocate Framebuffer")
                break
            }
            
            // Build Rectangle struct
            var content_rect = Rectangle(x_position: x_position, y_position: y_position, width: UInt16(req_width), height: UInt16(req_height))
            content_rect.encoding_type = 0
            
            // Build FramebufferUpdate struct
            // MARK: Uses hardcoded defaults, these might change?
            var frame_buffer_update = FramebufferUpdate(rectangles: [content_rect]).pack()
            frame_buffer_update.append(contentsOf: fb)
            
            // Write to socket
            do {
                try socket.write(from: Data(bytes: frame_buffer_update, count: frame_buffer_update.count))
            } catch {
                NSLog("BrokenPipeError")
                return
            }
            
            NSLog("Frame update sent!")
            
            // Dispatching to background Queue
            DispatchQueue.global(qos: .userInitiated).async {
                repeat {
                    
                    
                } while(true)
            }

            /*
            let filePath = NSHomeDirectory() + "/drip.png"
            let image = NSImage(contentsOfFile: filePath)!
            
            //var bitmap_rep: NSBitmapImageRep? = nil
            var cropped_image: NSImage? = nil
            
            // Construct the target frame
            let target_frame = NSRect(x: CGFloat(x_position), y: CGFloat(y_position), width: CGFloat(req_width), height: CGFloat(req_height))
            
            if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                let croppedCGImage = cgImage.cropping(to: target_frame)
                
                if let croppedImage = croppedCGImage {
                    cropped_image = NSImage(cgImage: croppedImage, size: NSSize(width: croppedImage.width, height: croppedImage.height))
                    
                    //bitmap_rep = NSBitmapImageRep(cgImage: croppedImage)
                    NSLog("NSImage cropped.")
                }
            }
            
            if let rawData = nsImageToRawEncoding(image: cropped_image!, rawEncoding: UInt8(4)) {
                // Use the rawData for further processing or transmission
                print("Conversion successful. Raw data size: \(rawData.count)")
                
                let content_rect = Rectangle(width: UInt16(cropped_image?.size.width ?? 0), height: UInt16(cropped_image?.size.width ?? 0))
                let fbu = FramebufferUpdate(rectangles: [content_rect]).pack()
                
                NSLog("Sending FramebufferUpdate-Structure..")
                try! socket.write(from: Data(bytes: fbu, count: fbu.count))
                
                NSLog("Sending FB..")
                try! socket.write(from: rawData)

                
            } else {
                print("Conversion failed.")
            }
             */
            
            
            
            /*
            // Extract the raw pixel data
            let height = bitmap_rep?.pixelsHigh
            let width = bitmap_rep?.pixelsWide
            let data = bitmap_rep?.bitmapData
            
            if(height ?? 0 != req_height) {
                NSLog("Height != req_height.")
            }
            
            if(height ?? 0 != req_height) {
                NSLog("Height != req_height.")
            }
            
        
            NSLog("Cropped image: h=\(height) w=\(width)")
            
            let image_bytes = Array(UnsafeBufferPointer(start: data, count: (height ?? 0) * (bitmap_rep?.bytesPerRow ?? 0)))
            

            
            NSLog("Sending payload..")
            
            // Assuming you want to convert the image to an RGBA format
            let rawEncoding: UInt8 = 4

            if let rawData = nsImageToRawEncoding(image: bitmap_rep, rawEncoding: UInt8(4)) {
                // Use the rawData for further processing or transmission
                print("Conversion successful. Raw data size: \(rawData.count)")
            } else {
                print("Conversion failed.")
            }

            
            
            //try! socket.write(from: Data(bytes: sond, count: sond.count))
            */
            /*
            if let image = NSImage(contentsOfFile: filePath) {


                

                // Calculate the size of the data in bytes
                let dataSize = height * imageRep.bytesPerRow

                // Convert the UnsafeMutablePointer<UInt8> to an [UInt8] array
                let image_bytes = Array(UnsafeBufferPointer(start: data, count: dataSize))
                

                fbu.append(contentsOf: image_bytes)
                
                do {
                    print("SENDING")
                    try socket.write(from: Data(bytes: fbu, count: fbu.count))
                } catch {
                    print("\(error)")
                }
                
            }
            */

            break
            
        case CommandTypes.KeyEvent:
            let down_flag = (command[1] != 0)
            let key_sym = UInt32(command[4] | command[5] | command[6] | command[7])
            
            if down_flag {
                NSLog("Key released: \(key_sym)")
            } else {
                NSLog("Key pressed: \(key_sym)")
            }
            break
        
        case CommandTypes.PointerEvent:
            let button_mask = command[1]
            let x_position = UInt16(UInt16(command[2] << 8) + UInt16(command[3]))
            let y_position = UInt16(UInt16(command[4] << 8) +  UInt16(command[5]))
            
            NSLog("PointerEvent at x=\(x_position) y=\(y_position) button_mask=\(button_mask)")
            break
            
        default:
            NSLog("Unhandled type: \(String(describing: commands[command[0]])) -- Data: \(buffer)")
            break
        }
        
    } else {
        NSLog("Got unsupported message from Client..")
    }
    
}
