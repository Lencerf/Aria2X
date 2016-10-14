//
//  AppDelegate.swift
//  Aria2X
//
//  Created by Lencerf on 16/6/24.
//  Copyright © 2016年 Lencerf. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var mainWindowController: MainWindowController!
    
    @IBOutlet weak var closeIndicator: NSWindow!
    @IBOutlet weak var urlfield: NSTextField!
    //lazy var aria2Core = Aria2Core()
    
    override func awakeFromNib() {
        let toolbar = NSToolbar.init(identifier: "AXToolBar")
        toolbar.delegate = mainWindowController
        toolbar.allowsUserCustomization = false
        toolbar.displayMode = .iconOnly
        toolbar.sizeMode = .regular
        toolbar.autosavesConfiguration = true
        window.toolbar = toolbar
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        /*
        let options = ["enable-rpc": "false",
                       "dir": "/Users/Lenserf/Downloads"]
        if let core = Aria2Core.init(options: options) {
            aria2Core = core
        }*/
    }
    
    /*
    func applicationWillTerminate(_ aNotification: Notification) {
        if closeIndicator == nil {
            Bundle.main.loadNibNamed("CloseIndicator", owner: self, topLevelObjects: nil)
        }
        window.beginSheet(closeIndicator, completionHandler: nil)
        var a:String
        a = readLine()!
        mainWindowController.endAria2Core()
        window.endSheet(closeIndicator)
    }*/

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplicationTerminateReply {
        if closeIndicator == nil {
            Bundle.main.loadNibNamed("CloseIndicator", owner: self, topLevelObjects: nil)
        }
        window.beginSheet(closeIndicator, completionHandler: nil)
        DispatchQueue.global().async(execute: {
            self.mainWindowController.endAria2Core()
            NSApp.reply(toApplicationShouldTerminate: true)
        })
        return NSApplicationTerminateReply.terminateLater
    }
    
    @IBAction func forceQuit(_ sender: AnyObject) {
        mainWindowController.aria2Core.forcePauseAllDownload()
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        window.makeKeyAndOrderFront(self)
        return false
    }
    
    @IBAction func newse(_ sender: AnyObject) {

        //aria2Core.restart(options: ["enable-rpc": "true", "rpc-listen-port": "6801"])
    }
    @IBAction func addURL(_ sender: AnyObject) {
        //print(urlfield.stringValue)
        //let urlstring = urlfield.stringValue
        //aria2Core.addURL(urlstring)
    }

    @IBAction func printInfo(_ sender: AnyObject) {
        let dict = mainWindowController.aria2Core.globalStat() as! [NSString:Int]
        for (key, value) in dict {
            print("\(key) = \(value)")
        }
        mainWindowController.aria2Core.testMyAPI()
        if urlfield.stringValue != "" {
            let id = UInt64(urlfield.stringValue)!
            print("\(id) status is", mainWindowController.aria2Core.status(id))
        }
    }
}

