//
//  main.swift
//  VNCTest
//
//  Created by zimsneexh on 31.05.23.
//

import Foundation
import Socket
import Dispatch

var PROTOCOL_VERSION = "RFB 003.008\n"

class VNCServer {
    
    static let bufferSize = 8192
    
    let port: Int
    var listenSocket: Socket? = nil
    var continueRunningValue = true
    var connectedSockets = [Int32: Socket]()
    let socketLockQueue = DispatchQueue(label: "eu.zimsneexh.Velocity.socketLockQueue")
    var continueRunning: Bool {
        set(newValue) {
            socketLockQueue.sync {
                self.continueRunningValue = newValue
            }
        }
        get {
            return socketLockQueue.sync {
                self.continueRunningValue
            }
        }
    }

    init(port: Int) {
        self.port = port
    }
    
    deinit {
        // Close all open sockets...
        for socket in connectedSockets.values {
            socket.close()
        }
        self.listenSocket?.close()
    }
    
    func run() {
        
        let queue = DispatchQueue.global(qos: .userInteractive)
        
        queue.async { [unowned self] in
            
            do {
                try self.listenSocket = Socket.create(family: .inet)
                
                guard let socket = self.listenSocket else {
                    print("Unable to unwrap socket...")
                    return
                }
                
                try socket.listen(on: self.port)
                
                print("Listening on port: \(socket.listeningPort)")
                
                repeat {
                    let newSocket = try socket.acceptClientConnection()
                    
                    print("Accepted connection from: \(newSocket.remoteHostname) on port \(newSocket.remotePort)")
                    self.addNewConnection(socket: newSocket)
                    
                } while self.continueRunning
                
            }
            catch let error {
                
                guard let socketError = error as? Socket.Error else {
                    print("Unexpected error: \(error)")
                    return
                }
                
                if self.continueRunning {
                    print("Error reported:\n \(socketError.description)")
                }
                
            }
        }
        dispatchMain()
    }
    
    func addNewConnection(socket: Socket) {
        
        // Add the new socket to the list of connected sockets...
        socketLockQueue.sync { [unowned self, socket] in
            self.connectedSockets[socket.socketfd] = socket
        }
        
        // Get the global concurrent queue...
        let queue = DispatchQueue.global(qos: .default)
        
        // Create the run loop work item and dispatch to the default priority global queue...
        queue.async { [unowned self, socket] in
            
            var shouldKeepRunning = true
            var readData = Data(capacity: VNCServer.bufferSize)
            var pixel_format = PixelFormat()
            
            do {
                NSLog("Performing VNC handshake..")
                if try !vnc_handshake(socket: socket, buffer: &readData) {
                    NSLog("Handshake failed.")
                    shouldKeepRunning = false
                }
                
                repeat {
                    readData = Data(capacity: VNCServer.bufferSize)
                    let bytesRead = try socket.read(into: &readData)
                    
                                        
                    if bytesRead > 0 {
                        handle_event(pixelformat: &pixel_format, socket: socket, buffer: &readData)
                    }
                    
                    if bytesRead == 0 {
                        shouldKeepRunning = false
                        break
                    }
                    
                    readData.count = 0
                    
                } while shouldKeepRunning
                
                print("Socket: \(socket.remoteHostname):\(socket.remotePort) closed...")
                socket.close()
                
                self.socketLockQueue.sync { [unowned self, socket] in
                    self.connectedSockets[socket.socketfd] = nil
                }
                
            } catch let error {
                guard let socketError = error as? Socket.Error else {
                    print("Unexpected error by connection at \(socket.remoteHostname):\(socket.remotePort)...")
                    return
                }
                if self.continueRunning {
                    print("Error reported by connection at \(socket.remoteHostname):\(socket.remotePort):\n \(socketError.description)")
                }
            }
        }
        
        func vnc_handshake(socket: Socket, buffer: inout Data) throws -> Bool {
            
            // Write the protocol version we support (003.008)
            try socket.write(from: PROTOCOL_VERSION)
            
            // Read protocol version answer
            var bytes_read = try socket.read(into: &buffer)
            
            // Read bytes as answer, decode to String()
            if bytes_read > 0 {
                let response = String(data: buffer, encoding: .ascii)
                
                if(response != PROTOCOL_VERSION) {
                    return false;
                }
                
            } else {
                return false;
            }
            
            // clear buffer
            buffer = Data(capacity: VNCServer.bufferSize)
            
            // Send security types to the server
            struct SecurityTypes {
                var number_of_security_types: UInt8
                var security_types: [UInt8]
            }
            
            // Mark: we only support no security for now
            let security_types = SecurityTypes(number_of_security_types: 1, security_types: [1])
            
            // UInt8 (number of types) [UInt8] security_types -> byteArray
            var byte_array = [ security_types.number_of_security_types ]
            for sc in security_types.security_types {
                byte_array.append(sc)
            }
            
            // Write Struct as data
            try socket.write(from: Data(bytes: byte_array, count: byte_array.count))
            
            // Read answer from client
            bytes_read = try socket.read(into: &buffer)
            let code = Array.init(buffer)[0]
            
            // Check if the accepted security type exists
            if(security_types.security_types.contains(code)) {
                NSLog("Offered security type accepted by client.")
            } else {
                return false;
            }
            
            // clear buffer
            buffer = Data(capacity: VNCServer.bufferSize)
            
            // SecurityResult: Status -> OK
            let status_code: UInt32 = 0
            let packed_status = pack_uint32(toPack: status_code)
            try socket.write(from: Data(bytes: packed_status, count: packed_status.count))
            
            // ClientInit Message
            bytes_read = try socket.read(into: &buffer)
            
            //MARK: do we need to handle this?
            // Shared flag -> can the "Desktop" be used by multiple clients at the same time?
            let shared = Array.init(buffer)[0]
            
            NSLog("Desktop shared flag: \(shared)")
            buffer = Data(capacity: VNCServer.bufferSize)
            
            let serv_init_packed = ServerInit().pack()
            try socket.write(from: Data(bytes: serv_init_packed, count: serv_init_packed.count))
            
            NSLog("Server init sent!")
            NSLog("Handshake completed successfully.")
            
            // Clear out the buffer
            buffer = Data(capacity: VNCServer.bufferSize)
            return true;
        }
    }
    
    func shutdownServer() {
        print("\nShutdown in progress...")

        self.continueRunning = false
        
        // Close all open sockets...
        for socket in connectedSockets.values {
            
            self.socketLockQueue.sync { [unowned self, socket] in
                self.connectedSockets[socket.socketfd] = nil
                socket.close()
            }
        }
        
        DispatchQueue.main.sync {
            exit(0)
        }
    }
}

let port = 1337
let server = VNCServer(port: port)
print("Swift VNC Server")
server.run()
