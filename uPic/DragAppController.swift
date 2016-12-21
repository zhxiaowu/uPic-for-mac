//
//  DragAppController.swift
//  uPic
//
//  Created by Frank on 2016/12/21.
//  Copyright © 2016年 defcoding. All rights reserved.
//


import Cocoa

import Qiniu
import CryptoSwift
import SwiftyJSON
import LetsMove


class DragAppController: NSObject, NSWindowDelegate, NSDraggingDestination {

    @IBOutlet weak var dragMenu: NSMenu!
    @IBOutlet weak var uploadImageView: UploadImageView!

    let dragApp = NSStatusBar.system().statusItem(withLength: NSVariableStatusItemLength)
    var userDefaults : UserDefaults!

    override func awakeFromNib() {
        let imageItem = dragMenu.item(withTitle: "Image")!
        imageItem.view = uploadImageView

        let icon = NSImage(named: "statusIcon")
        icon?.isTemplate = true // best for dark mode
        dragApp.image = icon
        dragApp.menu = dragMenu

        dragApp.button?.window?.registerForDraggedTypes([NSFilenamesPboardType])
        dragApp.button?.window?.delegate = self
        
        userDefaults = NSUserDefaultsController.shared().defaults
        
        PFMoveToApplicationsFolderIfNecessary()
        
    }

    func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        
        let icon = NSImage(named: "dropIcon")
        icon?.isTemplate = true
        dragApp.image = icon
        
        return NSDragOperation.copy
    }
    
    func draggingExited(_ sender: NSDraggingInfo?) {
        
        let icon = NSImage(named: "statusIcon")
        icon?.isTemplate = true // best for dark mode
        dragApp.image = icon
    }

    func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        
        let icon = NSImage(named: "statusIcon")
        icon?.isTemplate = true // best for dark mode
        dragApp.image = icon
        
        
        let pasteBoard = sender.draggingPasteboard()
        let filePaths = pasteBoard.propertyList(forType: NSFilenamesPboardType) as! NSArray
        
        
        let domain = userDefaults.string(forKey: "domain")!

        if domain == "" {
            
            UserNotificationController.shared.displayNotification(
                withTitle: "❌错",
                informativeText: "需要配置七牛信息")
            return false;
        }
        
        let isStyle = userDefaults.integer(forKey: "isStyle")
        print (isStyle)
        let style = userDefaults.string(forKey: "style")

        
        let qiNiu = QNUploadManager()!
        
        for path in filePaths {
            let token = getQiniuToken()
            let filePath = path as! String
            let filename = NSUUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
            let suffix = filePath.components(separatedBy: ".").last!
            let key = "\(filename).\(suffix)"
            //print(key)
            //print(token)

            qiNiu.putFile(filePath, key: key, token: token, complete: {info, key, resp -> Void in
                //print(info!)
                
                if info != nil && info?.error != nil {
                    
                    UserNotificationController.shared.displayNotification(
                        withTitle: "图片上传失败，请检查设置信息",
                        informativeText: filePath)
                    
                } else {
                
                    let image = NSImage(contentsOfFile: filePath)
                    var imageUrl = "\(domain)/\(key!)"
                    
                    if  isStyle == 1 {
                        imageUrl += style!
                    }
                    
                    let uploadImageRow = UploadImageRowStruct(image: image!, url: imageUrl)
                    self.uploadImageView.uploadImageRows.append(uploadImageRow)
                    self.uploadImageView.uploadImageTable.reloadData()
                    print("reload")
                
                    UserNotificationController.shared.displayNotification(
                        withTitle: "图片上传成功",
                        informativeText: filePath)
                    }
                }, option: nil)
        }
        return true
    }

    func getQiniuToken() -> String {
        
        let accessKey = userDefaults.string(forKey: "accessKey")!
        let secretKey = userDefaults.string(forKey: "secretKey")!
        let bucket = userDefaults.string(forKey: "bucket")!

        let deadline = round(NSDate(timeIntervalSinceNow: 3600).timeIntervalSince1970)
        let putPolicyDict:JSON = [
            "scope": bucket,
            "deadline": deadline,
            "returnBody": "",
        ]
        let encodePutPolicy = QNUrlSafeBase64.encode(putPolicyDict.rawString())!
        let secretSign =  try! HMAC(key: (secretKey.utf8.map({$0})), variant: .sha1).authenticate((encodePutPolicy.utf8.map({$0}))).toBase64()!

        let putPolicy:String = [accessKey, secretSign, encodePutPolicy].joined(separator: ":")
        return putPolicy
    }

    @IBAction func quitApp(_ sender: NSMenuItem) {
        NSApplication.shared().terminate(self)
    }
}
