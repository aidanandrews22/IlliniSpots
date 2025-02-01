import SwiftUI

struct BuildingListView: View {
    let buildings: [BuildingDetails]
    let userId: UUID?
    let isLoading: Bool
    let onLoadMore: () -> Void
    let totalBuildings: Int
    let category: String
    let hasMoreData: Bool
    
    private var countText: String {
        let total = category == "All" ? totalBuildings : buildings.count
        let itemType = category == "Libraries" ? "libraries" : "buildings"
        return "\(buildings.count) of \(total) \(itemType) loaded"
    }
    
    private var shouldShowEmptyState: Bool {
        if category == "All" {
            return buildings.isEmpty && !isLoading
        } else {
            // Only show empty state for filtered categories when we've loaded all buildings
            return buildings.isEmpty && !isLoading && !hasMoreData
        }
    }
    
    var body: some View {
        LazyVStack(spacing: 24) {
            if shouldShowEmptyState {
                VStack(spacing: 16) {
                    Image(systemName: getEmptyStateIcon())
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text(getEmptyStateMessage())
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
            }
            
            ForEach(buildings, id: \.building.id) { building in
                NavigationLink(destination: BuildingDetailView(buildingDetails: building, userId: userId)) {
                    BuildingCard(buildingDetails: building, userId: userId)
                        .padding(.horizontal)
                }
                .buttonStyle(PlainButtonStyle())
                .onAppear {
                    if building == buildings.last {
                        onLoadMore()
                    }
                }
                .transition(.opacity)
                .animation(.easeInOut, value: building.images)
            }
            
            if isLoading {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Loading buildings...")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
            
            if !buildings.isEmpty {
                Text(countText)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
            }
        }
        .padding(.vertical, 16)
    }
    
    private func getEmptyStateIcon() -> String {
        switch category {
        case "Available":
            return "door.left.hand.closed"
        case "Favorites":
            return "heart"
        case "Libraries":
            return "books.vertical"
        default:
            return "building.2"
        }
    }
    
    private func getEmptyStateMessage() -> String {
        switch category {
        case "Available":
            return "No buildings are currently available.\nCheck back later!"
        case "Favorites":
            return "You haven't added any favorites yet.\nTap the heart icon on buildings to add them here!"
        case "Libraries":
            return "No libraries found."
        default:
            return "No buildings found."
        }
    }
}