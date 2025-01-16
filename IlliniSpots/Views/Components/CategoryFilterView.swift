import SwiftUI

struct CategoryFilterView: View {
    let categories: [String]
    @Binding var selectedCategory: String
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 32) {
                ForEach(categories, id: \.self) { category in
                    CategoryButton(
                        category: category,
                        isSelected: selectedCategory == category,
                        action: {
                            withAnimation(.easeInOut) {
                                selectedCategory = category
                            }
                        }
                    )
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
}

struct CategoryButton: View {
    let category: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            Text(category)
                .font(.system(size: 16))
                .foregroundColor(isSelected ? .black : .gray)
            
            Rectangle()
                .frame(height: 2)
                .foregroundColor(isSelected ? .black : .clear)
        }
        .onTapGesture(perform: action)
    }
} 