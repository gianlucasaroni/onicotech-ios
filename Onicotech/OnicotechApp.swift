//
//  OnicotechApp.swift
//  Onicotech
//
//  Created by Gianluca Saroni on 10/02/26.
//

import SwiftUI

@main
struct OnicotechApp: App {
    @StateObject private var authManager = AuthenticationManager()
    
    init() {
        KingfisherConfigurator.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
        }
    }
}
