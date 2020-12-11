//
//  WindowController.swift
//  ACVM
//
//  Created by Ben Mackin on 12/7/20.
//

import Foundation
import Cocoa

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
        
    }
    
    @IBAction func didTapStopButton(_ sender: NSToolbarItem) {
        virtMachine.process?.terminate()
        cleanUpProcessOnStop()
    }
    
    func cleanUpProcessOnStop() {
        virtMachine.process = nil
        virtMachine.state = 0
        
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
        
        if virtMachine.state == 0 {
            stopButton.action = nil
            startButton.action = #selector(didTapStartButton(_:))
            pauseButton.action = nil
            deleteButton.action = #selector(didTapDeleteVMButton(_:))
        } else if virtMachine.state == 1 {
            stopButton.action = #selector(didTapStopButton(_:))
            startButton.action = nil
            pauseButton.action = nil //#selector(didTapPauseButton(_:))
            deleteButton.action = nil
        } else if virtMachine.state == 2 {
            stopButton.action = #selector(didTapStopButton(_:))
            startButton.action = #selector(didTapStartButton(_:))
            pauseButton.action = nil
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
        
        let process = Process()
        process.executableURL = Bundle.main.url(
            forResource: "qemu-system-aarch64",
            withExtension: nil
        )
        
        var arguments: [String] = [
            "-M", "virt,highmem=no",
            "-accel", "hvf",
            "-cpu", "host",
            "-smp", String(virtMachine.config.cores),
            "-m", String(virtMachine.config.ram) + "M",
            "-bios", efiURL.path,
            "-device", virtMachine.config.graphicOptions,
            "-device", "qemu-xhci",
            "-device", "usb-kbd",
            "-device", "usb-tablet",
            "-nic", "user,model=virtio" + virtMachine.config.nicOptions,
            "-rtc", "base=localtime,clock=host",
            "-drive", "file=\(virtMachine.config.nvram),format=raw,if=pflash,index=1",
            "-device", "intel-hda",
            "-device", "hda-duplex"
        ]
        
        if virtMachine.config.mainImageUseVirtIO {
            arguments += [
                "-drive", "file=\(mainImage.path),if=virtio,id=boot,cache=writethrough",
            ]
        }
        else {
            arguments += [
                "-drive", "file=\(mainImage.path),if=none,id=boot,cache=writethrough",
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
        
        updateStates()

        do {
            try process.run()
        } catch {
            NSLog("Failed to run, error: \(error)")
        }
    }
}
