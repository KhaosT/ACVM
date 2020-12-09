//
//  ViewController.swift
//  ACVM
//
//  Created by Khaos Tian on 11/29/20.
//

import Cocoa

class MainVC: NSViewController {
        
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
    
    @IBOutlet weak var vmNameTextField: NSTextField!
    @IBOutlet weak var vmStateTextField: NSTextField!
    @IBOutlet weak var vmCoresTextField: NSTextField!
    @IBOutlet weak var vmRAMTextField: NSTextField!
    
    @IBOutlet weak var vmConfigTableView: NSTableView!
    
    var vmConfigList: [VmConfiguration]? = []
    
    func setupNotifications()
    {
        NotificationCenter.default.addObserver(forName: Notification.Name(rawValue: "qemuStatusChange"), object: nil, queue: nil) { (notification) in self.updateVMStateTextField(notification as NSNotification) }
        
        NotificationCenter.default.addObserver(forName: Notification.Name(rawValue: "refreshVMList"), object: nil, queue: nil) { (notification) in self.refreshVMList() }
    }
    
    func updateVMStateTextField(_ notification: NSNotification) {
        
        let qemuProcess = (notification.object)
        
        if qemuProcess != nil {
            vmStateTextField.stringValue = "Started"
        } else {
            vmStateTextField.stringValue = "Stopped"
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
        
        vmStateTextField.stringValue = ""
    }
    
    func findAllVMConfigs() {
        let fm = FileManager.default
        let path = "/Users/kupan787/Virtual Machines"

        vmConfigList?.removeAll()
        
        do {
            let items = try fm.contentsOfDirectory(atPath: path)

            for item in items {
                if item.hasSuffix("plist") {
                    if let xml = FileManager.default.contents(atPath: path + "/" + item.description) {
                        let vmConfig = try! PropertyListDecoder().decode(VmConfiguration.self, from: xml)
                        vmConfigList!.append(vmConfig)
                    }
                }
            }
        } catch {
            // failed to read directory – bad permissions, perhaps?
        }
        
        vmConfigList?.sort {
            $0.vmname < $1.vmname
        }
    }
    
    func populateVMAttributes(_ fileContents: Data?) {
        let vmConfig = try! PropertyListDecoder().decode(VmConfiguration.self, from: fileContents!)
        
        vmNameTextField.stringValue = vmConfig.vmname
        
        if vmConfig.cores != 0 {
            vmCoresTextField.stringValue = String(vmConfig.cores)
        }
        
        if vmConfig.ram != 0 {
            vmRAMTextField.stringValue = String(vmConfig.ram) + " MB"
        }
        
        vmStateTextField.stringValue = "Stopped"
    }
    
    func refreshVMList() {
        reloadFileList()
        
        vmNameTextField.stringValue = ""
        vmCoresTextField.stringValue = ""
        vmRAMTextField.stringValue = ""
        vmStateTextField.stringValue = ""
    }
    
    func reloadFileList() {
        findAllVMConfigs()
        vmConfigTableView.reloadData()
    }

    @objc func tableViewDoubleClick(_ sender:AnyObject) {
        guard vmConfigTableView.selectedRow >= 0,
              let item = vmConfigList?[vmConfigTableView.selectedRow] else {
            return
        }
        
        print("Double Click Start VM: " + item.vmname)
        
    }
    
}

extension MainVC: NSTableViewDataSource {

  func numberOfRows(in tableView: NSTableView) -> Int {
    return vmConfigList?.count ?? 0
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
        
        guard let item = vmConfigList?[row] else {
            return nil
        }
        
        if tableColumn == tableView.tableColumns[0] {
            //image = item.cdImage
            text = item.vmname
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
               let item = vmConfigList?[vmConfigTableView.selectedRow] {
                populateVMAttributes(FileManager.default.contents(atPath: "/Users/kupan787/Virtual Machines/" + item.vmname + ".plist"))
                
                let itemInfo:[String: VmConfiguration] = ["config": item]
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
