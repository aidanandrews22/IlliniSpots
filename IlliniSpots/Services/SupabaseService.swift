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
    func getAllBuildings() async throws -> [Building] {
        let buildings = try await client.from("buildings")
            .select()
            .order("sorted_id")
            .execute()
            .value as [Building]
        return buildings
    }
    
    func getBuildingImages(buildingId: Int64) async throws -> [BuildingImage] {
        let images = try await client.from("building_images")
            .select()
            .eq("building_id", value: String(buildingId))
            .order("display_order")
            .execute()
            .value as [BuildingImage]
        return images
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

struct Building: Codable, Identifiable {
    let id: Int64
    let name: String
    let description: String?
    let isAvailable: Bool?
    let address: String?
    let hours: String?
    let favorites: Int16
    let commentCount: Int16
    let sortedId: Int?
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, address, hours
        case isAvailable = "is_available"
        case favorites, commentCount = "comment_count"
        case sortedId = "sorted_id"
    }
}

struct BuildingImage: Codable, Identifiable {
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
