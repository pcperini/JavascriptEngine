//
//  JSEngine.swift
//  JavascriptEngine
//
//  Created by PATRICK PERINI on 7/14/15.
//  Copyright (c) 2015 Atomic. All rights reserved.
//

import UIKit
import WebKit

class JSEngine: NSObject {
    // MARK: Constants
    private static let globalVars = "var engine = window.webkit.messageHandlers;"
    private static let mainFunc = "window.onload = function () {engine.load.postMessage(null);}"
    
    // MARK: Properties
    private var webView: WKWebView
    private var messageHandlers: [String: (AnyObject!) -> Void] = [:]
    
    var debugHandler: ((AnyObject!) -> Void)? {
        get { return self.handlerForKey("debug") }
        set { self.setHandlerForKey("debug", handler: newValue) }
    }
    
    var errorHandler: ((AnyObject!) -> Void)? {
        get { return self.handlerForKey("error") }
        set { self.setHandlerForKey("error", handler: newValue) }
    }
    
    private var source: String {
        return self.webView.configuration.userContentController.userScripts.reduce("") {
            "\($0)\n\($1.source!)"
        }
    }
    
    // MARK: Initializers
    init(sourceString: String) {
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
        (UIApplication.sharedApplication().windows.first as? UIWindow)?.addSubview(self.webView)
        
        super.init()
        self.setHandlerForKey("httpRequest", handler: self.httpRequestHandler)
    }
    
    deinit {
        self.webView.removeFromSuperview()
    }
    
    // MARK: Accessors
    func handlerForKey(key: String) -> ((AnyObject!) -> Void)? {
        return self.messageHandlers[key]
    }
    
    // MARK: Mutators
    func setHandlerForKey(key: String, handler: ((AnyObject!) -> Void)?) {
        self.webView.configuration.userContentController.addScriptMessageHandler(self, name: key)
        self.messageHandlers[key] = handler
    }
    
    // MARK: Load Handlers
    func load(handler: (() -> Void)? = nil) {
        self.setHandlerForKey("load", handler: { (_: AnyObject!) in handler?() })
        self.webView.loadHTMLString("<html></html>", baseURL: nil)
    }
    
    func callFunction(function: String, thisArg: String = "null", args: [AnyObject]) {
        let argsString = NSString(data: NSJSONSerialization.dataWithJSONObject(args,
            options: nil,
            error: nil) ?? NSData(),
            encoding: NSUTF8StringEncoding)
        
        if argsString == nil {
            self.errorHandler?("Cannot parse args \(args)")
            return
        }
        
        let call = "try {" +
            "\(function).apply(\(thisArg), \(argsString!));" +
        "} catch (err) {" +
            "engine.error.postMessage(err + '');" +
        "}"
        
        self.webView.evaluateJavaScript(call, completionHandler: nil)
    }
    
    private func httpRequestHandler(requestObject: AnyObject!) {
        if let request = requestObject as? NSDictionary {
            let responseHandler = requestObject["responseHandler"] as! String
            let method = requestObject["method"] as? String ?? "GET"

            let baseURL = NSURL(string: (requestObject["baseURL"] as? String) ?? "")
            var path = requestObject["path"] as? String ?? "/"
            
            if let params = requestObject["params"] as? [String: AnyObject] {
                var paramPairs: [String] = []
                for (key, value) in params {
                    let (safeKey, safeValue) = (
                        key.stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding)!,
                        value.stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding)!
                    )
                    
                    paramPairs.append("\(safeKey)=\(safeValue)")
                }
                
                let paramsString = "&".join(paramPairs)
                path = "\(path)?\(paramsString)"
            }
            
            let fullURL = NSURL(string: path, relativeToURL: baseURL)!
            var urlRequest = NSMutableURLRequest(URL: fullURL)
            urlRequest.HTTPMethod = method
            
            if let headers = requestObject["headers"] as? [String: String] {
                for (key, value) in headers {
                    urlRequest.setValue(value, forHTTPHeaderField: key)
                }
            }
            
            if let body = requestObject["body"] as? NSObject {
                urlRequest.HTTPBody = NSJSONSerialization.dataWithJSONObject(body,
                    options: nil,
                    error: nil)
            }
            
            let userInfo = requestObject["userInfo"] as? NSDictionary ?? NSDictionary()
            NSURLConnection.sendAsynchronousRequest(urlRequest, queue: NSOperationQueue.mainQueue()) { (response: NSURLResponse!, data: NSData!, error: NSError!) in
                let dataString = NSString(data: data, encoding: NSUTF8StringEncoding) ?? ""
                self.callFunction(responseHandler, args: [
                    dataString,
                    userInfo
                ])
            }
        }
    }
}

extension JSEngine: WKScriptMessageHandler {
    @objc func userContentController(userContentController: WKUserContentController, didReceiveScriptMessage message: WKScriptMessage) {
        dispatch_async(dispatch_get_main_queue()) {
            self.handlerForKey(message.name)?(message.body)
        }
    }
}
