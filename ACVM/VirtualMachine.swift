//
//  VirtualMachine.swift
//  ACVM
//
//  Created by Ben Mackin on 12/9/20.
//

import Foundation

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
}

class VirtualMachine {
        
    var config:VmConfiguration = VmConfiguration()
    
    var process:Process?
    var state:Int = 0
}
