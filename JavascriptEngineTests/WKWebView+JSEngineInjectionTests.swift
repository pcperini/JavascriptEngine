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
}