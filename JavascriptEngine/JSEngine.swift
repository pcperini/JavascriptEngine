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
    // MARK: Constants
    private static let globalVars = "var engine = window.webkit.messageHandlers;"
    private static let mainFunc = "window.onload = function () {engine.load.postMessage(null);}"
    
    // MARK: Properties
    private var webView: WKWebView? {
        willSet {
            // Remove old reference to self for scriptMessageHandler
            for (key, _) in self.messageHandlers {
                self.webView?.configuration.userContentController.removeScriptMessageHandlerForName(key)
            }
        }
        
        didSet {
            // Migrate message handlers            
            for (key, value) in self.messageHandlers {
                self.setHandlerForKey(key, handler: value)
            }
            
            if self.handlerForKey("httpRequest") == nil {
                self.setHandlerForKey("httpRequest", handler: self.httpRequestHandler)
            }
            
            if self.handlerForKey("error") == nil {
                self.setHandlerForKey("error") { (errObj: AnyObject!) in
                    NSException(name: "JSEngineJavascriptException",
                        reason: "JSEngine threw a Javascript exception",
                        userInfo: ["error": errObj]).raise()
                }
            }
        }
    }
    
    private var messageHandlers: [String: (AnyObject!) -> Void] = [:]
    
    var debugHandler: ((AnyObject!) -> Void)? {
        get { return self.handlerForKey("debug") }
        set { self.setHandlerForKey("debug", handler: newValue) }
    }
    
    var errorHandler: ((NSError!) -> Void) {
        get {
            return self.handlerForKey("error") as ((NSError!) -> Void)!
        }
        
        set {
            self.setHandlerForKey("error") { (errObject: AnyObject!) in
                let err = NSError(domain: __FILE__, code: -1, userInfo: ["error": errObject])
                newValue(err)
            }
        }
    }
    
    private var loadHandler: (() -> Void)? {
        get {
            if let handler = self.handlerForKey("load") {
                return { handler(nil) }
            } else {
                return nil
            }
        }
        
        set {
            if let handler = newValue {
                self.setHandlerForKey("load") { (_: AnyObject!) in
                    handler()
                }
            } else {
                self.setHandlerForKey("load", handler: nil)
            }
        }
    }
    
    private var source: String? {
        return self.webView?.configuration.userContentController.userScripts.reduce("") {
            "\($0!)\n\($1.source!)"
        }
    }
    
    // MARK: Initializers
    override init() {
        super.init()
    }
    
    convenience init(sourceString: String) {
        self.init()
        self.setSourceString(sourceString)
    }
    
    deinit {
        self.webView?.removeFromSuperview()
    }
    
    // MARK: Accessors
    func handlerForKey(key: String) -> ((AnyObject!) -> Void)? {
        return self.messageHandlers[key]
    }
    
    // MARK: Mutators
    func setHandlerForKey(key: String, handler: ((AnyObject!) -> Void)?) {
        self.webView?.configuration.userContentController.removeScriptMessageHandlerForName(key)
        
        if let _handler = handler {
            self.webView?.configuration.userContentController.addScriptMessageHandler(self, name: key)
            self.messageHandlers[key] = _handler
        } else {
            self.messageHandlers.removeValueForKey(key)
        }
    }
    
    internal func setSourceString(sourceString: String) {
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
        (UIApplication.sharedApplication().windows.first as? UIWindow)?.addSubview(self.webView!)
        
        if self.loadHandler != nil { // Race condition, loadHandler has already been set.
            self.load(handler: self.loadHandler)
        }
    }
    
    // MARK: Load Handlers
    func load(handler: (() -> Void)? = nil) {
        
        self.loadHandler = nil
        self.loadHandler = handler
        
        if self.source != nil { // Race condition , source has already been set.
            self.webView?.loadHTMLString("<html></html>", baseURL: nil)
        }
    }
    
    func callFunction(function: String, thisArg: String = "null", args: [AnyObject]) {
        let argsString = NSString(data: NSJSONSerialization.dataWithJSONObject(args,
            options: nil,
            error: nil) ?? NSData(),
            encoding: NSUTF8StringEncoding)
        
        if argsString == nil {
            self.handlerForKey("error")?("Cannot parse args \(args)")
            return
        }

        let call = "try {" +
            "\(function).apply(\(thisArg), \(argsString!));" +
        "} catch (err) {" +
            "engine.error.postMessage(err + '');" +
        "}"
        
        self.webView?.evaluateJavaScript(call, completionHandler: nil)
    }
}

extension JSEngine: WKScriptMessageHandler {
    @objc public func userContentController(userContentController: WKUserContentController, didReceiveScriptMessage message: WKScriptMessage) {
        dispatch_async(dispatch_get_main_queue()) {
            self.handlerForKey(message.name)?(message.body)
        }
    }
}

// MARK: Default Handlers
private extension JSEngine {
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
                let respString: String
                if let respData = resp as? NSData {
                    respString = (NSString(data: respData, encoding: NSUTF8StringEncoding) as? String) ?? ""
                } else {
                    respString = ""
                }
                
                self.callFunction(responseHandler, args: [
                    respString,
                    userInfo
                ])
            }, failure: { (op: AFHTTPRequestOperation!, error: NSError!) in
                self.callFunction(responseHandler, args: [
                    "",
                    userInfo
                ])
            })
        }
    }
}
