//
//  TCPClient.swift
//  ACVM
//
//  Created by Ben Mackin on 12/11/20.
//

import Foundation

protocol TCPClientDelegate: class {
    func received(message: Message)
}

class TCPClient: NSObject {
    var inputStream: InputStream!
    var outputStream: OutputStream!

    weak var delegate: TCPClientDelegate?
    
    func setupNetworkCommunication(_ port: UInt32) {
        var readStream: Unmanaged<CFReadStream>?
        var writeStream: Unmanaged<CFWriteStream>?
        
        CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault,
                                           "localhost" as CFString,
                                           port,
                                           &readStream,
                                           &writeStream)
        
        inputStream = readStream!.takeRetainedValue()
        outputStream = writeStream!.takeRetainedValue()
        
        inputStream.delegate = self
        
        inputStream.schedule(in: .current, forMode: .common)
        outputStream.schedule(in: .current, forMode: .common)
        
        inputStream.open()
        outputStream.open()
    }

    func initQMPConnection() {
        let data = "{ \"execute\": \"qmp_capabilities\" }\r\n".data(using: .utf8)!
        
        data.withUnsafeBytes {
            guard let pointer = $0.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                print("Error joining qmp")
                return
            }
            
            outputStream.write(pointer, maxLength: data.count)
        }
    }
    
    func send(message: String) {
        let data = "\(message)".data(using: .utf8)!
        
        data.withUnsafeBytes {
            guard let pointer = $0.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                print("Error joining qmp")
                return
            }
            
            outputStream.write(pointer, maxLength: data.count)
        }
    }
    
    func close() {
      inputStream.close()
      outputStream.close()
    }
}

extension TCPClient: StreamDelegate {
    
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch eventCode {
        case .hasBytesAvailable:
            print("new message received")
            readAvailableBytes(stream: aStream as! InputStream)
        case .endEncountered:
            print("end of connection")
            close()
        case .errorOccurred:
            print("error occurred")
        case .hasSpaceAvailable:
            print("has space available")
        default:
            print("some other event...")
        }
    }

    private func readAvailableBytes(stream: InputStream) {
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 4096)
        while stream.hasBytesAvailable {
            let numberOfBytesRead = inputStream.read(buffer, maxLength: 4096)
            
            if numberOfBytesRead < 0, let error = stream.streamError {
                print(error)
                break
            }
            
            if let message = processedMessageString(buffer: buffer, length: numberOfBytesRead) {
                delegate?.received(message: message)
            }
        }
    }
    
    private func processedMessageString(buffer: UnsafeMutablePointer<UInt8>, length: Int) -> Message? {
        guard
            let stringArray = String(
                bytesNoCopy: buffer,
                length: length,
                encoding: .utf8,
                freeWhenDone: true)?.components(separatedBy: "~9999~"),
            let message = stringArray.last
        else {
            return nil
        }
        
        return Message(message: message)
    }
}

struct Message {
    let message: String
    
    init(message: String) {
        self.message = message
    }
}
