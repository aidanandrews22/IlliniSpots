import Foundation

@MainActor
class HomeViewModel: ObservableObject {
    @Published var buildingDetails: [BuildingDetails] = []
    @Published var favoriteBuildingDetails: [BuildingDetails] = []
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
                buildingDetails = []
                currentOffset = 0
                favoriteBuildingDetails = []
            }
            
            // Load buildings with details
            let newBuildingDetails = try await supabase.getAllBuildingsWithDetails(
                limit: pageSize,
                offset: currentOffset,
                userId: UUID(uuidString: "00000000-0000-0000-0000-000000000000")
            )
            
            buildingDetails.append(contentsOf: newBuildingDetails)
            
            // Update favorites
            favoriteBuildingDetails = buildingDetails.filter { $0.isFavorited }
            
            // Update pagination state
            hasMoreContent = buildingDetails.count < totalBuildingCount
            currentOffset += newBuildingDetails.count
            
        } catch {
            self.error = error
            print("Error loading buildings: \(error)")
        }
        
        isLoading = false
    }
    
    func loadMoreContent() async {
        guard !isLoading, hasMoreContent, !isLoadingMore else { return }
        isLoadingMore = true
        await loadBuildings(isInitialLoad: false)
        isLoadingMore = false
    }
    
    func ensureBuildingDataLoaded(_ buildingDetails: BuildingDetails) async {
        // No need to load additional data since BuildingDetails already contains everything
    }
} 