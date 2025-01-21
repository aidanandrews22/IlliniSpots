import Foundation
import SwiftData
import os.log

@Model
final class CachedBuilding {
    var id: Int64?
    var name: String?
    var buildingDescription: String?
    var isAvailable: Bool?
    var address: String?
    var hours: String?
    var favorites: Int16?
    var commentCount: Int16?
    var sortedId: Int?
    var lastUpdated: Date?
    
    @Relationship(deleteRule: .cascade)
    var rooms: [CachedRoom]?
    
    @Relationship(deleteRule: .cascade)
    var images: [CachedBuildingImage]?
    
    @Relationship(deleteRule: .cascade)
    var ratings: [CachedBuildingRating]?
    
    init(from building: Building, rooms: [Room] = [], images: [BuildingImage] = [], ratings: [BuildingRating] = []) {
        self.id = building.id
        self.name = building.name
        self.buildingDescription = building.description
        self.isAvailable = building.isAvailable
        self.address = building.address
        self.hours = building.hours
        self.favorites = building.favorites
        self.commentCount = building.commentCount
        self.sortedId = building.sortedId
        self.lastUpdated = Date()
        
        // Initialize relationships
        self.rooms = rooms.map { CachedRoom(from: $0, building: self) }
        self.images = images.map { CachedBuildingImage(from: $0, building: self) }
        self.ratings = ratings.map { CachedBuildingRating(from: $0, building: self) }
    }
}

@Model
final class CachedRoom {
    var id: Int64?
    var buildingId: Int64?
    var roomNumber: String?
    
    @Relationship(deleteRule: .cascade)
    var building: CachedBuilding?
    
    init(from room: Room, building: CachedBuilding? = nil) {
        self.id = room.id
        self.buildingId = room.buildingId
        self.roomNumber = room.roomNumber
        self.building = building
    }
}

@Model
final class CachedBuildingImage {
    var id: Int64?
    var buildingId: Int64?
    var url: String?
    var displayOrder: Int?
    var isPrimary: Bool?
    
    @Relationship(deleteRule: .cascade)
    var building: CachedBuilding?
    
    init(from image: BuildingImage, building: CachedBuilding? = nil) {
        self.id = image.id
        self.buildingId = image.buildingId
        self.url = image.url
        self.displayOrder = image.displayOrder
        self.isPrimary = image.isPrimary
        self.building = building
    }
}

@Model
final class CachedBuildingRating {
    var id: Int64?
    var userId: UUID?
    var buildingId: Int64?
    var rating: Int16?
    var comment: String?
    
    @Relationship(deleteRule: .cascade)
    var building: CachedBuilding?
    
    init(from rating: BuildingRating, building: CachedBuilding? = nil) {
        self.id = rating.id
        self.userId = rating.userId
        self.buildingId = rating.buildingId
        self.rating = rating.rating
        self.comment = rating.comment
        self.building = building
    }
}

actor BuildingCacheService {
    static let shared = BuildingCacheService()
    private let logger = Logger(subsystem: "com.illinispots.app", category: "BuildingCacheService")
    private let supabase = SupabaseService.shared
    private var modelContext: ModelContext?
    
    private init() {}
    
    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        logger.info("BuildingCacheService configured with ModelContext")
    }
    
    func loadCachedBuildings() async throws -> [BuildingDetails] {
        guard let context = modelContext else {
            logger.error("ModelContext not configured")
            throw CacheError.notConfigured
        }
        
        logger.info("Loading buildings from cache...")
        let descriptor = FetchDescriptor<CachedBuilding>(sortBy: [SortDescriptor(\.sortedId)])
        let cachedBuildings = try context.fetch(descriptor)
        
        logger.info("Found \(cachedBuildings.count) buildings in cache")
        
        return cachedBuildings.compactMap { cached in
            // Ensure required fields are present
            guard let id = cached.id,
                  let name = cached.name,
                  let favorites = cached.favorites,
                  let commentCount = cached.commentCount else {
                logger.warning("Skipping cached building due to missing required fields")
                return nil
            }
            
            let building = Building(
                id: id,
                name: name,
                description: cached.buildingDescription,
                isAvailable: cached.isAvailable,
                address: cached.address,
                hours: cached.hours,
                favorites: favorites,
                commentCount: commentCount,
                sortedId: cached.sortedId
            )
            
            let images = (cached.images ?? []).compactMap { image -> BuildingImage? in
                guard let id = image.id,
                      let buildingId = image.buildingId,
                      let url = image.url else { return nil }
                
                return BuildingImage(
                    id: id,
                    buildingId: buildingId,
                    url: url,
                    displayOrder: image.displayOrder,
                    isPrimary: image.isPrimary
                )
            }
            
            let ratings = (cached.ratings ?? []).compactMap { rating -> BuildingRating? in
                guard let id = rating.id,
                      let userId = rating.userId,
                      let buildingId = rating.buildingId,
                      let ratingValue = rating.rating else { return nil }
                
                return BuildingRating(
                    id: id,
                    userId: userId,
                    buildingId: buildingId,
                    rating: ratingValue,
                    comment: rating.comment
                )
            }
            
            let (isOpen, _) = supabase.getBuildingAvailability(buildingId: building.id, hours: building.hours)
            
            return BuildingDetails(
                building: building,
                isOpen: isOpen,
                totalRooms: cached.rooms?.count ?? 0,
                availableRooms: cached.rooms?.count ?? 0, // This will be updated in real-time
                ratings: ratings,
                images: images,
                isFavorited: false // This will be updated based on user state
            )
        }
    }
    
    func updateCache(with buildings: [Building]) async throws {
        guard let context = modelContext else {
            logger.error("ModelContext not configured")
            throw CacheError.notConfigured
        }
        
        logger.info("Starting cache update with \(buildings.count) buildings")
        
        // First, delete all existing cached buildings
        try clearCache()
        
        for building in buildings {
            logger.info("Processing building: \(building.name)")
            
            async let roomsTask = supabase.getRooms(buildingId: building.id)
            async let imagesTask = supabase.getBuildingImages(buildingId: building.id)
            async let ratingsTask = supabase.getBuildingRatings(buildingId: building.id)
            
            let (rooms, images, ratings) = try await (roomsTask, imagesTask, ratingsTask)
            
            // Create new cached building
            let cachedBuilding = CachedBuilding(
                from: building,
                rooms: rooms,
                images: images,
                ratings: ratings
            )
            context.insert(cachedBuilding)
            
            logger.info("Cached building \(building.name) with \(rooms.count) rooms, \(images.count) images, and \(ratings.count) ratings")
        }
        
        try context.save()
        logger.info("Cache update completed successfully")
    }
    
    func clearCache() throws {
        guard let context = modelContext else {
            logger.error("ModelContext not configured")
            throw CacheError.notConfigured
        }
        
        logger.info("Clearing building cache...")
        let descriptor = FetchDescriptor<CachedBuilding>()
        let cachedBuildings = try context.fetch(descriptor)
        cachedBuildings.forEach { context.delete($0) }
        try context.save()
        logger.info("Building cache cleared successfully")
    }
    
    enum CacheError: Error {
        case notConfigured
    }
} 