//
//  MainWindowController.swift
//  Aria2X
//
//  Created by Lencerf on 16/6/24.
//  Copyright © 2016年 Lencerf. All rights reserved.
//

import Cocoa

class MainWindowController: NSObject {
    override init() {
        let supportFolder = NSHomeDirectory() + "/Library/Application Support/Aria2X"
        if !FileManager.default.fileExists(atPath: supportFolder) {
            try! FileManager.default.createDirectory(atPath: supportFolder, withIntermediateDirectories: true, attributes: nil)
        }
        let sessionFilePath = supportFolder + "/session.txt"
        if !FileManager.default.fileExists(atPath: sessionFilePath) {
            FileManager.default.createFile(atPath: sessionFilePath, contents: nil, attributes: nil)
        }
        let options = ["enable-rpc": "true",
                       "dir": NSHomeDirectory()+"/Downloads",
                       "input-file": sessionFilePath,
                       "save-session": sessionFilePath]
        aria2Core = Aria2Core.init(options: options)
    }
    
    override func awakeFromNib() {
        refreshTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(updateList), userInfo: nil, repeats: true)
        tableViewMenu.delegate = self
        tableview.menu = tableViewMenu
    }
    
    func endAria2Core() {
        removeDownloadResultQueue.sync(execute: {
            print("all delete task finished")
        })
        aria2Core.end()
    }
    
    @IBOutlet weak var mainWindow: NSWindow!
    @IBOutlet weak var tableview: NSTableView! {
        didSet{
            self.tableview.register(NSNib(nibNamed: "AXTaskCellView", bundle: nil)!, forIdentifier: "AXTaskCellView")
        }
    }
    let aria2Core:Aria2Core
    
    var viewingList = 0 //0: viewing active tasks, 1: viewing finished tasks
    
    //MARK: UI update
    var tableViewMenu = NSMenu()
    var totalList = [UInt64]()
    var refreshTimer = Timer()
    
    func updateList(sender: AnyObject) {
        if let segmented = sender as? NSSegmentedControl {
            self.viewingList = segmented.selectedSegment
        }
        switch self.viewingList {
        case 0: self.updateActiveList()
        case 1: self.updateFinishedList()
        default: break
        }
    }
    
    func updateActiveList() {
        totalList = (aria2Core.activeDownload() as! [NSNumber]).map { $0.uint64Value }
        totalList += (aria2Core.waitingDownload() as! [NSNumber]).map { $0.uint64Value }
        totalList += (aria2Core.errorDownload() as! [NSNumber]).map { $0.uint64Value }
        tableviewUpdate()
    }
    
    func updateFinishedList() {
        totalList = (aria2Core.completeDownload() as! [NSNumber]).map { $0.uint64Value }
        tableviewUpdate()
    }
    
    func tableviewUpdate() {
        let selected = tableview.selectedRowIndexes
        //tableview.reloadData()
        //tableview.reloadData(forRowIndexes: IndexSet.init(integer: 0), columnIndexes: IndexSet.init(integer: 0))
        tableview.reloadData()
        //tableview.reloadData()
        //print("tableviewUpdate(), \(totalList.count)")
        tableview.selectRowIndexes(selected, byExtendingSelection: false)
    }
    
    //MARK: task manage
    
    weak var viewSegmentedControl: NSSegmentedControl!
    weak var resumeButton: NSButton!
    weak var pauseButton: NSButton!
    weak var removeButton: NSButton!
    weak var viewFileButton: NSButton!
    
    func addTask(sender: AnyObject) {
        guard let segmentedSender = sender as? NSSegmentedControl else {
            return
        }
        switch segmentedSender.selectedSegment {
        case 0:
            self.addURL(sender: segmentedSender)
        case 1:
            let addURLAlert = NSAlert()
            addURLAlert.messageText = "It is suggested to use a specialized BtTorrent client such as Transmission, since BT download of Aria2X is still in Alpha. Would you still like to continue?"
            addURLAlert.addButton(withTitle: "Add")
            addURLAlert.addButton(withTitle: "Cancel")
            addURLAlert.icon = NSWorkspace.shared().icon(forFileType: "torrent")
            addURLAlert.beginSheetModal(for: mainWindow, completionHandler: { (modalResponse) -> Void in
                if modalResponse == NSAlertFirstButtonReturn {
                    // add url here
                }
            })
        default:
            break;
        }
    }
    
    func addURL(sender: AnyObject) {
        //http://stackoverflow.com/questions/7387341/how-to-create-and-get-return-value-from-cocoa-dialog
        let addURLAlert = NSAlert()
        addURLAlert.messageText = "Please enter a URL"
        addURLAlert.addButton(withTitle: "Add")
        addURLAlert.addButton(withTitle: "Cancel")
        addURLAlert.icon = NSImage(named: "addURLIcon")
        let inputTextField = NSTextField(frame: NSRect(x: 0, y: 0, width: 400, height: 24))
        inputTextField.lineBreakMode = .byClipping
        addURLAlert.accessoryView = inputTextField
        addURLAlert.beginSheetModal(for: mainWindow, completionHandler: { (modalResponse) -> Void in
            if modalResponse == NSAlertFirstButtonReturn {
                let urlString = inputTextField.stringValue.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlPathAllowed)!
                guard URL(string: urlString) != nil else {
                    let alert = NSAlert()
                    alert.messageText = "Not a valid url"
                    alert.runModal()
                    return
                }
                //self.aria2Core.addURL(inputTextField.stringValue)
                self.aria2Core.addURL(inputTextField.stringValue, options: ["header":"User-Agent: netdisk;5.3.4.5;PC;PC-Windows;5.1.2600;WindowsBaiduYunGuanJia"])
                self.viewingList = 0
                self.viewSegmentedControl.selectedSegment = 0
            }
        })
    }
    
    let removeDownloadResultQueue = DispatchQueue.init(label: "removeDownloadResultQueue")
    
    func removeTask(sender: AnyObject) {
        let gids = tableview.selectedRowIndexes.map { totalList[$0] }
        let localUrlsOftasks = gids.map { (id:UInt64) -> [URL] in
            let paths = aria2Core.files(id)!.map { Optional.some($0)["path"] as! String }
            let validPaths = paths.filter { $0 != "" }
            let urls = validPaths.map { [URL(fileURLWithPath: $0), URL(fileURLWithPath: "\($0).aria2")] }
            return Array(urls.joined())
            
        }
        for (index, gid) in gids.enumerated() {
            removeDownloadResultQueue.async(execute: {
                print(self.aria2Core.removeDownload(gid))
                repeat {
                    print("+0.2s for remove download")
                    usleep(200000)// +0.2s
                } while !self.aria2Core.removeDownloadResult(gid)
                NSWorkspace.shared().recycle(localUrlsOftasks[index], completionHandler: { _, error in
                    if error != nil && error?._code != 260 { // file did not exist
                        print("fail, code = \(error?._code)")
                        
                    }
                })
            })
        }
        removeDownloadResultQueue.async(execute: { print("file deleted") })
    }
    
    func resumeTask(sender: AnyObject) {
        let gids = tableview.selectedRowIndexes.map { totalList[$0] }
        for gid in gids {
            aria2Core.unpauseDownload(gid)
        }
    }
    
    func pauseTask(sender: AnyObject) {
        let gids = tableview.selectedRowIndexes.map { totalList[$0] }
        for gid in gids {
            aria2Core.pauseDownload(gid)
        }
    }
    
    func showFileinFinder(sender: AnyObject) {
        let gids = tableview.selectedRowIndexes.map { totalList[$0] }
        let urlsOftasks = gids.map { (id:UInt64) -> [URL] in
            let paths = aria2Core.files(id).map { Optional.some($0)["path"] as! String }
            let validPaths = paths.filter { $0 != "" }
            let urls = validPaths.map { URL(fileURLWithPath: $0) }
            return urls
        }
        let urls = Array(urlsOftasks.joined())
        if urls.count > 0 {
            NSWorkspace.shared().activateFileViewerSelecting(urls)
        }
    }
    
    func copyTaskLink(sender: AnyObject) {
        //taskInfoDict?["files"][0]["urls"][0] as! String
        let gids = tableview.selectedRowIndexes.map { totalList[$0] }
        var linkStrings = [String]()
        for id in gids {
            let info = aria2Core.files(id)!
            for file in info {
                for aLink in Optional.some(file)["urls"] as! Array<String> {
                    linkStrings.append(aLink)
                }
            }
        }
        for alink in linkStrings {
            print(alink)
        }
    }
    
    internal func changeUnite(forNumber doubleValue:Double) -> String {
        if doubleValue > 1000000000000 {
            return String(format:"%.1f TB", doubleValue / 1000000000000)
        } else if doubleValue > 1000000000 {
            return String(format:"%.1f GB", doubleValue / 1000000000)
        } else if doubleValue > 1000000 {
            return String(format:"%.1f MB", doubleValue / 1000000)
        } else if doubleValue > 1000 {
            return String(format:"%.1f KB", doubleValue / 1000)
        } else {
            return "\(doubleValue) Bytes"
        }
    }
    
    
}

extension MainWindowController: NSTableViewDataSource, NSTableViewDelegate {
    //MARK: data source
    func numberOfRows(in tableView: NSTableView) -> Int {
        return totalList.count
    }
    
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        //print("tableView, viewFor \(tableColumn) and \(row)")
        let gid = totalList[row]
        guard aria2Core.isValidGid(gid) else {
            return nil
        }
        let taskInfoDict = aria2Core.infoDict(totalList[row])
        let taskName = (taskInfoDict?["files"][0]["path"] as! String).components(separatedBy: "/").last!
        let taskStatus = taskInfoDict?["status"] as! Int
        let totalLength = taskInfoDict?["totalLength"] as! Int
        let completedLength = taskInfoDict?["completedLength"] as! Int
        if tableColumn?.identifier == "TaskDetail" {
            let cell = tableView.make(withIdentifier: "AXTaskCellView", owner: self) as! AXTaskCellView
            if taskName == "" {
                cell.taskName.stringValue = taskInfoDict?["files"][0]["urls"][0] as! String
            } else {
                cell.taskName.stringValue = taskName
            }
            cell.downloadProgress.maxValue = Double(totalLength)
            cell.downloadProgress.doubleValue = Double(completedLength)
            cell.taskDetail.stringValue = self.changeUnite(forNumber: Double(completedLength)) + " / " + changeUnite(forNumber: Double(totalLength))
            switch taskStatus {
            case 1: cell.taskSpeed.stringValue = "waiting"
            case 2: cell.taskSpeed.stringValue = "paused"
            case 4: // error task
                cell.taskSpeed.stringValue = "error"
            default: //active task
                let speedString = self.changeUnite(forNumber: Double(taskInfoDict?["dls"] as! Int))
                cell.taskSpeed.stringValue = "DL: \(speedString)/s"
            }
            /* bt info to be supported */
            return cell
        } else {
            let filetype = taskName.components(separatedBy: ".").last!
            let icon =  NSWorkspace.shared().icon(forFileType: filetype)
            let imageCell = NSImageView.init(frame: NSRect(x: 0, y: 0, width: 64, height: 64))
            imageCell.image = icon
            return imageCell
        }
    }
    //MARK: delegate
    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let theTableview = notification.object as? NSTableView else { return }
        if theTableview.selectedRowIndexes.count > 0 {
            for index in theTableview.selectedRowIndexes {
                if aria2Core.status(totalList[index]) == 4 {
                    resumeButton.isEnabled = false
                }
            }
        } else {
            resumeButton.isEnabled = true
        }
        
    }
    
    
}

extension MainWindowController: NSToolbarDelegate {
    func normalToolBarItem(identifier: String, image: NSImage, selector:Selector?=nil) -> NSToolbarItem {
        let item = NSToolbarItem.init(itemIdentifier: identifier)
        let button = NSButton.init()
        button.bezelStyle = .texturedRounded
        button.target = self
        button.action = selector
        item.view = button
        let buttonSize = NSMakeSize(38, 27)
        item.minSize = buttonSize
        item.maxSize = buttonSize
        item.image = image
        return item
    }
    func normalToolBarItem(identifier: String, title: String, selector:Selector?=nil) -> NSToolbarItem {
        let item = NSToolbarItem.init(itemIdentifier: identifier)
        let button = NSButton.init()
        button.bezelStyle = .texturedRounded
        button.target = self
        button.action = selector
        button.title = title
        item.view = button
        let buttonSize = NSMakeSize(38, 27)
        item.minSize = buttonSize
        item.maxSize = buttonSize
        return item
    }
    
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: String, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        switch itemIdentifier {
        case "AddTask":
            let group = NSToolbarItemGroup(itemIdentifier: itemIdentifier)
            
            let itemA = NSToolbarItem(itemIdentifier: "AddURL")
            let itemB = NSToolbarItem(itemIdentifier: "AddTorrent")
            
            let segmented = NSSegmentedControl(frame: NSRect(x: 0, y: 0, width: 62, height: 25))
            segmented.segmentStyle = .texturedRounded
            segmented.trackingMode = .momentary
            segmented.segmentCount = 2
            segmented.target = self
            segmented.action = #selector(addTask(sender:))
            segmented.setImage(NSImage(named: "ToolbarURLTemplate")!, forSegment: 0)
            segmented.setImage(NSImage(named: "ToolbarTorrentTemplate")!, forSegment: 1)
            segmented.setWidth(28, forSegment: 0)
            segmented.setWidth(28, forSegment: 1)
            group.paletteLabel = "Add Task"
            group.subitems = [itemA, itemB]
            group.view = segmented
            
            return group
            
        case "ResumeTask":
            let resumeItem = normalToolBarItem(identifier: itemIdentifier, title: "▶︎", selector: #selector(resumeTask(sender:)))
            resumeButton = resumeItem.view as? NSButton
            return resumeItem
        case "PauseTask":
            return normalToolBarItem(identifier: "PauseTask", image: NSImage(named: "ToolbarPauseSelectedTemplate")!, selector: #selector(pauseTask(sender:)))
        case "RemoveTask":
            return normalToolBarItem(identifier: itemIdentifier, image: NSImage(named: "ToolbarRemoveTemplate")!, selector: #selector(removeTask(sender:)))
        case "ShowFile":
            return normalToolBarItem(identifier: itemIdentifier, image: NSImage(named: "ToolbarFilterTemplate")!, selector: #selector(showFileinFinder(sender:)))
        case "Setting":
            return normalToolBarItem(identifier: itemIdentifier, image: NSImage(named: NSImageNameActionTemplate)!)
            
        case "SwitchLists":
            //http://stackoverflow.com/questions/1323204/interface-builder-segmented-controls
            let group = NSToolbarItemGroup(itemIdentifier: itemIdentifier)
            
            let itemA = NSToolbarItem(itemIdentifier: "ActiveToolbarItem")
            itemA.label = "Active"
            let itemB = NSToolbarItem(itemIdentifier: "FinishedToolbarItem")
            itemB.label = "Finished"
            
            let segmented = NSSegmentedControl(frame: NSRect(x: 0, y: 0, width: 152, height: 25))
            segmented.segmentStyle = .texturedRounded
            segmented.trackingMode = .selectOne
            segmented.segmentCount = 2
            // Don't set a label: these would appear inside the button
            segmented.setLabel("Active", forSegment: 0)
            //segmented.setImage(NSImage(named: NSImageNameGoLeftTemplate)!, forSegment: 0)
            segmented.setWidth(70, forSegment: 0)
            segmented.setLabel("Finished", forSegment: 1)
            segmented.setWidth(70, forSegment: 1)
            segmented.selectedSegment = 0
            segmented.target = self
            segmented.action = #selector(updateList(sender:))
            self.viewSegmentedControl = segmented
            // `group.label` would overwrite segment labels
            group.paletteLabel = "Navigation"
            group.subitems = [itemA, itemB]
            group.view = segmented
            
            let toolbarItem:NSToolbarItem = group
            return toolbarItem
            
        default:
            return nil
        }
    }
    
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [String] {
        let items = ["AddTask",
                     "PauseTask",
                     "ResumeTask",
                     "SwitchLists",
                     "ShowFile",
                     "Setting",
                     "RemoveTask",
                     NSToolbarSpaceItemIdentifier,
                     NSToolbarFlexibleSpaceItemIdentifier]
        return items
    }
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [String] {
        let items = ["AddTask",
                     "ResumeTask",
                     "PauseTask",
                     NSToolbarFlexibleSpaceItemIdentifier,
                     "SwitchLists",
                     NSToolbarFlexibleSpaceItemIdentifier,
                     NSToolbarSpaceItemIdentifier,
                     "RemoveTask",
                     "ShowFile",
                     "Setting"]
        return items
    }
}

extension MainWindowController: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let clickedRow = tableview.clickedRow
        if clickedRow == -1 {
            return
        } else if tableview.selectedRowIndexes.count == 0 || !tableview.selectedRowIndexes.contains(clickedRow) {
            tableview.selectRowIndexes(IndexSet.init(integer: clickedRow), byExtendingSelection: false)
        }
        var newItems = [NSMenuItem]()
        if viewingList == 0 {
            newItems.append(NSMenuItem(title: "Pause", action: #selector(pauseTask), keyEquivalent: ""))
            newItems.append(NSMenuItem(title: "Resume", action: #selector(resumeTask), keyEquivalent: ""))
        }
        newItems.append(NSMenuItem(title: "Remove", action: #selector(removeTask), keyEquivalent: ""))
        newItems.append(NSMenuItem.separator())
        newItems.append(NSMenuItem(title: "Show in Finder", action: #selector(showFileinFinder), keyEquivalent: ""))
        
        newItems.append(NSMenuItem(title: "Copy Link", action: #selector(copyTaskLink), keyEquivalent: ""))
        for item in newItems {
            item.target = self
            menu.addItem(item)
        }
    }
    func constructMenuForIndex(from first:Int, to last:Int) -> [NSMenuItem] {
        var items = [NSMenuItem]()
        let itemPause = NSMenuItem.init(title: "pause", action: #selector(pauseTask), keyEquivalent: "")
        items.append(itemPause)
        return items
    }
}
