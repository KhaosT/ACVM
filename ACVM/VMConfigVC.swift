//
//  ViewController.swift
//  ACVM
//
//  Created by Khaos Tian on 11/29/20.
//

import Cocoa

class VMConfigVC: NSViewController, FileDropViewDelegate {
    
    @IBOutlet weak var tabView: NSTabView!
    
    @IBOutlet weak var cpuTabButton: NSButton!
    @IBOutlet weak var disksTabButton: NSButton!
    @IBOutlet weak var networkTabButton: NSButton!
    
    @IBOutlet weak var actionButton: NSButton!
    @IBOutlet weak var cancelButton: NSButton!
    @IBOutlet weak var resetNVRAMButton: NSButton!
    
    @IBOutlet weak var vmNameTextField: NSTextField!
    @IBOutlet weak var vmNameAlertTextField: NSTextField!
    
    // CPU Pane
    @IBOutlet weak var cpuTextField: NSTextField!
    @IBOutlet weak var ramTextField: NSTextField!
    @IBOutlet weak var graphicPopupButton: NSPopUpButton!
    @IBOutlet weak var unhideMousePointer: NSButton!
    
    // Disk Pane
    @IBOutlet weak var mainImage: FileDropView!
    @IBOutlet weak var useVirtIOForDisk: NSButton!
    @IBOutlet weak var enableWriteThroughCache: NSButton!
    
    @IBOutlet weak var cdImage: FileDropView!
    @IBOutlet weak var mountCDImage: NSButtonCell!
    @IBOutlet weak var removeCDButton: NSButton!
    
    // Network Pane
    @IBOutlet weak var nicOptionsTextField: NSTextField!
    
    var virtMachine:VirtualMachine = VirtualMachine()
    
    // MARK: Navigation Buttons
    
    @IBAction func didTabCPUButton(_ sender: NSButton) {
        cpuTabButton.isBordered = true
        disksTabButton.isBordered = false
        networkTabButton.isBordered = false
        
        tabView.selectTabViewItem(at: 0)
        self.preferredContentSize = NSSize(width: 456, height: 438)

        //view.window?.setFrame(NSRect(x: 0, y: 0, width: 456, height: 438), display: true, animate: true)
    }
    
    @IBAction func didTapDiskButton(_ sender: NSButton) {
        cpuTabButton.isBordered = false
        disksTabButton.isBordered = true
        networkTabButton.isBordered = false
        
        tabView.selectTabViewItem(at: 1)
        self.preferredContentSize = NSSize(width: 456, height: 438)

        //view.window?.setFrame(NSRect(x: 0, y: 0, width: 456, height: 438), display: true, animate: true)
    }
    
    @IBAction func didTapNetworkButton(_ sender: NSButton) {
        cpuTabButton.isBordered = false
        disksTabButton.isBordered = false
        networkTabButton.isBordered = true
        
        tabView.selectTabViewItem(at: 2)
        self.preferredContentSize = NSSize(width: 456, height: 300)
        
        //view.window?.setFrame(NSRect(x: 0, y: 0, width: 456, height: 300), display: true, animate: true)
    }
    
    // MARK: Remainder of Class
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        vmNameTextField.isEditable = true
        
        if virtMachine.config.vmname != "" {
            loadConfigValues()
            
            if FileManager.default.fileExists(atPath: virtMachine.config.nvram) {
                resetNVRAMButton.isEnabled = true
            }
            
            vmNameTextField.isEditable = false
            
            if virtMachine.config.mainImage != "" {
                mainImage.toolTip = URL(fileURLWithPath: virtMachine.config.mainImage).lastPathComponent
            }
            
            if virtMachine.config.cdImage != "" {
                cdImage.toolTip = URL(fileURLWithPath: virtMachine.config.cdImage).lastPathComponent
            }
        }
        
        mainImage.delegate = self
        cdImage.delegate = self
        
        self.preferredContentSize = NSSize(width: 456, height: 438)
    }
    
    func loadConfigValues() {
        vmNameTextField.stringValue = virtMachine.config.vmname
                
        cpuTextField.stringValue = String(virtMachine.config.cores)
        ramTextField.stringValue = String(virtMachine.config.ram)
                
        let mainImageFilePath = virtMachine.config.mainImage
        if FileManager.default.fileExists(atPath: mainImageFilePath) {
            let contentURL = URL(fileURLWithPath: mainImageFilePath)
            mainImage.contentURL = contentURL
        }
           
        let cdImageFilePath = virtMachine.config.cdImage
        if FileManager.default.fileExists(atPath: cdImageFilePath) {
            let contentURL = URL(fileURLWithPath: cdImageFilePath)
            cdImage.contentURL = contentURL
            removeCDButton.isEnabled = true
            mountCDImage.isEnabled = true
        }
        
        if virtMachine.config.unhideMousePointer {
            unhideMousePointer.state = .on
        }
        else
        {
            unhideMousePointer.state = .off
        }
        
        if virtMachine.config.mainImageUseVirtIO {
            useVirtIOForDisk.state = .on
        }
        else
        {
            useVirtIOForDisk.state = .off
        }
        
        if virtMachine.config.mainImageUseWTCache {
            enableWriteThroughCache.state = .on
        }
        else
        {
            enableWriteThroughCache.state = .off
        }
        
        if virtMachine.config.mountCDImage {
            mountCDImage.state = .on
        }
        else
        {
            mountCDImage.state = .off
        }
        
        graphicPopupButton.selectItem(withTitle: virtMachine.config.graphicOptions)
        nicOptionsTextField.stringValue = virtMachine.config.nicOptions
    }
    
    @IBAction func onGraphicChange(_ sender: Any) {
        if displayAdaptor == "ramfb"{
            unhideMousePointer.state = .off;
        } else {
            unhideMousePointer.state = .on;
        }
    }
    
    @IBAction func didTapSaveButton(_ sender: NSButton) {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        
        if vmConfigName != ""
        {            
            let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let directoryURL = appSupportURL.appendingPathComponent("com.oltica.ACVM")
              
            do {
                try FileManager.default.createDirectory (at: directoryURL, withIntermediateDirectories: true, attributes: nil)
                let documentURL = directoryURL.appendingPathComponent (vmConfigName + ".plist")
                
                if virtMachine.config.vmname == "" &&
                    FileManager.default.fileExists(atPath: documentURL.path) {
                    vmNameAlertTextField.stringValue = "That name is already in use, please try another."
                    vmNameAlertTextField.isHidden = false
                    return
                }
                
                virtMachine.config.vmname = vmConfigName
                virtMachine.config.cores = Int(numberOfCores) ?? 4
                virtMachine.config.ram = (Int(ramSize) ?? 4096)
                virtMachine.config.mainImage = mainImage.contentURL?.path ?? ""
                virtMachine.config.cdImage = cdImage.contentURL?.path ?? ""
                
                if unhideMousePointer.state == .off {
                    virtMachine.config.unhideMousePointer = false
                }
                else
                {
                    virtMachine.config.unhideMousePointer = true
                }
                
                if useVirtIOForDisk.state == .off {
                    virtMachine.config.mainImageUseVirtIO = false
                }
                else
                {
                    virtMachine.config.mainImageUseVirtIO = true
                }
                
                if enableWriteThroughCache.state == .off {
                    virtMachine.config.mainImageUseWTCache = false
                }
                else
                {
                    virtMachine.config.mainImageUseWTCache = true
                }
                
                if mountCDImage.state == .off {
                    virtMachine.config.mountCDImage = false
                }
                else
                {
                    virtMachine.config.mountCDImage = true
                }
                
                virtMachine.config.graphicOptions = displayAdaptor
                virtMachine.config.nicOptions = nicOptions
                
                if !FileManager.default.fileExists(atPath: virtMachine.config.nvram) {
                    let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                    let directoryURL = appSupportURL.appendingPathComponent("com.oltica.ACVM")
                    let documentURL = directoryURL.appendingPathComponent (virtMachine.config.vmname + ".nvram")
                    
                    virtMachine.config.nvram = documentURL.path
                    
                    let qemuimg = Process()
                    qemuimg.executableURL = Bundle.main.url(
                        forResource: "qemu-img",
                        withExtension: nil
                    )
                    
                    let qi_arguments: [String] = [
                        "create", "-f",
                        "raw", virtMachine.config.nvram,
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
                
                let data = try encoder.encode(virtMachine.config)
                try data.write(to: documentURL)
                
                vmNameAlertTextField.isHidden = true
                
                //self.view.window?.close()
                //let application = NSApplication.shared
                //application.stopModal()
                self.dismiss(self)
                
                NotificationCenter.default.post(name: Notification.Name(rawValue: "refreshVMList"), object: nil)
            }
            catch {
                print(error)
            }
        }
        else
        {
            vmNameAlertTextField.stringValue = "Please enter a VMName to save the configuration."
            vmNameAlertTextField.isHidden = false
        }
    }
    
    
    @IBAction func didTapCancelButton(_ sender: NSButton) {
        //self.view.window?.close()
        //let application = NSApplication.shared
        //application.stopModal()
        self.dismiss(self)
    }
    
    
    @IBAction func didTapResetNVRAMButton(_ sender: NSButton) {
        do {
            try FileManager.default.removeItem(atPath: virtMachine.config.nvram)
            resetNVRAMButton.isEnabled = false
        }
        catch {
            
        }
    }
    
    @IBAction func didTapRemoveButton(_ sender: Any) {
        cdImage.contentURL = nil
        //virtMachine.config.cdImage = ""
        removeCDButton.isEnabled = false
        mountCDImage.state = .off
        mountCDImage.isEnabled = false
    }
    
    
    // MARK: Machine Props
    
    private var vmConfigName: String {
        let vmname = vmNameTextField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !vmname.isEmpty else {
            return ""
        }
        
        return vmname
    }
    
    private var numberOfCores: String {
        guard let numOfCores = Int(cpuTextField.stringValue),
              numOfCores > 0 else {
            return "4"
        }
        
        return "\(numOfCores)"
    }
    
    private var ramSize: String {
        let adjustedRamText = ramTextField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !adjustedRamText.isEmpty else {
            return "4096"
        }
        
        return adjustedRamText
    }
    
    private var displayAdaptor: String {
        guard let adjustedDisplayText = graphicPopupButton.titleOfSelectedItem else {
            return "ramfb"
        }
        return adjustedDisplayText
    }
    
    private var nicOptions: String {
        var options = ""
        
        if !nicOptionsTextField.stringValue.isEmpty {
            options = nicOptionsTextField.stringValue
        }
        
        return options
    }
    
    // MARK: - File Drop
    
    func fileDropView(_ view: FileDropView, didUpdate contentURL: URL) {
        switch view {
        case mainImage:
            mainImage.contentURL = contentURL
        case cdImage:
            cdImage.contentURL = contentURL
            removeCDButton.isEnabled = true
            mountCDImage.isEnabled = true
        default:
            break
        }
    }
}

