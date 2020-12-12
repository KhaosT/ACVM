//
//  ViewController.swift
//  ACVM
//
//  Created by Khaos Tian on 11/29/20.
//

import Cocoa

class MainVC: NSViewController {
    
    @IBOutlet weak var vmNameTextField: NSTextField!
    @IBOutlet weak var vmStateTextField: NSTextField!
    @IBOutlet weak var vmCoresTextField: NSTextField!
    @IBOutlet weak var vmRAMTextField: NSTextField!
    
    @IBOutlet weak var vmConfigTableView: NSTableView!
    
    var vmList: [VirtualMachine]? = []
    
    func setupNotifications()
    {
        NotificationCenter.default.addObserver(forName: Notification.Name(rawValue: "qemuStatusChange"), object: nil, queue: nil) { (notification) in self.updateVMStateTextField(notification as NSNotification) }
        
        NotificationCenter.default.addObserver(forName: Notification.Name(rawValue: "refreshVMList"), object: nil, queue: nil) { (notification) in self.refreshVMList() }
    }
    
    func updateVMStateTextField(_ notification: NSNotification) {
        
        let state = (notification.object) as! Int
        
        switch state {
        case 0:
            vmStateTextField.stringValue = "Stopped"
        case 1:
            vmStateTextField.stringValue = "Started"
        case 2:
            vmStateTextField.stringValue = "Paused"
        default:
            vmStateTextField.stringValue = ""
        }
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        vmConfigTableView.delegate = self
        vmConfigTableView.dataSource = self
        vmConfigTableView.target = self
        vmConfigTableView.doubleAction = #selector(tableViewDoubleClick(_:))
        
        setupNotifications()
                    
        reloadFileList()
    }
    
    func findAllVMConfigs() -> Bool {
        var retVal = false
        let fm = FileManager.default
        let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directoryURL = appSupportURL.appendingPathComponent("com.oltica.ACVM")
        
        do {
            let items = try fm.contentsOfDirectory(atPath: directoryURL.path)

            for item in items {
                if item.hasSuffix("plist") {
                    if let xml = FileManager.default.contents(atPath: directoryURL.path + "/" + item.description) {
                        let vmConfig = try! PropertyListDecoder().decode(VmConfiguration.self, from: xml)
                        let vm = VirtualMachine()
                        vm.config = vmConfig
                        
                        if vmList!.contains(where: { element in element.config.vmname == vm.config.vmname }) {
                            // Item exists
                        } else {
                            vmList!.append(vm)
                            retVal = true
                        }
                    }
                }
            }
                
            let numOfVMs = vmList?.count
            
            vmList!.removeAll(where: { element in
                if !FileManager.default.fileExists(atPath: directoryURL.path + "/" + element.config.vmname + ".plist") {
                    return true
                }
                else {
                    return false
                }
            })
            
            if numOfVMs != vmList?.count {
                retVal = true
            }
            
        } catch {
            // failed to read directory – bad permissions, perhaps?
        }
        
        vmList?.sort {
            $0.config.vmname.uppercased() < $1.config.vmname.uppercased()
        }
        
        return retVal
    }
    
    func populateVMAttributes(_ vm: VirtualMachine) {
        let vmConfig = vm.config
        
        vmNameTextField.stringValue = vmConfig.vmname
        
        if vmConfig.cores != 0 {
            vmCoresTextField.stringValue = String(vmConfig.cores)
        }
        
        if vmConfig.ram != 0 {
            vmRAMTextField.stringValue = String(vmConfig.ram) + " MB"
        }
        
        switch vm.state {
        case 0:
            vmStateTextField.stringValue = "Stopped"
        case 1:
            vmStateTextField.stringValue = "Started"
        case 2:
            vmStateTextField.stringValue = "Paused"
        default:
            vmStateTextField.stringValue = ""
        }
        
    }
    
    func refreshVMList() {
        vmNameTextField.stringValue = ""
        vmCoresTextField.stringValue = ""
        vmRAMTextField.stringValue = ""
        vmStateTextField.stringValue = ""
        
        reloadFileList()
    }
    
    func reloadFileList() {
        let curRow = vmConfigTableView.selectedRow
        let rowsAddedOrRemove = findAllVMConfigs()
        vmConfigTableView.reloadData()
        
        if rowsAddedOrRemove {
            vmConfigTableView.selectRow(at: -1)
        } else {
            vmConfigTableView.selectRow(at: curRow)
        }
    }

    @objc func tableViewDoubleClick(_ sender:AnyObject) {
        guard vmConfigTableView.selectedRow >= 0,
              let item = vmList?[vmConfigTableView.selectedRow] else {
            return
        }
        
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateController(withIdentifier: "vmconfig") as! VMConfigVC
        vc.virtMachine = item
        self.presentAsSheet(vc)
        
    }
    
    override func prepare (for segue: NSStoryboardSegue, sender: Any?)
    {
        if  let viewController = segue.destinationController as? VMConfigVC {
            viewController.virtMachine = (vmList?[vmConfigTableView.selectedRow])!
        }
    }
    
}

extension NSTableView {
    func selectRow(at index: Int) {
        selectRowIndexes(.init(integer: index), byExtendingSelection: false)
        if let action = action {
            perform(action)
        }
    }
}

extension MainVC: NSTableViewDataSource {

  func numberOfRows(in tableView: NSTableView) -> Int {
    return vmList?.count ?? 0
  }

  func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
    guard tableView.sortDescriptors.first != nil else {
      return
    }

    reloadFileList()
  }

}

extension MainVC: NSTableViewDelegate {
    
    fileprivate enum CellIdentifiers {
        static let NameCell = "VmConfigNameCellID"
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        
        var image: NSImage?
        var text: String = ""
        var cellIdentifier: String = ""
        
        guard let item = vmList?[row] else {
            return nil
        }
        
        if tableColumn == tableView.tableColumns[0] {
            //image = item.cdImage
            text = item.config.vmname
            cellIdentifier = CellIdentifiers.NameCell
        }
        
        if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: cellIdentifier), owner: nil) as? NSTableCellView {
            cell.textField?.stringValue = text
            cell.imageView?.image = image ?? nil
            return cell
        }
        return nil
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        
        if (notification.object as? NSTableView) != nil {
            
            if vmConfigTableView.selectedRow >= 0,
               let item = vmList?[vmConfigTableView.selectedRow] {
                populateVMAttributes(item)
                
                let itemInfo:[String: VirtualMachine] = ["config": item]
                NotificationCenter.default.post(name: Notification.Name(rawValue: "vmConfigChange"), object: nil, userInfo: itemInfo)
            }
            else
            {
                vmNameTextField.stringValue = ""
                vmCoresTextField.stringValue = ""
                vmRAMTextField.stringValue = ""
                vmStateTextField.stringValue = ""
                
                NotificationCenter.default.post(name: Notification.Name(rawValue: "vmConfigChange"), object: nil, userInfo: nil)
            }
            
            
        }
    }
    
}
