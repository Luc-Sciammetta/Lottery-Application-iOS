//
//  ContentView.swift
//  Lottery App
//
//  Created by Luc Sciammetta on 3/23/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
            Text("This will become a lottery app!")
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
