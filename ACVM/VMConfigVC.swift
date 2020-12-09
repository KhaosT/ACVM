//
//  ViewController.swift
//  ACVM
//
//  Created by Khaos Tian on 11/29/20.
//

import Cocoa

class VMConfigVC: NSViewController, FileDropViewDelegate {
    
    @IBOutlet weak var unhideMousePointer: NSButton!
    @IBOutlet weak var mainImage: FileDropView!
    @IBOutlet weak var cdImage: FileDropView!
    @IBOutlet weak var vmNameTextField: NSTextField!
    
    @IBOutlet weak var cpuTextField: NSTextField!
    @IBOutlet weak var ramTextField: NSTextField!
    @IBOutlet weak var nicOptionsTextField: NSTextField!
    
    @IBOutlet weak var graphicPopupButton: NSPopUpButton!
    
    private var mainImageURL: URL?
    private var cdImageURL: URL?
    
    @IBOutlet weak var actionButton: NSButton!
    @IBOutlet weak var cancelButton: NSButton!
    @IBOutlet weak var resetNVRAMButton: NSButton!
    
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
    
    var vmConfig: VmConfiguration = VmConfiguration(vmname: "", cores: 4, ram: 4096, mainImage: "", cdImage: "", unhideMousePointer: false, graphicOptions: "", nicOptions: "")
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if vmConfig.vmname != "" {
            loadConfigValues()
            resetNVRAMButton.isEnabled = true
        }
        
        mainImage.delegate = self
        cdImage.delegate = self
    }
    
    func loadConfigValues() {
        vmNameTextField.stringValue = vmConfig.vmname
                
        cpuTextField.stringValue = String(vmConfig.cores)
        ramTextField.stringValue = String(vmConfig.ram)
                
        let mainImageFilePath = vmConfig.mainImage
        if FileManager.default.fileExists(atPath: mainImageFilePath) {
            let contentURL = URL(fileURLWithPath: mainImageFilePath)
            mainImageURL = contentURL
            mainImage.contentURL = contentURL
        }
           
        let cdImageFilePath = vmConfig.cdImage
        if FileManager.default.fileExists(atPath: cdImageFilePath) {
            let contentURL = URL(fileURLWithPath: cdImageFilePath)
            cdImageURL = contentURL
            cdImage.contentURL = contentURL
        }
        
        if vmConfig.unhideMousePointer {
            unhideMousePointer.state = .on
        }
        else
        {
            unhideMousePointer.state = .off
        }
        
        graphicPopupButton.selectItem(withTitle: vmConfig.graphicOptions)
        nicOptionsTextField.stringValue = vmConfig.nicOptions
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
            let path = URL(fileURLWithPath: "/Users/kupan787/Virtual Machines/" + vmConfigName + ".plist")

            vmConfig.vmname = vmConfigName
            vmConfig.cores = Int(numberOfCores) ?? 4
            vmConfig.ram = (Int(ramSize) ?? 4)
            vmConfig.mainImage = mainImageURL?.path ?? ""
            vmConfig.cdImage = cdImageURL?.path ?? ""
            
            if unhideMousePointer.state == .off {
                vmConfig.unhideMousePointer = false
            }
            else
            {
                vmConfig.unhideMousePointer = true
            }
            
            vmConfig.graphicOptions = displayAdaptor
            vmConfig.nicOptions = nicOptions
            
            do {
                let data = try encoder.encode(vmConfig)
                try data.write(to: path)
            } catch {
                print(error)
            }
        }
        
        //self.view.window?.close()
        //let application = NSApplication.shared
        //application.stopModal()
        self.dismiss(self)
        
        NotificationCenter.default.post(name: Notification.Name(rawValue: "refreshVMList"), object: nil)
    }
    
    
    @IBAction func didTapCancelButton(_ sender: NSButton) {
        //self.view.window?.close()
        //let application = NSApplication.shared
        //application.stopModal()
        self.dismiss(self)
    }
    
    
    @IBAction func didTapResetNVRAMButton(_ sender: NSButton) {
        do {
            try FileManager.default.removeItem(atPath: vmConfig.mainImage + ".nvram")
            resetNVRAMButton.isEnabled = false
        }
        catch {
            
        }
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
            options += ",\(nicOptionsTextField.stringValue)"
        }
        
        return options
    }
    
    // MARK: - File Drop
    
    func fileDropView(_ view: FileDropView, didUpdate contentURL: URL) {
        switch view {
        case mainImage:
            mainImageURL = contentURL
        case cdImage:
            cdImageURL = contentURL
        default:
            break
        }
    }
}

