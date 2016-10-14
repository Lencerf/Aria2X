//
//  AXTaskCellView.swift
//  Aria2X
//
//  Created by Lencerf on 16/6/15.
//  Copyright © 2016年 Lencerf. All rights reserved.
//

import Cocoa

class AXTaskCellView: NSTableCellView {
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }
    
    override var backgroundStyle: NSBackgroundStyle {
        didSet {
            switch backgroundStyle {
            case .dark:
                taskName.textColor = NSColor.white
                taskDetail.textColor = NSColor.controlLightHighlightColor
                taskSpeed.textColor = NSColor.controlLightHighlightColor
            case .light:
                taskName.textColor = NSColor.labelColor
                taskDetail.textColor = NSColor.labelColor
                taskSpeed.textColor = NSColor.labelColor
            default:
                break
            }
        }
    }
    
    @IBOutlet weak var taskName: NSTextField!
    @IBOutlet weak var taskDetail: NSTextField!
    @IBOutlet weak var downloadProgress: NSProgressIndicator!
    @IBOutlet weak var taskSpeed: NSTextField!
    
}
