import SwiftUI

struct BuildingsGridSection: View {
    let buildings: [BuildingDetails]
    let cardWidth: CGFloat
    let isLoading: Bool
    let hasMoreContent: Bool
    let totalCount: Int
    let onLoadMore: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("All Buildings")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(Color("Text"))
                .padding(.horizontal)
            
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ],
                spacing: 16
            ) {
                ForEach(buildings, id: \.building.id) { details in
                    NavigationLink(destination: BuildingDetailView(buildingDetails: details, userId: nil)) {
                        BuildingCard(buildingDetails: details, userId: nil)
                            .id(details.building.id)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal)
            
            if hasMoreContent {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                }
            }
            
            if buildings.count > 0 {
                Text("\(buildings.count) of \(totalCount) buildings loaded")
                    .font(.caption)
                    .foregroundColor(Color("Text").opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom)
            }
        }
    }
} 