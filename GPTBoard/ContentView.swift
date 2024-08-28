//
//  ContentView.swift
//  GPTBoard
//
//  Created by Karan Khurana on 4/10/23.
//

import SwiftUI

struct ContentView: View {
    
    @State private var username: String = ""
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundColor(.accentColor)
            TextField("User name (email address)",
                      text: $username)
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
