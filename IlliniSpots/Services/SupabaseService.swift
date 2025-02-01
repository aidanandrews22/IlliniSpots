import Foundation
import Supabase

class SupabaseService {
    static let shared = SupabaseService()
    private let client: SupabaseClient
    
    private init() {
        // Initialize Supabase client with project URL and anon key
        client = SupabaseClient(
            supabaseURL: URL(string: "https://yacxrjflvkqotooujcbb.supabase.co")!,
            supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlhY3hyamZsdmtxb3Rvb3VqY2JiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzQxMTI5ODEsImV4cCI6MjA0OTY4ODk4MX0.Wr305nlT-jg0LvxX2nCOm2UHOSPwuYSiJHCaAVw2Djk"
        )
    }
    
    func createOrUpdateUser(icloudId: String, email: String? = nil, firstName: String? = nil, lastName: String? = nil) async throws -> User {
        // First try to get existing user
        if let existingUser = try await getUser(icloudId: icloudId) {
            // If we have new profile data, update it
            if let email = email {
                try await updateProfile(
                    id: existingUser.profileId,
                    firstName: firstName,
                    lastName: lastName,
                    email: email
                )
            }
            return existingUser
        }
        
        // Create profile first with required email
        let profile = try await createProfile(email: email ?? "pending@illinispots.com", firstName: firstName, lastName: lastName)
        
        // Create user with the generated profile ID
        let newUser = try await client.from("users")
            .insert([
                "icloud_id": icloudId,
                "profile_id": profile.id.uuidString
            ])
            .select()
            .single()
            .execute()
            .value as User
        
        return newUser
    }
    
    func updateProfile(id: UUID, firstName: String?, lastName: String?, email: String) async throws {
        var updateData: [String: String] = [:]
        
        if let firstName = firstName {
            updateData["first_name"] = firstName
        }
        if let lastName = lastName {
            updateData["last_name"] = lastName
        }
        updateData["email"] = email
        
        try await client.from("profiles")
            .update(updateData)
            .eq("id", value: id.uuidString)
            .execute()
    }
    
    private func createProfile(email: String, firstName: String? = nil, lastName: String? = nil) async throws -> Profile {
        let profile = try await client.from("profiles")
            .insert([
                "email": email,
                "first_name": firstName,
                "last_name": lastName
            ])
            .select()
            .single()
            .execute()
            .value as Profile
        
        return profile
    }
    
    func getUser(icloudId: String) async throws -> User? {
        do {
            let user = try await client.from("users")
                .select()
                .eq("icloud_id", value: icloudId)
                .single()
                .execute()
                .value as User
            return user
        } catch {
            return nil
        }
    }
    
    func getProfile(id: UUID) async throws -> Profile? {
        do {
            let profile = try await client.from("profiles")
                .select()
                .eq("id", value: id.uuidString)
                .single()
                .execute()
                .value as Profile
            return profile
        } catch {
            return nil
        }
    }
    
    // MARK: - Building Methods
    func getAllBuildings(limit: Int = 25, offset: Int = 0) async throws -> [Building] {
        let buildings = try await client.from("buildings")
            .select()
            .order("sorted_id")
            .range(from: offset, to: offset + limit - 1)
            .execute()
            .value as [Building]
        return buildings
    }
    
    func getTotalBuildingCount() async throws -> Int {
        let response = try await client.from("buildings")
            .select("*", count: .exact)
            .execute()
        return response.count ?? 0
    }
    
    func getBuildingImages(buildingId: Int64) async throws -> [BuildingImage] {
        let images = try await client.from("building_images")
            .select()
            .eq("building_id", value: String(buildingId))
            .order("display_order")
            .execute()
            .value as [BuildingImage]
        
        // Sort images: primary first, then by display order
        return images.sorted { first, second in
            // Primary images come first
            if first.isPrimary == true && second.isPrimary != true {
                return true
            }
            if second.isPrimary == true && first.isPrimary != true {
                return false
            }
            // Then sort by display order
            return (first.displayOrder ?? 0) < (second.displayOrder ?? 0)
        }
    }
    
    func getUserBuildingFavorites(userId: UUID) async throws -> [BuildingFavorite] {
        do {
            let favorites = try await client.from("building_favorites")
                .select()
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value as [BuildingFavorite]
            return favorites
        } catch {
            return []
        }
    }
    
    func getRooms(buildingId: Int64) async throws -> [Room] {
//        logger.info("Fetching rooms for building ID: \(buildingId)")
        let rooms = try await client.from("rooms")
            .select()
            .eq("building_id", value: String(buildingId))
            .execute()
            .value as [Room]
//        logger.info("Found \(rooms.count) rooms for building ID: \(buildingId)")
        return rooms
    }

    // In-memory dictionary to cache BuildingDetails for quick lookups.
    private var buildingDetailsCache = [Int64: BuildingDetails]()
    
    func getAllBuildingsWithDetails(
        limit: Int = 25,
        offset: Int = 0,
        userId: UUID? = nil,
        onBuildingReady: ((BuildingDetails) -> Void)? = nil
    ) async throws -> [BuildingDetails] {
        print("\n📚 Starting batch load with concurrency: Offset \(offset), Limit \(limit)")
        
        let buildings = try await getAllBuildings(limit: limit, offset: offset)
        print("📋 Found \(buildings.count) buildings to load")

        var results = [BuildingDetails]()

        try await withThrowingTaskGroup(of: BuildingDetails.self) { group in
            for building in buildings {
                // If we have a cached BuildingDetails, skip additional fetch
                if let cachedDetails = buildingDetailsCache[building.id] {
                    results.append(cachedDetails)
                    onBuildingReady?(cachedDetails)
                    continue
                }

                group.addTask {
                    // Check open/closed status
                    let (isOpen, _) = self.getBuildingAvailability(
                        buildingId: building.id,
                        hours: building.hours ?? ""
                    )
                    
                    // Fetch room info in parallel
                    async let roomsTask = self.getRoomCounts(buildingId: building.id)
                    async let ratingsTask = self.getBuildingRatings(buildingId: building.id)
                    async let imagesTask = self.getBuildingImages(buildingId: building.id)

                    // Check if user has favorited
                    var isFavorited = false
                    if let userId = userId {
                        let favorites = try await self.getUserBuildingFavorites(userId: userId)
                        isFavorited = favorites.contains { $0.buildingId == building.id }
                    }

                    // Await data
                    let (totalRooms, actualAvailableRooms) = try await roomsTask
                    let ratings = try await ratingsTask
                    let images = try await imagesTask

                    // Use actualAvailableRooms
                    let details = BuildingDetails(
                        building: building,
                        isOpen: isOpen,
                        totalRooms: totalRooms,
                        availableRooms: isOpen ? actualAvailableRooms : 0,
                        ratings: ratings,
                        images: images,
                        isFavorited: isFavorited
                    )
                    return details
                }
            }

            // Collect results
            for try await details in group {
                self.buildingDetailsCache[details.building.id] = details
                results.append(details)
                onBuildingReady?(details)
            }
        }

        // Sort by sortedId so "All" is in the correct order
        results.sort { ($0.building.sortedId ?? 0) < ($1.building.sortedId ?? 0) }

        print("\n✅ Batch complete: \(results.count) buildings loaded\n")
        return results
    }

    // New function to get room counts
    private func getRoomCounts(buildingId: Int64) async throws -> (total: Int, available: Int) {
        // Get all rooms for the building
        let rooms = try await client.from("rooms")
            .select()
            .eq("building_id", value: String(buildingId))
            .execute()
            .value as [Room]
            
        let totalRooms = rooms.count
        let availableRooms = try await getRoomAvailability(buildingId: buildingId)
        
        return (totalRooms, availableRooms)
    }
    
    func getBuildingDetailsWithLogging(buildingId: Int64, userId: UUID? = nil) async throws -> BuildingDetails {
        print("🏛️ Fetching details for building ID: \(buildingId)")
        
        // Fetch building
        let building = try await client.from("buildings")
            .select()
            .eq("id", value: String(buildingId))
            .single()
            .execute()
            .value as Building
        print("📍 Building basic info retrieved: \(building.name)")
        
        // Get building availability status
        let (isOpen, _) = getBuildingAvailability(buildingId: building.id, hours: building.hours ?? "")
        print("🕒 Building is currently \(isOpen ? "OPEN" : "CLOSED")")
        print("🕐 Current hours: \(building.hours ?? "No hours available")")
        
        // Get room availability
        async let roomsTask = getRoomCounts(buildingId: building.id)
        print("🔍 Checking room availability...")
        
        // Get ratings
        async let ratingsTask = getBuildingRatings(buildingId: building.id)
        print("⭐️ Fetching ratings...")
        
        // Get images
        async let imagesTask = getBuildingImages(buildingId: building.id)
        print("🖼️ Loading images...")
        
        // Check if favorited
        var isFavorited = false
        if let userId = userId {
            let favorites = try await getUserBuildingFavorites(userId: userId)
            isFavorited = favorites.contains { $0.buildingId == building.id }
            print("❤️ Favorite status: \(isFavorited ? "Favorited" : "Not favorited")")
        }
        
        let (totalRooms, availableRooms) = try await roomsTask
        print("📊 Room availability: \(availableRooms)/\(totalRooms) rooms available")
        
        let ratings = try await ratingsTask
        if !ratings.isEmpty {
            let avgRating = Double(ratings.map { Int($0.rating) }.reduce(0, +)) / Double(ratings.count)
            print("⭐️ Average rating: \(String(format: "%.1f", avgRating)) (\(ratings.count) ratings)")
        } else {
            print("⭐️ No ratings available")
        }
        
        let images = try await imagesTask
        print("🖼️ Found \(images.count) images")
        
        let details = BuildingDetails(
            building: building,
            isOpen: isOpen,
            totalRooms: totalRooms,
            availableRooms: availableRooms,
            ratings: ratings,
            images: images,
            isFavorited: isFavorited
        )
        
        print("✅ Successfully compiled building details for: \(building.name)")
        return details
    }
    
    func getBuildingRatingDetails(buildingId: Int64) async throws -> (average: Double?, count: Int) {
        print("⭐️ Fetching rating details for building ID: \(buildingId)")
        
        let ratings = try await getBuildingRatings(buildingId: buildingId)
        let count = ratings.count
        
        guard count > 0 else {
            print("ℹ️ No ratings found for building")
            return (nil, 0)
        }
        
        let sum = ratings.reduce(0.0) { $0 + Double($1.rating) }
        let average = sum / Double(count)
        
        print("📊 Rating summary:")
        print("   - Total ratings: \(count)")
        print("   - Average rating: \(String(format: "%.2f", average))")
        
        // Log distribution of ratings
        let distribution = Dictionary(grouping: ratings) { $0.rating }
            .mapValues { $0.count }
            .sorted { $0.key > $1.key }
        
        print("📈 Rating distribution:")
        distribution.forEach { rating, count in
            let percentage = Double(count) / Double(ratings.count) * 100
            print("   - \(rating) stars: \(count) (\(String(format: "%.1f", percentage))%)")
        }
        
        return (average, count)
    }
}

// MARK: - Models
struct User: Codable {
    let id: UUID
    let icloudId: String
    let profileId: UUID
    
    enum CodingKeys: String, CodingKey {
        case id
        case icloudId = "icloud_id"
        case profileId = "profile_id"
    }
}

struct Profile: Codable {
    let id: UUID
    let firstName: String?
    let lastName: String?
    let email: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case firstName = "first_name"
        case lastName = "last_name"
        case email
    }
}

// Update Building to be a class
final class Building: Codable, Identifiable, Equatable {
    let id: Int64
    let name: String
    let description: String?
    let isAvailable: Bool?
    let address: String?
    let hours: String?
    let favorites: Int16
    let commentCount: Int16
    let sortedId: Int?
    
    init(id: Int64, name: String, description: String?, isAvailable: Bool?, address: String?, hours: String?, favorites: Int16, commentCount: Int16, sortedId: Int?) {
        self.id = id
        self.name = name
        self.description = description
        self.isAvailable = isAvailable
        self.address = address
        self.hours = hours
        self.favorites = favorites
        self.commentCount = commentCount
        self.sortedId = sortedId
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, address, hours
        case isAvailable = "is_available"
        case favorites, commentCount = "comment_count"
        case sortedId = "sorted_id"
    }
    
    static func == (lhs: Building, rhs: Building) -> Bool {
        lhs.id == rhs.id
    }
}

struct BuildingImage: Codable, Identifiable, Equatable {
    let id: Int64
    let buildingId: Int64
    let url: String
    let displayOrder: Int?
    let isPrimary: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id, url
        case buildingId = "building_id"
        case displayOrder = "display_order"
        case isPrimary = "is_primary"
    }
}

struct BuildingFavorite: Codable, Identifiable {
    let id: Int64
    let userId: UUID
    let buildingId: Int64
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case buildingId = "building_id"
    }
}

// MARK: - Building Ratings
struct BuildingRating: Codable, Identifiable, Equatable {
    let id: Int64
    let userId: UUID
    let buildingId: Int64
    let rating: Int16
    let comment: String?
    
    enum CodingKeys: String, CodingKey {
        case id, rating, comment
        case userId = "user_id"
        case buildingId = "building_id"
    }
}

@Observable class BuildingDetails: Equatable {
    let building: Building
    let isOpen: Bool
    let totalRooms: Int
    let availableRooms: Int
    private(set) var ratings: [BuildingRating]
    private(set) var images: [BuildingImage]
    private(set) var isFavorited: Bool
    
    init(building: Building, isOpen: Bool, totalRooms: Int, availableRooms: Int, ratings: [BuildingRating], images: [BuildingImage], isFavorited: Bool) {
        self.building = building
        self.isOpen = isOpen
        self.totalRooms = totalRooms
        self.availableRooms = availableRooms
        self.ratings = ratings
        self.images = images
        self.isFavorited = isFavorited
    }
    
    static func == (lhs: BuildingDetails, rhs: BuildingDetails) -> Bool {
        lhs.building.id == rhs.building.id
    }
    
    func update(ratings: [BuildingRating]? = nil, images: [BuildingImage]? = nil, isFavorited: Bool? = nil) {
        if let ratings = ratings {
            self.ratings = ratings
        }
        if let images = images {
            self.images = images
        }
        if let isFavorited = isFavorited {
            self.isFavorited = isFavorited
        }
    }
}

extension SupabaseService {
    // MARK: - Building Ratings Methods
    func getBuildingRatings(buildingId: Int64) async throws -> [BuildingRating] {
        do {
            let ratings = try await client.from("building_ratings")
                .select()
                .eq("building_id", value: String(buildingId))
                .execute()
                .value as [BuildingRating]
            return ratings
        } catch {
            return []
        }
    }
    
    func toggleBuildingFavorite(userId: UUID, buildingId: Int64) async throws {
        // Check if favorite exists
        let existingFavorites = try await client.from("building_favorites")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("building_id", value: String(buildingId))
            .execute()
            .value as [BuildingFavorite]
        
        if existingFavorites.isEmpty {
            // Add favorite
            try await client.from("building_favorites")
                .insert(["user_id": userId.uuidString,
                        "building_id": String(buildingId)])
                .execute()
            
            // Increment favorites count
            try await client.from("buildings")
                .update(["favorites": "favorites + 1"])
                .eq("id", value: String(buildingId))
                .execute()
        } else {
            // Remove favorite
            try await client.from("building_favorites")
                .delete()
                .eq("user_id", value: userId.uuidString)
                .eq("building_id", value: String(buildingId))
                .execute()
            
            // Decrement favorites count
            try await client.from("buildings")
                .update(["favorites": "favorites - 1"])
                .eq("id", value: String(buildingId))
                .execute()
        }
    }
    
    // MARK: - Building Availability Methods
    func getBuildingAvailability(buildingId: Int64, hours: String?) -> (isOpen: Bool, availableRooms: Int) {
        print("🕒 Checking building availability...")

        // Use the Chicago time zone, ensuring correct local time.
        let calendar = Calendar.current
        let localNow = Date().inChicagoTimeZone
        let weekday = calendar.component(.weekday, from: localNow)
        let currentTime = calendar.component(.hour, from: localNow) * 60 + calendar.component(.minute, from: localNow)

        guard let hours = hours else {
            print("⚠️ No hours data available - marking as closed")
            return (false, 0)
        }

        let hoursArray = hours.components(separatedBy: "; ")
        // Map Sunday (=1) to the last index in an array that starts with Monday
        // Monday=2 -> index 0, Tuesday=3 -> index 1, ..., Sunday=1 -> index 6
        let dayIndex = (weekday + 5) % 7
        guard dayIndex < hoursArray.count else {
            print("❌ Invalid weekday for hours data")
            return (false, 0)
        }

        let originalTodayHours = hoursArray[dayIndex]
        print("📅 Current weekday: \(weekday)")
        print("⏰ Current time (in minutes since midnight): \(currentTime)")
        print("📋 Today's hours: \(originalTodayHours)")

        // Normalize fancy dash/whitespace
        let todayHours = originalTodayHours
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: " ", with: " ")
            .replacingOccurrences(of: " ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if todayHours.contains("Closed") {
            print("🚫 Building is closed today")
            return (false, 0)
        }

        // Check for 24-hour operation
        if todayHours.contains("Open 24 hours") {
            print("🕐 Building is open 24 hours")
            return (true, 1)
        }
        
        // Example format after cleaning might look like:
        //   "Monday: 6:00 AM - 11:00 PM"
        // We split off the "Monday:" portion, then split by " - "
        let components = todayHours.components(separatedBy: ": ")
        guard components.count > 1 else {
            print("❌ Invalid hours format")
            return (false, 0)
        }
        
        // The time range should be something like "6:00 AM - 11:00 PM"
        let hourString = components[1]
        let timeRange = hourString.components(separatedBy: " - ")
        guard timeRange.count == 2 else {
            print("❌ Invalid time range format")
            print("Time components: \(timeRange)")
            return (false, 0)
        }
        
        // New fallback logic if the open portion lacks AM/PM but the close portion has it
        var openPart = timeRange[0].trimmingCharacters(in: .whitespaces)
        var closePart = timeRange[1].trimmingCharacters(in: .whitespaces)
        
        let openHasSuffix = openPart.hasSuffix("AM") || openPart.hasSuffix("PM")
        let closeHasSuffix = closePart.hasSuffix("AM") || closePart.hasSuffix("PM")
        
        if !openHasSuffix && closeHasSuffix {
            if closePart.hasSuffix("AM") {
                openPart += " AM"
            } else if closePart.hasSuffix("PM") {
                openPart += " PM"
            }
        }
        
        guard let openTime = timeStringToMinutes(openPart),
              var closeTime = timeStringToMinutes(closePart) else {
            print("❌ Could not parse open/close times")
            return (false, 0)
        }

        // Handle closing after midnight (e.g., "10:00 AM - 12:00 AM")
        if closeTime < openTime {
            closeTime += 1440 // add 24 hours
        }

        print("🕐 Open time (in minutes): \(openTime)")
        print("🕐 Close time (in minutes): \(closeTime)")
        print("🕐 Current time (in minutes): \(currentTime)")

        let isOpen = currentTime >= openTime && currentTime <= closeTime
        print(isOpen ? "✅ Building is currently OPEN" : "🚫 Building is currently CLOSED")

        return (isOpen, isOpen ? 1 : 0)
    }
    
    private func timeStringToMinutes(_ timeString: String) -> Int? {
        let components = timeString.components(separatedBy: " ")
        guard components.count == 2 else { return nil }
        
        let timeComponents = components[0].components(separatedBy: ":")
        guard timeComponents.count == 2,
              var hours = Int(timeComponents[0]),
              let minutes = Int(timeComponents[1]) else {
            return nil
        }
        
        if components[1] == "PM" && hours != 12 {
            hours += 12
        } else if components[1] == "AM" && hours == 12 {
            hours = 0
        }
        
        return hours * 60 + minutes
    }
    
    func getCurrentTerms() async throws -> [Term] {
        let now = Date().inChicagoTimeZone
        let calendar = Date.chicagoCalendar
        
        do {
            let terms = try await client.from("terms")
                .select()
                .order("start_date")
                .execute()
                .value as [Term]
            
            // Find all terms that contain the current date
            return terms.filter { term in
                let startDate = term.startDate.inChicagoTimeZone
                let endDate = term.endDate.inChicagoTimeZone
                
                // Adjust end date to end of day
                let adjustedEndDate = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endDate) ?? endDate
                
                return now >= startDate && now <= adjustedEndDate
            }
        } catch {
            print("Error fetching terms: \(error)")
            return []
        }
    }
    
    func getAllTerms() async throws -> [Term] {
        let terms = try await client.from("terms")
            .select()
            .order("start_date")
            .execute()
            .value as [Term]
        return terms
    }
    
    // MARK: - Room Availability Methods
    func getRoomAvailability(buildingId: Int64) async throws -> Int {
        print("🔄 Starting room availability check for building ID: \(buildingId)")
        
        let currentTerms = try await BuildingCacheService.shared.getCurrentTerms()
        guard !currentTerms.isEmpty else {
            print("⚠️ No current terms found - returning 0 available rooms")
            return 0
        }
        
        let termIds = currentTerms.map { String($0.id) }
        print("📅 Current terms: \(currentTerms.map { "\($0.term) \($0.year) (\($0.partOfTerm))" }.joined(separator: ", "))")
        
        let calendar = Date.chicagoCalendar
        let now = Date().inChicagoTimeZone
        let currentWeekday = calendar.component(.weekday, from: now)
        let weekdayString = weekdayToString(currentWeekday)
        print("📆 Current day: \(weekdayString)")
        
        // Get current time in HH:mm:ss format
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        formatter.timeZone = Date.chicagoTimeZone
        let currentTimeString = formatter.string(from: now)
        print("⏰ Current time: \(currentTimeString)")
        
        // Get all rooms for the building
        let rooms = try await client.from("rooms")
            .select()
            .eq("building_id", value: String(buildingId))
            .execute()
            .value as [Room]
        
        print("🏢 Total rooms found: \(rooms.count)")
        
        var availableRooms = rooms.count
        var occupiedRooms: [String] = []
        
        // Check each room's events across all current terms
        for room in rooms {
            let events = try await client.from("events")
                .select()
                .eq("room_id", value: String(room.id))
                .in("term_id", values: termIds)
                .lte("start_time", value: currentTimeString)
                .gte("end_time", value: currentTimeString)
                .like("days_of_week", pattern: "%\(weekdayString)%")
                .execute()
                .value as [Event]
            
            if !events.isEmpty {
                availableRooms -= 1
                let termInfo = currentTerms.first { $0.id == events[0].termId }?.partOfTerm ?? "unknown"
                occupiedRooms.append("\(room.roomNumber) (\(events[0].name) - \(termInfo))")
            }
        }
        
        print("📊 Room availability summary:")
        print("   - Total rooms: \(rooms.count)")
        print("   - Available rooms: \(availableRooms)")
        print("   - Occupied rooms: \(rooms.count - availableRooms)")
        
        if !occupiedRooms.isEmpty {
            print("🚫 Currently occupied rooms:")
            occupiedRooms.forEach { print("   - \($0)") }
        }
        
        return availableRooms
    }
    
    private func weekdayToString(_ weekday: Int) -> String {
        switch weekday {
        case 1: return "U"
        case 2: return "M"
        case 3: return "T"
        case 4: return "W"
        case 5: return "R"
        case 6: return "F"
        case 7: return "S"
        default: return ""
        }
    }
}

// MARK: - Additional Models
struct Term: Codable, Identifiable {
    let id: Int64
    let year: Int
    let term: String
    let yearTerm: String
    let partOfTerm: String
    let startDate: Date
    let endDate: Date
    
    enum CodingKeys: String, CodingKey {
        case id, year, term
        case yearTerm = "year_term"
        case partOfTerm = "part_of_term"
        case startDate = "start_date"
        case endDate = "end_date"
    }
}

struct Room: Codable, Identifiable {
    let id: Int64
    let buildingId: Int64
    let roomNumber: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case buildingId = "building_id"
        case roomNumber = "room_number"
    }
}

struct Event: Codable, Identifiable {
    let id: Int64
    let roomId: Int64
    let termId: Int64
    let name: String
    let startTime: String
    let endTime: String
    let daysOfWeek: String
    
    enum CodingKeys: String, CodingKey {
        case id, name
        case roomId = "room_id"
        case termId = "term_id"
        case startTime = "start_time"
        case endTime = "end_time"
        case daysOfWeek = "days_of_week"
    }
}

// Helper extension for Date
extension Date {
    var iso8601String: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: self)
    }
    
    static var chicagoTimeZone: TimeZone {
        TimeZone(identifier: "America/Chicago") ?? .current
    }
    
    static var chicagoCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = chicagoTimeZone
        return calendar
    }
    
    var inChicagoTimeZone: Date {
        let calendar = Date.chicagoCalendar
        let components = calendar.dateComponents(in: Date.chicagoTimeZone, from: self)
        return calendar.date(from: components) ?? self
    }
}
