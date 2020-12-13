//
//  AppDelegate.swift
//  ACVM
//
//  Created by Khaos Tian on 11/29/20.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    var vmList: [VirtualMachine]? = []
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
        
        for vm in vmList! {
            
            if vm.process != nil {
                vm.process?.terminate()
            }
            
        }
    }


}

