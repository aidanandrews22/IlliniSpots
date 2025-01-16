//
//  TempApp.swift
//  Temp
//
//  Created by Aidan Andrews on 1/7/25.
//

import SwiftUI
import AuthenticationServices
import os.log

@main
struct IlliniSpotsApp: App {
    @StateObject private var authManager = AuthenticationManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .onAppear {
                    authManager.checkCredentialState()
                }
        }
    }
}
