//
//  MainWC.swift
//  ACVM
//
//  Created by Ben Mackin on 12/7/20.
//

import Foundation
import Cocoa
import Network

class MainWC: NSWindowController {

    private var mainImageURL: URL?
    private var cdImageURL: URL?
    private var virtMachine: VirtualMachine = VirtualMachine()
    
    @IBOutlet weak var startButton: NSToolbarItem!
    @IBOutlet weak var stopButton: NSToolbarItem!
    @IBOutlet weak var pauseButton: NSToolbarItem!
    @IBOutlet weak var configButton: NSToolbarItem!
    @IBOutlet weak var deleteButton: NSToolbarItem!
    
    private var configButtonAction: Selector!
    
    @IBAction func didTapDeleteVMButton(_ sender: NSToolbarItem) {        
        let alert = NSAlert()
        alert.messageText = "Delete VM Configuration"
        alert.informativeText = "Are you sure you want to delete the VM Configuration " + virtMachine.config.vmname + "? Note that this will not remove any disk images. Those must be manually removed."
        
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        
        alert.beginSheetModal(for: self.window!) { (response) in
            if response == .alertFirstButtonReturn {
                do {
                    let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                    let directoryURL = appSupportURL.appendingPathComponent("com.oltica.ACVM")
                    
                    try FileManager.default.removeItem(atPath: directoryURL.path + "/" + self.virtMachine.config.vmname + ".plist")
                    try FileManager.default.removeItem(atPath: self.virtMachine.config.nvram)
                    
                    self.virtMachine.process = nil
                    self.virtMachine.state = 0
                    self.updateStates()
                    
                    NotificationCenter.default.post(name: Notification.Name(rawValue: "refreshVMList"), object: nil)
                    self.updateCurrentVMConfig()
                }
                catch {
                
                }
            }
        }
    }
    
    override func prepare (for segue: NSStoryboardSegue, sender: Any?)
    {
        let toolbarItem = sender as! NSToolbarItem
        
        if toolbarItem.label != "New" {
            if  let viewController = segue.destinationController as? VMConfigVC {
                viewController.virtMachine = virtMachine
            }
        }
    }
    
    @IBAction func didTapPauseButton(_ sender: NSToolbarItem) {
        virtMachine.client!.send(message: "{ \"execute\": \"stop\" }\r\n")
        virtMachine.state = 2
        updateStates()
    }
    
    @IBAction func didTapUnPauseButton(_ sender: NSToolbarItem) {
        virtMachine.client!.send(message: "{ \"execute\": \"cont\" }\r\n")
        virtMachine.state = 1
        updateStates()
    }
    
    @IBAction func didTapStopButton(_ sender: NSToolbarItem) {
        //virtMachine.process?.terminate()
        
        if virtMachine.state == 2 {
            virtMachine.client!.send(message: "{ \"execute\": \"cont\" }\r\n")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.virtMachine.client!.send(message: "{ \"execute\": \"system_powerdown\" }\r\n")
            }
        } else {
            virtMachine.client!.send(message: "{ \"execute\": \"system_powerdown\" }\r\n")
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.cleanUpProcessOnStop()
        }
    }
    
    func cleanUpProcessOnStop() {
        virtMachine.process = nil
        virtMachine.state = 0
        
        if virtMachine.client != nil {
            virtMachine.client!.close()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.virtMachine.client = nil
            }
        }

        virtMachine.config.cdImage = ""
        let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directoryURL = appSupportURL.appendingPathComponent("com.oltica.ACVM")
          
        do {
            try FileManager.default.createDirectory (at: directoryURL, withIntermediateDirectories: true, attributes: nil)
            let documentURL = directoryURL.appendingPathComponent (virtMachine.config.vmname + ".plist")
            let encoder = PropertyListEncoder()
            encoder.outputFormat = .xml
            
            let data = try encoder.encode(virtMachine.config)
            try data.write(to: documentURL)
        }
        catch {
            
        }
        
        updateStates()
    }
    
    func setupNotifications()
    {
        NotificationCenter.default.addObserver(forName: Notification.Name(rawValue: "vmConfigChange"), object: nil, queue: nil) { (notification) in self.updateCurrentVMConfig(notification as NSNotification) }
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        configButtonAction = configButton.action
        
        updateStates()
        setupNotifications()
        
        configButton.action = nil
        startButton.action = nil
        deleteButton.action = nil
        stopButton.action = nil
        pauseButton.action = nil
    }
    
    private func updateStates() {
        
        if virtMachine.state == 0 { // Stopped
            stopButton.action = nil
            startButton.action = #selector(didTapStartButton(_:))
            pauseButton.action = nil
            deleteButton.action = #selector(didTapDeleteVMButton(_:))
        } else if virtMachine.state == 1 { // Started
            stopButton.action = #selector(didTapStopButton(_:))
            startButton.action = nil
            pauseButton.action = #selector(didTapPauseButton(_:))
            deleteButton.action = nil
        } else if virtMachine.state == 2 { // Paused
            stopButton.action = #selector(didTapStopButton(_:))
            startButton.action = nil //#selector(didTapStartButton(_:))
            pauseButton.action = #selector(didTapUnPauseButton(_:))
            deleteButton.action = #selector(didTapDeleteVMButton(_:))
        }
        
        NotificationCenter.default.post(name: Notification.Name(rawValue: "qemuStatusChange"), object: virtMachine.state)
    }
    
    @objc
    private func processDidTerminate(_ notification: Notification) {
        guard let process = notification.object as? Process,
              process == virtMachine.process else {
            return
        }
        
        cleanUpProcessOnStop()
    }
    
    func updateCurrentVMConfig(_ notification: NSNotification) {
        configButton.action = nil
        startButton.action = nil
        deleteButton.action = nil
        stopButton.action = nil
        
        if let config = notification.userInfo?["config"] as? VirtualMachine {
            virtMachine = config
            configButton.action = configButtonAction
            updateStates()
        }
    }
    
    func updateCurrentVMConfig() {
        configButton.action = nil
        startButton.action = nil
        deleteButton.action = nil
        stopButton.action = nil
    }
    
    @IBAction func didTapStartButton(_ sender: Any) {
        
        guard virtMachine.process == nil else {
            virtMachine.process?.terminate()
            cleanUpProcessOnStop()
            return
        }
        
        // read in config
        let mainImageFilePath = virtMachine.config.mainImage
        if FileManager.default.fileExists(atPath: mainImageFilePath) {
            let contentURL = URL(fileURLWithPath: mainImageFilePath)
            mainImageURL = contentURL
        }
        
        let cdImageFilePath = virtMachine.config.cdImage
        if FileManager.default.fileExists(atPath: cdImageFilePath) {
            let contentURL = URL(fileURLWithPath: cdImageFilePath)
            cdImageURL = contentURL
        }
        
        guard let efiURL = Bundle.main.url(forResource: "QEMU_EFI", withExtension: "fd"),
              let mainImage = mainImageURL else {
            return
        }
        
        var icon = NSImage()
        icon = NSImage(named: "qemu")!
        
        let qemu = NSWorkspace()
        qemu.setIcon(icon, forFile: Bundle.main.url(
            forResource: "qemu-system-aarch64",
            withExtension: nil
        )!.path)
        
        let process = Process()
        process.executableURL = Bundle.main.url(
            forResource: "qemu-system-aarch64",
            withExtension: nil
        )
        
        let port = Int.random(in: 60000...65000)
        
        var arguments: [String] = [
            "-M", "virt,highmem=no",
            "-accel", "hvf",
            "-cpu", "host",
            "-name", virtMachine.config.vmname,
            "-smp", "cpus=" + String(virtMachine.config.cores) + ",sockets=1,cores=" + String(virtMachine.config.cores) + ",threads=1",
            "-m", String(virtMachine.config.ram) + "M",
            "-bios", efiURL.path,
            "-device", virtMachine.config.graphicOptions,
            "-device", "qemu-xhci",
            "-device", "usb-kbd",
            "-device", "usb-tablet",
            "-device", "usb-mouse",
            "-device", "usb-kbd",
            "-nic", "user,model=virtio" + virtMachine.config.nicOptions,
            "-rtc", "base=localtime,clock=host",
            "-drive", "file=\(virtMachine.config.nvram),format=raw,if=pflash,index=1",
            "-device", "intel-hda",
            "-device", "hda-duplex",
            "-chardev", "socket,id=mon0,host=localhost,port=\(port),server,nowait",
            "-mon", "chardev=mon0,mode=control,pretty=on"
        ]
        
        var useCace = "directsync"
        if virtMachine.config.mainImageUseWTCache {
            useCace = "writethrough"
        }
        
        if virtMachine.config.mainImageUseVirtIO {
            arguments += [
                "-drive", "file=\(mainImage.path),if=virtio,id=boot,cache=\(useCace)",
            ]
        }
        else {
            arguments += [
                "-drive", "file=\(mainImage.path),if=none,id=boot,cache=\(useCace)",
                "-device", "nvme,drive=boot,serial=boot"
            ]
        }
        
        if let cdImageURL = cdImageURL {
            arguments += [
                "-drive", "file=\(cdImageURL.path),media=cdrom,if=none,id=cdimage",
                "-device", "usb-storage,drive=cdimage"
            ]
        }
        
        if virtMachine.config.unhideMousePointer {
            arguments += [
                "-display","cocoa,show-cursor=on"
            ]
        }
        
        if 1==0 {
            arguments += [
                "-usb",
                //"-device", "usb-host,hostbus=0,hostaddr=1"
                // hostaddr=1 doesn't show anything in linux
                // hostaddr=0 shows a record in lsusb
                "-device", "usb-host,vendorid=0x0781,productid=0x5581"
            ]
        }
        
        process.arguments = arguments
        process.qualityOfService = .userInteractive
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(processDidTerminate(_:)),
            name: Process.didTerminateNotification,
            object: process
        )

        virtMachine.process = process
        virtMachine.state = 1
        
        do {
            try process.run()
            
            while !process.isRunning {
            
            }
            
            let client = TCPClient()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                client.setupNetworkCommunication(UInt32(port))
                client.initQMPConnection()
                self.virtMachine.client = client
            }
            
        } catch {
            NSLog("Failed to run, error: \(error)")
            
            virtMachine.process = nil
            virtMachine.state = 0
        }
        
        updateStates()
    }
}
