import Foundation
import os.log

@MainActor
class HomeViewModel: ObservableObject {
    @Published var buildingDetails: [BuildingDetails] = []
    @Published var favoriteBuildingDetails: [BuildingDetails] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var totalBuildingCount: Int = 0
    @Published var hasMoreContent = true
    
    private let supabase = SupabaseService.shared
    private let cache = BuildingCacheService.shared
    private let logger = Logger(subsystem: "com.illinispots.app", category: "HomeViewModel")
    private let pageSize = 25
    private var currentOffset = 0
    private var isLoadingMore = false
    private var hasFetchedInitialCount = false
    private var lastRefreshTime: Date?
    private let refreshInterval: TimeInterval = 3600 // 1 hour
    
    func loadBuildings(isInitialLoad: Bool = true, forceRefresh: Bool = false) async {
        guard !isLoading else { return }
        isLoading = true
        logger.info("Loading buildings (initial: \(isInitialLoad), force refresh: \(forceRefresh))")
        
        do {
            // Check if we need to refresh from server
            let shouldRefreshFromServer = forceRefresh || 
                lastRefreshTime == nil || 
                Date().timeIntervalSince(lastRefreshTime!) > refreshInterval
            
            if shouldRefreshFromServer {
                logger.info("Refreshing data from server")
                // Get total count from server
                totalBuildingCount = try await supabase.getTotalBuildingCount()
                hasFetchedInitialCount = true
                
                // Fetch all buildings from server
                let buildings = try await supabase.getAllBuildings()
                
                // Update cache with new data
                try await cache.updateCache(with: buildings)
                lastRefreshTime = Date()
                logger.info("Server refresh completed")
            }
            
            if isInitialLoad {
                buildingDetails = []
                currentOffset = 0
                favoriteBuildingDetails = []
            }
            
            // Load from cache
            logger.info("Loading buildings from cache")
            let cachedBuildings = try await cache.loadCachedBuildings()
            
            // Update UI with cached data
            buildingDetails = cachedBuildings
            favoriteBuildingDetails = buildingDetails.filter { $0.isFavorited }
            
            // Update pagination state
            hasMoreContent = buildingDetails.count < totalBuildingCount
            currentOffset += buildingDetails.count
            
            logger.info("Successfully loaded \(self.buildingDetails.count) buildings")
            
        } catch {
            self.error = error
            logger.error("Error loading buildings: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    func loadMoreContent() async {
        guard !isLoading, hasMoreContent, !isLoadingMore else { return }
        isLoadingMore = true
        await loadBuildings(isInitialLoad: false)
        isLoadingMore = false
    }
    
    func refreshBuildings() async {
        logger.info("Manual refresh triggered")
        await loadBuildings(isInitialLoad: true, forceRefresh: true)
    }
    
    func ensureBuildingDataLoaded(_ buildingDetails: BuildingDetails) async {
        // No need to load additional data since BuildingDetails already contains everything
        // and is kept up to date through the cache
    }
} 
