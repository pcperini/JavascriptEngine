//
//  JSEngine.swift
//  JavascriptEngine
//
//  Created by PATRICK PERINI on 7/14/15.
//  Copyright (c) 2015 Atomic. All rights reserved.
//

import UIKit
import WebKit
import AFNetworking

public class JSEngine: NSObject {
    // MARK: Types
    internal class Responder: NSObject, WKScriptMessageHandler {
        // MARK: Properties
        weak var engine: JSEngine? { // Introduce a WEAK, circular depedency, to break WKWebView's STRONG circular dependency.
            willSet {
                // This should never get called. But it can, if someone fiddles with retaining the web view.
                for (key, _) in self.engine?.messageHandlers ?? [:] {
                    self.engine?.webView?.configuration.userContentController.removeScriptMessageHandlerForName(key)
                }
            }
        }
        
        // MARK: Responders
        @objc func userContentController(userContentController: WKUserContentController, didReceiveScriptMessage message: WKScriptMessage) {
            dispatch_async(dispatch_get_main_queue()) {
                self.engine?.handlerForKey(message.name)?(message.body)
            }
        }
    }
    
    // MARK: Constants
    private static let globalVars = "var engine = window.webkit.messageHandlers;"
    private static let mainFunc = "window.onload = function () {engine.load.postMessage(null);};"
    
    // MARK: Properties
    private(set) public var lastHTTPRequest: AFHTTPRequestOperation?
    public var loadTimeout: NSTimeInterval = 10.0

    internal let responder: Responder
    private var webView: WKWebView? {
        willSet {
            // Remove old reference to self for scriptMessageHandler
            for (key, _) in self.messageHandlers {
                self.webView?.configuration.userContentController.removeScriptMessageHandlerForName(key)
            }
            
            self.webView?.removeFromSuperview()
        }
        
        didSet {
            // Migrate message handlers            
            for (key, value) in self.messageHandlers {
                self.setHandlerForKey(key, handler: value)
            }
            
            if self.handlerForKey("httpRequest") == nil {
                self.setHandlerForKey("httpRequest") { [unowned self] in
                    self.httpRequestHandler($0)
                }
            }
            
            if self.handlerForKey("error") == nil {
                self.setHandlerForKey("error") { [unowned self] in
                    self.defaultErrorHandler($0)
                }
            }
            
            (UIApplication.sharedApplication().windows.first as? UIWindow)?.addSubview(self.webView!)
        }
    }
    
    private(set) internal var messageHandlers: [String: (AnyObject!) -> Void] = [:]
    public var debugHandler: ((AnyObject!) -> Void)? {
        get { return self.handlerForKey("debug") }
        set { self.setHandlerForKey("debug", handler: newValue) }
    }
    
    public var errorHandler: ((NSError!) -> Void) {
        get {
            return self.handlerForKey("error") as ((NSError!) -> Void)!
        }
        
        set {
            self.setHandlerForKey("error") { (errObject: AnyObject!) in
                let err = NSError(domain: __FILE__.lastPathComponent, code: -1, userInfo: ["error": errObject])
                newValue(err)
            }
        }
    }
    
    private(set) public var loaded: Bool = false
    private var loadHandler: (() -> Void)? {
        get {
            if let handler = self.handlerForKey("load") {
                return { [unowned self] in
                    handler(nil)
                }
            } else {
                return nil
            }
        }
        
        set {
            self.loaded = false
            if let handler = newValue {
                
                // Handle timeout
                var timeoutDidFire = false
                let timeoutInterval = dispatch_time(DISPATCH_TIME_NOW, Int64(NSTimeInterval(NSEC_PER_SEC) * self.loadTimeout))
                dispatch_after(timeoutInterval, dispatch_get_main_queue()) {
                    if !self.loaded {
                        timeoutDidFire = true
                        self.handlerForKey("error")?("JSEngineTimeout")
                    }
                }
                
                // Set handler
                self.setHandlerForKey("load") { (_: AnyObject!) in
                    if timeoutDidFire {
                        // Load eventually completed. Ignore it.
                        return
                    }
                    
                    self.loaded = true
                    handler()
                }
            } else {
                self.setHandlerForKey("load", handler: nil)
            }
        }
    }
    
    public var source: String? {
        get {
            return self.webView?.configuration.userContentController.userScripts.reduce("") {
                "\($0!)\n\($1.source!)"
            }
        }
        
        set {
            if let sourceString = newValue {
                // Construct new content controller
                let contentController = WKUserContentController()
                
                contentController.addUserScript(WKUserScript(source: JSEngine.globalVars,
                    injectionTime: WKUserScriptInjectionTime.AtDocumentStart,
                    forMainFrameOnly: true))
                
                contentController.addUserScript(WKUserScript(source: sourceString,
                    injectionTime: WKUserScriptInjectionTime.AtDocumentEnd,
                    forMainFrameOnly: true))
                
                contentController.addUserScript(WKUserScript(source: JSEngine.mainFunc,
                    injectionTime: WKUserScriptInjectionTime.AtDocumentEnd,
                    forMainFrameOnly: true))
                
                let config = WKWebViewConfiguration()
                config.userContentController = contentController
                
                self.webView = WKWebView(frame: CGRect(),
                    configuration: config)
                
                if self.loadHandler != nil { // Race condition, loadHandler has already been set.
                    self.load(handler: self.loadHandler)
                }
            }
        }
    }
    
    // MARK: Initializers
    public override init() {
        self.responder = Responder()
        super.init()
        
        self.responder.engine = self
    }
    
    public convenience init(sourceString: String) {
        self.init()
        self.source = sourceString
    }
    
    deinit {
        self.webView?.removeFromSuperview()
    }
    
    // MARK: Accessors
    public func handlerForKey(key: String) -> ((AnyObject!) -> Void)? {
        return self.messageHandlers[key]
    }
    
    public class func signatureForFunction(function: String, thisArg: String = "null", args: [AnyObject] = []) -> String? {
        let argsString = NSString(data: NSJSONSerialization.dataWithJSONObject(args,
            options: nil,
            error: nil) ?? NSData(),
            encoding: NSUTF8StringEncoding)
        
        if argsString == nil {
            return nil
        }
        
        let call = "try {" +
            "\(function).apply(\(thisArg), \(argsString!));" +
            "} catch (err) {" +
            "engine.error.postMessage(err + '');" +
        "}"
        
        return call
    }
    
    // MARK: Mutators
    public func setHandlerForKey(key: String, handler: ((AnyObject!) -> Void)?) {
        self.webView?.configuration.userContentController.removeScriptMessageHandlerForName(key)
        
        if let _handler = handler {
            self.webView?.configuration.userContentController.addScriptMessageHandler(self.responder, name: key)
            self.messageHandlers[key] = _handler
        } else {
            self.messageHandlers.removeValueForKey(key)
        }
    }
    
    // MARK: Load Handlers
    public func load(handler: (() -> Void)? = nil) {
        
        self.loadHandler = nil
        self.loadHandler = handler
        
        if self.source != nil { // Race condition , source has already been set.
            self.webView?.loadHTMLString("<html></html>", baseURL: nil)
        }
    }
    
    public func callFunction(function: String, thisArg: String = "null", args: [AnyObject] = []) {
        if let call = JSEngine.signatureForFunction(function, thisArg: thisArg, args: args) {
            self.webView?.evaluateJavaScript(call, completionHandler: nil)
        } else {
            self.handlerForKey("error")?("Cannot parse args \(args)")
        }
    }
}

// MARK: Default Handlers
private extension JSEngine {
    private func defaultErrorHandler(errObj: AnyObject!) {
        NSException(name: "JSEngineJavascriptException",
            reason: "JSEngine threw a Javascript exception",
            userInfo: ["error": errObj, "source": self.source ?? NSNull()]).raise()
    }
    
    private func httpRequestHandler(requestObject: AnyObject!) {
        if let request = requestObject as? NSDictionary {
            let responseHandler = requestObject["responseHandler"] as! String
            
            // Get URL
            let baseURL = NSURL(string: (requestObject["baseURL"] as? String) ?? "")
            var path = requestObject["path"] as? String ?? "/"
            
            let networkManager = AFHTTPRequestOperationManager(baseURL: baseURL)
            networkManager.responseSerializer = AFHTTPResponseSerializer()
            networkManager.completionQueue = dispatch_get_main_queue()
            
            // Get method
            let methodString = requestObject["method"] as? String ?? "GET"
            let method: ((URLString: String!, parameters: AnyObject!, success: ((AFHTTPRequestOperation!, AnyObject!) -> Void)!, failure: ((AFHTTPRequestOperation!, NSError!) -> Void)!) -> AFHTTPRequestOperation!)
            
            switch (methodString) {
            case "GET":
                method = networkManager.GET
            case "POST":
                method = networkManager.POST
            case "PUT":
                method = networkManager.PUT
            case "DELETE":
                method = networkManager.DELETE
            case "PATCH":
                method = networkManager.PATCH
                
            case "HEAD":
                method = { (URLString: String!, parameters: AnyObject!, success: ((AFHTTPRequestOperation!, AnyObject!) -> Void)!, failure: ((AFHTTPRequestOperation!, NSError!) -> Void)!) in
                    return networkManager.HEAD(URLString,
                        parameters: parameters,
                        success: { (op: AFHTTPRequestOperation!) -> Void in
                            success(op, NSNull())
                    }, failure: failure)
                }
                
            default:
                method = { (URLString: String!, parameters: AnyObject!, success: ((AFHTTPRequestOperation!, AnyObject!) -> Void)!, failure: ((AFHTTPRequestOperation!, NSError!) -> Void)!) in
                    failure(nil, nil)
                    return nil
                }
            }
            
            // Get headers
            if let headers = requestObject["headers"] as? [String: String] {
                for (key, value) in headers {
                    networkManager.requestSerializer.setValue(value, forHTTPHeaderField: key)
                }
            }
            
            // Get params
            var allParams: [String: AnyObject] = [:]
            if let params = requestObject["params"] as? [String: AnyObject] {
                for (key, value) in params {
                    allParams[key] = value
                }
            }
            
            if let body = requestObject["body"] as? [String: AnyObject] {
                for (key, value) in body {
                    allParams[key] = value
                }
            }
            
            // Make call
            let userInfo = requestObject["userInfo"] as? NSDictionary ?? NSDictionary()
            method(URLString: path, parameters: allParams, success: { (op: AFHTTPRequestOperation!, resp: AnyObject!) in
                self.lastHTTPRequest = op
                
                let respString: String
                if let respData = resp as? NSData {
                    respString = (NSString(data: respData, encoding: NSUTF8StringEncoding) as? String) ?? ""
                } else {
                    respString = ""
                }
                
                self.callFunction(responseHandler, args: [
                    respString,
                    userInfo,
                    NSNull()
                ])
            }, failure: { (op: AFHTTPRequestOperation!, error: NSError!) in
                self.lastHTTPRequest = op
                
                self.callFunction(responseHandler, args: [
                    "",
                    userInfo,
                    error.localizedDescription
                ])
            })
        }
    }
}
