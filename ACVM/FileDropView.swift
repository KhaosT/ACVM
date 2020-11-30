//
//  FileDropView.swift
//  ACVM
//
//  Created by Khaos Tian on 11/30/20.
//

import Cocoa

class FileDropView: NSImageView {
    
    weak var delegate: FileDropViewDelegate?
    
    var contentURL: URL? {
        didSet {
            guard let url = contentURL else {
                image = nil
                return
            }
            
            image = NSWorkspace.shared.icon(forFile: url.path)
        }
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    private func commonInit() {
        registerForDraggedTypes([.fileURL])
    }
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let pasteboard = sender.draggingPasteboard
        
        guard let types = pasteboard.types, types.contains(.fileURL) else {
            return []
        }
                
        return .copy
    }
    
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        let pasteboard = sender.draggingPasteboard
        
        guard let types = pasteboard.types, types.contains(.fileURL) else {
            return []
        }
                
        return .copy
    }
    
    override func draggingExited(_ sender: NSDraggingInfo?) {}
    
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard
        
        guard let types = pasteboard.types, types.contains(.fileURL) else {
            return false
        }
                
        return true
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard
        
        guard let types = pasteboard.types, types.contains(.fileURL) else {
            return false
        }
        
        if let fileURLString = pasteboard.propertyList(forType: .fileURL) as? String,
           let fileURL = URL(string: fileURLString) {
            contentURL = fileURL
            delegate?.fileDropView(self, didUpdate: fileURL)
        }
        
        return true
    }
    
    override func concludeDragOperation(_ sender: NSDraggingInfo?) {}
}

protocol FileDropViewDelegate: AnyObject {
    
    func fileDropView(_ view: FileDropView, didUpdate contentURL: URL)
}
