//
//  JSRemoteSourceFileTests.swift
//  JavascriptEngine
//
//  Created by PATRICK PERINI on 7/20/15.
//  Copyright (c) 2015 Atomic. All rights reserved.
//

import Foundation
import XCTest

class JSRemoteSourceFileTests: XCTestCase {
    static let defaultTimeout: NSTimeInterval = 5
    
    private class JSRemoteSourceFileTestDelegate: NSObject, JSRemoteSourceFileDelegate {
        var handler: ((JSRemoteSourceFile, String?) -> Void)?
        @objc func remoteSoureFile(file: JSRemoteSourceFile, didUpdateContent content: String?) {
            self.handler?(file, content)
        }
    }

    func testRemoteFetching() {
        let expectation = self.expectationWithDescription("Source file did load from remote")
        let remoteURL = NSURL(string: "https://gist.githubusercontent.com/pcperini/7cb055bf8f5d8aa535cc/raw/d3ffcc83dc92829a5e5b3281f871237d28747ed1/gistfile1.txt")!

        let remoteSourceFileDelegate = JSRemoteSourceFileTestDelegate()
        
        let remoteSourceFile = JSRemoteSourceFile(remoteURL: remoteURL)
        remoteSourceFile.delegate = remoteSourceFileDelegate
        
        remoteSourceFileDelegate.handler = { (file: JSRemoteSourceFile, content: String?) in
            XCTAssertNotNil(remoteSourceFile, "Remote source file is nil")
            
            XCTAssertNotNil(content, "Remote content is nil")
            XCTAssertEqual(remoteSourceFile.content!, "501DA978-591C-42B3-8449-FBBA67A0662A - VALID", "Remote source file content not correct")
            expectation.fulfill()
        }
        
        remoteSourceFile.updateContent()
        self.waitForExpectationsWithTimeout(JSRemoteSourceFileTests.defaultTimeout * 10, handler: nil)
    }
    
    func testFilePersistence() {
        let expectation = self.expectationWithDescription("Source file did load from remote")
        let remoteURL = NSURL(string: "https://gist.githubusercontent.com/pcperini/7cb055bf8f5d8aa535cc/raw/d3ffcc83dc92829a5e5b3281f871237d28747ed1/gistfile1.txt")!
        
        let remoteSourceFileDelegate = JSRemoteSourceFileTestDelegate()
        let remoteSourceFile = JSRemoteSourceFile(remoteURL: remoteURL)
        remoteSourceFile.delegate = remoteSourceFileDelegate
        
        var repeatLocally = true
        remoteSourceFileDelegate.handler = { (file: JSRemoteSourceFile, content: String?) in
            XCTAssertNotNil(file, "Remote source file is nil")
            
            XCTAssertNotNil(content, "Remote content is nil")
            XCTAssertEqual(file.content!, "501DA978-591C-42B3-8449-FBBA67A0662A - VALID", "Remote source file content not correct")
            
            if repeatLocally {
                // This test takes advantage of the fact that colliding file names will reference the same source.
                // This is intentional.
                let remoteSourceFile = JSRemoteSourceFile(remoteURL: NSURL(fileURLWithPath: remoteURL.lastPathComponent!)!)
                remoteSourceFile.delegate = remoteSourceFileDelegate

                repeatLocally = false
                remoteSourceFile.updateContent()
            } else {
                expectation.fulfill()
            }
        }
        
        remoteSourceFile.updateContent()
        self.waitForExpectationsWithTimeout(JSRemoteSourceFileTests.defaultTimeout * 10, handler: nil)
    }
}