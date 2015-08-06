//
//  JSEngine+RemoteSourceFileTests.swift
//  JavascriptEngine
//
//  Created by PATRICK PERINI on 7/28/15.
//  Copyright (c) 2015 Atomic. All rights reserved.
//

import Foundation
import XCTest
import WebKit

class WKWebView_JSEngineInjectionTests: XCTestCase {
    static let defaultTimeout: NSTimeInterval = 20

    func testInjection() {
        let expectation = self.expectationWithDescription("engine was successfully injected")
        
        let webView = WKWebView()
        webView.loadHTMLString("<html>" +
            "<body>" +
                "<div id='test_id'>Hello!</div>" +
            "</body>" +
        "</html>", baseURL: nil)
        
        let engine = JSEngine(sourceString: "" +
            "engine.success.postMessage(document.getElementById('test_id') != null);" +
        "")
        
        engine.setHandlerForKey("success") { (resultObject: AnyObject!) in
            if resultObject as? Bool == true {
                expectation.fulfill()
            }
        }
        
        webView.injectEngine(engine)
        engine.load {}
        
        self.waitForExpectationsWithTimeout(WKWebView_JSEngineInjectionTests.defaultTimeout, handler: nil)
    }
    
    func testSignature() {
        let expectation = self.expectationWithDescription("signature-generated call worked")
        let expectedValue = "goodbye world"
        
        let webView = WKWebView()
        webView.loadHTMLString("<html>" +
            "<head>" +
                "<source type='text/javascript'>" +
                    "var testGlobalVar = 'hello world';" +
                "</source>" +
            "</head>" +
        "</html>", baseURL: nil)
        
        let engine = JSEngine(sourceString: "function testFunc() {" +
            "testGlobalVar = '\(expectedValue)';" +
        "}")
        
        webView.injectEngine(engine)
        engine.load {
            let call = JSEngine.signatureForFunction("testFunc")
            webView.evaluateJavaScript(call!) { (_: (AnyObject!, NSError!)) in
                webView.evaluateJavaScript("testGlobalVar") { (result: (AnyObject!, NSError!)) in
                    XCTAssertNotNil(result.0 as? String, "Result is not a string")
                    XCTAssertEqual(expectedValue, result.0 as! String, "Results does not equal expected value")
                    expectation.fulfill()
                }
            }
        }
        
        self.waitForExpectationsWithTimeout(10, handler: nil)
    }
    
    func testWebViewRelease() {
        let webView = WKWebView()
        webView.loadHTMLString("<html>" +
            "<body>" +
                "<div id='test_id'>Hello!</div>" +
            "</body>" +
        "</html>", baseURL: nil)
        
        if (true) { // scope offset
            let engine = JSEngine(sourceString: "" +
                "engine.success.postMessage(document.getElementById('test_id') != null);" +
            "")
            
            webView.injectEngine(engine)
            XCTAssertGreaterThan(UIApplication.sharedApplication().keyWindow!.subviews.count, 1, "engine's web view not added to window")
            // engine will fall out of scope, should take own web view with it
        }
        
        XCTAssertLessThan(UIApplication.sharedApplication().keyWindow!.subviews.count, 2, "engine's web view not removed from window")
    }
}