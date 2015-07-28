//
//  JSEngine+RemoteSourceFileTests.swift
//  JavascriptEngine
//
//  Created by PATRICK PERINI on 7/28/15.
//  Copyright (c) 2015 Atomic. All rights reserved.
//

import Foundation
import XCTest

class JSEngine_RemoteSourceFileTests: XCTestCase {
    static let defaultTimeout: NSTimeInterval = 50
    
    private class JSRemoteSourceFileTestDelegate: NSObject, JSRemoteSourceFileDelegate {
        var handler: ((JSRemoteSourceFile, String?) -> Void)?
        func remoteSoureFile(file: JSRemoteSourceFile, didUpdateContent content: String?) {
            self.handler?(file, content)
        }
    }
    
    func testRemoteFetchingAndDebug() {
        let expectation = self.expectationWithDescription("debug handler was called")
        
        let remoteFile = JSRemoteSourceFile(remoteURL: NSURL(string: "https://gist.githubusercontent.com/pcperini/7c5d6520f630d56d6357/raw/a9273d18defde05476b7380eb4fcd5f1debe6c17/gistfile2.js")!)
        let engine = JSEngine(remoteSourceFile: remoteFile)
        
        let message = "hello world"
        engine.debugHandler = {
            XCTAssertNotNil($0 as! String, "Debug message is not string")
            XCTAssertEqual($0 as! String, message, "Debug message was wrong")
            expectation.fulfill()
        }
        
        engine.load {
            engine.callFunction("debugTest", args: [message])
        }

        self.waitForExpectationsWithTimeout(JSEngine_RemoteSourceFileTests.defaultTimeout, handler: nil)
    }

}