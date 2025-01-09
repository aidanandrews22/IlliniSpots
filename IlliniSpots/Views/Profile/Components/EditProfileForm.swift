import SwiftUI

struct EditProfileForm: View {
    @Binding var firstName: String
    @Binding var lastName: String
    @Binding var email: String
    let onSave: () async -> Void
    let onCancel: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Edit Profile")
                .font(.title)
                .foregroundColor(Color("Text"))
            
            TextField("First Name", text: $firstName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            TextField("Last Name", text: $lastName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            TextField("Email", text: $email)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
            
            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .foregroundColor(Color("Primary"))
                
                Spacer()
                
                Button("Save") {
                    Task {
                        await onSave()
                    }
                }
                .foregroundColor(Color("Primary"))
            }
            .padding(.top)
        }
        .padding()
    }
}

#Preview {
    EditProfileForm(
        firstName: .constant("John"),
        lastName: .constant("Doe"),
        email: .constant("john@example.com"),
        onSave: { },
        onCancel: { }
    )
} 