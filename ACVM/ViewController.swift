//
//  ViewController.swift
//  ACVM
//
//  Created by Khaos Tian on 11/29/20.
//

import Cocoa

class ViewController: NSViewController, FileDropViewDelegate {

    private var qemuProcess: Process?
    
    @IBOutlet weak var unhideMousePointer: NSButton!
    @IBOutlet weak var mainImage: FileDropView!
    @IBOutlet weak var cdImage: FileDropView!
    
    @IBOutlet weak var cpuTextField: NSTextField!
    @IBOutlet weak var ramTextField: NSTextField!

    @IBOutlet weak var graphicPopupButton: NSPopUpButton!
    
    private var mainImageURL: URL?
    private var cdImageURL: URL?
    
    @IBOutlet weak var actionButton: NSButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let mainImageFilePath = UserDefaults.standard.string(forKey: Constants.mainImageFilePath),
           FileManager.default.fileExists(atPath: mainImageFilePath) {
            let contentURL = URL(fileURLWithPath: mainImageFilePath)
            mainImageURL = contentURL
            mainImage.contentURL = contentURL
        }
        
        updateStates()
        
        mainImage.delegate = self
        cdImage.delegate = self
    }
    
    private func updateStates() {
        if mainImageURL != nil {
            actionButton.isEnabled = true
        } else {
            actionButton.isEnabled = false
        }
        
        if qemuProcess != nil {
            actionButton.title = "Stop"
            mainImage.isEnabled = false
            cdImage.isEnabled = false
            cpuTextField.isEnabled = false
            ramTextField.isEnabled = false
            unhideMousePointer.isEnabled = false;
            graphicPopupButton.isEnabled = false;
        } else {
            actionButton.title = "Start"
            mainImage.isEnabled = true
            cdImage.isEnabled = true
            cpuTextField.isEnabled = true
            ramTextField.isEnabled = true
            unhideMousePointer.isEnabled = true;
            graphicPopupButton.isEnabled = true;
        }
        
    }
    
    @IBAction func onGraphicChange(_ sender: Any) {
        if displayAdaptor == "ramfb"{
            unhideMousePointer.state = .off;
        } else {
            unhideMousePointer.state = .on;
        }
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
    
    @IBAction func didTapStartButton(_ sender: Any) {
        guard qemuProcess == nil else {
            qemuProcess?.terminate()
            qemuProcess = nil
            updateStates()
            return
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
            "-smp", numberOfCores,
            "-m", ramSize,
            "-bios", efiURL.path,
            "-device", displayAdaptor,
            "-device", "qemu-xhci",
            "-device", "usb-kbd",
            "-device", "usb-tablet",
            "-nic", "user,model=virtio",
            "-rtc", "base=localtime,clock=host",
            "-drive", "file=\(mainImage.path),if=none,id=boot,cache=writethrough",
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
        if unhideMousePointer.state == .on {
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
    
    // MARK: Machine Props
    
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
            return "4G"
        }
        
        return adjustedRamText
    }
    
    private var displayAdaptor: String {
        let adjustedDisplayText = graphicPopupButton.titleOfSelectedItem;
        guard adjustedDisplayText != nil else {
            return "ramfb"
        }
        
        return adjustedDisplayText!
    }
    
    func fileDropView(_ view: FileDropView, didUpdate contentURL: URL) {
        switch view {
        case mainImage:
            UserDefaults.standard.set(contentURL.path, forKey: Constants.mainImageFilePath)
            mainImageURL = contentURL
            updateStates()
        case cdImage:
            cdImageURL = contentURL
            updateStates()
        default:
            break
        }
    }
    
    private enum Constants {
        static let mainImageFilePath: String = "mainImageFilePath"
    }
}

