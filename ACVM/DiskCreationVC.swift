//
//  DiskCreationVC.swift
//  ACVM
//
//  Created by Ben Mackin on 12/9/20.
//

import Cocoa

class DiskCreationVC: NSViewController {
    
    
    @IBOutlet weak var diskSizeTextField: NSTextField!
    @IBOutlet weak var diskSizeButton: NSPopUpButton!
    @IBOutlet weak var diskLocationTextField: NSTextField!
    @IBOutlet weak var createButton: NSButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //self.view.window?.styleMask.remove(.resizable)

        self.preferredContentSize = NSMakeSize(self.view.frame.size.width, self.view.frame.size.height);
    }
    
    @IBAction func didTapChooseButton(_ sender: Any) {
        
        let savePanel = NSSavePanel()
        savePanel.allowedFileTypes = ["qcow2","raw"]
        savePanel.allowsOtherFileTypes = false
        savePanel.canCreateDirectories = true
        savePanel.canSelectHiddenExtension = false
        savePanel.isExtensionHidden = false
        savePanel.message = "Select location to save new disk image."
        savePanel.nameFieldStringValue = "NewDisk"
        
        savePanel.begin(completionHandler: { (result) in
                if result.rawValue == NSApplication.ModalResponse.OK.rawValue {
                    self.diskLocationTextField.stringValue = savePanel.url!.path
                    self.createButton.isEnabled = true
                }
            })
        
    }
    
    @IBAction func didTapCreateButton(_ sender: Any) {
        let qemuimg = Process()
        qemuimg.executableURL = Bundle.main.url(
            forResource: "qemu-img",
            withExtension: nil
        )
        
        let qi_arguments: [String] = [
            "create",
            "-f", diskSizeButton.titleOfSelectedItem!,
            "-o", "cluster_size=2M",
            diskLocationTextField.stringValue,
            diskSizeTextField.stringValue + "g"
        ]
        
        qemuimg.arguments = qi_arguments
        qemuimg.qualityOfService = .userInteractive

        do {
            try qemuimg.run()
        } catch {
            NSLog("Failed to run, error: \(error)")
        }
        
        self.view.window?.close()
        let application = NSApplication.shared
        application.stopModal()
    }
    
    @IBAction func didTapCancelButton(_ sender: Any) {
        self.view.window?.close()
        let application = NSApplication.shared
        application.stopModal()
    }
}

