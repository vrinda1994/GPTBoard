//
//  GPTBoardApp.swift
//  GPTBoard
//
//  Created by Karan Khurana on 4/10/23.
//

import SwiftUI
import Firebase

@main
struct GPTBoardApp: App {
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
