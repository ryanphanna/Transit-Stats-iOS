import UIKit

final class ProfileImageManager {
    static let shared = ProfileImageManager()
    private init() {}

    private var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("profile_picture.jpg")
    }

    func save(_ image: UIImage) {
        if let data = image.jpegData(compressionQuality: 0.8) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    func load() -> UIImage? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }

    func delete() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
