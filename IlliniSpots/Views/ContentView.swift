import SwiftUI

struct ContentView: View {
    let categories = ["All", "Available", "Favorites", "Libraries"]
    
    @State private var selectedCategory = "All"
    @State private var buildings: [BuildingDetails] = []
    @State private var isLoading = false
    @State private var currentPage = 0
    @State private var hasMoreData = true
    @State private var userId: UUID? = nil // This should be set from your auth system
    
    private let pageSize = 25
    
    var filteredBuildings: [BuildingDetails] {
        switch selectedCategory {
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
    
    func loadMoreContent() async {
        guard !isLoading && hasMoreData else { return }
        
        isLoading = true
        do {
            let newBuildings = try await SupabaseService.shared.getAllBuildingsWithDetails(
                limit: pageSize,
                offset: currentPage * pageSize,
                userId: userId,
                onBuildingReady: { building in
                    // Update UI on main thread as each building becomes ready
                    DispatchQueue.main.async {
                        buildings.append(building)
                    }
                }
            )
            
            // Update pagination state
            await MainActor.run {
                if newBuildings.isEmpty {
                    hasMoreData = false
                } else {
                    currentPage += 1
                }
                isLoading = false
            }
        } catch {
            print("Error loading buildings: \(error)")
            await MainActor.run {
                isLoading = false
            }
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
                    BuildingListView(
                        buildings: filteredBuildings,
                        userId: userId,
                        isLoading: isLoading,
                        onLoadMore: {
                            if hasMoreData {
                                Task {
                                    await loadMoreContent()
                                }
                            }
                        }
                    )
                }
            }
            .navigationBarHidden(true)
            .background(Color(.systemBackground))
            .task {
                if buildings.isEmpty {
                    await loadMoreContent()
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
} 