//
//  TempApp.swift
//  Temp
//
//  Created by Aidan Andrews on 1/7/25.
//

import SwiftUI
import AuthenticationServices
import os.log
import SwiftData

@main
struct IlliniSpotsApp: App {
    @StateObject private var authManager = AuthenticationManager()
    private let logger = Logger(subsystem: "com.illinispots.app", category: "IlliniSpotsApp")
    
    let modelContainer: ModelContainer
    
    init() {
        do {
            // Configure SwiftData
            let schema = Schema([
                CachedBuilding.self,
                CachedRoom.self,
                CachedBuildingImage.self,
                CachedBuildingRating.self,
                CachedTerm.self
            ])
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                cloudKitDatabase: .none // Disable CloudKit integration
            )
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            
            // Configure BuildingCacheService with the model context
            configureBuildingCacheService(modelContainer: modelContainer)
            
            logger.info("SwiftData and BuildingCacheService configured successfully")
        } catch {
            logger.error("Failed to configure SwiftData: \(error.localizedDescription)")
            fatalError("Failed to configure SwiftData: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .onAppear {
                    authManager.checkCredentialState()
                }
        }
        .modelContainer(modelContainer)
    }
    
    private func configureBuildingCacheService(modelContainer: ModelContainer) {
        BuildingCacheService.shared.configure(modelContainer.mainContext)
    }
}

