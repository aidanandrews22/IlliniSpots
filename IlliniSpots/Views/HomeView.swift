import SwiftUI
import SwiftData

struct HomeView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    @Environment(\.modelContext) private var modelContext
    let categories = ["All", "Open", "Available", "Favorites", "Libraries"]
    
    @State private var selectedCategory = "All"
    @State private var buildings: [BuildingDetails] = []
    @State private var isLoading = false
    @State private var totalBuildingCount = 0
    
    var filteredBuildings: [BuildingDetails] {
        switch selectedCategory {
        case "Open":
            return buildings.filter { $0.isOpen }
        case "Available":
            return buildings.filter { $0.isOpen && $0.availableRooms > 0 }
        case "Libraries":
            return buildings.filter { $0.building.name.contains("Library") }
        case "Favorites":
            return buildings.filter { $0.isFavorited }
        default:
            return buildings
        }
    }
    
    func loadContent() async {
        await MainActor.run {
            isLoading = true
            buildings = [] // Clear existing buildings
        }
        
        // Show cached data first
        do {
            let cachedBuildings = try await BuildingCacheService.shared.loadCachedBuildings()
            if !cachedBuildings.isEmpty {
                await MainActor.run {
                    buildings = cachedBuildings
                    totalBuildingCount = cachedBuildings.count
                }
            }
        } catch {
            print("Error loading from cache: \(error)")
        }
        
        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                // Update terms in parallel
                group.addTask {
                    do {
                        try await BuildingCacheService.shared.updateTermsCache()
                    } catch {
                        print("Error updating terms cache: \(error)")
                    }
                }
                
                // Fetch buildings in parallel
                group.addTask {
                    let count = try await SupabaseService.shared.getTotalBuildingCount()
                    await MainActor.run {
                        totalBuildingCount = count
                    }
                    
                    // Create a temporary array to collect buildings
                    var tempBuildings: [BuildingDetails] = []
                    
                    // Retrieve all buildings with concurrency
                    let freshBuildings = try await SupabaseService.shared.getAllBuildingsWithDetails(
                        limit: count,
                        offset: 0,
                        userId: authManager.userId,
                        onBuildingReady: { details in
                            tempBuildings.append(details)
                        }
                    )
                    
                    // Update UI with complete set of buildings
                    await MainActor.run {
                        buildings = freshBuildings
                    }
                }
                
                // Wait for both tasks
                try await group.waitForAll()
            }
            
            // Optionally update the local cache in the background
            Task {
                do {
                    try await BuildingCacheService.shared.updateCache(with: buildings.map(\.building))
                } catch {
                    print("Error updating cache: \(error)")
                }
            }
        } catch {
            print("Error loading from Supabase: \(error)")
        }
        
        await MainActor.run {
            isLoading = false
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                SearchBarView()
                
                CategoryFilterView(
                    categories: categories,
                    selectedCategory: $selectedCategory
                )
                
                ScrollView {
                    if isLoading && buildings.isEmpty {
                        ProgressView("Loading buildings...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.top, 40)
                    } else {
                        BuildingListView(
                            buildings: filteredBuildings,
                            userId: authManager.userId,
                            isLoading: isLoading,
                            onLoadMore: { }, // No more pagination needed
                            totalBuildings: totalBuildingCount,
                            category: selectedCategory,
                            hasMoreData: false // We always have all data
                        )
                    }
                }
            }
            .navigationBarHidden(true)
            .background(Color(.systemBackground))
            .task {
                // Configure cache service with model context
                BuildingCacheService.shared.configure(modelContext)
                
                // Load data on first launch
                if buildings.isEmpty {
                    await loadContent()
                }
            }
            .refreshable {
                // Allow manual refresh
                await loadContent()
            }
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthenticationManager())
} 