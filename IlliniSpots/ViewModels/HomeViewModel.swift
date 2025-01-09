import Foundation

@MainActor
class HomeViewModel: ObservableObject {
    @Published var buildings: [Building] = []
    @Published var favoriteBuildings: [Building] = []
    @Published var buildingImages: [Int64: String] = [:]
    @Published var isLoading = false
    @Published var error: Error?
    @Published var totalBuildingCount: Int = 0
    @Published var hasMoreContent = true
    
    private let supabase = SupabaseService.shared
    private let pageSize = 25
    private var currentOffset = 0
    private var isLoadingMore = false
    private var hasFetchedInitialCount = false
    
    func loadBuildings(isInitialLoad: Bool = true) async {
        guard !isLoading else { return }
        isLoading = true
        
        do {
            // Always ensure we have the total count
            if !hasFetchedInitialCount {
                totalBuildingCount = try await supabase.getTotalBuildingCount()
                hasFetchedInitialCount = true
            }
            
            if isInitialLoad {
                buildings = []
                currentOffset = 0
                buildingImages = [:]
            }
            
            // Load buildings with pagination
            let newBuildings = try await supabase.getAllBuildings(limit: pageSize, offset: currentOffset)
            buildings.append(contentsOf: newBuildings)
            
            // Update pagination state
            hasMoreContent = buildings.count < totalBuildingCount
            currentOffset += newBuildings.count
            
            // Load favorite buildings if user is signed in
            if isInitialLoad, let userId = UUID(uuidString: "00000000-0000-0000-0000-000000000000") {
                let favorites = try await supabase.getUserBuildingFavorites(userId: userId)
                favoriteBuildings = buildings.filter { building in
                    favorites.contains { $0.buildingId == building.id }
                }
            }
            
            // Load primary images for new buildings
            await loadImagesForBuildings(newBuildings)
        } catch {
            self.error = error
            print("Error loading buildings: \(error)")
        }
        
        isLoading = false
    }
    
    private func loadImagesForBuildings(_ buildings: [Building]) async {
        await withTaskGroup(of: Void.self) { group in
            for building in buildings {
                group.addTask {
                    do {
                        let images = try await self.supabase.getBuildingImages(buildingId: building.id)
                        if let primaryImage = images.first(where: { $0.isPrimary == true }) ?? images.first {
                            await MainActor.run {
                                self.buildingImages[building.id] = primaryImage.url
                            }
                        }
                    } catch {
                        print("Failed to load image for building \(building.id): \(error)")
                    }
                }
            }
        }
    }
    
    func loadMoreContent() async {
        guard !isLoading, hasMoreContent, !isLoadingMore else { return }
        isLoadingMore = true
        await loadBuildings(isInitialLoad: false)
        isLoadingMore = false
    }
    
    func ensureBuildingDataLoaded(_ building: Building) async {
        // Ensure image is loaded for visible building
        if buildingImages[building.id] == nil {
            await loadImagesForBuildings([building])
        }
    }
} 