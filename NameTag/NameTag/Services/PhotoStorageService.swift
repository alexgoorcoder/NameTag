import Foundation
import UIKit

@Observable
final class PhotoStorageService {
    let photosDirectory: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        photosDirectory = docs.appendingPathComponent("photos", isDirectory: true)
        try? FileManager.default.createDirectory(at: photosDirectory, withIntermediateDirectories: true)
    }

    /// Save a profile photo locally, returns the filename
    func savePhoto(uid: String, image: UIImage) throws -> String {
        let resized = resizeImage(image, maxDimension: 500)
        guard let data = resized.jpegData(compressionQuality: 0.7) else {
            throw PhotoStorageError.compressionFailed
        }
        let filename = "\(uid).jpg"
        let url = photosDirectory.appendingPathComponent(filename)
        try data.write(to: url)
        return filename
    }

    /// Compress photo for BLE transfer (~10-30KB)
    func compressForBLE(image: UIImage) -> Data? {
        let tiny = resizeImage(image, maxDimension: 150)
        return tiny.jpegData(compressionQuality: 0.3)
    }

    /// Save photo received via BLE from a contact
    func saveReceivedPhoto(uid: String, data: Data) throws -> String {
        let filename = "\(uid).jpg"
        let url = photosDirectory.appendingPathComponent(filename)
        try data.write(to: url)
        return filename
    }

    /// Get the file URL for a photo filename
    func photoURL(for filename: String) -> URL {
        photosDirectory.appendingPathComponent(filename)
    }

    /// Load UIImage from filename
    func loadImage(filename: String) -> UIImage? {
        let url = photosDirectory.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    /// Load compressed photo data for BLE transfer
    func loadPhotoDataForBLE(filename: String) -> Data? {
        guard let image = loadImage(filename: filename) else { return nil }
        return compressForBLE(image: image)
    }

    func deletePhoto(filename: String) {
        let url = photosDirectory.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
    }

    func deleteAllPhotos() {
        try? FileManager.default.removeItem(at: photosDirectory)
        try? FileManager.default.createDirectory(at: photosDirectory, withIntermediateDirectories: true)
    }

    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        guard size.width > maxDimension || size.height > maxDimension else { return image }

        let ratio = min(maxDimension / size.width, maxDimension / size.height)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

enum PhotoStorageError: LocalizedError {
    case compressionFailed

    var errorDescription: String? {
        switch self {
        case .compressionFailed: return "Failed to compress image"
        }
    }
}
