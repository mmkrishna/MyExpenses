import PhotosUI
import SwiftUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(UserProfileViewModel.self) private var profile

    @State private var draftName: String = ""
    @State private var draftPhotoData: Data?
    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    ZStack(alignment: .bottomTrailing) {
                        ProfileAvatarView(photoData: draftPhotoData, initials: initials, size: 96)
                        ZStack {
                            Circle().fill(Color.accentColor)
                            Image(systemName: "camera.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                        }
                        .frame(width: 28, height: 28)
                    }
                }
                .accessibilityLabel("Change profile photo")
                .padding(.top, 24)

                VStack(spacing: 0) {
                    TextField("Your Name", text: $draftName)
                        .font(.body)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                }
                .cardStyle(padding: 0)

                if draftPhotoData != nil {
                    Button(role: .destructive) {
                        draftPhotoData = nil
                        pickerItem = nil
                    } label: {
                        Text("Remove Photo")
                    }
                }

                Spacer()
            }
            .padding()
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        profile.name = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
                        profile.photoData = draftPhotoData
                        Haptics.success()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                draftName = profile.name
                draftPhotoData = profile.photoData
            }
            .task(id: pickerItem) {
                guard let pickerItem, let data = try? await pickerItem.loadTransferable(type: Data.self) else { return }
                draftPhotoData = data
            }
        }
    }

    private var initials: String {
        let parts = draftName.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first }
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }
}

#Preview {
    EditProfileView()
        .environment(UserProfileViewModel())
}
