//
//  JSRemoteSourceFile.swift
//  JavascriptEngine
//
//  Created by PATRICK PERINI on 7/19/15.
//  Copyright (c) 2015 Atomic. All rights reserved.
//

import Foundation
import AFNetworking

@objc public protocol JSRemoteSourceFileDelegate {
    // MARK: Optionals
    func remoteSoureFile(file: JSRemoteSourceFile, didUpdateContent content: String?)
}

public class JSRemoteSourceFile: NSObject {
    // MARK: Properties
    public weak var delegate: JSRemoteSourceFileDelegate?
    
    private let fileName: String
    private let localCachePath: String
    private var updatingFromLocal: Bool = false
    
    private(set) public var content: String? {
        didSet {
            if oldValue != self.content {
                self.delegate?.remoteSoureFile(self, didUpdateContent: self.content)
            }
            
            if !self.updatingFromLocal {
                self.saveContentToFileAtPath(self.localCachePath)
            }
        }
    }
    
    public var remoteRetryDelay: NSTimeInterval = 1.0
    private let remoteURL: NSURL
    private var updatingFromRemote: Bool = false
    private let networkManager: AFHTTPRequestOperationManager = {
        let manager = AFHTTPRequestOperationManager()
        manager.responseSerializer = AFHTTPResponseSerializer()
        manager.completionQueue = dispatch_get_main_queue()
        return manager
    }()
    
    // MARK: Class Initializers
    public override class func initialize() {
        super.initialize()
        AFNetworkReachabilityManager.sharedManager().startMonitoring()
    }
    
    // MARK: Initializers
    public required init(remoteURL: NSURL) {
        self.fileName = remoteURL.lastPathComponent!
        self.remoteURL = remoteURL
        
        let paths = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.CachesDirectory,
            NSSearchPathDomainMask.UserDomainMask,
            true)
        self.localCachePath = (paths.first! as NSString).stringByAppendingPathComponent(self.fileName)
        
        super.init()
        
        NSNotificationCenter.defaultCenter().addObserver(self,
            selector: "remoteReachabilityDidChange:",
            name: AFNetworkingReachabilityDidChangeNotification,
            object: nil)
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    // MARK: Mutators
    public func updateContent(retryDelay: NSTimeInterval = 0.0) {
        // Wait for delay
        if retryDelay > 0.0 {
            let afterTime = Int64(NSTimeInterval(NSEC_PER_SEC) * retryDelay)
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, afterTime), dispatch_get_main_queue()) {
                self.updateContent(0.0)
            }
            
            return
        }
        
        // Grab from disk if possible
        self.updateContentFromFileAtPath(self.localCachePath)
        
        // Update from remote
        if !self.updatingFromRemote && AFNetworkReachabilityManager.sharedManager().reachable {
            self.updatingFromRemote = true
            
            self.networkManager.GET(self.remoteURL.absoluteString, parameters: nil, success: { (op: AFHTTPRequestOperation!, response: AnyObject!) in
                if let responseData = response as? NSData {
                    self.content = NSString(data: responseData, encoding: NSUTF8StringEncoding) as String?
                }
                
                self.updatingFromRemote = false
                if self.content == nil {
                    self.updateContent(self.remoteRetryDelay)
                }
                
            }, failure: { (op: AFHTTPRequestOperation?, error: NSError?) in
                self.updatingFromRemote = false
                self.updateContent(self.remoteRetryDelay)
            })
        }
    }
    
    private func updateContentFromFileAtPath(filePath: String) {
        self.updatingFromLocal = true
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)) {
            let content = (try? NSString(contentsOfFile: filePath,
                encoding: NSUTF8StringEncoding)) as String?
            
            dispatch_async(dispatch_get_main_queue()) {
                self.content = content
                self.updatingFromLocal = false
            }
        }
    }
    
    private func saveContentToFileAtPath(filePath: String) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)) {
            let _ = try? self.content?.writeToFile(filePath,
                atomically: true,
                encoding: NSUTF8StringEncoding)
        }
    }
    
    // MARK: Responders
    internal func remoteReachabilityDidChange(notification: NSNotification) {
        self.updateContent()
    }
}
