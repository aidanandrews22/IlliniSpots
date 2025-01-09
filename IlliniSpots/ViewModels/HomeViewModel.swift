import Foundation

@MainActor
class HomeViewModel: ObservableObject {
    @Published var buildings: [Building] = []
    @Published var favoriteBuildings: [Building] = []
    @Published var buildingImages: [Int64: String] = [:]
    @Published var isLoading = false
    @Published var error: Error?
    
    private let supabase = SupabaseService.shared
    
    func loadBuildings() async {
        isLoading = true
        error = nil
        
        do {
            // Load all buildings
            buildings = try await supabase.getAllBuildings()
            
            // Load favorite buildings if user is signed in
            // TODO: Replace with actual user ID when authentication is implemented
            if let userId = UUID(uuidString: "00000000-0000-0000-0000-000000000000") {
                let favorites = try await supabase.getUserBuildingFavorites(userId: userId)
                favoriteBuildings = buildings.filter { building in
                    favorites.contains { $0.buildingId == building.id }
                }
            }
            
            // Load primary images for each building
            for building in buildings {
                let images = try await supabase.getBuildingImages(buildingId: building.id)
                if let primaryImage = images.first(where: { $0.isPrimary == true }) ?? images.first {
                    buildingImages[building.id] = primaryImage.url
                }
            }
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
} 