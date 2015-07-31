//
//  WKWebView+JSEngineInjection.swift
//  JavascriptEngine
//
//  Created by PATRICK PERINI on 7/31/15.
//  Copyright (c) 2015 Atomic. All rights reserved.
//

import WebKit

public extension WKWebView {
    // MARK: Engine Injection
    public func injectEngine(engine: JSEngine) {
        if let source = engine.source {
            self.configuration.userContentController.addUserScript(WKUserScript(source: source,
                injectionTime: WKUserScriptInjectionTime.AtDocumentEnd,
                forMainFrameOnly: true))
            
            for (key, _) in engine.messageHandlers {
                self.configuration.userContentController.addScriptMessageHandler(engine, name: key)
            }
        }
    }
}