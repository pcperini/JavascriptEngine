//
//  JSEngineTests.swift
//  JavascriptEngineTests
//
//  Created by PATRICK PERINI on 7/14/15.
//  Copyright (c) 2015 Atomic. All rights reserved.
//

import UIKit
import XCTest

class JSEngineTests: XCTestCase {
    static let defaultTimeout: NSTimeInterval = 5
    
    func testLoading() {
        let expectation = self.expectationWithDescription("load handler was called")
        let engine = JSEngine(sourceString: "")
        
        engine.load {
            expectation.fulfill()
        }
        self.waitForExpectationsWithTimeout(JSEngineTests.defaultTimeout, handler: nil)
    }
    
    func testDebug() {
        let expectation = self.expectationWithDescription("debug handler was called")
        let engine = JSEngine(sourceString: "function debugTest(message) {" +
            "engine.debug.postMessage(message);" +
        "}")
        
        let message = "hello world"
        engine.debugHandler = {
            XCTAssertNotNil($0 as! String, "Debug message is not string")
            XCTAssertEqual($0 as! String, message, "Debug message was wrong")
            expectation.fulfill()
        }
        
        engine.load {
            engine.callFunction("debugTest", args: [message])
        }
        
        self.waitForExpectationsWithTimeout(JSEngineTests.defaultTimeout, handler: nil)
    }
    
    func testError() {
        let expectation = self.expectationWithDescription("error handler was called")
        let engine = JSEngine(sourceString: "function errorTest(message) {" +
            "throw message;" + // Implict call to engine.error.postMessage()
        "}")
        
        let message = "hello world"
        engine.errorHandler = {
            XCTAssertNotNil($0 as! String, "Error message is not string")
            XCTAssertEqual($0 as! String, message, "Error message was wrong")
            expectation.fulfill()
        }
        
        engine.load {
            engine.callFunction("errorTest", args: [message])
        }
        
        self.waitForExpectationsWithTimeout(JSEngineTests.defaultTimeout, handler: nil)
    }
    
    func testHTTPGet() {
        let expectation = self.expectationWithDescription("http request was successful")
        let engine = JSEngine(sourceString: "function requestTest(endpoint, expectedResponse) {" +
            "engine.httpRequest.postMessage({" +
                "'path': endpoint," +
                "'responseHandler': 'responseTest'," +
                "'params': {'cache': 'bust'}," +
                "'headers': {'User-Agent': 'Mozilla'}," +
                "'userInfo': {'expectedResponse': expectedResponse}" +
            "});" +
        "}" +
            
        "function responseTest(dataString, userInfo) {" +
            "engine.debug.postMessage([dataString, userInfo.expectedResponse]);" +
        "}")
        
        let url = "https://gist.githubusercontent.com/pcperini/7cb055bf8f5d8aa535cc/raw/d3ffcc83dc92829a5e5b3281f871237d28747ed1/gistfile1.txt"
        let expectedResponse = "501DA978-591C-42B3-8449-FBBA67A0662A - VALID"
        
        engine.debugHandler = {
            XCTAssertNotNil($0 as! [String], "Response is not string array")
            
            let response = $0 as! [String]
            XCTAssertTrue(response.count == 2, "Response does not contain 2 element")
            
            XCTAssertEqual(response.first!, response.last!, "Result response does not equal expected response")
            expectation.fulfill()
        }
        
        engine.load {
            engine.callFunction("requestTest", args: [url, expectedResponse])
        }
        
        self.waitForExpectationsWithTimeout(JSEngineTests.defaultTimeout * 10, handler: nil)
    }
    
    func testCustomHandler() {
        let expectation = self.expectationWithDescription("handler test was successful")
        let engine = JSEngine(sourceString: "function handlerTest(message) {" +
            "engine.testHandler.postMessage(message);" +
        "}")
        
        let message = "hello world"
        engine.setHandlerForKey("testHandler") {
            XCTAssertNotNil($0 as! String, "Response is not string")
            XCTAssertEqual($0 as! String, message, "Response does not equal message")
            
            expectation.fulfill()
        }
        
        engine.load {
            engine.callFunction("handlerTest", args: [message])
        }
        
        self.waitForExpectationsWithTimeout(JSEngineTests.defaultTimeout, handler: nil)
    }
    
    func testReloadSource() {
        let expectation = self.expectationWithDescription("load handler was called")
        let engine = JSEngine()
        
        engine.load {
            expectation.fulfill()
        }
        
        engine.setSourceString("")
        self.waitForExpectationsWithTimeout(JSEngineTests.defaultTimeout, handler: nil)
    }
}