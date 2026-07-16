import SwiftUI

struct ProfileAvatarView: View {
    let photoData: Data?
    let initials: String
    var size: CGFloat = 44

    var body: some View {
        Group {
            if let photoData, let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Circle().fill(Color.accentColor.gradient)
                    Text(initials)
                        .font(.system(size: size * 0.38, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: 12) {
        ProfileAvatarView(photoData: nil, initials: "MK")
        ProfileAvatarView(photoData: nil, initials: "MK", size: 72)
    }
    .padding()
}
