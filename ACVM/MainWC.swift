//
//  WindowController.swift
//  ACVM
//
//  Created by Ben Mackin on 12/7/20.
//

import Foundation
import Cocoa

class MainWC: NSWindowController {

    private var qemuProcess: Process?
    private var mainImageURL: URL?
    private var cdImageURL: URL?
    private var vmConfig: VmConfiguration?
    
    struct VmConfiguration: Codable {
        var vmname:String
        var cores:Int
        var ram:Int
        var mainImage:String
        var cdImage:String
        var unhideMousePointer:Bool
        var graphicOptions:String
        var nicOptions:String
    }
    
    @IBOutlet weak var startButton: NSToolbarItem!
    @IBOutlet weak var stopButton: NSToolbarItem!
    @IBOutlet weak var pauseButton: NSToolbarItem!
    @IBOutlet weak var configButton: NSToolbarItem!
    @IBOutlet weak var deleteButton: NSToolbarItem!
    
    private var configButtonAction: Selector!
    
    @IBAction func didTapDeleteVMButton(_ sender: NSToolbarItem) {
        print("Delete VM")
        
        let alert = NSAlert()
        alert.messageText = "Delete VM Configuration"
        alert.informativeText = "Are you sure you want to delete the VM Configuration " + vmConfig!.vmname + "? Note that this will not remove any disk images. Those must be manually removed."
        
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        
        alert.beginSheetModal(for: self.window!) { (response) in
            if response == .alertFirstButtonReturn {
                do {
                    try FileManager.default.removeItem(atPath: "/Users/kupan787/Virtual Machines/" + self.vmConfig!.vmname + ".plist")
                    
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
                viewController.vmConfig = VMConfigVC.VmConfiguration(vmname: vmConfig!.vmname, cores: vmConfig!.cores, ram: vmConfig!.ram, mainImage: vmConfig!.mainImage, cdImage: vmConfig!.cdImage, unhideMousePointer: vmConfig!.unhideMousePointer, graphicOptions: vmConfig!.graphicOptions, nicOptions: vmConfig!.nicOptions)
            }
        }
    }
    
    @IBAction func didTapPauseButton(_ sender: NSToolbarItem) {
        print("Pause VM")
    }
    
    @IBAction func didTapStopButton(_ sender: NSToolbarItem) {
        print("Stop VM")
        
        qemuProcess?.terminate()
        qemuProcess = nil
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
        
        if qemuProcess != nil {
            stopButton.action = #selector(didTapStopButton(_:))
            startButton.action = nil
            pauseButton.action = #selector(didTapPauseButton(_:))
            deleteButton.action = nil
        } else {
            stopButton.action = nil
            startButton.action = #selector(didTapStartButton(_:))
            pauseButton.action = nil
            deleteButton.action = #selector(didTapDeleteVMButton(_:))
        }
        
        NotificationCenter.default.post(name: Notification.Name(rawValue: "qemuStatusChange"), object: qemuProcess)
    }
    
    @objc
    private func processDidTerminate(_ notification: Notification) {
        guard let process = notification.object as? Process,
              process == qemuProcess else {
            return
        }
        
        qemuProcess = nil
        updateStates()
    }
    
    func updateCurrentVMConfig(_ notification: NSNotification) {
        configButton.action = nil
        startButton.action = nil
        deleteButton.action = nil
        stopButton.action = nil
        
        if let config = notification.userInfo?["config"] as? MainVC.VmConfiguration {
            vmConfig = VmConfiguration(vmname: config.vmname, cores: config.cores, ram: config.ram, mainImage: config.mainImage, cdImage: config.cdImage, unhideMousePointer: config.unhideMousePointer, graphicOptions: config.graphicOptions, nicOptions: config.nicOptions)
            
            configButton.action = configButtonAction //#selector(didTapConfigureVMButton(_:))
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
        
        guard qemuProcess == nil else {
            qemuProcess?.terminate()
            qemuProcess = nil
            updateStates()
            return
        }
        
        // read in config
        if let mainImageFilePath = vmConfig?.mainImage,
           FileManager.default.fileExists(atPath: mainImageFilePath) {
            let contentURL = URL(fileURLWithPath: mainImageFilePath)
            mainImageURL = contentURL
        }
        
        if let cdImageFilePath = vmConfig?.cdImage,
           FileManager.default.fileExists(atPath: cdImageFilePath) {
            let contentURL = URL(fileURLWithPath: cdImageFilePath)
            cdImageURL = contentURL
        }
        
        guard let efiURL = Bundle.main.url(forResource: "QEMU_EFI", withExtension: "fd"),
              let mainImage = mainImageURL else {
            return
        }
        
        let url = URL(fileURLWithPath: mainImage.path + ".nvram")
        
        if !FileManager.default.fileExists(atPath: url.path) {
            let qemuimg = Process()
            qemuimg.executableURL = Bundle.main.url(
                forResource: "qemu-img",
                withExtension: nil
            )
            
            let qi_arguments: [String] = [
                "create", "-f",
                "raw", url.path,
                "67108864"
            ]
            
            qemuimg.arguments = qi_arguments
            qemuimg.qualityOfService = .userInteractive

            do {
                try qemuimg.run()
            } catch {
                NSLog("Failed to run, error: \(error)")
            }
        }
        
        /*if 1 == 0 {
            let qemuimg = Process()
            qemuimg.executableURL = Bundle.main.url(
                forResource: "qemu-img",
                withExtension: nil
            )
            
            let qi_arguments: [String] = [
                "create",
                "-f", "qcow2",
                "-o", "cluster_size=2M",
                "/Users/kupan787/Virtual Machines/10g.img", "10g"
            ]
            
            qemuimg.arguments = qi_arguments
            qemuimg.qualityOfService = .userInteractive

            do {
                try qemuimg.run()
            } catch {
                NSLog("Failed to run, error: \(error)")
            }
        }*/
        
        let process = Process()
        process.executableURL = Bundle.main.url(
            forResource: "qemu-system-aarch64",
            withExtension: nil
        )
        
        var arguments: [String] = [
            "-M", "virt,highmem=no",
            "-accel", "hvf",
            "-cpu", "host",
            "-smp", String(vmConfig!.cores),
            "-m", String(vmConfig!.ram) + "M",
            "-bios", efiURL.path,
            "-device", vmConfig!.graphicOptions,
            "-device", "qemu-xhci",
            "-device", "usb-kbd",
            "-device", "usb-tablet",
            "-nic", "user,model=virtio" + vmConfig!.nicOptions,
            "-rtc", "base=localtime,clock=host",
            "-drive", "file=\(mainImage.path),if=none,id=boot,cache=writethrough",
            //"-drive", "file=\(mainImage.path),if=virtio,id=boot,cache=writethrough", // Needed for Linux
            "-drive", "file=\(mainImage.path).nvram,format=raw,if=pflash,index=1",
            "-device", "nvme,drive=boot,serial=boot",
            "-device", "intel-hda",
            "-device", "hda-duplex"
        ]
        
        if let cdImageURL = cdImageURL {
            arguments += [
                "-drive", "file=\(cdImageURL.path),media=cdrom,if=none,id=cdimage",
                "-device", "usb-storage,drive=cdimage"
            ]
        }
        
        if vmConfig!.unhideMousePointer {
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

        qemuProcess = process
        
        updateStates()

        do {
            try process.run()
        } catch {
            NSLog("Failed to run, error: \(error)")
        }
    }
}
