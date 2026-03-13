import SwiftUI

struct AsyncProfileImage: View {
    let photoFileName: String?

    var body: some View {
        if let filename = photoFileName, let image = loadImage(filename: filename) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            placeholder
        }
    }

    private func loadImage(filename: String) -> UIImage? {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docs.appendingPathComponent("photos").appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    private var placeholder: some View {
        Rectangle()
            .fill(.quaternary)
            .overlay {
                Image(systemName: "person.fill")
                    .font(.title)
                    .foregroundStyle(.secondary)
            }
    }
}
