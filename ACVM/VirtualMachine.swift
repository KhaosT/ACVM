//
//  VirtualMachine.swift
//  ACVM
//
//  Created by Ben Mackin on 12/9/20.
//

import Foundation
import Cocoa

struct VmConfiguration: Codable {
    var vmname:String = ""
    var cores:Int = 4
    var ram:Int = 4096
    var mainImage:String = ""
    var cdImage:String = ""
    var unhideMousePointer:Bool = false
    var graphicOptions:String = ""
    var nicOptions:String = ""
    var nvram:String = ""
    var mainImageUseVirtIO:Bool = false
    var mainImageUseWTCache:Bool = true
    
    enum CodingKeys: String, CodingKey {
        case vmname = "vmname"
        case cores = "cores"
        case ram = "ram"
        case mainImage = "mainImage"
        case cdImage = "cdImage"
        case unhideMousePointer = "unhideMousePointer"
        case graphicOptions = "graphicOptions"
        case nicOptions = "nicOptions"
        case nvram = "nvram"
        case mainImageUseVirtIO = "mainImageUseVirtIO"
        case mainImageUseWTCache = "mainImageUseWTCache"
    }
    
    init() {
        
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        vmname = try values.decodeIfPresent(String.self, forKey: .vmname) ?? ""
        cores = try values.decodeIfPresent(Int.self, forKey: .cores) ?? 4
        ram = try values.decodeIfPresent(Int.self, forKey: .ram) ?? 4096
        mainImage = try values.decodeIfPresent(String.self, forKey: .mainImage) ?? ""
        cdImage = try values.decodeIfPresent(String.self, forKey: .cdImage) ?? ""
        unhideMousePointer = try values.decodeIfPresent(Bool.self, forKey: .unhideMousePointer) ?? false
        graphicOptions = try values.decodeIfPresent(String.self, forKey: .graphicOptions) ?? ""
        nicOptions = try values.decodeIfPresent(String.self, forKey: .nicOptions) ?? ""
        nvram = try values.decodeIfPresent(String.self, forKey: .nvram) ?? ""
        mainImageUseVirtIO = try values.decodeIfPresent(Bool.self, forKey: .mainImageUseVirtIO) ?? false
        mainImageUseWTCache = try values.decodeIfPresent(Bool.self, forKey: .mainImageUseWTCache) ?? true
    }
}

class VirtualMachine {
        
    var config:VmConfiguration = VmConfiguration()
    
    var process:Process?
    var client:TCPClient?
    var state:Int = 0
    var liveImage:NSImage?
}
