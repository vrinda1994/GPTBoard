//
//  ChatGPTHandler.swift
//  GPTBoard
//
//  Created by Karan Khurana on 4/14/23.
//

import Foundation

class ChatGPTHandler {
    private let sharedDefaults: UserDefaults = {
        let suiteName = "group.com.mmcm.gptboard"
        return UserDefaults(suiteName: suiteName)!
    }()
    
    private let pendingMessageKey = "PendingMessage"

    func savePendingMessage(_ message: String) {
        sharedDefaults.set(message, forKey: pendingMessageKey)
        sharedDefaults.synchronize()
    }

    func fetchPendingMessage() -> String? {
        return sharedDefaults.string(forKey: pendingMessageKey)
    }

    func clearPendingMessage() {
        sharedDefaults.removeObject(forKey: pendingMessageKey)
    }
}
