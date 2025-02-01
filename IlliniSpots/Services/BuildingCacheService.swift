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

@Model
final class CachedTerm {
    var id: Int64
    var year: Int
    var term: String
    var yearTerm: String
    var partOfTerm: String
    var startDate: Date
    var endDate: Date
    var lastUpdated: Date?
    
    init(from term: Term) {
        self.id = term.id
        self.year = term.year
        self.term = term.term
        self.yearTerm = term.yearTerm
        self.partOfTerm = term.partOfTerm
        self.startDate = term.startDate
        self.endDate = term.endDate
        self.lastUpdated = Date()
    }
}

@globalActor actor BuildingCacheActor {
    static let shared = BuildingCacheActor()
}

@BuildingCacheActor
final class BuildingCacheService {
    static let shared = BuildingCacheService()
    private let logger = Logger(subsystem: "com.illinispots.app", category: "BuildingCacheService")
    private let supabase = SupabaseService.shared
    private var modelContext: ModelContext?
    private let cacheExpirationInterval: TimeInterval = 60 * 60 * 24 // 24 hours
    
    private init() {}
    
    nonisolated func configure(_ context: ModelContext) {
        Task { @BuildingCacheActor in
            self.modelContext = context
            logger.info("BuildingCacheService configured with ModelContext")
        }
    }
    
    func loadCachedBuildings() async throws -> [BuildingDetails] {
        guard let context = modelContext else {
            logger.error("ModelContext not configured")
            throw CacheError.notConfigured
        }
        
        logger.info("Loading buildings from cache...")
        let descriptor = FetchDescriptor<CachedBuilding>(sortBy: [SortDescriptor(\.sortedId)])
        let cachedBuildings = try await MainActor.run {
            try context.fetch(descriptor)
        }
        
        logger.info("Found \(cachedBuildings.count) buildings in cache")
        
        return try await withThrowingTaskGroup(of: BuildingDetails?.self) { group in
            for cached in cachedBuildings {
                group.addTask {
                    guard let id = cached.id,
                          let name = cached.name,
                          let favorites = cached.favorites,
                          let commentCount = cached.commentCount else {
                        self.logger.warning("Skipping cached building due to missing required fields")
                        return nil
                    }
                    
                    // Create the model for the building
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
                    
                    // Collect rating/image data from CachedBuilding as before
                    let images = try await MainActor.run {
                        (cached.images ?? []).compactMap { image -> BuildingImage? in
                            guard let imgId = image.id,
                                  let bldId = image.buildingId,
                                  let url = image.url
                            else { return nil }
                            return BuildingImage(
                                id: imgId,
                                buildingId: bldId,
                                url: url,
                                displayOrder: image.displayOrder,
                                isPrimary: image.isPrimary
                            )
                        }
                        .sorted {
                            // keep primary images first
                            if $0.isPrimary == true && $1.isPrimary != true { return true }
                            if $1.isPrimary == true && $0.isPrimary != true { return false }
                            return ($0.displayOrder ?? 0) < ($1.displayOrder ?? 0)
                        }
                    }
                    
                    let ratings = try await MainActor.run {
                        (cached.ratings ?? []).compactMap { rating -> BuildingRating? in
                            guard let ratingId = rating.id,
                                  let userId = rating.userId,
                                  let buildingId = rating.buildingId,
                                  let ratingValue = rating.rating
                            else { return nil }
                            return BuildingRating(
                                id: ratingId,
                                userId: userId,
                                buildingId: buildingId,
                                rating: ratingValue,
                                comment: rating.comment
                            )
                        }
                    }
                    
                    // 1) Determine if building is open via hours-based logic
                    let (isOpen, _) = self.supabase.getBuildingAvailability(buildingId: building.id, hours: building.hours ?? "")
                    
                    // 2) Get the actual total rooms and available rooms from the service
                    let (totalRooms, actualAvailableRooms) = try await self.supabase.getRoomCounts(buildingId: building.id)
                    
                    return BuildingDetails(
                        building: building,
                        isOpen: isOpen,
                        totalRooms: totalRooms,
                        availableRooms: isOpen ? actualAvailableRooms : 0,
                        ratings: ratings,
                        images: images,
                        isFavorited: false // updated separately if user is logged in
                    )
                }
            }
            
            var results: [BuildingDetails] = []
            for try await buildingDetails in group {
                if let details = buildingDetails {
                    results.append(details)
                }
            }
            
            // Sort by sortedId so it matches your preferred order
            return results.sorted { ($0.building.sortedId ?? 0) < ($1.building.sortedId ?? 0) }
        }
    }
    
    func updateCache(with buildings: [Building]) async throws {
        guard let context = modelContext else {
            logger.error("ModelContext not configured")
            throw CacheError.notConfigured
        }
        
        logger.info("Starting cache update with \(buildings.count) buildings")
        
        // Process buildings in smaller batches to prevent memory issues
        let batchSize = 10
        for i in stride(from: 0, to: buildings.count, by: batchSize) {
            let end = min(i + batchSize, buildings.count)
            let batch = buildings[i..<end]
            
            for building in batch {
                logger.info("Processing building: \(building.name)")
                
                // Check if building already exists in cache
                let buildingId = building.id
                let descriptor = FetchDescriptor<CachedBuilding>(
                    predicate: #Predicate<CachedBuilding> { cached in
                        cached.id == buildingId
                    }
                )
                let existingBuildings = try context.fetch(descriptor)
                let existingBuilding = existingBuildings.first
                
                // Check if we need to update based on cache freshness
                let shouldUpdate = existingBuilding.map { cached -> Bool in
                    guard let lastUpdated = cached.lastUpdated else { return true }
                    return Date().timeIntervalSince(lastUpdated) > cacheExpirationInterval
                } ?? true
                
                if shouldUpdate {
                    async let roomsTask = supabase.getRooms(buildingId: building.id)
                    async let imagesTask = supabase.getBuildingImages(buildingId: building.id)
                    async let ratingsTask = supabase.getBuildingRatings(buildingId: building.id)
                    
                    let (rooms, images, ratings) = try await (roomsTask, imagesTask, ratingsTask)
                    
                    if let existing = existingBuilding {
                        // Update existing building
                        existing.name = building.name
                        existing.buildingDescription = building.description
                        existing.isAvailable = building.isAvailable
                        existing.address = building.address
                        existing.hours = building.hours
                        existing.favorites = building.favorites
                        existing.commentCount = building.commentCount
                        existing.sortedId = building.sortedId
                        existing.lastUpdated = Date()
                        
                        // Update relationships
                        existing.rooms = rooms.map { CachedRoom(from: $0, building: existing) }
                        existing.images = images.map { CachedBuildingImage(from: $0, building: existing) }
                        existing.ratings = ratings.map { CachedBuildingRating(from: $0, building: existing) }
                        
                        logger.info("Updated cached building: \(building.name)")
                    } else {
                        // Create new cached building
                        let cachedBuilding = CachedBuilding(
                            from: building,
                            rooms: rooms,
                            images: images,
                            ratings: ratings
                        )
                        context.insert(cachedBuilding)
                        logger.info("Created new cached building: \(building.name)")
                    }
                    
                    // Save after each building to prevent memory issues
                    try context.save()
                    
                    logger.info("Processed building \(building.name) with \(rooms.count) rooms, \(images.count) images, and \(ratings.count) ratings")
                } else {
                    logger.info("Skipped updating \(building.name) - cache is still fresh")
                }
            }
        }
        
        // Clean up any buildings that no longer exist in the source data
        let allBuildingIds = Set(buildings.map { $0.id })
        let allCachedDescriptor = FetchDescriptor<CachedBuilding>()
        let allCachedBuildings = try context.fetch(allCachedDescriptor)
        
        for cachedBuilding in allCachedBuildings {
            if let id = cachedBuilding.id, !allBuildingIds.contains(id) {
                context.delete(cachedBuilding)
                logger.info("Deleted cached building that no longer exists in source data")
            }
        }
        
        try context.save()
        logger.info("Cache update completed successfully")
    }
    
    func getCurrentTerms() async throws -> [Term] {
        guard let context = modelContext else {
            logger.error("ModelContext not configured")
            throw CacheError.notConfigured
        }
        
        // First try to get from cache
        let now = Date().inChicagoTimeZone
        let descriptor = FetchDescriptor<CachedTerm>(
            predicate: #Predicate<CachedTerm> { term in
                term.startDate <= now && term.endDate >= now
            }
        )
        
        let cachedTerms = try context.fetch(descriptor)
        if !cachedTerms.isEmpty {
            return cachedTerms.map { cachedTerm in
                Term(
                    id: cachedTerm.id,
                    year: cachedTerm.year,
                    term: cachedTerm.term,
                    yearTerm: cachedTerm.yearTerm,
                    partOfTerm: cachedTerm.partOfTerm,
                    startDate: cachedTerm.startDate,
                    endDate: cachedTerm.endDate
                )
            }
        }
        
        // If not in cache, fetch from Supabase and cache them
        let terms = try await supabase.getCurrentTerms()
        if !terms.isEmpty {
            for term in terms {
                let cachedTerm = CachedTerm(from: term)
                context.insert(cachedTerm)
            }
            try context.save()
        }
        
        return terms
    }
    
    func updateTermsCache() async throws {
        guard let context = modelContext else {
            logger.error("ModelContext not configured")
            throw CacheError.notConfigured
        }
        
        // Fetch all terms from Supabase
        let terms = try await supabase.getAllTerms()
        
        // Clear existing terms
        try await clearTermsCache()
        
        // Cache new terms
        for term in terms {
            let cachedTerm = CachedTerm(from: term)
            context.insert(cachedTerm)
        }
        
        try context.save()
        logger.info("Terms cache updated with \(terms.count) terms")
    }
    
    private func clearTermsCache() async throws {
        guard let context = modelContext else {
            logger.error("ModelContext not configured")
            throw CacheError.notConfigured
        }
        
        logger.info("Clearing terms cache...")
        
        let descriptor = FetchDescriptor<CachedTerm>()
        let cachedTerms = try context.fetch(descriptor)
        
        // Delete each term individually
        for term in cachedTerms {
            context.delete(term)
            
            // Save after each deletion to prevent memory issues
            try context.save()
        }
        
        logger.info("Terms cache cleared successfully")
    }
    
    /// Explicitly clear the cache when requested by the user
    func clearCacheOnUserRequest() throws {
        guard let context = modelContext else {
            logger.error("ModelContext not configured")
            throw CacheError.notConfigured
        }
        
        logger.info("User requested cache clear - clearing building cache...")
        
        let descriptor = FetchDescriptor<CachedBuilding>()
        let cachedBuildings = try context.fetch(descriptor)
        
        // Delete each building individually
        for building in cachedBuildings {
            context.delete(building)
            
            // Save after each deletion to prevent memory issues
            try context.save()
        }
        
        logger.info("Building cache cleared successfully on user request")
    }
    
    enum CacheError: Error {
        case notConfigured
    }
}
