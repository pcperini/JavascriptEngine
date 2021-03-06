//
//  JSEngine+RemoteSourceFile.swift
//  JavascriptEngine
//
//  Created by PATRICK PERINI on 7/22/15.
//  Copyright (c) 2015 Atomic. All rights reserved.
//

// MARK: Remote Source File Support
public extension JSEngine {
    public convenience init(remoteSourceFile: JSRemoteSourceFile) {
        self.init()
        remoteSourceFile.delegate = self
        remoteSourceFile.updateContent()
    }
}

extension JSEngine: JSRemoteSourceFileDelegate {
    public func remoteSoureFile(file: JSRemoteSourceFile, didUpdateContent content: String?) {
        if let content = content {
            self.source = content
        }
    }
}
