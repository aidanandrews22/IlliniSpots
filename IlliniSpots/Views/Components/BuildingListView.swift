import SwiftUI

struct BuildingListView: View {
    let buildings: [BuildingDetails]
    let userId: UUID?
    let isLoading: Bool
    let onLoadMore: () -> Void
    
    var body: some View {
        LazyVStack(spacing: 24) {
            ForEach(buildings, id: \.building.id) { building in
                BuildingCard(buildingDetails: building, userId: userId)
                    .padding(.horizontal)
                    .onAppear {
                        if building == buildings.last {
                            onLoadMore()
                        }
                    }
                    .transition(.opacity)
                    .animation(.easeInOut, value: building.images)
            }
            
            if isLoading {
                ProgressView()
                    .padding()
            }
        }
        .padding(.vertical, 16)
    }
} 